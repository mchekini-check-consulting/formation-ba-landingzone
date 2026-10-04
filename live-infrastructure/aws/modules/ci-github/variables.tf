variable "team_name" {
  description = "Nom de l'equipe"
  type        = string
}

variable "env_name" {
  description = "Nom de l'environnement (dev, prod, ...)"
  type        = string
}

variable "github_org" {
  description = "Organisation GitHub des depots applicatifs"
  type        = string
}

variable "repository_prefix" {
  description = "Prefixe commun aux depots GitHub ET aux depots ECR (ex. formation-ba-) : tout nouveau depot qui le porte est autorise sans modifier Terraform"
  type        = string
}

variable "branch" {
  description = "Seule branche autorisee a pousser (condition sur le sub du jeton OIDC)"
  type        = string
  default     = "main"
}

variable "tags" {
  description = "Tags a appliquer aux ressources"
  type        = map(string)
  default     = {}
}
