# CNI aws-vpc-cni (DaemonSet aws-node) repris en addon EKS managé.
#
# Avant : installé en self-managed au bootstrap du cluster, hors Terraform,
# avec ENABLE_PREFIX_DELEGATION=false -> plafond réel ~33 pods/nœud sur un
# t4g.large alors que le kubelet annonce maxPods=110 (cf. ADR 002).
#
# Migration prefix delegation en 3 applies successifs sur cette ressource :
#   1. reprise de l'addon, config inchangée
#   2. WARM_IP_TARGET temporaire pour libérer les slots ENI
#   3. ENABLE_PREFIX_DELEGATION=true (cet état)
#
# addon_version figée sur la version déjà déployée (même image) : la reprise
# ne doit rien changer d'autre que la gestion par Terraform.
# preserve = true : supprimer cette ressource laisse le DaemonSet aws-node en
# place (rollback sans coupure réseau, et utile le jour d'une bascule Cilium,
# cf. ADR 005).
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.22.4-eksbuild.3"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  preserve                    = true

  # Étape 3 : prefix delegation -> chaque slot ENI porte un /28 (16 IP),
  # cohérent avec maxPods=110 du launch template (cf. ADR 002).
  # WARM_IP_TARGET / MINIMUM_IP_TARGET (étape 2) retirés : en mode prefix ils
  # prendraient le pas sur WARM_PREFIX_TARGET.
  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  tags = local.tags
}
