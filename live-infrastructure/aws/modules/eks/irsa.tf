# Fournisseur OIDC IAM du cluster (IRSA) : un role IAM peut faire confiance aux
# ServiceAccounts du cluster par motif (StringLike sur le sub du jeton), ce que
# Pod Identity ne permet pas (une association par ServiceAccount exact).
# Utilise par les sauvegardes CloudNativePG (module pg-backups) : chaque nouveau
# cluster de base (<nom>-db) obtient l'acces S3 sans changement Terraform.
# Composant du cluster, partage : chaque outil cree son role dans son module.
resource "aws_iam_openid_connect_provider" "eks" {
  url            = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
  tags           = local.tags
}
