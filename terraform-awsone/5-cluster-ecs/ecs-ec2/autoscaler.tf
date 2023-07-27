################################################################################
# Supporting Resources
################################################################################
module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  for_each = {
    # On-demand instances
    asg-ondemand = {
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

        # DSA
        # Deploy only if tenantID is set
        if [ ! -z "${var.ws_tenantid}" ]
        then
          ACTIVATIONURL='dsm://agents.deepsecurity.trendmicro.com:443/'
          MANAGERURL='https://app.deepsecurity.trendmicro.com:443'
          CURLOPTIONS='--silent --tlsv1.2'
          linuxPlatform='';
          isRPM='';

          if [[ $(/usr/bin/id -u) -ne 0 ]]; then
              echo You are not running as the root user.  Please try again with root privileges.;
              logger -t You are not running as the root user.  Please try again with root privileges.;
              exit 1;
          fi;

          if ! type curl >/dev/null 2>&1; then
              echo "Please install CURL before running this script."
              logger -t Please install CURL before running this script
              exit 1
          fi

          CURLOUT=$(eval curl -L $MANAGERURL/software/deploymentscript/platform/linuxdetectscriptv1/ -o /tmp/PlatformDetection $CURLOPTIONS;)
          err=$?
          if [[ $err -eq 60 ]]; then
              echo "TLS certificate validation for the agent package download has failed. Please check that your Workload Security Manager TLS certificate is signed by a trusted root certificate authority. For more information, search for \"deployment scripts\" in the Deep Security Help Center."
              logger -t TLS certificate validation for the agent package download has failed. Please check that your Workload Security Manager TLS certificate is signed by a trusted root certificate authority. For more information, search for \"deployment scripts\" in the Deep Security Help Center.
              exit 1;
          fi

          if [ -s /tmp/PlatformDetection ]; then
              . /tmp/PlatformDetection
          else
              echo "Failed to download the agent installation support script."
              logger -t Failed to download the Deep Security Agent installation support script
              exit 1
          fi

          platform_detect
          if [[ -z "$linuxPlatform" ]] || [[ -z "$isRPM" ]]; then
              echo Unsupported platform is detected
              logger -t Unsupported platform is detected
              exit 1
          fi

          if [[ $linuxPlatform == *"SuSE_15"* ]]; then
              if ! type pidof &> /dev/null || ! type start_daemon &> /dev/null || ! type killproc &> /dev/null; then
                  echo Please install sysvinit-tools before running this script
                  logger -t Please install sysvinit-tools before running this script
                  exit 1
              fi
          fi

          echo Downloading agent package...
          if [[ $isRPM == 1 ]]; then package='agent.rpm'
              else package='agent.deb'
          fi
          curl -H "Agent-Version-Control: on" -L $MANAGERURL/software/agent/$runningPlatform$majorVersion/$archType/$package?tenantID=112725 -o /tmp/$package $CURLOPTIONS

          echo Installing agent package...
          rc=1
          if [[ $isRPM == 1 && -s /tmp/agent.rpm ]]; then
              rpm -ihv /tmp/agent.rpm
              rc=$?
          elif [[ -s /tmp/agent.deb ]]; then
              dpkg -i /tmp/agent.deb
              rc=$?
          else
              echo Failed to download the agent package. Please make sure the package is imported in the Workload Security Manager
              logger -t Failed to download the agent package. Please make sure the package is imported in the Workload Security Manager
              exit 1
          fi
          if [[ $rc != 0 ]]; then
              echo Failed to install the agent package
              logger -t Failed to install the agent package
              exit 1
          fi

          echo Install the agent package successfully

          sleep 15
          /opt/ds_agent/dsa_control -r
          /opt/ds_agent/dsa_control -a $ACTIVATIONURL "tenantID:${var.ws_tenantid}" "token:${var.ws_token}" "policyid:${var.ws_policyid}"
        fi
      EOT
    }

    # Spot instances
    asg-spot = {
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
            instance_type     = "t3.large"
            weighted_capacity = "2"
          },
          {
            instance_type     = "t3.medium"
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

        # DSA
        # Deploy only if tenantID is set
        if [ ! -z "${var.ws_tenantid}" ]
        then
          ACTIVATIONURL='dsm://agents.deepsecurity.trendmicro.com:443/'
          MANAGERURL='https://app.deepsecurity.trendmicro.com:443'
          CURLOPTIONS='--silent --tlsv1.2'
          linuxPlatform='';
          isRPM='';

          if [[ $(/usr/bin/id -u) -ne 0 ]]; then
              echo You are not running as the root user.  Please try again with root privileges.;
              logger -t You are not running as the root user.  Please try again with root privileges.;
              exit 1;
          fi;

          if ! type curl >/dev/null 2>&1; then
              echo "Please install CURL before running this script."
              logger -t Please install CURL before running this script
              exit 1
          fi

          CURLOUT=$(eval curl -L $MANAGERURL/software/deploymentscript/platform/linuxdetectscriptv1/ -o /tmp/PlatformDetection $CURLOPTIONS;)
          err=$?
          if [[ $err -eq 60 ]]; then
              echo "TLS certificate validation for the agent package download has failed. Please check that your Workload Security Manager TLS certificate is signed by a trusted root certificate authority. For more information, search for \"deployment scripts\" in the Deep Security Help Center."
              logger -t TLS certificate validation for the agent package download has failed. Please check that your Workload Security Manager TLS certificate is signed by a trusted root certificate authority. For more information, search for \"deployment scripts\" in the Deep Security Help Center.
              exit 1;
          fi

          if [ -s /tmp/PlatformDetection ]; then
              . /tmp/PlatformDetection
          else
              echo "Failed to download the agent installation support script."
              logger -t Failed to download the Deep Security Agent installation support script
              exit 1
          fi

          platform_detect
          if [[ -z "$linuxPlatform" ]] || [[ -z "$isRPM" ]]; then
              echo Unsupported platform is detected
              logger -t Unsupported platform is detected
              exit 1
          fi

          if [[ $linuxPlatform == *"SuSE_15"* ]]; then
              if ! type pidof &> /dev/null || ! type start_daemon &> /dev/null || ! type killproc &> /dev/null; then
                  echo Please install sysvinit-tools before running this script
                  logger -t Please install sysvinit-tools before running this script
                  exit 1
              fi
          fi

          echo Downloading agent package...
          if [[ $isRPM == 1 ]]; then package='agent.rpm'
              else package='agent.deb'
          fi
          curl -H "Agent-Version-Control: on" -L $MANAGERURL/software/agent/$runningPlatform$majorVersion/$archType/$package?tenantID=112725 -o /tmp/$package $CURLOPTIONS

          echo Installing agent package...
          rc=1
          if [[ $isRPM == 1 && -s /tmp/agent.rpm ]]; then
              rpm -ihv /tmp/agent.rpm
              rc=$?
          elif [[ -s /tmp/agent.deb ]]; then
              dpkg -i /tmp/agent.deb
              rc=$?
          else
              echo Failed to download the agent package. Please make sure the package is imported in the Workload Security Manager
              logger -t Failed to download the agent package. Please make sure the package is imported in the Workload Security Manager
              exit 1
          fi
          if [[ $rc != 0 ]]; then
              echo Failed to install the agent package
              logger -t Failed to install the agent package
              exit 1
          fi

          echo Install the agent package successfully

          sleep 15
          /opt/ds_agent/dsa_control -r
          /opt/ds_agent/dsa_control -a $ACTIVATIONURL "tenantID:${var.ws_tenantid}" "token:${var.ws_token}" "policyid:${var.ws_policyid}"
        fi
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
  max_size            = 2
  desired_capacity    = 1

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = true

  # Spot instances
  use_mixed_instances_policy = each.value.use_mixed_instances_policy
  mixed_instances_policy     = each.value.mixed_instances_policy

  # Key nane
  key_name = "${var.environment}-key-pair"

  # Tags
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
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "${var.public_subnet_cidr_blocks[0]},${var.public_subnet_cidr_blocks[1]},${var.public_subnet_cidr_blocks[2]}"
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = local.tags
}
