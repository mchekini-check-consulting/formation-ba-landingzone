# live-infrastructure

Infrastructure AWS geree avec [Terragrunt](https://terragrunt.gruntwork.io/)
(DRY sur backend/provider/tags) + Terraform. Voir [ADR.md](./ADR.md) pour le
detail des choix d'architecture, et [aws/modules/eks/ADR.md](./aws/modules/eks/ADR.md)
pour les choix specifiques au module EKS.

## Arborescence

```
live-infrastructure/
├── terragrunt.hcl                 # config racine : backend S3, provider AWS genere
├── .tflint.hcl                    # ruleset TFLint global
├── .gitignore
│
└── aws/
    ├── env.hcl                    # config commune AWS (region = "eu-west-3")
    │
    ├── modules/                   # code Terraform reutilisable
    │   ├── eks/                   # VPC + cluster EKS + node group + addon Pod Identity + fournisseur OIDC (IRSA) (voir son README.md)
    │   ├── pg-backups/            # bucket S3 des sauvegardes PostgreSQL (CNPG) + role IRSA commun des Clusters <nom>-db
    │   ├── external-dns/          # role IAM Route53 (*.check-consulting.net) + association Pod Identity
    │   └── ci-github/             # provider OIDC GitHub + role de push ECR commun (depots formation-ba-*)
    │
    ├── global/                    # ressources AWS transverses (pas de account.hcl requis)
    │
    └── environments/              # ressources scopees a un environnement/compte
        ├── dev/                   # compte AWS Dev (205493924920)
        │   ├── account.hcl        # team_name, aws_account_id, env_name = "dev"
        │   ├── eks/
        │   │   └── terragrunt.hcl # source = ../../modules/eks, inputs (version, instance type, ...)
        │   ├── external-dns/
        │   │   └── terragrunt.hcl # source = ../../modules/external-dns, dependency eks (cluster_name)
        │   ├── ci-github/
        │   │   └── terragrunt.hcl # source = ../../modules/ci-github, prefixe formation-ba-
        │   └── pg-backups/
        │       └── terragrunt.hcl # source = ../../modules/pg-backups, dependency eks (fournisseur OIDC)
        │
        └── prod/                  # (vide pour l'instant)
```

Chaque dossier sous `environments/<env>/` (ex. `eks/`) est une **stack**
Terragrunt independante : son propre state S3, son propre `terraform plan`/
`apply`.

## Prerequis

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= 0.63
- [TFLint](https://github.com/terraform-linters/tflint) (a lancer manuellement avant `plan`/`apply`, voir [ADR 007](./ADR.md#007-suppression-du-hook-tflint-bug-windows-go-plugin-imbrique) -- pas de hook automatique)
- Credentials AWS actives pour le compte cible (`aws sso login`, variables `AWS_*`, ...) -- doivent correspondre a `aws_account_id` dans `account.hcl` de l'environnement, sinon le `provider` genere refuse d'agir (voir [ADR 003](./ADR.md#003-provider-et-garde-fou-de-compte-generes-depuis-accounthcl))
- Le bucket S3 de state de l'environnement (`tfstate-<team_name>-<env_name>-landing-zone`, ex. `tfstate-team-eks-dev-landing-zone` en region `eu-west-3`, voir [ADR 002](./ADR.md#002-bucket-s3-par-environnement-state-key-derivee-du-chemin-lockfile-natif)) doit exister dans le compte AWS de cet environnement avant son premier `apply` -- pas de bootstrap automatique dans ce repo

## Commandes de base

Toutes les commandes `terragrunt` s'executent **depuis le dossier de la
stack** (ex. `aws/environments/dev/eks/`), sauf `run-all` qui peut s'executer
depuis un dossier parent pour agir sur toutes les stacks qu'il contient.

```bash
# Se placer dans une stack
cd aws/environments/dev/eks

# Init (backend + module + providers)
terragrunt init

# Plan / Apply / Destroy
terragrunt plan
terragrunt apply
terragrunt destroy

# kubeconfig une fois le cluster applique
aws eks update-kubeconfig --region eu-west-3 --name $(terragrunt output -raw cluster_name)
```

```bash
# Agir sur toutes les stacks d'un environnement (ex: tout dev/) d'un coup
cd aws/environments/dev
terragrunt run-all plan
terragrunt run-all apply
```

```bash
# Lint d'un module (a la main -- pas de hook automatique, voir ADR 007 :
# le hook tflint casse sous Windows quand Terragrunt capture son stdout).
# --chdir deplace aussi la resolution de --config : le chemin est relatif
# au dossier chdir, pas au repertoire courant -- d'ou le ../../../.
cd live-infrastructure
tflint --init --config=../../../.tflint.hcl --chdir=aws/modules/eks
tflint --config=../../../.tflint.hcl --chdir=aws/modules/eks
```

```bash
# Formater / valider la syntaxe de tous les fichiers .hcl du repo
cd live-infrastructure
terragrunt hclfmt
terragrunt hclvalidate

# Voir la config Terragrunt fusionnee (root + env.hcl + account.hcl + composant)
# pour debugger un input/backend/provider genere
cd aws/environments/dev/eks
terragrunt render-json
```

```bash
# Regenerer la doc (README.md) d'un module Terraform apres modification
terraform-docs markdown table --output-file README.md --output-mode inject aws/modules/eks
```

## Ajouter un environnement (ex. `prod`)

1. Creer `aws/environments/prod/account.hcl` (`aws_account_id`, `env_name = "prod"`).
2. Creer `aws/environments/prod/eks/terragrunt.hcl` (copier celui de `dev`,
   adapter les `inputs`).
3. `cd aws/environments/prod/eks && terragrunt init && terragrunt plan`.

## Ajouter un composant (ex. `rds`)

1. Ecrire le module Terraform dans `aws/modules/rds/`.
2. Creer `aws/environments/<env>/rds/terragrunt.hcl` avec `include "root"`,
   `terraform.source` pointant vers `aws/modules//rds`, et les `inputs`.
3. `cd aws/environments/<env>/rds && terragrunt init && terragrunt plan`.
