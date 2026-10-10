# Driver EBS CSI : volumes persistants (PVC) sur EBS. Composant du cluster,
# requis par tout outil qui stocke des données (CloudNativePG, SonarQube, ...).
# Crée aussi la StorageClass gp3 par défaut du cluster (defaultStorageClass) :
# un PVC sans storageClassName obtient un volume gp3 chiffré.
#
# Credentials AWS du contrôleur via EKS Pod Identity (pod-identity.tf).

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "role-${var.team_name}-${var.project_name}-${var.env_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
  tags               = local.tags
}

# Politique gérée AWS : création / attachement / suppression des volumes EBS
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ServiceAccount créé par l'addon pour le contrôleur
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
  tags            = local.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"

  configuration_values = jsonencode({
    defaultStorageClass = { enabled = true } # StorageClass gp3 par défaut
  })

  tags = local.tags

  # Le contrôleur a besoin de nœuds pour démarrer et de ses credentials dès le départ
  depends_on = [
    aws_eks_node_group.apps,
    aws_eks_addon.pod_identity_agent,
    aws_eks_pod_identity_association.ebs_csi,
    aws_iam_role_policy_attachment.ebs_csi,
  ]
}
