# Add-On: Trivy

## Deploy

Fundamentally, Trivy gathers security data from various Kubernetes security tools into Kubernetes Custom Resource Definitions (CRD). These extend the Kubernetes APIs so that users can manage and access security reports through the Kubernetes interfaces, like kubectl.

To deploy it, run

```sh
deploy-trivy.sh
```

## Usage

Workload Scanning

```sh
# Vulnerability audit
kubectl get vulnerabilityreports --all-namespaces -o wide

# Configuration audit
kubectl get configauditreports --all-namespaces -o wide
```

Inspect any of the reports run something like this

```sh
kubectl describe vulnerabilityreport -n kube-system daemonset-kube-proxy
```
