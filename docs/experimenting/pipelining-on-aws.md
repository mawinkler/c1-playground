# Pipelining on AWS

## Requirements & Preparations

Pipelining on AWS requires an EKS cluster, of course. So this pipeline does not work with any other Playground variant.

## Deployment

Run

```sh
deploy-pipeline-aws.sh
```

This script automates the following:

1. Creation of a role for CodeBuild - In an AWS CodePipeline, we are going to use AWS CodeBuild to deploy a Kubernetes service. This requires an AWS Identity and Access Management (IAM) role capable of interacting with the EKS cluster. In this step, we are going to create an IAM role and add an inline policy that we will use in the CodeBuild stage to interact with the EKS cluster via kubectl.
2. Now that we have the IAM role created, we are going to add the role to the aws-auth ConfigMap for the EKS cluster. Once the ConfigMap includes this new role, kubectl in the CodeBuild stage of the pipeline will be able to interact with the EKS cluster via the IAM role.
3. We're going to create the AWS CodePipeline using AWS CloudFormation which defines all used resources for our pipeline. In our case this includes ECR, S3, CodeBuild, CodePipeline, CodeCommit, ServiceRoles, and Smart Check.
4. Next, we're adding a remote repository in AWS CodeCommit which our pipeline will use. At the time of writing the script clones my `c1-app-sec-uploader`. While doing this we create the kubernetes manifest for our app.
5. Finally, we push our code to the CodeCommit repo which will trigger the pipeline run.

The pipeline builds the container image, pushes it to ECR, scans the image with Artifact Scanning as a Service and finally deploys it to EKS (if the image does not exceed the vulnerability threshold :-))

The interaction with Artifact Scanning as a Service is actually done by a containerized `tmas` client which I'm hosting here: (c1-cs-tmas)[https://github.com/mawinkler/c1-cs-tmas].

The deployment obviously can fail if you're running Cloud One Container Security on the cluster, since the image will contain vulnerabilities. So it just depends on you and your defined policy.

If everything works you'll have a running uploader demo on your cluster.

## Further Reading

- AWS EKS Cluster Authentication: <https://docs.aws.amazon.com/eks/latest/userguide/cluster-auth.html>

## Tear Down

To tear down the pipeline including CodeCommit, Roles etc. simply run the auto-generated script

```sh
pipeline-aws-down.sh
```
