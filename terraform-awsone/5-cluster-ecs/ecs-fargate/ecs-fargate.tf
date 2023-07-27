# #############################################################################
# Create an EKS Cluster
# #############################################################################
module "ecs" {
  source = "terraform-aws-modules/ecs/aws"
  version = "5.2.0"

  cluster_name = "${var.environment}-ecs-fargate"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/aws-ec2"
      }
    }
  }

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 20
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 80
      }
    }
  }

  tags = {
    Name        = "${var.environment}-ecs"
    Environment = "${var.environment}"
  }
}
