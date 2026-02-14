# Infrastructure as Code (IaC)

> Gérer l'infrastructure via du code versionné.

## Principle

```
┌─────────────────────────────────────────────────────────────────┐
│                         CODE (Git)                               │
│                                                                  │
│  main.tf                                                         │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ resource "aws_instance" "web" {                             ││
│  │   ami           = "ami-12345"                               ││
│  │   instance_type = "t3.micro"                                ││
│  │ }                                                           ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────┬───────────────────────────┘
                                      │
                                      │ terraform apply
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CLOUD PROVIDER                              │
│                                                                  │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐                     │
│  │   EC2   │    │   RDS   │    │   S3    │                     │
│  └─────────┘    └─────────┘    └─────────┘                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Outils

| Outil | Type | Provider |
|-------|------|----------|
| **Terraform** | Déclaratif | Multi-cloud |
| **OpenTofu** | Déclaratif | Multi-cloud (fork OSS) |
| **Pulumi** | Impératif | Multi-cloud |
| **CloudFormation** | Déclaratif | AWS only |
| **ARM/Bicep** | Déclaratif | Azure only |
| **Ansible** | Configuration | Multi-platform |

## Structure Terraform

```
infrastructure/
├── modules/                    # Modules réutilisables
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks/
│   └── rds/
│
├── environments/               # Par environnement
│   ├── dev/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── prod/
│
└── global/                     # Ressources partagées
    ├── iam/
    └── dns/
```

## Exemple Terraform

```hcl
# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block

  tags = {
    Name        = var.name
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.name}-public-${count.index}"
  }
}

# environments/prod/main.tf
module "vpc" {
  source = "../../modules/vpc"

  name               = "production"
  environment        = "prod"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}
```

## Workflow

```
1. terraform init      # Initialiser
2. terraform plan      # Prévisualiser
3. terraform apply     # Appliquer
4. terraform destroy   # Détruire (attention!)
```

## Best Practices

### 1. State Management

```hcl
# backend.tf - State distant
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### 2. Variables & Secrets

```hcl
# Ne JAMAIS commiter les secrets
# Utiliser variables d'environnement ou Vault

variable "db_password" {
  type      = string
  sensitive = true
}

# Via environment
# export TF_VAR_db_password="secret"
```

### 3. Modules

```hcl
# Réutiliser via modules
module "web_server" {
  source = "./modules/ec2"

  instance_type = "t3.medium"
  ami           = data.aws_ami.ubuntu.id
}
```

### 4. Validation

```yaml
# CI Pipeline
- terraform fmt -check
- terraform validate
- terraform plan
- tflint
- checkov --directory .
```

## Immutable vs Mutable

| Approche | Description | Outil |
|----------|-------------|-------|
| **Immutable** | Remplacer, pas modifier | Terraform, Packer |
| **Mutable** | Modifier en place | Ansible, Chef |

```
Immutable (recommandé):
┌─────────┐     ┌─────────┐
│Server v1│ ──▶ │Server v2│  (nouveau serveur)
└─────────┘     └─────────┘

Mutable:
┌─────────┐     ┌─────────┐
│Server v1│ ──▶ │Server v1│  (même serveur modifié)
└─────────┘     │  + pkg  │
                └─────────┘
```

## Related Patterns

| Pattern | Relation |
|---------|----------|
| GitOps | IaC dans Git |
| Immutable Infrastructure | Serveurs remplacés |
| Blue-Green | Deux environnements IaC |

## Sources

- [Terraform Docs](https://developer.hashicorp.com/terraform)
- [Gruntwork IaC Guide](https://gruntwork.io/guides/)
