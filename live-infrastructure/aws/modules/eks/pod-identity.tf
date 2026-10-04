# Agent EKS Pod Identity : distribue des credentials IAM aux pods dont le
# ServiceAccount a une association (aws_eks_pod_identity_association).
# Composant du cluster, partagé par tous les outils qui appellent AWS
# (external-dns, plus tard vault-secrets-operator, ...) : chaque outil crée
# son rôle et son association dans son propre module.
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"
  tags         = local.tags
}
