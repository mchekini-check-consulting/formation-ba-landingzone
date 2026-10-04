include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/live-infrastructure/aws/modules//eks"
}

locals {
  kubernetes_version = "1.31"
}

inputs = {
  # team_name et env_name viennent deja de account.hcl, merges dans les
  # inputs du root terragrunt.hcl -- pas besoin de les repeter ici.
  project_name = "business-analyst-formation"

  cluster_version = local.kubernetes_version

  # 4 VM Graviton2 (ARM64), famille burstable
  node_instance_type = "t4g.large"
  node_count         = 4
}
