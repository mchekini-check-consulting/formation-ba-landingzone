# Role IAM de cert-manager, donne au pod via EKS Pod Identity.
# Validation DNS-01 de Let's Encrypt pour les certificats wildcard :
#   - *.<zone_name>                     (plateforme : argocd-dev, sonarqube-dev, ...)
#   - *.<projet>.<env>.<zone_name>      (applications : <app>.<projet>.<env>.<zone_name>)
# cert-manager ne peut ecrire QUE des enregistrements TXT _acme-challenge.* de
# cette zone Route53 ; tout autre nom ou type est refuse par IAM.
#
# Prerequis : addon eks-pod-identity-agent (module eks, pod-identity.tf).

locals {
  tags = merge(var.tags, {
    Project = var.project_name
  })

  # Noms des challenges ACME (forme normalisee Route53) : wildcard de la zone
  # et wildcards des sous-domaines <projet>.<env>
  challenge_names = [
    "_acme-challenge.${var.zone_name}",
    "_acme-challenge.*.${var.zone_name}",
  ]
}

data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = false
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cert_manager" {
  name               = "role-${var.team_name}-${var.project_name}-${var.env_name}-cert-manager"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "route53" {
  # Ecriture : uniquement le TXT du challenge ACME, dans cette zone
  statement {
    sid       = "AcmeChallengeTxtOnly"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [data.aws_route53_zone.this.arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values   = local.challenge_names
    }
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsRecordTypes"
      values   = ["TXT"]
    }
  }

  # Lecture des enregistrements de cette zone uniquement
  statement {
    sid       = "ReadZone"
    actions   = ["route53:ListResourceRecordSets"]
    resources = [data.aws_route53_zone.this.arn]
  }

  # Attente de la propagation du TXT avant de demander la validation
  statement {
    sid       = "WatchPropagation"
    actions   = ["route53:GetChange"]
    resources = ["arn:aws:route53:::change/*"]
  }

  # Recherche de zone : ne peut pas etre restreinte a une zone (lecture seule)
  statement {
    sid       = "ListZones"
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "route53" {
  name   = "route53-acme-${var.zone_name}"
  role   = aws_iam_role.cert_manager.id
  policy = data.aws_iam_policy_document.route53.json
}

# Lie le ServiceAccount <namespace>/<service_account> du cluster au role
resource "aws_eks_pod_identity_association" "cert_manager" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.cert_manager.arn
  tags            = local.tags
}
