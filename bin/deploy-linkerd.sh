linkerd check --pre
linkerd install | kubectl apply -f -

linkerd viz install | kubectl apply -f - # install the on-cluster metrics stack
linkerd jaeger install | kubectl apply -f - # Distributed tracing with Linkerd

kubectl get -n container-security deploy -o yaml \
  | linkerd inject - \
  | kubectl apply -f -

kubectl -n linkerd-viz expose deployment web --type=LoadBalancer --name=web-lb

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  template:
    spec:
      containers:
        - name: web
          args:
            - -linkerd-controller-api-addr=linkerd-controller-api.linkerd.svc.cluster.local:8085
            - -linkerd-metrics-api-addr=metrics-api.linkerd-viz.svc.cluster.local:8085
            - -cluster-domain=cluster.local
            - -grafana-addr=grafana.linkerd-viz.svc.cluster.local:3000
            - -controller-namespace=linkerd
            - -viz-namespace=linkerd-viz
            - -log-level=info
            - -enforced-host=^dashboard\.example\.com$
````

set 

```
- -enforced-host=.*
```