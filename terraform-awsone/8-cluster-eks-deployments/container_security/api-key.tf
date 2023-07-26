# ####################################
# Container Security Cluster API
# ####################################
resource "null_resource" "always_run" {
  triggers = {
    timestamp = "${timestamp()}"
  }
}

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "restapi_object" "cluster" {

  provider       = restapi.clusters
  path           = ""
  create_method  = "POST"
  destroy_method = "DELETE"
  data = "{\"name\": \"${var.environment}_eks_${random_string.suffix.result}\",\"description\": \"Playground Cluster\",\"policyID\": \"${var.cluster_policy}\"}"

  lifecycle {
    replace_triggered_by = [
      null_resource.always_run
    ]
  }
}

# Store Cluster API Key for use in the helm installation step
locals {
  cluster_apikey = jsondecode(restapi_object.cluster.api_response).apiKey
}
