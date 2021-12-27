{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    googleapis = { url = "github:googleapis/googleapis"; flake = false; };
    lnrpc = { url = "github:lightningnetwork/lnd?lnrpc"; flake = false; };
  };

  outputs = { self, nixpkgs, flake-utils, lnrpc, googleapis }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in
      rec {
        packages = flake-utils.lib.flattenTree {
          lnrpc-py = pkgs.stdenv.mkDerivation {
            name = "lnrpc-py";

            phases = [ "buildPhase" ];
            buildInputs = with pkgs; with pkgs.python39Packages; [ python39 grpcio grpcio-tools googleapis-common-protos ];

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
            name = "fiksn/lnrpc-py";
            tag = "latest";
            # Fix me
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
          buildInputs = [ packages.lnrpc-py ];
          shellHook = ''
            echo "Hello ${packages.lnrpc-py}"
          '';
        };

        devShells.docker = pkgs.mkShell {
          buildInputs = [ pkgs.crane ];
          shellHook = ''
            echo "docker load < ${packages.lnrpc-py-docker}"
            echo "docker run -it fiksn/lnrpc-py:latest bash"
          '';
        };

     });
}
