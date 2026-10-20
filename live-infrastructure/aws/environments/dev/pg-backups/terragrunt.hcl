include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/live-infrastructure/aws/modules//pg-backups"
}

# Le fournisseur OIDC du cluster (IRSA) vient du composant eks.
# mock_outputs : permet un plan avant l'apply d'eks qui le cree.
dependency "eks" {
  config_path = "../eks"

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
}
