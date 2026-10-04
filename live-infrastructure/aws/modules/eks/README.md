# Module `eks`

VPC dedie + cluster EKS + 1 node group (4x `t4g.large` ARM64 Graviton2,
burstable). Voir [ADR.md](./ADR.md) pour le detail des choix d'architecture.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_cluster.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.apps](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_role.eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.eks_cluster_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_node_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_node_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_internet_gateway.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_launch_template.apps](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_route_table.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_iam_policy_document.eks_cluster_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_node_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | AZ utilisees pour les subnets | `list(string)` | <pre>[<br/>  "eu-west-3a",<br/>  "eu-west-3b",<br/>  "eu-west-3c"<br/>]</pre> | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Version Kubernetes du control plane EKS. null = derniere version stable EKS au moment de l'apply. | `string` | `null` | no |
| <a name="input_env_name"></a> [env\_name](#input\_env\_name) | Nom de l'environnement (dev, prod, ...) | `string` | n/a | yes |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Nombre de noeuds fixes du node group (pas d'autoscaling) | `number` | `4` | no |
| <a name="input_node_instance_type"></a> [node\_instance\_type](#input\_node\_instance\_type) | Type d'instance du node group | `string` | `"t4g.large"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Nom du projet | `string` | `"ecom"` | no |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | CIDR des subnets publics, un par AZ | `list(string)` | <pre>[<br/>  "10.4.0.0/20",<br/>  "10.4.16.0/20",<br/>  "10.4.32.0/20"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags a appliquer aux ressources | `map(string)` | `{}` | no |
| <a name="input_team_name"></a> [team\_name](#input\_team\_name) | Nom de l'equipe | `string` | `"formation"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR du VPC dedie au cluster EKS | `string` | `"10.4.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | Certificat CA du cluster (base64) |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint de l'API server EKS |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Nom du cluster EKS |
| <a name="output_kubeconfig_command"></a> [kubeconfig\_command](#output\_kubeconfig\_command) | Commande pour generer le kubeconfig local |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | ID des subnets publics, un par AZ |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID du VPC |
<!-- END_TF_DOCS -->
