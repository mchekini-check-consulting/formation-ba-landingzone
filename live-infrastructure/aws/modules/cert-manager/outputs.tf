output "role_arn" {
  description = "Role IAM de cert-manager (EKS Pod Identity)"
  value       = aws_iam_role.cert_manager.arn
}

output "zone_id" {
  description = "ID de la zone Route53 (a reporter dans hostedZoneID du ClusterIssuer)"
  value       = data.aws_route53_zone.this.zone_id
}
