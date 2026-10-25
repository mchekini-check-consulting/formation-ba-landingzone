# Backend et provider "aws" sont generes par Terragrunt (remote_state /
# generate "provider" dans terragrunt.hcl) -- ce module ne declare que les
# providers requis, pas leur configuration.
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
