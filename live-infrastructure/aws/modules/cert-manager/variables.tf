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
  description = "Cluster EKS ou tourne cert-manager (output du composant eks)"
  type        = string
}

variable "zone_name" {
  description = "Zone Route53 publique des certificats wildcard *.<env>.<zone_name> et *.<projet>.<env>.<zone_name> (challenge DNS-01)"
  type        = string
  default     = "check-consulting.net"
}

# Doivent correspondre a formation-ba-gitops/platform-gitops (values/common/cert-manager.yaml et
# tools.cert-manager.namespace)
variable "namespace" {
  description = "Namespace Kubernetes de cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "service_account" {
  description = "ServiceAccount Kubernetes du controleur cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "tags" {
  description = "Tags a appliquer aux ressources"
  type        = map(string)
  default     = {}
}
