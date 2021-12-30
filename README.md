# lnrpc-py
LND RPC Python bindings

It will build the stuff as described in [LND RPC Python](https://github.com/lightningnetwork/lnd/blob/master/docs/grpc/python.md).
It uses flakes to cache all git repos.

You can obtain the built image from [fiksn/lnrpc-py](https://hub.docker.com/r/fiksn/lnrpc-py).
Or do something like:
```
COPY --from=fiksn/lnrpc-py ./*.py .
```

Idea is that this will be perodically updated and rebuilt through GitHub actions.

If possible you should use [Nix](https://nixos.org) with [Flakes](https://nixos.wiki/wiki/Flakes) support. For people already using Nix
this boils down to:
```
# Install nix tools with flake support
nix-env -iA nixpkgs.nixFlakes
```
and
```
# Configure Nix
mkdir -p ~/.config/nix
if ! test -f ~/.config/nix/nix.conf || ! grep -q experimental-features ~/.config/nix/nix.conf; then
    echo 'experimental-features = ca-references flakes nix-command' >>~/.config/nix/nix.conf
fi
```

Or you can directly install such a version:
```
# Interactively install the latest version of Nix
if ! type -p nix; then
    sh <(curl -L https://github.com/numtide/nix-flakes-installer/releases/latest/download/install)
fi

# Configure Nix
mkdir -p ~/.config/nix
if ! test -f ~/.config/nix/nix.conf || ! grep -q experimental-features ~/.config/nix/nix.conf; then
    echo 'experimental-features = ca-references flakes nix-command' >>~/.config/nix/nix.conf
fi
```

But is totally possible to use this repo without any Nix (by just consuming the periodically generated files that are published as a docker image).

## Documentation

[LND documentation](https://api.lightning.community/?python)

## Examples

To just obtain the files:
```
$ nix build .
$ ls result/
chainnotifier_pb2.py  chainnotifier_pb2_grpc.py  invoices_pb2.py  invoices_pb2_grpc.py  lightning_pb2.py  lightning_pb2_grpc.py  router_pb2.py  router_pb2_grpc.py
```

To build and push docker image:
```
$ ./push.sh
```

To start developing:
```
$ nix develop
$ python example.py
```
