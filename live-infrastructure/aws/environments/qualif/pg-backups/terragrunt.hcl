include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/live-infrastructure/aws/modules//pg-backups"
}

# qualif n'a pas son propre EKS : fournisseur OIDC du cluster de dev.
# mock_outputs : permet un plan avant l'apply d'eks qui le cree.
dependency "eks" {
  config_path = "../../dev/eks"

  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/oidc.eks.eu-west-3.amazonaws.com/id/MOCK"
    oidc_issuer       = "oidc.eks.eu-west-3.amazonaws.com/id/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  project_name      = "business-analyst-formation"
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_issuer       = dependency.eks.outputs.oidc_issuer
  # Cluster partage avec dev : seuls les Clusters des namespaces qualif-<projet>
  # peuvent assumer le role
  service_account_patterns = ["system:serviceaccount:qualif-*:*-db"]
}
