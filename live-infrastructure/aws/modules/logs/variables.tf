variable "team_name" {
  description = "Nom de l'equipe"
  type        = string
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "env_name" {
  description = "Nom de l'environnement (dev, prod, ...)"
  type        = string
}

variable "cluster_name" {
  description = "Cluster EKS ou tourne Loki (output du composant eks)"
  type        = string
}

# Doit correspondre a formation-ba-gitops : gitops/values/<env>/loki.yaml
# (loki.limits_config.retention_period = retention_days * 24h)
variable "retention_days" {
  description = "Retention des logs dans Loki (compactor), en jours"
  type        = number
  default     = 30
}

variable "lifecycle_margin_days" {
  description = "Jours ajoutes a retention_days avant l'expiration S3 (filet de securite)"
  type        = number
  default     = 7
}

# Doivent correspondre a formation-ba-gitops (tools.loki.namespace et
# ServiceAccount de values/common/loki.yaml)
variable "namespace" {
  description = "Namespace Kubernetes de Loki"
  type        = string
  default     = "logging"
}

variable "loki_service_account" {
  description = "ServiceAccount Kubernetes de Loki"
  type        = string
  default     = "loki"
}

variable "tags" {
  description = "Tags a appliquer aux ressources"
  type        = map(string)
  default     = {}
}
