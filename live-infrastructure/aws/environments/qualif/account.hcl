# qualif : heberge sur le cluster EKS de dev (namespaces qualif-<projet>),
# meme compte AWS ; seules ses ressources propres sont declarees ici.
locals {
  team_name      = "team-eks"
  aws_account_id = "205493924920"
  env_name       = "qualif"
}
