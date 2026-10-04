# CI GitHub Actions -> ECR, sans secret et sans liste figee de projets :
#   1. GitHub signe un jeton OIDC pour le job (sub = repo:<org>/<depot>:ref:refs/heads/<branche>)
#   2. AWS STS l'echange contre les credentials temporaires d'UN role commun
#   3. Le role pousse dans les depots ECR <prefixe>* ; un depot qui n'existe pas
#      encore est cree par ECR au premier push (modele CREATE_ON_PUSH ci-dessous) :
#      un nouveau depot GitHub ou un nouveau sous-repertoire avec un Dockerfile
#      ne demande aucun changement ici.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Tous les depots ECR qui commencent par le prefixe (formation-ba-*/backend, ...)
  ecr_arn_pattern = "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/${var.repository_prefix}*"
}

# Reglages appliques par ECR a tout depot cree au premier push.
# "prefix" est un namespace ECR (segment avant "/"), pas un debut de nom :
# "formation-ba-" est invalide et "formation-ba" ne couvrirait que formation-ba/...
# ROOT = tout depot cree au push ; en pratique uniquement <prefixe>*, car
# seul le role CI ci-dessous a ecr:CreateRepository, et seulement sur <prefixe>*.
resource "aws_ecr_repository_creation_template" "ci" {
  prefix               = "ROOT"
  applied_for          = ["CREATE_ON_PUSH"]
  description          = "Depots crees au premier push par la CI GitHub"
  image_tag_mutability = "IMMUTABLE" # un tag (= sha du commit) ne change jamais d'image

  lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Garder les 20 images les plus recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}

# Fournisseur d'identite GitHub : un seul par compte AWS
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = var.tags
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Tout depot <org>/<prefixe>*, uniquement depuis sa branche principale
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.repository_prefix}*:ref:refs/heads/${var.branch}"]
    }
  }
}

resource "aws_iam_role" "ci" {
  name               = "role-${var.team_name}-${var.env_name}-gha-${trimsuffix(var.repository_prefix, "-")}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "push" {
  # Jeton docker login ECR : ne se restreint pas a un depot
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push (CreateRepository : creation au premier push), uniquement sur <prefixe>*
  statement {
    sid = "PushPrefixedRepositories"
    actions = [
      "ecr:CreateRepository",
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [local.ecr_arn_pattern]
  }
}

resource "aws_iam_role_policy" "push" {
  name   = "ecr-push"
  role   = aws_iam_role.ci.id
  policy = data.aws_iam_policy_document.push.json
}
