# Deployments

The playground provides a couple of scripts which deploy pre-configured versions of several products. This includes currently:

- Container Security
- Smart Check
- Prometheus & Grafana
- Starboard
- Falco Runtime Security
- Harbor
- Open Policy Agent
- Gatekeeper

Deploy the products via `Deploy...` in the menu.

In addition to the above the playground now supports AWS CodePipelines. The pipeline builds a container image based on a sample repo, scans it with Smart Check and deploys it with integrated Cloud One Application Security to the EKS cluster.

The pipeline requires an EKS with a deployed Smart Check. If everything has been set up, running the script `deploy-pipeline-aws.sh` should do the trick :-). When you're done with the pipeline run the generated script `pipeline-aws-down.sh` to tear it down.
