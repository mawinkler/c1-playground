# Clusters

From within the main menu choose `Create Cluster...` and select your desired type.

Depending on where you have deployed the playground you potentially need to ensure an authenticated cloud CLI.

Prerequisites | GKE | EKS | AKS
------ | ------ | ----- | ---
Ubuntu | `gcloud` | `aws` w/ Access Keys | `az`
Cloud9 | `gcloud` | `aws` w/ Instance Role (1) | `az`

*(1)* The instance role is automatically created and assigned to the Cloud9 instance during bootstrapping.

Then choose your cluster variant to create.

If you want to tear down your cluster choose `Tear Down Cluster` from within the menu. This will destroy the last cluster you created.

> ***Note:*** Cluster versions are defined by the current defaults of the hyper scaler. The built-in cluster is currently version fixed to kubernetes 1.24.7.
