# Add-On: Starboard

## Deploy

Fundamentally, Starboard gathers security data from various Kubernetes security tools into Kubernetes Custom Resource Definitions (CRD). These extend the Kubernetes APIs so that users can manage and access security reports through the Kubernetes interfaces, like kubectl.

To deploy it, run

```sh
deploy-starboard.sh
```

## Usage

```sh
kubectl logs -f -n starboard deployment/starboard-starboard-operator
```

Workload Scanning

```sh
kubectl get job -n starboard
kubectl get vulnerabilityreports --all-namespaces -o wide
kubectl get configauditreports --all-namespaces -o wide
```

Infrastructure Scanning - The operator discovers also Kubernetes nodes and runs CIS Kubernetes Benchmark checks on each of them. The results are stored as CISKubeBenchReport objects.

```sh
kubectl get ciskubebenchreports -o wide
```

Inspect any of the reports run something like this

```sh
kubectl describe vulnerabilityreport -n kube-system daemonset-kindnet-kindnet-cni
```
