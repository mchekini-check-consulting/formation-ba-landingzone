# Logs du cluster : stockage de Loki.
#
#   - bucket S3 de Loki (chunks + index TSDB), ecrit par logging/loki
#   - role IAM de Loki, donne au pod par EKS Pod Identity
#
# Retention a deux niveaux (doivent rester coherents avec formation-ba-gitops,
# gitops/values/<env>/loki.yaml : loki.limits_config.retention_period) :
#   - Loki (compactor) supprime les logs plus vieux que retention_days
#   - S3 expire tout objet de plus de retention_days + lifecycle_margin_days :
#     filet de securite si le compactor ne tourne plus, jamais le mecanisme normal
# Pas de versioning : un objet supprime par le compactor doit vraiment disparaitre.
#
# Prerequis : addon eks-pod-identity-agent (module eks, pod-identity.tf).

locals {
  name = "${var.team_name}-${var.project_name}-${var.env_name}-loki"
  tags = merge(var.tags, {
    Project = var.project_name
  })
}

# --- Bucket Loki -----------------------------------------------------------

resource "aws_s3_bucket" "loki" {
  bucket = local.name
  tags   = local.tags
}

resource "aws_s3_bucket_ownership_controls" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "loki" {
  bucket                  = aws_s3_bucket.loki.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-S3 : logs non sensibles au point de justifier une cle KMS dediee (cout
# des appels KMS a chaque chunk ecrit/lu)
resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    id     = "expiration-filet-de-securite"
    status = "Enabled"
    filter {}

    expiration {
      days = var.retention_days + var.lifecycle_margin_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid     = "TlsObligatoire"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [aws_s3_bucket.loki.arn, "${aws_s3_bucket.loki.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "loki" {
  bucket     = aws_s3_bucket.loki.id
  policy     = data.aws_iam_policy_document.bucket.json
  depends_on = [aws_s3_bucket_public_access_block.loki]
}

# --- Role Pod Identity -----------------------------------------------------

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "loki" {
  name               = "role-${var.team_name}-${var.project_name}-${var.env_name}-loki"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}

# Lecture, ecriture, suppression (retention du compactor) dans ce seul bucket
data "aws_iam_policy_document" "loki" {
  statement {
    sid       = "Bucket"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.loki.arn]
  }

  statement {
    sid = "Objects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.loki.arn}/*"]
  }
}

resource "aws_iam_role_policy" "loki" {
  name   = "s3-${local.name}"
  role   = aws_iam_role.loki.id
  policy = data.aws_iam_policy_document.loki.json
}

resource "aws_eks_pod_identity_association" "loki" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.loki_service_account
  role_arn        = aws_iam_role.loki.arn
  tags            = local.tags
}
