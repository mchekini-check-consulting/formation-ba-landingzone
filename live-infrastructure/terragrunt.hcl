# Config racine Terragrunt -- incluse par tous les terragrunt.hcl enfants via
# `include "root" { path = find_in_parent_folders() }`. Les fonctions
# find_in_parent_folders() ci-dessous se resolvent depuis le repertoire de
# l'unite qui inclut ce fichier (pas depuis ce fichier lui-meme), donc chaque
# stack (aws/environments/dev/eks, ...) remonte vers son propre env.hcl /
# account.hcl.

locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  team_name      = local.account_vars.locals.team_name
  region         = local.env_vars.locals.region
  aws_account_id = local.account_vars.locals.aws_account_id
  env_name       = local.account_vars.locals.env_name

  # Source unique des tags partages : repris tel quel dans le provider
  # genere (default_tags, ne s'applique qu'aux resources top-level "tags")
  # ET passe en input a tous les modules (var.tags), pour les cas comme
  # aws_launch_template.tag_specifications.tags qui n'heritent jamais du
  # default_tags provider (nested block, pas le tags top-level de la
  # resource) -- cf. aws/modules/eks/ADR.md.
  common_tags = {
    Team      = local.team_name
    Env       = local.env_name
    ManagedBy = "Terragrunt"
  }
}

# Backend S3 avec locking natif (use_lockfile, Terraform >= 1.10) -- pas de
# table DynamoDB necessaire. Un bucket Azure Blob suivra le meme pattern
# (backend "azurerm") le jour ou un dossier azure/ apparait a cote de aws/.
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "tfstate-${local.team_name}-${local.env_name}-landing-zone"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.region
    encrypt      = true
    use_lockfile = true
  }
}

# Provider genere a partir de env.hcl (region) et account.hcl (compte AWS
# cible) de la stack courante -- empeche un apply accidentel sur le mauvais
# compte via allowed_account_ids.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"

  allowed_account_ids = ["${local.aws_account_id}"]

  default_tags {
    tags = ${jsonencode(local.common_tags)}
  }
}
EOF
}

inputs = merge(
  local.env_vars.locals,
  local.account_vars.locals,
  { tags = local.common_tags },
)
