# Add-On: Open Policy Agent

- [Add-On: Open Policy Agent](#add-on-open-policy-agent)
  - [Deploy](#deploy)
  - [Usage](#usage)
    - [Example Policy: Registry Whitelisting](#example-policy-registry-whitelisting)

Ultra fast and slim kubernetes playground.

## Deploy

The Open Policy Agent (OPA, pronounced “oh-pa”) is an open source, general-purpose policy engine that unifies policy enforcement across the stack. OPA provides a high-level declarative language that lets you specify policy as code and simple APIs to offload policy decision-making from your software. You can use OPA to enforce policies in microservices, Kubernetes, CI/CD pipelines, API gateways, and more.

You don’t have to write policies on your own at the beginning of your journey, OPA and Gatekeeper both have excellent community libraries. You can have a look, fork them, and use them in your organization from here, [OPA](https://github.com/open-policy-agent/library), and [Gatekeeper](https://github.com/open-policy-agent/gatekeeper-library) libraries.

To deploy the registry run:

```sh
$ ./deploy-opa.sh
```

## Usage

### Example Policy: Registry Whitelisting

```sh
$ cat <<EOF >opa/registry-whitelist.rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Pod"
  image := input.request.object.spec.containers[_].image
  not startswith(image, "172.18.255.1/")
  msg := sprintf("Image is not from our trusted cluster registry: %v", [image])
}
EOF

$ kubectl -n opa create configmap registry-whitelist --from-file=opa/registry-whitelist.rego
```

Try to create a deployment

```sh
$ kubectl create deployment echo --image=inanimate/echo-server
```

If you now run a `kubectl get pods`, the echo-server should ***NOT*** show up.

Access the logs from OPA

```sh
$ kubectl -n opa logs -l app=opa -c opa -f
```

There should be something like

```json
"message": "Error creating: admission webhook \"validating-webhook.openpolicyagent.org\" denied the request: Image is not from our trusted cluster registry: inanimate/echo-server",
```
