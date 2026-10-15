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
  description = "Cluster EKS ou tourne Kargo (output du composant eks)"
  type        = string
}

variable "repository_prefix" {
  description = "Prefixe des depots ECR lisibles par Kargo (<depot GitHub>/<composant>)"
  type        = string
  default     = "formation-ba-"
}

# Doivent correspondre a formation-ba-gitops/platform-gitops (tools.kargo.namespace
# et ServiceAccount du controleur cree par le chart)
variable "namespace" {
  description = "Namespace Kubernetes de Kargo"
  type        = string
  default     = "kargo"
}

variable "service_account" {
  description = "ServiceAccount Kubernetes du controleur Kargo"
  type        = string
  default     = "kargo-controller"
}

variable "tags" {
  description = "Tags a appliquer aux ressources"
  type        = map(string)
  default     = {}
}
