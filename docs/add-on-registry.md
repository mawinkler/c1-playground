# Add-On: Registry

- [Add-On: Registry](#add-on-registry)
  - [Deploy](#deploy)
  - [Access](#access)

Ultra fast and slim kubernetes playground.

## Deploy

To deploy the registry run:

```sh
./deploy-registry.sh
```

## Access

Follow the steps for your platform below. A file called `services` is either created or updated with the link and the credentials to connect to the registry.

***Linux***

Example:

`Registry login with: echo trendmicro | docker login https://172.18.255.1:5000 --username admin --password-stdin`

***MacOS***

Example:

`Registry login with: echo trendmicro | docker login https://playground-registry:443 --username admin --password-stdin`

***Cloud9***

A file called `services` is either created or updated with the link and the credentials to connect to the registry.

Example:

`Registry login with: echo trendmicro | docker login https://172.18.255.1:5000 --username admin --password-stdin`
