# Deployments

The playground provides a couple of scripts which deploy pre-configured versions of several products. This includes currently:

- Container Security
- Falco Runtime Security
- Open Policy Agent
- Gatekeeper
- Prometheus & Grafana
- Trivy
- KUBEClarity
- Kubescape
- Harbor
- Jenkins
- GitLab
- Workload Security

Deploy the products via `Deploy...` in the menu.

In addition to the above the playground now supports AWS CodePipelines. The pipeline builds a container image based on a sample repo, scans it with Artifact Scanning as a Service and deploys it with integrated Cloud One Application Security to the EKS cluster.

The pipeline requires an EKS. If everything has been set up, running the script `deploy-pipeline-aws.sh` should do the trick :-). When you're done with the pipeline run the generated script `pipeline-aws-down.sh` to tear it down.
