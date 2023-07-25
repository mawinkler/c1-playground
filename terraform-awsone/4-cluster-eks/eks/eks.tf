# #############################################################################
# Create an EKS Cluster
# #############################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "${var.environment}-eks"
  cluster_version = var.kubernetes_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = true

  cluster_addons = {
    coredns = {
      most_recent = true

      timeouts = {
        create = "2m" # default 20m. Times out on first launch while being effectively created
      }
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Self managed node groups will not automatically create the aws-auth configmap so we need to
  # create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = module.eks_admins_iam_role.iam_role_arn
      username = module.eks_admins_iam_role.iam_role_name
      groups   = ["system:masters"]
    },
  ]

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    # cluster_additional_security_group_ids = [aws_security_group.eks.id]
    cluster_additional_security_group_ids = [var.private_security_group_id]
    disk_size                             = 50
    instance_types                        = ["t3.medium", "t3.large"]
    # vpc_security_group_ids                = [aws_security_group.eks.id]
    vpc_security_group_ids = [var.private_security_group_id]
  }

  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    egress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      self        = true
    }
  }

  eks_managed_node_groups = {
    "${var.environment}_node" = {
      min_size     = 1
      max_size     = 10
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
      labels = {
        Name        = "${var.environment}-eks"
        Environment = "${var.environment}"
      }
      taints = {
      }
      tags = {
        Name        = "${var.environment}-eks"
        Environment = "${var.environment}"
      }
    }
  }

  tags = {
    Name        = "${var.environment}-eks"
    Environment = "${var.environment}"
  }
}

module "fargate_profile" {
  count = var.create_fargate_profile ? 1 : 0

  source = "terraform-aws-modules/eks/aws//modules/fargate-profile"

  name         = "fargate-profile"
  cluster_name = module.eks.cluster_name

  subnet_ids = var.private_subnet_ids
  selectors = [{
    namespace = "fargate"
  }]

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2009
data "aws_eks_cluster" "eks" {
  depends_on = [
    module.eks.eks_managed_node_groups
  ]
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  depends_on = [
    module.eks.eks_managed_node_groups
  ]
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.eks.id]
    command     = "aws"
  }
}
