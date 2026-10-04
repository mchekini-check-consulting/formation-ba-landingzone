output "role_arn" {
  description = "Role IAM commun (role-to-assume des workflows)"
  value       = aws_iam_role.ci.arn
}

output "registry" {
  description = "Registre ECR du compte"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com"
}
