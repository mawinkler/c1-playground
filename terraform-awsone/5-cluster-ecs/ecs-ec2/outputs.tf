# #############################################################################
# Outputs
# #############################################################################
output "cluster_name" {
  value = module.ecs.cluster_name
}

output "cluster_arn" {
  value = module.ecs.cluster_arn
}

output "loadbalancer_dns" {
  value = module.alb.lb_dns_name
}
