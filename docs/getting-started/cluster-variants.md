# Cluster Variants

The Playground has support for the following Kubernetes cluster variants. They all come preconfigured and ready to be used:

- Local Cluster (Kind)
- AWS EKS with Amazon Linux nodes
- AWS EKS with Bottlerocket nodes (in Private Preview)
- AWS EKS with Bottlerocket nodes and Fargate profile (in Private Preview)
- Azure Kubernetes Cluster
- Google Kubernetes Engine

> **When to use which variant:**  
> Besides the obvious reason that you want to test or learn something specific you are pretty much flexible. Most of the provided services run on each cluster type. Personally, when I just need to test something quickly I simply choose the local cluster because it is up in 2 minutes, provides the full Kubernetes functionality and is destroyed in 2 seconds.  
> Important to note: All managed clusters by the CSPs create costs! Since the playground configures everything for you you should tear down these clusters when you're done. This means, and this is the approach I'm using, when I want to have an always there cluster, I run the local cluster on a local machine in my own lab.

## Local Cluster (Kind)

This variant is actually the fastest and cheapest variant of Kubernetes clusters available in the Playground. It uses the greate open source project `kind`. kind is a tool for running local Kubernetes clusters using Docker container “nodes”. kind was primarily designed for testing Kubernetes itself, but may be used for local development, learning and testing things.

You can very quickly create this kind of clusters on any Ubuntu server, whereby I'm testing it currently on a Ubuntu 20.04 LTS and a Cloud9 with an Ubuntu operating system. Other platforms might work, but are untested.

Some specs:

- Performance depends on the host, of course
- MetalLB as the Load Balancer
- Ingress Controller based on Nginx
- Calico Pod Network
- Automatic proxy configuration on host level

## AWS EKS with Amazon Linux nodes

This is the current configuration for a standard EKS cluster:

```yaml
managedNodeGroups:
- name: nodegroup
  instanceType: m5.large
  minSize: 2
  maxSize: 4
  desiredCapacity: 2
  iam:
    withAddonPolicies:
      albIngress: true
      ebs: true
      cloudWatch: true
      autoScaler: true
      awsLoadBalancerController: true
```

Some additional specs:

- Nodes EC2 type currently m5.large
- Secrets encryption is enabled
- CloudWatch logging is enabled
- Calico (Tigera) pod network
- Amazon EBS CSI driver is deployed

## AWS EKS with Bottlerocket nodes

This is the current configuration for a standard EKS cluster with Bottlerocket nodes:

```yaml
managedNodeGroups:
- name: nodegroup
  instanceType: m5.large
  minSize: 2
  maxSize: 4
  desiredCapacity: 2
  amiFamily: Bottlerocket
  iam:
    withAddonPolicies:
      albIngress: true
      ebs: true
      cloudWatch: true
      autoScaler: true
      awsLoadBalancerController: true
  tags:
    nodegroup-type: Bottlerocket
```

Some additional specs:

- Secrets encryption is enabled
- CloudWatch logging is enabled
- Calico (Tigera) pod network
- Amazon EBS CSI driver is deployed

## AWS EKS with Bottlerocket nodes and Fargate profile

This is the current configuration for a standard EKS cluster with Bottlerocket nodes and an additional Fargate profile:

```yaml
managedNodeGroups:
- name: nodegroup
  instanceType: m5.large
  minSize: 2
  maxSize: 4
  desiredCapacity: 4
  amiFamily: Bottlerocket
  iam:
    withAddonPolicies:
      albIngress: true
      ebs: true
      cloudWatch: true
      autoScaler: true
      awsLoadBalancerController: true
  tags:
    nodegroup-type: Bottlerocket

fargateProfiles:
  - name: fp-default
    selectors:
      # All workloads in the "default" and "kube-system" Kubernetes
      # namespace will be scheduled onto Fargate:
      - namespace: default
      - namespace: kube-system
      - namespace: victims
```

The cluster will behave as normally, but the workload within the namespaces `default`, `kube-system`, and `victims` will actually run on Fargate.

## Azure Kubernetes Cluster

Here, you'll get an AKS cluster on Azure.

Some additional specs:

- Two nodes
- Monitoring is enabled

## Google Kubernetes Engine

- Nodes e2-standard-4 (4CPU/16GB per node)
