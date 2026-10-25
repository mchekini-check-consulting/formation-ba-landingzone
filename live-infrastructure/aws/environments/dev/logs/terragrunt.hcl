include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/live-infrastructure/aws/modules//logs"
}

# Le cluster (et son addon eks-pod-identity-agent) vient du composant eks.
# mock_outputs : permet un plan avant l'apply d'eks.
# Cluster partage par dev et qualif : un seul Loki, un seul bucket.
dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  project_name = "business-analyst-formation"
  cluster_name = dependency.eks.outputs.cluster_name

  # = gitops/values/dev/loki.yaml : loki.limits_config.retention_period (720h)
  retention_days = 30
}
