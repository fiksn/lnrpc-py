# lnrpc-py
LND RPC Python bindings

It will build the stuff as described in [LND RPC Python](https://github.com/lightningnetwork/lnd/blob/master/docs/grpc/python.md).
It uses flakes to cache all git repos.

You can obtain the built image from [fiksn/lnrpc-py](https://hub.docker.com/r/fiksn/lnrpc-py).
Or do something like:
```
COPY --from=fiksn/lnrpc-py ./*.py .
```

Examples:

To just obtain the files:
```
$ nix build .
$ ls result/
chainnotifier_pb2.py  chainnotifier_pb2_grpc.py  invoices_pb2.py  invoices_pb2_grpc.py  lightning_pb2.py  lightning_pb2_grpc.py  router_pb2.py  router_pb2_grpc.py
```

To build and push docker image:
```
nix develop .#docker
```

To start developing:
```
$ nix develop
$ python example.py
```

