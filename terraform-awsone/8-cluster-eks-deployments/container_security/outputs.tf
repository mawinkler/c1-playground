# #############################################################################
# Outputs
# #############################################################################
output "cluster_apikey" {
  value     = jsondecode(restapi_object.cluster.api_response).apiKey
  sensitive = true
}
