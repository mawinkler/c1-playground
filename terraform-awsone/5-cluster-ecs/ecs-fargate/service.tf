################################################################################
# Service
################################################################################
module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.2.0"

  # Service
  name        = module.ecs.cluster_name
  cluster_arn = module.ecs.cluster_arn

  # Task Definition
  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    # spot instances
    asg-spot = {
      capacity_provider = module.ecs.autoscaling_capacity_providers["asg-spot"].name
      weight            = 1
      base              = 1
    }
  }

  volume = {
    my-vol = {}
  }

  # Container definition(s)
  # container_definitions = {
  #   (local.container_name) = {
  #     image = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
  #     port_mappings = [
  #       {
  #         name          = local.container_name
  #         containerPort = local.container_port
  #         protocol      = "tcp"
  #       }
  #     ]

  #     mount_points = [
  #       {
  #         sourceVolume  = "my-vol",
  #         containerPath = "/var/www/my-vol"
  #       }
  #     ]

  #     entry_point = ["/usr/sbin/apache2", "-D", "FOREGROUND"]

  #     # Example image used requires access to write to root filesystem
  #     readonly_root_filesystem = false
  #   }
  # }

  container_definitions = {
    (local.container_name) = {
      image = "mawinkler/java-goof"
      port_mappings = [
        {
          name          = local.container_name
          containerPort = local.container_port
          protocol      = "tcp"
        }
      ]

      # mount_points = [
      #   {
      #     sourceVolume  = "my-vol",
      #     containerPath = "/var/www/my-vol"
      #   }
      # ]

      command = ["catalina.sh", "run"]
      # entry_point = ["/usr/sbin/apache2", "-D", "FOREGROUND"]

      # Example image used requires access to write to root filesystem
      readonly_root_filesystem = false
    }
  }

  load_balancer = {
    service = {
      target_group_arn = element(module.alb.target_group_arns, 0)
      container_name   = local.container_name
      container_port   = local.container_port
    }
  }

  subnet_ids = var.private_subnet_ids
  security_group_rules = {
    alb_http_ingress = {
      type                     = "ingress"
      from_port                = local.container_port
      to_port                  = local.container_port
      protocol                 = "tcp"
      description              = "Service port"
      source_security_group_id = module.alb_sg.security_group_id
    }
  }

  tags = local.tags
}
