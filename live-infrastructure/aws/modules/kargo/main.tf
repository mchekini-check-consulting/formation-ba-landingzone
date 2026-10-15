# Role IAM du controleur Kargo, donne au pod via EKS Pod Identity.
# Kargo surveille les images ECR des depots metier (Warehouses) pour creer
# les Freights a promouvoir : lecture seule, uniquement les depots <prefixe>*.
#
# Kargo essaie d'abord d'assumer un role kargo-project-<projet> par Project ;
# ces roles n'existent pas ici, il utilise donc ce role pour tous les Projects
# (pas d'isolation ECR par Project : acceptable, lecture seule sur des images
# deja accessibles a tout le cluster).
#
# Prerequis : addon eks-pod-identity-agent (module eks, pod-identity.tf).

locals {
  tags = merge(var.tags, {
    Project = var.project_name
  })
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "kargo" {
  name               = "role-${var.team_name}-${var.project_name}-${var.env_name}-kargo"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "ecr" {
  # Jeton du registre : ne peut pas etre restreint a un depot
  statement {
    sid       = "EcrToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Lecture des tags, manifestes et dates de build (NewestBuild)
  statement {
    sid = "EcrReadOnly"
    actions = [
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.repository_prefix}*",
    ]
  }
}

resource "aws_iam_role_policy" "ecr" {
  name   = "ecr-read-${var.repository_prefix}"
  role   = aws_iam_role.kargo.id
  policy = data.aws_iam_policy_document.ecr.json
}

# Lie le ServiceAccount <namespace>/<service_account> du cluster au role
resource "aws_eks_pod_identity_association" "kargo" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.kargo.arn
  tags            = local.tags
}
