# Sauvegardes des bases PostgreSQL (CloudNativePG) : bucket S3 + role IAM commun.
#
# Arborescence (ecrite par le plugin Barman Cloud et les CronJobs de dump,
# configures dans formation-ba-gitops, gitops/values/<common|env>/databases.yaml) :
#   <env>/<namespace>/<cluster>/                     sauvegardes physiques + WAL (PITR)
#   <env>/<namespace>/<cluster>/dumps/<base logique>/ pg_dump par base logique
#
# Acces par IRSA, sans liste figee de clusters : le role fait confiance a tout
# ServiceAccount <namespace>/<nom>-db du cluster EKS (CNPG cree un ServiceAccount
# du nom du Cluster ; les clusters s'appellent <outil>-db ou app-db). Un nouveau
# cluster ou une nouvelle base ne demande aucun changement ici.
# Les projets metier ne peuvent pas creer de ServiceAccount (whitelist de leur
# AppProject ArgoCD) : seul l'operateur CNPG en cree.
#
# Protection des donnees :
#   - versioning + Object Lock (GOVERNANCE) : une version d'objet ne peut etre ni
#     effacee ni ecrasee pendant object_lock_days ; un DELETE (retention Barman)
#     ne fait que poser un marqueur de suppression, la version reste recuperable
#   - versions remplacees/supprimees conservees noncurrent_days, puis effacees
#   - chiffrement KMS (cle dediee), acces public bloque, TLS obligatoire
#   - prevent_destroy : le bucket ne peut pas etre detruit par Terraform

data "aws_caller_identity" "current" {}

locals {
  name = "${var.team_name}-${var.project_name}-${var.env_name}-pg-backups"
  tags = merge(var.tags, {
    Project = var.project_name
  })
}

# --- Chiffrement ----------------------------------------------------------

resource "aws_kms_key" "backups" {
  description             = "Chiffrement des sauvegardes PostgreSQL (${local.name})"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = local.tags
}

resource "aws_kms_alias" "backups" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.backups.key_id
}

# --- Bucket ---------------------------------------------------------------

resource "aws_s3_bucket" "backups" {
  bucket              = local.name
  object_lock_enabled = true # uniquement a la creation du bucket
  tags                = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.backups.arn
    }
    bucket_key_enabled = true # moins d'appels KMS (cout)
  }
}

# Retention minimale de chaque version d'objet. GOVERNANCE : contournable
# uniquement avec s3:BypassGovernanceRetention (administrateurs), jamais par
# le role des bases.
resource "aws_s3_bucket_object_lock_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.object_lock_days
    }
  }
  depends_on = [aws_s3_bucket_versioning.backups]
}

# La retention "metier" (fenetre PITR, nombre de dumps) est geree cote
# Kubernetes par base (databases.yaml) ; ici seulement le menage des versions.
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "versions-remplacees-et-supprimees"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_retention_days
    }
    expiration {
      expired_object_delete_marker = true
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.backups]
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
    resources = [aws_s3_bucket.backups.arn, "${aws_s3_bucket.backups.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "backups" {
  bucket     = aws_s3_bucket.backups.id
  policy     = data.aws_iam_policy_document.bucket.json
  depends_on = [aws_s3_bucket_public_access_block.backups]
}

# --- Role IRSA des bases ---------------------------------------------------

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Tout namespace, ServiceAccount <nom>-db (= nom du Cluster CNPG)
    condition {
      test     = "StringLike"
      variable = "${var.oidc_issuer}:sub"
      values   = var.service_account_patterns
    }
  }
}

resource "aws_iam_role" "backups" {
  name               = "role-${var.team_name}-${var.project_name}-${var.env_name}-pg-backups"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "backups" {
  statement {
    sid       = "BucketLocation"
    actions   = ["s3:GetBucketLocation"]
    resources = [aws_s3_bucket.backups.arn]
  }

  # Listing limite au prefixe de l'environnement
  statement {
    sid       = "ListEnv"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.backups.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.env_name}/*"]
    }
  }

  # Lecture (restauration), ecriture (sauvegarde), suppression (retention :
  # simple marqueur, la version reste protegee par Object Lock)
  statement {
    sid = "ObjectsEnv"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.backups.arn}/${var.env_name}/*"]
  }

  statement {
    sid = "Kms"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.backups.arn]
  }
}

resource "aws_iam_role_policy" "backups" {
  name   = "s3-${local.name}"
  role   = aws_iam_role.backups.id
  policy = data.aws_iam_policy_document.backups.json
}
