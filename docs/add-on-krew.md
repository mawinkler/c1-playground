# Add-On: Krew

- [Add-On: Krew](#add-on-krew)
  - [Usage](#usage)

Ultra fast and slim kubernetes playground.

## Usage

Krew is a tool that makes it easy to use kubectl plugins. Krew helps you discover plugins, install and manage them on your machine. It is similar to tools like apt, dnf or brew. Today, over 130 kubectl plugins are available on Krew.

Example usage:

```sh
kubectl krew list
kubectl krew install tree
```

The tree command is a kubectl plugin to browse Kubernetes object hierarchies as a tree.

```sh
kubectl tree node playground-control-plane -A
```
