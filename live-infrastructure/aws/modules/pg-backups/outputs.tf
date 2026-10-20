# A reporter dans formation-ba-gitops, gitops/values/<env>/databases.yaml
output "bucket_name" {
  description = "Bucket des sauvegardes PostgreSQL"
  value       = aws_s3_bucket.backups.id
}

output "role_arn" {
  description = "Role IRSA des Clusters CNPG (annotation eks.amazonaws.com/role-arn)"
  value       = aws_iam_role.backups.arn
}

output "kms_key_arn" {
  description = "Cle KMS de chiffrement du bucket"
  value       = aws_kms_key.backups.arn
}
