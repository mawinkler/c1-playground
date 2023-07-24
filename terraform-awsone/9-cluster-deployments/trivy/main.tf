# ####################################
# Container Security Life-cycle
# ####################################
resource "helm_release" "trivy" {
  depends_on   = [kubernetes_namespace_v1.trivy_namespace]
  repository   = "https://aquasecurity.github.io/helm-charts"
  chart        = "trivy-operator"
  name         = "trivy-operator"
  namespace    = var.namespace
  reuse_values = true

  set {
    name  = "trivy.ignoreUnfixed"
    value = true
  }

  set {
    name  = "debugMode"
    value = true
  }
}
