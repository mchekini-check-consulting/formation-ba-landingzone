output "vpc_id" {
  description = "ID du VPC"
  value       = aws_vpc.eks.id
}

output "subnet_ids" {
  description = "ID des subnets publics, un par AZ"
  value       = aws_subnet.eks[*].id
}

output "cluster_name" {
  description = "Nom du cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint de l'API server EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Certificat CA du cluster (base64)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN du fournisseur OIDC IAM du cluster (IRSA)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_issuer" {
  description = "Emetteur OIDC du cluster, sans https:// (prefixe des conditions IRSA)"
  value       = trimprefix(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://")
}

output "kubeconfig_command" {
  description = "Commande pour generer le kubeconfig local"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${aws_eks_cluster.main.name}"
}
