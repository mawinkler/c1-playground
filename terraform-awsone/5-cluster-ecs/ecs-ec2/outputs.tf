# #############################################################################
# Outputs
# #############################################################################
output "cluster_name" {
  value = module.ecs.cluster_name
}

output "cluster_arn" {
  value = module.ecs.cluster_arn
}
