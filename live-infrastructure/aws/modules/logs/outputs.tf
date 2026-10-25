# A reporter dans formation-ba-gitops, gitops/values/<env>/loki.yaml
output "bucket_name" {
  description = "Bucket S3 de Loki (loki.storage.bucketNames)"
  value       = aws_s3_bucket.loki.id
}

output "loki_role_arn" {
  description = "Role IAM de Loki (Pod Identity, rien a annoter cote Kubernetes)"
  value       = aws_iam_role.loki.arn
}

output "grafana_role_arn" {
  description = "Role IAM de Grafana pour la datasource CloudWatch (Pod Identity)"
  value       = aws_iam_role.grafana.arn
}
