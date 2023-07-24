# #############################################################################
# Create a Namespace
# #############################################################################
resource "kubernetes_namespace_v1" "trendmicro_system" {
  metadata {
    name = var.namespace
  }
}
