
locals {
  container_name = "ecs-sample"
  container_port = 80

  tags = {
    Name        = "${var.environment}-ecs-ec2"
    Environment = "${var.environment}"
  }
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.2.0"

  cluster_name = "${var.environment}-ecs"

  # Capacity provider - autoscaling groups
  default_capacity_provider_use_fargate = false

  autoscaling_capacity_providers = {
    # On-demand instances
    ex-1 = {
      auto_scaling_group_arn         = module.autoscaling["ex-1"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        # maximum_scaling_step_size = 5
        # minimum_scaling_step_size = 1
        status          = "ENABLED"
        target_capacity = 3
      }

      default_capacity_provider_strategy = {
        weight = 60
        base   = 20
      }
    }

    # Spot instances
    ex-2 = {
      auto_scaling_group_arn         = module.autoscaling["ex-2"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        # maximum_scaling_step_size = 15
        # minimum_scaling_step_size = 5
        status          = "ENABLED"
        target_capacity = 3
      }

      default_capacity_provider_strategy = {
        weight = 40
      }
    }
  }

  tags = local.tags
}

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
    # On-demand instances
    ex-1 = {
      capacity_provider = module.ecs.autoscaling_capacity_providers["ex-1"].name
      weight            = 1
      base              = 1
    }
  }

  volume = {
    my-vol = {}
  }

  # Container definition(s)
  container_definitions = {
    (local.container_name) = {
      image = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
      port_mappings = [
        {
          name          = local.container_name
          containerPort = local.container_port
          protocol      = "tcp"
        }
      ]

      mount_points = [
        {
          sourceVolume  = "my-vol",
          containerPath = "/var/www/my-vol"
        }
      ]

      entry_point = ["/usr/sbin/apache2", "-D", "FOREGROUND"]

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

################################################################################
# Supporting Resources
################################################################################

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${module.ecs.cluster_name}-service"
  description = "Service security group"
  vpc_id      = var.vpc_id

  ingress_rules       = ["http-80-tcp"]
  ingress_cidr_blocks = [var.access_ip]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["10.0.96.0/19", "10.0.128.0/19", "10.0.160.0/19"] #var.private_subnet_ids.cidr_blocks

  tags = local.tags
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = module.ecs.cluster_name

  load_balancer_type = "application"

  vpc_id          = var.vpc_id
  subnets         = var.public_subnet_ids
  security_groups = [module.alb_sg.security_group_id]

  http_tcp_listeners = [
    {
      port               = local.container_port
      protocol           = "HTTP"
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "${module.ecs.cluster_name}-${local.container_name}"
      backend_protocol = "HTTP"
      backend_port     = local.container_port
      target_type      = "ip"
    },
  ]

  tags = local.tags
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  for_each = {
    # On-demand instances
    ex-1 = {
      instance_type              = "t3.large"
      use_mixed_instances_policy = false
      mixed_instances_policy     = {}
      user_data                  = <<-EOT
        #!/bin/bash
        cat <<'EOF' >> /etc/ecs/ecs.config
        ECS_CLUSTER=${module.ecs.cluster_name}
        ECS_LOGLEVEL=debug
        ECS_CONTAINER_INSTANCE_TAGS=${jsonencode(local.tags)}
        ECS_ENABLE_TASK_IAM_ROLE=true
        EOF
      EOT
    }
    # Spot instances
    ex-2 = {
      instance_type              = "t3.medium"
      use_mixed_instances_policy = true
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_base_capacity                  = 0
          on_demand_percentage_above_base_capacity = 0
          spot_allocation_strategy                 = "price-capacity-optimized"
        }

        override = [
          {
            instance_type     = "m4.large"
            weighted_capacity = "2"
          },
          {
            instance_type     = "t3.large"
            weighted_capacity = "1"
          },
        ]
      }
      user_data = <<-EOT
        #!/bin/bash
        cat <<'EOF' >> /etc/ecs/ecs.config
        ECS_CLUSTER=${module.ecs.cluster_name}
        ECS_LOGLEVEL=debug
        ECS_CONTAINER_INSTANCE_TAGS=${jsonencode(local.tags)}
        ECS_ENABLE_TASK_IAM_ROLE=true
        ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
        EOF
      EOT
    }
  }

  name = "${module.ecs.cluster_name}-${each.key}"

  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  instance_type = each.value.instance_type

  security_groups                 = [module.autoscaling_sg.security_group_id]
  user_data                       = base64encode(each.value.user_data)
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = module.ecs.cluster_name
  iam_role_description        = "ECS role for ${module.ecs.cluster_name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "EC2"
  min_size            = 1
  max_size            = 5
  desired_capacity    = 2

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = true

  # Spot instances
  use_mixed_instances_policy = each.value.use_mixed_instances_policy
  mixed_instances_policy     = each.value.mixed_instances_policy

  tags = local.tags
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = module.ecs.cluster_name
  description = "Autoscaling group security group"
  vpc_id      = var.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = local.tags
}
