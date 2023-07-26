# ####################################
# Container Security Life-cycle
# ####################################
resource "helm_release" "container_security" {
  depends_on   = [kubernetes_namespace_v1.trendmicro_system]
  chart        = "https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz"
  name         = "container-security"
  namespace    = var.namespace
  reuse_values = true

  values = [
    "${file("container_security/overrides.yaml")}"
  ]

  set {
    name  = "cloudOne.apiKey"
    value = local.cluster_apikey
  }

  set {
    name  = "cloudOne.endpoint"
    value = "https://container.${var.cloud_one_region}.${var.cloud_one_instance}.trendmicro.com"
  }

  set {
    name  = "cloudOne.jobManager.enabled"
    value = true
  }

  set {
    name  = "cloudOne.runtimeSecurity.enabled"
    value = true
  }

  set {
    name  = "cloudOne.vulnerabilityScanning.enabled"
    value = true
  }

  set {
    name  = "cloudOne.auditlog.enabled"
    value = true
  }
}
