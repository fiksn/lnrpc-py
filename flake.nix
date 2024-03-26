{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    googleapis = { url = "github:googleapis/googleapis"; flake = false; };
    lnrpc = { url = "github:lightningnetwork/lnd?lnrpc"; flake = false; };
  };

  outputs = { self, nixpkgs, nix2container, flake-utils, lnrpc, googleapis }:
    flake-utils.lib.eachSystem (builtins.filter (x: x != "i686-linux") flake-utils.lib.defaultSystems) (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        nix2containerPkgs = nix2container.packages.${system};

        registry = "fiksn/lnrpc-py";
        isOk = pkg: !pkg.meta.broken && pkg.meta.available;
        pythonBin = pkgs.python311;
        pythonPackages = pythonBin.pkgs;
        test_imports = pkgs.writeTextFile {
          name = "test_imports.py";
          text = ''
            import lightning_pb2 as ln
            import lightning_pb2_grpc as lnrpc
            import chainnotifier_pb2 as chainnotifier
            import chainnotifier_pb2_grpc as chainnotifier_grpc
            import chainkit_pb2 as chainkit
            import chainkit_pb2_grpc as chainkit_grpc
            import router_pb2 as router
            import router_pb2_grpc as router_grpc
            import invoices_pb2 as invoices
            import invoices_pb2_grpc as invoices_grpc
            import peers_pb2 as peers
            import peers_pb2_grpc as peers_grpc
            import signer_pb2 as signer
            import signer_pb2_grpc as signer_grpc
            import dev_pb2 as dev
            import dev_pb2_grpc as dev_grpc

            import grpc
            import os
            import sys

            sys.exit(0)
          '';
        };
      in
      rec {
        packages = flake-utils.lib.flattenTree {
          lnrpc-py = pkgs.stdenv.mkDerivation {
            name = "lnrpc-py";

            phases = [ "buildPhase" ];
            propagatedBuildInputs = with pkgs; with pythonPackages; [ pythonBin grpcio grpcio-tools googleapis-common-protos ];

            buildPhase = ''
              mkdir -p $out
              cd $out
              cp -f ${lnrpc}/lnrpc/lightning.proto .
              cp -f ${lnrpc}/lnrpc/routerrpc/router.proto .
              cp -f ${lnrpc}/lnrpc/chainrpc/chainnotifier.proto .
              cp -f ${lnrpc}/lnrpc/chainrpc/chainkit.proto .
              cp -f ${lnrpc}/lnrpc/invoicesrpc/invoices.proto .
              cp -f ${lnrpc}/lnrpc/peersrpc/peers.proto .
              cp -f ${lnrpc}/lnrpc/signrpc/signer.proto .
              cp -f ${lnrpc}/lnrpc/devrpc/dev.proto .
              cp -f ${lnrpc}/lnrpc/walletrpc/walletkit.proto .
              mkdir -p signrpc ; cp -f signer.proto signrpc/
              for i in *.proto; do python -m grpc_tools.protoc --proto_path=${googleapis}:. --python_out=. --grpc_python_out=. $i; done
              # Just in case anybody wants a better naming
              mkdir grpc_generated
              touch grpc_generated/__init__.py
              for i in *.py; do cp ./$i grpc_generated/$i; done
              rm -rf *.proto
            '';
          };

          # Docker build
          lnrpc-py-docker = nix2containerPkgs.nix2container.buildImage {
            name = registry;
            tag = "latest";
            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [ packages.lnrpc-py ] ++ (if isOk pkgs.busybox then [ pkgs.busybox ] else [ ]);
              pathsToLink = [ "/bin" ];
            };
            config = {
              Cmd = [ "/bin/sh" ];
              WorkingDir = "${packages.lnrpc-py}";
            };
          };

          # Fake derivation used for its side effects (bad)
          pushDocker = pkgs.stdenv.mkDerivation {
            name = "pushDocker";

            buildInputs = [ nix2containerPkgs.skopeo-nix2container ];

            phases = [ "buildPhase" ];

            buildPhase =
              let
                docker_user = pkgs.lib.maybeEnv "DOCKER_USER" "";
                docker_pass = pkgs.lib.maybeEnv "DOCKER_PASS" "";
              in
              ''
                skopeo --insecure-policy copy --retry-times 5 --dest-creds ${docker_user}:${docker_pass} nix:${packages.lnrpc-py-docker} docker://${registry}
                echo "done" > $out
              '';
          };
        };

        defaultPackage = packages.lnrpc-py;

        devShell = pkgs.mkShell {
          buildInputs = with pythonPackages; [ packages.lnrpc-py protobuf grpcio pkgs.pre-commit ] ++ [pythonBin grpcio grpcio-tools googleapis-common-protos];

          shellHook = ''
            PYTHONPATH=$PYTHONPATH:${packages.lnrpc-py}
            python ${test_imports} || exit 1
            echo "The built packages are available under ${packages.lnrpc-py}"
          '';
        };


      });
}
