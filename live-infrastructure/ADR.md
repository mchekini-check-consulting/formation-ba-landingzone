# ADR -- Architecture Terragrunt de `live-infrastructure/`

Decisions concernant la structure globale du repo (racine, hierarchie
`env.hcl`/`account.hcl`, backend, hooks) -- distinct de
[`aws/modules/eks/ADR.md`](./aws/modules/eks/ADR.md), qui documente les choix
internes au module EKS. Format [ADR](https://adr.github.io/).

| # | Titre | Statut |
|---|-------|--------|
| [001](#001-terragrunt-dry-plutot-que-terraform-seul) | Terragrunt DRY plutot que Terraform seul | Accepte |
| [002](#002-bucket-s3-par-environnement-state-key-derivee-du-chemin-lockfile-natif) | Bucket S3 par environnement, state key derivee du chemin, lockfile natif | Accepte |
| [003](#003-provider-et-garde-fou-de-compte-generes-depuis-accounthcl) | Provider et garde-fou de compte generes depuis `account.hcl` | Accepte |
| [004](#004-separation-global-vs-environmentsenv) | Separation `global/` vs `environments/<env>/` | Accepte |
| [005](#005-hook-tflint-avant-tout-plan--apply) | Hook tflint avant tout plan / apply | Remplace par 007 |
| [006](#006-modules-terraform-sous-awsmodules-terragrunthcl-de-composant-minimal) | Modules Terraform sous `aws/modules/`, terragrunt.hcl de composant minimal | Accepte |
| [007](#007-suppression-du-hook-tflint-bug-windows-go-plugin-imbrique) | Suppression du hook tflint (bug Windows go-plugin imbrique) | Accepte |
| [008](#008-assume-role-dediee--pipeline-ci-cd-avec-review-pour-prod) | Assume-role dediee + pipeline CI/CD avec review pour prod | Propose (non implemente) |
| [009](#009-tags-partages-centralises-au-root-localcommon_tags-propages-via-inputstags) | Tags partages centralises au root (`local.common_tags`), propages via `inputs.tags` | Accepte |

---

## 001. Terragrunt DRY plutot que Terraform seul

**Contexte** -- Plusieurs comptes AWS (dev, prod, ...) doivent partager le
meme backend/provider/tags, sans dupliquer ce boilerplate dans chaque
composant, et sans workspaces Terraform (un seul state logique par
workspace, mauvaise isolation blast-radius entre environnements).

**Decision** -- Un `terragrunt.hcl` racine porte tout ce qui est commun
(backend, provider, hooks), inclus par chaque composant via
`include "root" { path = find_in_parent_folders() }`. Deux niveaux de
config partagee complètent la hierarchie :
- `aws/env.hcl` : donnees communes au cloud AWS (region).
- `aws/environments/<env>/account.hcl` : donnees du compte cible
  (`team_name`, `aws_account_id`, `env_name`).

Le root les lit via `read_terragrunt_config(find_in_parent_folders(...))` --
ces appels se resolvent depuis le repertoire du composant qui *inclut* le
root, pas depuis le root lui-meme, donc chaque stack remonte naturellement
vers son propre `env.hcl`/`account.hcl`.

**Consequences** -- Ajouter un environnement = un dossier
`environments/<env>/` + un `account.hcl`, sans toucher au root ni aux
modules. Chaque stack a son propre state Terraform (isolation complete),
contrairement a des workspaces sur un state partage.

## 002. Bucket S3 par environnement, state key derivee du chemin, lockfile natif

**Contexte** -- Chaque composant (`eks/`, futurs `rds/`, `vpc/`, ...) de
chaque environnement doit avoir un state isole, sans backend a configurer a
la main pour chacun. Chaque environnement vit par ailleurs dans son propre
compte AWS (`account.hcl`, [ADR 003](#003-provider-et-garde-fou-de-compte-generes-depuis-accounthcl)) --
un bucket unique partage entre comptes aurait exige des policies
cross-account pour que chaque compte puisse y ecrire son state.

**Decision** -- `remote_state` (backend `s3`) dans le root :
`bucket = "tfstate-${local.team_name}-${local.env_name}-landing-zone"` --
un bucket distinct par environnement (`team_name` et `env_name` viennent de
`account.hcl`, donc bootstrappe dans le compte AWS de cet environnement, pas
dans un compte "central"). `key = "${path_relative_to_include()}/terraform.tfstate"` --
le chemin du composant (ex. `aws/environments/dev/eks`) devient la cle a
l'interieur de ce bucket, un state par composant. `use_lockfile = true`
(Terraform >= 1.10) remplace la table DynamoDB historique pour le locking.

**Consequences** -- Chaque environnement doit bootstrapper son propre bucket
(hors Terraform, avant son premier `apply`) dans son propre compte AWS --
pas de bucket "central" a proteger/partager entre comptes, isolation
complete meme au niveau du stockage de state (une compromission du compte
dev n'expose pas le state prod). Renommer `team_name`/`env_name` dans
`account.hcl` change le nom du bucket attendu -- a faire avec une migration
explicite (creer le nouveau bucket, `terragrunt state mv`/re-`init`), jamais
en silence. Deplacer un composant dans l'arborescence change sa cle de state
a l'interieur du bucket, meme regle.

## 003. Provider et garde-fou de compte generes depuis `account.hcl`

**Contexte** -- Un `apply` lance depuis le mauvais profil/session AWS peut
modifier le mauvais compte silencieusement.

**Decision** -- Le root genere `provider.tf` (`generate "provider"`) avec
`region` (depuis `env.hcl`), `allowed_account_ids = [account.hcl.aws_account_id]`
et des `default_tags` (Team/Env/ManagedBy, cf. [009](#009-tags-partages-centralises-au-root-localcommon_tags-propages-via-inputstags)
pour la source de ces tags). Le composant n'a jamais a declarer de provider
lui-meme.

**Consequences** -- Si le compte AWS courant (credentials actives) ne
correspond pas a `account.hcl`, Terraform refuse le `plan`/`apply` avec une
erreur explicite plutot que d'agir sur le mauvais compte.

## 004. Separation `global/` vs `environments/<env>/`

**Contexte** -- Certaines ressources AWS sont scopees a un environnement
precis (le cluster EKS de dev), d'autres sont transverses (un provider OIDC
partage, une zone Route53, un role CI/CD utilise par tous les
environnements).

**Decision** -- `aws/global/` accueille les ressources sans notion
d'environnement (pas de `account.hcl` requis a ce niveau). `aws/environments/<env>/`
accueille tout ce qui est scope a un compte/environnement precis, avec son
`account.hcl`. Les deux sont vides pour l'instant hormis `environments/dev/eks/`.

**Consequences** -- Regle de placement d'un nouveau composant : "il n'existe
qu'une fois, quel que soit le nombre d'environnements" => `global/` ;
"il existe une fois par environnement" => `environments/<env>/`.

## 005. Hook tflint avant tout plan / apply

> **Remplace par [007](#007-suppression-du-hook-tflint-bug-windows-go-plugin-imbrique)**
> -- casse sur Windows, hook retire du root.

**Contexte** -- Un `terraform plan`/`apply` ne detecte pas les erreurs de
style, variables non typees, ressources non documentees, etc.

**Decision** -- `before_hook "tflint"` dans le root, declenche sur les
commandes `plan` et `apply`, execute `tflint --config=<repo>/live-infrastructure/.tflint.hcl`
sur le module source de la stack courante.

**Consequences** -- Un `terragrunt plan` echoue immediatement si `tflint`
remonte une erreur (ruleset defini dans `.tflint.hcl`), avant meme d'appeler
Terraform.

## 006. Modules Terraform sous `aws/modules/`, terragrunt.hcl de composant minimal

**Contexte** -- Le diagramme d'origine ne montrait qu'un `terragrunt.hcl`
sous `aws/environments/dev/eks/` -- pas de fichiers `.tf`. Terragrunt a
neanmoins besoin d'un vrai module Terraform a pointer (`terraform.source`).

**Decision** -- Le code Terraform vit dans `aws/modules/<nom>/` (ex. `eks/`),
reference en local par chaque `terragrunt.hcl` de composant via
`source = "${get_repo_root()}/live-infrastructure/aws/modules//<nom>"`. Le
`terragrunt.hcl` d'un composant ne contient que `include "root"`,
`terraform.source` et `inputs` -- jamais de logique HCL Terraform.

**Consequences** -- Le meme module peut etre reutilise par plusieurs
environnements (`dev/eks`, `prod/eks`) avec des `inputs` differents, sans
duplication de code. Si le module doit un jour vivre dans un repo Git
separe/versionne (partage inter-repos), seul `terraform.source` change --
aucun impact sur `env.hcl`/`account.hcl`/le root.

## 007. Suppression du hook tflint (bug Windows go-plugin imbrique)

**Contexte** -- Le `before_hook "tflint"` de [005](#005-hook-tflint-avant-tout-plan--apply)
echoue systematiquement sous Windows avec `Unrecognized remote plugin
message` / `Failed to read any lines from plugin's stdout`, alors que
`tflint --init` / `tflint --chdir=...` fonctionnent parfaitement en lanceant
la commande directement dans un terminal. Diagnostic : TFLint charge son
ruleset `aws` via le protocole go-plugin (handshake texte sur stdout). Quand
TFLint est lui-meme lance comme sous-processus par Terragrunt (qui capture/
redirige le stdout du hook pour le prefixer dans ses logs), le pipe stdout
du plugin `aws` (petit-fils du process Terragrunt) se retrouve corrompu par
cette redirection imbriquee -- confirme par le binaire plugin telecharge
(taille, architecture, PE valide, executable en direct) et par l'echec
identique reproductible uniquement via le hook, jamais en CLI directe.

**Decision** -- Retirer le `before_hook "tflint"` du `terragrunt.hcl` racine.
TFLint reste dans le repo (`.tflint.hcl`) mais se lance a la main (ou en CI
sur runner Linux, non affecte par ce bug) : voir la commande dans
[README.md](./README.md#commandes-de-base).

**Consequences** -- Plus de garde-fou automatique avant `plan`/`apply` en
local sur poste Windows -- le lint devient une discipline manuelle (ou a
faire porter par la CI). A reevaluer si Terragrunt ou TFLint corrigent ce
comportement en amont (bug cote interaction go-plugin imbrique, pas cote
configuration de ce repo).

## 008. Assume-role dediee + pipeline CI/CD avec review pour prod

> **Statut : propose, non implemente.** Capture la decision pour ne pas la
> perdre -- a faire avant un premier `apply` reel sur `environments/prod/`.

**Contexte** -- [003](#003-provider-et-garde-fou-de-compte-generes-depuis-accounthcl)
garantit qu'on ne peut pas `apply` sur le mauvais compte AWS
(`allowed_account_ids`), mais ne dit rien sur *comment* on s'authentifie sur
le bon compte. Aujourd'hui, `terragrunt apply` utilise directement les
credentials personnelles actives de qui lance la commande (session
`aws sso login`, variables `AWS_*`, ...) -- valable pour `dev`, insuffisant
pour `prod` : pas de role de deploiement dedie, pas de trace de qui a
deploye quoi via une identite partagee/auditee, et rien n'empeche un
`apply` prod lance a la main depuis un poste local.

**Decision (proposee)** -- Pour `environments/prod/` (et plus tard tout
environnement sensible) :
1. Ajouter un `role_arn` (role de deploiement dedie, ex.
   `role-formation-prod-deploy`) dans `account.hcl` de l'environnement
   concerne, repris par le `generate "provider"` du root (bloc
   `assume_role { role_arn = ... }` dans le `provider "aws"` genere) --
   les credentials personnelles ne servent alors qu'a assumer ce role
   (`sts:AssumeRole`), jamais a agir directement sur les ressources prod.
2. Faire passer les `apply` prod par une pipeline CI/CD avec etape de
   review/approbation (le repo avait des `azure-pipelines-*.yml` avant le
   nettoyage de l'architecture -- a recreer/adapter pour ce layout
   Terragrunt le jour ou ce point est priorise), plutot que par un
   `terragrunt apply` local.

**Consequences** -- Reduit le blast radius d'une session locale compromise
(elle ne peut qu'assumer un role scope, pas agir directement) et donne un
point de review obligatoire avant tout changement prod. Necessite de
provisionner le role IAM `role_arn` (et sa trust policy) avant de l'utiliser,
et de remettre en place une pipeline CI/CD adaptee a cette arborescence
Terragrunt.

## 009. Tags partages centralises au root (`local.common_tags`), propages via `inputs.tags`

**Contexte** -- Le premier `apply` reel a echoue sur
`aws_launch_template.apps` du module `eks` : `InvalidTagSpecification.Malformed:
The tags cannot be null or empty`. Cause : `var.tags` valait `{}` cote module
(aucun `terragrunt.hcl` ne le renseignait), et le `default_tags` du provider
genere (Team/Env/ManagedBy, [003](#003-provider-et-garde-fou-de-compte-generes-depuis-accounthcl))
ne s'applique qu'aux `tags` top-level d'une resource -- jamais aux blocs
imbriques comme `tag_specifications.tags` d'un launch template. Premier
correctif fait localement dans le module (fallback `Project`/`Env` en dur) --
mais ca dupliquait la definition des tags globaux (Team/Env/ManagedBy) deja
ecrite dans le `generate "provider"` du root, avec un risque de derive entre
les deux, alors que `team_name`/`region` suivent deja un pattern DRY centralise
au root ([001](#001-terragrunt-dry-plutot-que-terraform-seul)).

**Decision** -- Une seule definition des tags partages, dans le root :
```hcl
locals {
  common_tags = {
    Team      = local.team_name
    Env       = local.env_name
    ManagedBy = "Terragrunt"
  }
}
```
Reutilisee aux deux endroits qui en ont besoin : `generate "provider"`
(`default_tags.tags = ${jsonencode(local.common_tags)}`) et
`inputs = merge(..., { tags = local.common_tags })`. Chaque module recoit
donc `var.tags` deja rempli -- il n'a plus qu'a ajouter ce qui lui est
propre (ex. `Project` dans `eks/`, cf. [aws/modules/eks/ADR.md](./aws/modules/eks/ADR.md)).

**Consequences** -- Une seule source de verite pour les tags partages ;
tout futur module avec un bloc de tags imbrique (ASG, launch template, ...)
recoit des tags non vides sans code defensif specifique a ecrire. Modifier
la politique de tags globale = un seul endroit a toucher (`local.common_tags`).
`jsonencode()` sert a serialiser la map HCL en texte injecte dans le
`generate` block -- verifie que la syntaxe objet JSON qui en resulte
(`{"Team":"...",...}`) est acceptee nativement par le parseur HCL2.
