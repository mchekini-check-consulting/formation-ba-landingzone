output "role_arn" {
  description = "Role IAM du controleur Kargo (EKS Pod Identity)"
  value       = aws_iam_role.kargo.arn
}
