# #############################################################################
# Create a Namespace
# #############################################################################
resource "kubernetes_namespace_v1" "victims_namespace" {
  metadata {
    name = var.namespace
  }
}
