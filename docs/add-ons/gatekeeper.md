# Add-On: Gatekeeper

## Deploy

Gatekeeper is a customizable admission webhook for Kubernetes that dynamically enforces policies executed by the OPA. Gatekeeper uses CustomResourceDefinitions internally and allows us to define ConstraintTemplates and Constraints to enforce policies on Kubernetes resources such as Pods, Deployments, Jobs.

OPA/Gatekeeper uses its own declarative language called Rego, a query language. You define rules in Rego which, if invalid or returned a false expression, will trigger a constraint violation and blocks the ongoing process of creating/updating/deleting the resource.

***ConstraintTemplate***

A ConstraintTemplate consists of both the Rego logic that enforces the Constraint and the schema for the Constraint, which includes the schema of the CRD and the parameters that can be passed into a Constraint.

***Constraint***

Constraint is an object that says on which resources are the policies applicable, and also what parameters are to be queried and checked to see if they are available in the resource manifest the user is trying to apply in your Kubernetes cluster. Simply put, it is a declaration that its author wants the system to meet a given set of requirements.

To deploy run:

```sh
deploy-gatekeeper.sh
```

## Usage

### Example Policy: Namespace Label Mandates

There is an example within the gatekeeper directory which you can apply by doing

```sh
kubectl apply -f gatekeeper/constrainttemplate.yaml
kubectl apply -f gatekeeper/constraints.yaml
```

From now on, any new namespace being created requires labels set for `stage`, `status` and `zone`.

To test it, run

```sh
kubectl create namespace nginx --dry-run=true -o yaml | kubectl apply -f -
```

```
Error from server ([label-check] 

DENIED. 
Reason: Our org policy mandates the following labels: 
You must provide these labels: {"stage", "status", "zone"}): error when creating "STDIN": admission webhook "validation.gatekeeper.sh" denied the request: [label-check] 

DENIED. 
Reason: Our org policy mandates the following labels: 
You must provide these labels: {"stage", "status", "zone"}
```

A valid namespace definition could look like the following:

```sh
cat <<EOF | kubectl apply -f - -o yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nginx
  labels:
    zone: eu-central-1
    stage: dev
    status: ready
EOF
```

A subsequent nginx deployment can be done via:

```sh
kubectl create deployment --image=nginx --namespace nginx nginx
```
