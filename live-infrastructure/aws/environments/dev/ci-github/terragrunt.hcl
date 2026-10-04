include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/live-infrastructure/aws/modules//ci-github"
}

# Le provider OIDC GitHub est unique par compte AWS : ce composant le porte
# pour le compte dev (205493924920).
inputs = {
  github_org        = "mchekini-check-consulting"
  github_org_id     = "115934988"
  repository_prefix = "formation-ba-"
}
