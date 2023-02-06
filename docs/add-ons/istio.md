# Istio

## Deploy

```sh
# Add repo
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Install the Istio base chart
kubectl create namespace istio-system
helm install istio-base istio/base -n istio-system

# Install the Istio discovery chart which deploys the istiod service
helm install istiod istio/istiod -n istio-system --wait

# (Optional) Install an ingress gateway
kubectl create namespace istio-ingress
kubectl label namespace istio-ingress istio-injection=enabled
helm install istio-ingress istio/gateway -n istio-ingress --wait

# Verified using Helm
helm status istiod -n istio-system
```
