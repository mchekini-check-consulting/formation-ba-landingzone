include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/live-infrastructure/aws/modules//external-dns"
}

# Le cluster (et son addon eks-pod-identity-agent) doit exister avant
# l'association Pod Identity. mock_outputs : permet un plan avant le
# premier apply d'eks.
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
  zone_name    = "check-consulting.net"
}
