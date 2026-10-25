resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  # var.cluster_version = null -> EKS utilise la derniere version stable
  # disponible au moment de l'apply. Fixee explicitement par environnement
  # via le local kubernetes_version de chaque eks/terragrunt.hcl.
  version = var.cluster_version

  vpc_config {
    subnet_ids              = aws_subnet.eks[*].id
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  tags = local.tags

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# Pas d'image_id : EKS resout l'AMI AL2023 ARM standard et fusionne notre
# user_data (config nodeadm additionnelle) avec son propre bootstrap de
# jonction au cluster. maxPods=110 suppose ENABLE_PREFIX_DELEGATION actif
# sur l'addon vpc-cni ; sans ca le kubelet reste plafonne selon l'ENI par
# defaut d'un t4g.large.
resource "aws_launch_template" "apps" {
  name_prefix   = "lt-${var.team_name}-${var.project_name}-${var.env_name}-apps-"
  instance_type = var.node_instance_type

  # AL2023 + launch template custom exige un MIME multipart : sans
  # l'enveloppe, EKS ne peut pas fusionner ce NodeConfig avec son propre
  # bootstrap de jonction au cluster (erreur "not in MIME multipart format").
  user_data = base64encode(<<-EOT
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="//"

    --//
    Content-Type: application/node.eks.aws

    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      kubelet:
        config:
          maxPods: 110

    --//--
  EOT
  )

  # Name distinct du name_prefix ci-dessus : name_prefix nomme le launch
  # template lui-meme, pas les instances EC2 qu'il lance -- sans cle "Name"
  # ici, les instances n'affichent que leur ID dans la console EC2.
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, {
      Name = "node-${var.team_name}-${var.project_name}-${var.env_name}-apps"
    })
  }

  tags = local.tags
}

# Node group unique -- 4 VM Graviton2 (t4g.large, ARM64, burstable). ami_type
# force AL2023_ARM_64_STANDARD : sans lui EKS resout par defaut une AMI
# x86_64, incompatible avec une instance type ARM.
resource "aws_eks_node_group" "apps" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "apps"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.eks[*].id
  ami_type        = "AL2023_ARM_64_STANDARD"

  launch_template {
    id      = aws_launch_template.apps.id
    version = aws_launch_template.apps.latest_version
  }

  scaling_config {
    desired_size = var.node_count
    min_size     = var.node_count
    max_size     = var.node_count
  }

  labels = {
    workload = "apps"
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_ecr,
  ]
}
