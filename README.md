# Playground

- [Playground](#playground)
  - [Start MacOS](#start-macos)
  - [Start Linux](#start-linux)

Ultra fast and slim kubernetes playground

## Start MacOS

```sh
./start.sh
./deploy-registry.sh
./deploy-smartcheck.sh
```

```sh
kubectl port-forward -n smartcheck svc/proxy 1443:443
```

Access with browser `https://localhost:1443`

## Start Linux

```sh
./start.sh
./deploy-registry.sh
./deploy-smartcheck.sh
```

```sh
echo trendmicro | docker login https://172-18-255-2.nip.io:5000 --username admin --password-stdin
```
