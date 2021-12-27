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
              python -m grpc_tools.protoc --proto_path=${googleapis}:. --python_out=. --grpc_python_out=. lightning.proto
              python -m grpc_tools.protoc --proto_path=${googleapis}:. --python_out=. --grpc_python_out=. router.proto
              rm -rf *.proto
            '';
          };
        
          lnrpc-py-docker = pkgs.dockerTools.buildImage {
            name = registry;
            tag = "latest";
            # TODO(fiction) - fix me
            fromImage = pkgs.dockerTools.buildImage {
              name = "bash";
              tag = "latest";
              contents = pkgs.bashInteractive;
            };
            contents = packages.lnrpc-py;
            config = {
              Cmd = [ "/bin/bash" ];
              WorkingDir = "${packages.lnrpc-py}";
            };
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

        devShells.docker = pkgs.mkShell {
          buildInputs = [ pkgs.crane pkgs.gzip ];
          shellHook = ''
            if [ -n "$DOCKER_USER" ] && [ -n "$DOCKER_PASS" ]; then
              echo "Authenticating to registry..."
              actual=$(echo ${registry} | cut -d"/" -f1)
              # When there is no dot default to docker hub
              echo $actual | grep -vq '\.' && actual="index.docker.io"
              crane auth login -u $DOCKER_USER -p $DOCKER_PASS $actual || true
            fi

            # Crane wants .tar
            cp -f ${packages.lnrpc-py-docker} .
            base=$(basename ${packages.lnrpc-py-docker})
            name=$(echo $base | rev | cut -d"." -f2- | rev)
            rm -rf $name
            gunzip $base
            # can't use parameter expansion since $ { } is nix magic

            echo "crane push $name ${registry}"
            crane push $name ${registry} && rm -rf $name

            echo "If you want to play with the image you should do: "
            echo "docker load < ${packages.lnrpc-py-docker}"
          '';
        };

     });
}
