# #############################################################################
# Create a Namespace
# #############################################################################
resource "kubernetes_namespace_v1" "trivy_namespace" {
  metadata {
    name = var.namespace
  }
}
