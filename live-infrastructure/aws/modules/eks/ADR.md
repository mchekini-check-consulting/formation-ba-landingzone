# ADR -- Module `aws/modules/eks`

Historique des decisions d'architecture prises pour ce module. Format
[ADR](https://adr.github.io/) : Contexte / Decision / Consequences. Statut
`Accepte` = applique dans le code actuel, `Accepte (report)` = tranche mais
pas encore implemente.

| # | Titre | Statut |
|---|-------|--------|
| [001](#001-perimetre-minimal-du-module) | Perimetre minimal du module | Accepte |
| [002](#002-node-group-unique-4x-t4glarge-arm64) | Node group unique 4x t4g.large ARM64 | Accepte |
| [003](#003-version-kubernetes-pilotee-par-environnement) | Version Kubernetes pilotee par environnement | Accepte |
| [004](#004-roles-iam-colocalises-dans-le-module) | Roles IAM colocalises dans le module | Accepte |
| [005](#005-cni--rester-sur-aws-vpc-cni-migration-cilium-eni-reportee) | CNI : rester sur aws-vpc-cni, migration Cilium ENI reportee | Accepte (report) |
| [006](#006-abandon-decr-au-profit-de-harbor) | Abandon d'ECR au profit de Harbor | Accepte |
| [007](#007-backend-et-provider-generes-par-terragrunt-pas-dans-le-module) | Backend et provider generes par Terragrunt, pas dans le module | Accepte |
| [008](#008-localtags--mergevartags-project---jamais-vide) | `local.tags = merge(var.tags, {Project})` -- jamais vide | Accepte |

---

## 001. Perimetre minimal du module

**Contexte** -- Le premier jet du module (porte depuis l'ancien
`aws-eks/`) incluait aussi Vault (KMS auto-unseal + role IRSA), le role IRSA
EBS CSI et le role + policy IRSA AWS Load Balancer Controller. Le besoin
exprime etait "juste deployer un EKS 4 VM".

**Decision** -- Le module `eks` se limite a : VPC dedie (1 IGW, N subnets
publics, 1 route table), cluster EKS, 1 IAM role cluster, 1 IAM role node,
1 node group.

**Consequences** -- Vault, EBS CSI, AWS LB Controller ne sont pas geres ici.
Ils reviendront comme unites Terragrunt separees (ou un module dedie) le jour
ou le besoin est confirme, suivant le meme pattern que `eks/`.

## 002. Node group unique 4x t4g.large ARM64

**Contexte** -- L'architecture source (Azure/AKS puis premiere version AWS)
avait 3 node groups (system/apps/db, t3.medium x86_64) avec taints/labels par
tier. Le besoin reformule etait : 4 VM, `t4g.large`, ARM64 Graviton2,
burstable.

**Decision** -- Un seul node group `apps`, `desired = min = max =
var.node_count` (defaut 4), `instance_type = var.node_instance_type` (defaut
`t4g.large`) via `aws_launch_template`, et `ami_type =
"AL2023_ARM_64_STANDARD"` explicite sur le node group (sans cet argument EKS
resout par defaut une AMI x86_64, incompatible avec une instance ARM).

**Consequences** -- Pas d'isolation par tier (system/apps/db) ni
d'autoscaling (Karpenter reporte, comme dans le module d'origine). Le
`NodeConfig` du launch template fixe `kubelet.maxPods: 110`, ce qui suppose
`ENABLE_PREFIX_DELEGATION=true` sur l'addon `vpc-cni` -- **cet addon n'est
pas configure dans ce module minimal**, donc le plafond reel de pods/noeud
reste aujourd'hui le defaut ENI d'un `t4g.large`, pas 110. A corriger quand
le CNI sera tranche definitivement (cf. [005](#005)).

## 003. Version Kubernetes pilotee par environnement

**Contexte** -- La version du control plane ne doit pas etre figee dans le
module partage par tous les environnements : dev peut suivre la derniere
version, prod peut vouloir rester en retard volontairement.

**Decision** -- `variable "cluster_version"` (defaut `null` = derniere
version stable EKS au moment de l'apply), consommee par
`aws_eks_cluster.main.version`. Chaque stack fixe sa valeur via un
`locals.kubernetes_version` dans son propre `environments/<env>/eks/terragrunt.hcl`
et la passe en `inputs.cluster_version` -- pas dans `env.hcl` (regional,
partage) ni `account.hcl` (identite du compte), car c'est un choix propre a
ce composant EKS.

**Consequences** -- Upgrade de version = un diff d'une ligne dans le
`terragrunt.hcl` de l'environnement concerne, sans toucher au module ni aux
autres environnements.

## 004. Roles IAM colocalises dans le module

**Contexte** -- Question : pourquoi `iam.tf` (role cluster + role node +
attachements de policies AWS managees) vit dans le module `eks` plutot que
dans un stack IAM a part (ex. `aws/global/`) ?

**Decision** -- Ces roles restent dans le module car ils n'ont aucun usage
en dehors de ce cluster precis : un seul assume-role principal chacun
(`eks.amazonaws.com` / `ec2.amazonaws.com`), meme cycle de vie
(creation/destruction avec le cluster), et duplication volontaire par
environnement (le node role de `dev` n'a strictement rien a voir avec celui
de `prod`, meme compte AWS ou non). Les mettre dans le module garde `eks/`
autonome : `terragrunt apply` sur une stack suffit, sans dependance vers un
stack IAM externe deploye a part.

**Consequences** -- Si un role IAM devient *transverse* (partage entre
plusieurs clusters/composants, ex. un role CI/CD), il ira dans
`aws/global/`, pas ici -- regle de decision : "un seul consommateur et meme
lifecycle que le cluster" => module local ; "plusieurs consommateurs ou
lifecycle independant" => `aws/global/`.

## 005. CNI : rester sur aws-vpc-cni, migration Cilium ENI reportee

**Contexte** -- Le CNI par defaut d'EKS est `aws-vpc-cni` (DaemonSet
`aws-node`), installe au bootstrap des noeuds. Cilium en mode **ENI** (IPAM
AWS natif, Cilium remplace `aws-node` mais reutilise les memes permissions
EC2 d'allocation d'IP/ENI) est envisage pour la gestion des NetworkPolicies.

**Decision** -- Ne pas basculer maintenant. Rester sur `aws-vpc-cni` par
defaut. Le node role garde `AmazonEKS_CNI_Policy` (`eks.tf` /
`aws_iam_role_policy_attachment.eks_node_cni`) en anticipation de la bascule
future : Cilium en mode ENI a besoin des memes droits EC2
(DescribeSubnets/CreateNetworkInterface/AssignPrivateIpAddresses/...) que
`aws-vpc-cni`, donc cette policy n'est pas a retirer, juste a reutiliser le
jour de la bascule.

**Consequences** -- La bascule vers Cilium (suppression du DaemonSet
`aws-node`, non-installation de l'addon EKS `vpc-cni`, `helm install cilium
... --set eni.enabled=true --set ipam.mode=eni --set
egressMasqueradeInterfaces=eth0`) se fera hors Terraform (Helm/ArgoCD), sans
changement cote IAM. A ce moment-la, revoir aussi le point maxPods=110
souleve en [002](#002) : Cilium ENI gere son propre IPAM et son propre
plafond de pods/noeud, independant de `ENABLE_PREFIX_DELEGATION`.

## 006. Abandon d'ECR au profit de Harbor

> **Corrige apres un `apply` reel.** La policy ECR a ete retiree du node
> role puis **remise** : elle n'est pas liee au choix du registre
> applicatif, elle est exigee par EKS lui-meme (cf. Correction ci-dessous).
> Conservee ici pour tracer l'erreur, pas seulement le resultat final.

**Contexte** -- Le node role avait `AmazonEC2ContainerRegistryReadOnly`
pour pull des images depuis ECR.

**Decision (initiale, erronee)** -- Policy retiree
(`aws_iam_role_policy_attachment.eks_node_ecr` supprimee de `iam.tf`,
reference retiree du `depends_on` de `aws_eks_node_group.apps`). Harbor
sera installe plus tard comme registre applicatif de reference.

**Consequences (anticipees, incompletes)** -- Aucun droit IAM AWS necessaire
pour Harbor (registre tiers, pas un service AWS) : l'authentification des
pulls se fera via `imagePullSecrets` / credentials Harbor cote Kubernetes,
hors scope de ce module.

**Correction** -- Le premier `apply` reel avec cette policy retiree a
echoue : `aws_eks_node_group.apps` termine en `CREATE_FAILED` apres ~33 min,
`NodeCreationFailure: Unhealthy nodes in the kubernetes cluster` sur les 4
instances. Cause reelle : `kube-proxy` et le plugin `vpc-cni` (composants
**systeme** du cluster, pas des images applicatives) sont pulles depuis des
repos ECR **geres par AWS** dans chaque region au bootstrap de chaque node --
`AmazonEC2ContainerRegistryReadOnly` (ou equivalent) est donc exigee par EKS
sur *tout* node role, independamment du registre choisi pour les images
applicatives. Sans elle, kubelet demarre mais les pods systeme ne passent
jamais `Running`, le node reste `Unhealthy`, et le node group entier echoue.
La policy a ete remise dans `iam.tf` (`aws_iam_role_policy_attachment.eks_node_ecr`)
avec le `depends_on` correspondant sur `aws_eks_node_group.apps`.

**Consequences (revisees)** -- Harbor remplace ECR pour les images
**applicatives** uniquement (`imagePullSecrets` cote Kubernetes, toujours
hors scope Terraform) -- mais `AmazonEC2ContainerRegistryReadOnly` reste
necessaire sur le node role pour le bootstrap des composants systeme EKS,
qu'on utilise ECR pour ses propres images ou non. Le titre de cette decision
("abandon d'ECR") ne s'applique donc qu'a l'usage applicatif, pas au node
role.

## 007. Backend et provider generes par Terragrunt, pas dans le module

**Contexte** -- L'ancien `aws-eks/providers.tf` declarait un `backend "s3"`
et un `provider "aws"` en dur dans le code Terraform.

**Decision** -- Le module ne declare que `required_providers` (`versions.tf`).
Le backend S3 (`remote_state`) et le `provider "aws"` (region + 
`allowed_account_ids` + `default_tags`) sont generes par le `terragrunt.hcl`
racine (`generate "provider"`), a partir de `env.hcl` (region) et
`account.hcl` (compte AWS, nom d'environnement) de chaque stack.

**Consequences** -- Le meme module `eks` est reutilisable tel quel pour
`dev` et `prod` sans dupliquer de configuration provider/backend ; le
garde-fou `allowed_account_ids` empeche un `apply` accidentel sur le mauvais
compte AWS.

## 008. `local.tags = merge(var.tags, {Project})` -- jamais vide

**Contexte** -- Premier `apply` reel echoue sur `aws_launch_template.apps` :
`InvalidTagSpecification.Malformed: The tags cannot be null or empty`.
`var.tags` valait `{}` (defaut de la variable, rien ne le renseignait) --
et le `default_tags` du provider genere par Terragrunt
([racine ADR 003](../../../ADR.md#003-provider-et-garde-fou-de-compte-generes-depuis-accounthcl))
ne s'applique qu'aux `tags` top-level d'une resource, jamais aux blocs
imbriques comme `tag_specifications.tags` -- ce bloc arrivait donc reellement
vide cote API EC2.

**Decision** -- Corrige a deux niveaux, cf.
[racine ADR 009](../../../ADR.md#009-tags-partages-centralises-au-root-localcommon_tags-propages-via-inputstags) :
le root fournit desormais toujours `inputs.tags` (Team/Env/ManagedBy, jamais
vide) -- mais le module reste defensif independamment de cette garantie
externe : `local.tags = merge(var.tags, { Project = var.project_name })`
(dans `vpc.tf`), utilise partout a la place de `var.tags` brut
(`eks.tf`, `iam.tf`, `vpc.tf`).

**Consequences** -- Le module ne peut plus jamais produire une
`tag_specifications.tags` vide, meme appele isolement (tests, autre root
terragrunt, module reutilise sans le pattern `inputs.tags`). Piege a
retenir pour tout futur `aws_launch_template`/ASG ajoute a ce module :
verifier explicitement le `tag_specifications`, l'erreur ne se declenche
qu'a l'`apply` du node group, pas au `plan` ni au `validate`.
