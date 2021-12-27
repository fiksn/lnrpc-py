# lnrpc-py
LND RPC Python bindings

It will build the stuff as described in [LND RPC Python](https://github.com/lightningnetwork/lnd/blob/master/docs/grpc/python.md)

Examples:

```
$ nix build .
$ ls result/
lightning_pb2.py  lightning_pb2_grpc.py  router_pb2.py  router_pb2_grpc.py
```

```
nix develop .#docker
```
