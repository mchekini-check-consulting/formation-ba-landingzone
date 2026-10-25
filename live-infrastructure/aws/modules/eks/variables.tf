variable "team_name" {
  description = "Nom de l'equipe"
  type        = string
  default     = "formation"
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "ecom"
}

variable "env_name" {
  description = "Nom de l'environnement (dev, prod, ...)"
  type        = string
}

variable "cluster_version" {
  description = "Version Kubernetes du control plane EKS. null = derniere version stable EKS au moment de l'apply."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR du VPC dedie au cluster EKS"
  type        = string
  default     = "10.4.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR des subnets publics, un par AZ"
  type        = list(string)
  default     = ["10.4.0.0/20", "10.4.16.0/20", "10.4.32.0/20"]
}

variable "availability_zones" {
  description = "AZ utilisees pour les subnets"
  type        = list(string)
  default     = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
}

# t4g.large = 2 vCPU / 8 Gio, Graviton2 (ARM64) burstable
variable "node_instance_type" {
  description = "Type d'instance du node group"
  type        = string
  default     = "t4g.large"
}

variable "node_count" {
  description = "Nombre de noeuds fixes du node group (pas d'autoscaling)"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags a appliquer aux ressources"
  type        = map(string)
  default     = {}
}
