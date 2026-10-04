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
  description = "Cluster EKS ou tourne external-dns (output du composant eks)"
  type        = string
}

variable "zone_name" {
  description = "Zone Route53 publique dont external-dns peut gerer les sous-domaines (et uniquement eux)"
  type        = string
  default     = "check-consulting.net"
}

# Doivent correspondre a platform-gitops (values/common/external-dns.yaml et
# tools.external-dns.namespace)
variable "namespace" {
  description = "Namespace Kubernetes d'external-dns"
  type        = string
  default     = "external-dns"
}

variable "service_account" {
  description = "ServiceAccount Kubernetes d'external-dns"
  type        = string
  default     = "external-dns"
}

variable "tags" {
  description = "Tags a appliquer aux ressources"
  type        = map(string)
  default     = {}
}
