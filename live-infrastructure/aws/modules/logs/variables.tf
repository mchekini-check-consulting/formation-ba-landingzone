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
  description = "Cluster EKS ou tournent Loki et Grafana (output du composant eks)"
  type        = string
}

variable "eks_log_group_arn" {
  description = "Groupe CloudWatch des logs du control plane EKS, lu par Grafana (output du composant eks)"
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

# Doivent correspondre a formation-ba-gitops (tools.loki.namespace, tools.grafana.namespace
# et ServiceAccounts des values/common/loki.yaml et grafana.yaml)
variable "namespace" {
  description = "Namespace Kubernetes de Loki et Grafana"
  type        = string
  default     = "logging"
}

variable "loki_service_account" {
  description = "ServiceAccount Kubernetes de Loki"
  type        = string
  default     = "loki"
}

variable "grafana_service_account" {
  description = "ServiceAccount Kubernetes de Grafana"
  type        = string
  default     = "grafana"
}

variable "tags" {
  description = "Tags a appliquer aux ressources"
  type        = map(string)
  default     = {}
}
