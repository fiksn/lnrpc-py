{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    googleapis = { url = "github:googleapis/googleapis"; flake = false; };
    lnrpc = { url = "github:lightningnetwork/lnd?lnrpc"; flake = false; };
  };

  outputs = { self, nixpkgs, flake-utils, lnrpc, googleapis }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        registry = "fiksn/lnrpc-py";
        pythonPackages = pkgs.python39Packages;
        pythonBin = pkgs.python39;
        test_imports = pkgs.writeTextFile {
          name = "test_imports.py";
          text = ''
            import lightning_pb2 as ln
            import lightning_pb2_grpc as lnrpc
            import chainnotifier_pb2 as chainnotifier
            import chainnotifier_pb2_grpc as chainnotifier_grpc
            import router_pb2 as router
            import router_pb2_grpc as router_grpc
            import invoices_pb2 as invoices
            import invoices_pb2_grpc as invoices_grpc

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
              cp -f ${lnrpc}/lnrpc/invoicesrpc/invoices.proto .
              for i in *.proto; do python -m grpc_tools.protoc --proto_path=${googleapis}:. --python_out=. --grpc_python_out=. $i; done
              rm -rf *.proto
            '';
          };

          lnrpc-py-docker = pkgs.dockerTools.buildImage {
            name = registry;
            tag = "latest";
            contents = [ packages.lnrpc-py pkgs.busybox ];
            config = {
              Cmd = [ "/bin/sh" ];
              WorkingDir = "${packages.lnrpc-py}";
            };
          };

          # Fake derivation used for its side effects (bad)
          pushDocker = pkgs.stdenv.mkDerivation {
            name = "pushDocker";

            buildInputs = [ pkgs.crane pkgs.gzip pkgs.util-linux ];

            phases = [ "buildPhase" ];

            buildPhase =
              let
                docker_user = pkgs.lib.maybeEnv "DOCKER_USER" "";
                docker_pass = pkgs.lib.maybeEnv "DOCKER_PASS" "";
              in
              pkgs.lib.optionalString
                (docker_user != "" && docker_pass != "")
                ''
                  export HOME=$out
                  echo "Authenticating to registry as user ${docker_user}..."
                  actual=$(echo ${registry} | cut -d"/" -f1)
                  # When there is no dot default to docker hub
                  echo $actual | grep -vq '\.' && actual="index.docker.io"
                  crane auth login -u ${docker_user} -p ${docker_pass} $actual || true
                '' + ''
                # Crane wants .tar
                cp -f ${packages.lnrpc-py-docker} .
                base=$(basename ${packages.lnrpc-py-docker})
                name=$(echo $base | rev | cut -d"." -f2- | rev)
                rm -rf $name
                gunzip $base
                # can't use parameter expansion since $ { } is nix magic
 
                echo "crane push $name ${registry}"
                crane push $name ${registry}
                rm -rf $name
                rm -rf $out/.docker
                echo "done" > $out/data
              '';
          };
        };

        defaultPackage = packages.lnrpc-py;

        devShell = pkgs.mkShell {
          buildInputs = with pythonPackages; [ packages.lnrpc-py protobuf grpcio ];

          shellHook = ''
            PYTHONPATH=$PYTHONPATH:${packages.lnrpc-py}
            python ${test_imports} || exit 1
            echo "The built packages are available under ${packages.lnrpc-py}"
          '';
        };


      });
}
