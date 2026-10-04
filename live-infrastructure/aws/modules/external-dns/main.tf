# Role IAM d'external-dns, donne au pod via EKS Pod Identity.
# Il ne peut modifier QUE les enregistrements *.<zone_name> de cette zone
# Route53 : l'apex, les autres zones et les autres domaines racine sont
# refuses par IAM, quelle que soit la config cote Kubernetes.
#
# Prerequis : addon eks-pod-identity-agent (module eks, pod-identity.tf).

locals {
  tags = merge(var.tags, {
    Project = var.project_name
  })
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

resource "aws_iam_role" "external_dns" {
  name               = "role-${var.team_name}-${var.project_name}-${var.env_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "route53" {
  # Ecriture : une seule zone, et seulement des sous-domaines
  statement {
    sid       = "ChangeSubdomainRecordsOnly"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [data.aws_route53_zone.this.arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values   = ["*.${var.zone_name}"]
    }
  }

  # Lecture des enregistrements de cette zone uniquement
  statement {
    sid = "ReadZone"
    actions = [
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResources",
    ]
    resources = [data.aws_route53_zone.this.arn]
  }

  # Lister les zones ne peut pas etre restreint a une zone (lecture seule)
  statement {
    sid       = "ListZones"
    actions   = ["route53:ListHostedZones"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "route53" {
  name   = "route53-${var.zone_name}"
  role   = aws_iam_role.external_dns.id
  policy = data.aws_iam_policy_document.route53.json
}

# Lie le ServiceAccount <namespace>/<service_account> du cluster au role
resource "aws_eks_pod_identity_association" "external_dns" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.external_dns.arn
  tags            = local.tags
}
