output "role_arn" {
  description = "Role IAM d'external-dns (EKS Pod Identity)"
  value       = aws_iam_role.external_dns.arn
}

output "zone_id" {
  description = "ID de la zone Route53 geree (a reporter dans --zone-id-filter)"
  value       = data.aws_route53_zone.this.zone_id
}
