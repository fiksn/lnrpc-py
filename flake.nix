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
        registry = "registry.digitalocean.com/fiksn/lnrpc-py";
      in
      rec {
        packages = flake-utils.lib.flattenTree {
          lnrpc-py = pkgs.stdenv.mkDerivation {
            name = "lnrpc-py";

            phases = [ "buildPhase" ];
            propagatedBuildInputs = with pkgs; with pkgs.python39Packages; [ python39 grpcio grpcio-tools googleapis-common-protos ];

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
            # (TODO fiction - fix me)
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
          buildInputs = [ packages.lnrpc-py pkgs.python39Packages.protobuf pkgs.python39Packages.grpcio ];

          shellHook = ''
            echo "Hello ${packages.lnrpc-py}"
            PYTHONPATH=$PYTHONPATH:${packages.lnrpc-py}
          '';
        };

        devShells.docker = pkgs.mkShell {
          buildInputs = [ pkgs.crane pkgs.gzip ];
          shellHook = ''
            echo "docker load < ${packages.lnrpc-py-docker}"

            if [ -n $DOCKER_USER ] && [ -n $DOCKER_PASS ]; then
              echo "Authenticating to registry..."
              actual=$(echo ${registry} | cut -d"/" -f1)
              echo "Actual $actual"
              crane auth login -u $DOCKER_USER -p $DOCKER_PASS $actual || true
            fi

            cp -f ${packages.lnrpc-py-docker} .
            base=$(basename ${packages.lnrpc-py-docker})
            name=$(echo $base | rev | cut -d"." -f2- | rev)
            rm -rf $name
            gunzip $base
            # can't use parameter expansion since $ { } is nix magic
            echo $name
            crane push $name ${registry}
            rm -rf $name
          '';
        };

     });
}
