variable "team_name" {
  description = "Nom de l'equipe"
  type        = string
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "env_name" {
  description = "Nom de l'environnement (dev, prod, ...) : prefixe des objets du bucket"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN du fournisseur OIDC IAM du cluster EKS (output du composant eks)"
  type        = string
}

variable "oidc_issuer" {
  description = "Emetteur OIDC du cluster EKS sans https:// (output du composant eks)"
  type        = string
}

# Doit correspondre aux noms des Clusters CNPG (formation-ba-gitops :
# tools.<outil>-db et app-db des projets metier)
variable "service_account_patterns" {
  description = "Sub des ServiceAccounts autorises a assumer le role (StringLike)"
  type        = list(string)
  default     = ["system:serviceaccount:*:*-db"]
}

variable "object_lock_days" {
  description = "Duree pendant laquelle une version d'objet ne peut etre ni effacee ni ecrasee (Object Lock GOVERNANCE)"
  type        = number
  default     = 7
}

variable "noncurrent_retention_days" {
  description = "Conservation des versions remplacees ou supprimees avant effacement definitif"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags a appliquer aux ressources"
  type        = map(string)
  default     = {}
}
