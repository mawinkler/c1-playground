module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.2.0"

  cluster_name = "${var.environment}-ecs"

  # Capacity provider - autoscaling groups
  default_capacity_provider_use_fargate = false

  autoscaling_capacity_providers = {
    # On-demand instances
    asg-ondemand = {
      auto_scaling_group_arn         = module.autoscaling["asg-ondemand"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        # maximum_scaling_step_size = 5
        # minimum_scaling_step_size = 1
        status          = "ENABLED"
        target_capacity = 1
      }

      default_capacity_provider_strategy = {
        weight = 60
        base   = 20
      }
    }

    # Spot instances
    asg-spot = {
      auto_scaling_group_arn         = module.autoscaling["asg-spot"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        # maximum_scaling_step_size = 15
        # minimum_scaling_step_size = 5
        status          = "ENABLED"
        target_capacity = 2
      }

      default_capacity_provider_strategy = {
        weight = 40
      }
    }
  }

  tags = local.tags
}
