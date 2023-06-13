# Migrate

This tries to solve the challenge to migrate workload of an existing cluster using public image registries to a trusted, private one (without breaking the services).

To try it, being in the playground directory run

```sh
migrate/save-cluster.sh
```

This scripts dumps the full cluster to json files separated by namespace. The namespaces `kube-system`, `registry` and `default` are currently excluded.

Effectively, this is a **backup** of your cluster including ConfigMaps and Secrets etc. which you can deploy on a different cluster easily (`kubectl create -f xxx.json`)

To migrate the images currently in use run

```sh
migrate/migrate-images.sh
```

This second script updates the saved manifests in regards the image location to point them to the private registry. If the image has a digest within it's name it is stripped.

The image get's then pulled from the public repo and pushed to the internal one. TODO: This is followed by an image scan and the redeployment.

> ***Note:*** at the time of writing the only supported private registry is the internal one.
