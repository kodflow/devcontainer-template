# Immutable Infrastructure

> Remplacer les serveurs au lieu de les modifier.

**Principe :** Traiter les serveurs comme du bétail, pas comme des animaux de compagnie.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                  MUTABLE vs IMMUTABLE                            │
│                                                                  │
│  MUTABLE (traditionnel)           IMMUTABLE (moderne)           │
│  ┌─────────────────────┐          ┌─────────────────────┐       │
│  │     Server v1       │          │     Server v1       │       │
│  │  ┌───────────────┐  │          │  (destroyed)        │       │
│  │  │  App v1.0     │  │          └─────────────────────┘       │
│  │  └───────────────┘  │                    ↓                   │
│  │         ↓           │          ┌─────────────────────┐       │
│  │  ┌───────────────┐  │          │     Server v2       │       │
│  │  │  + Patch      │  │          │  (new from image)   │       │
│  │  └───────────────┘  │          │  ┌───────────────┐  │       │
│  │         ↓           │          │  │  App v1.1     │  │       │
│  │  ┌───────────────┐  │          │  │  + All deps   │  │       │
│  │  │  + Config     │  │          │  └───────────────┘  │       │
│  │  │  + Hotfix     │  │          └─────────────────────┘       │
│  │  │  + Drift...   │  │                                        │
│  │  └───────────────┘  │                                        │
│  └─────────────────────┘                                        │
│                                                                  │
│  Problème: Configuration drift      Solution: État connu        │
└─────────────────────────────────────────────────────────────────┘
```

## Pipeline immutable

```
┌─────────────────────────────────────────────────────────────────┐
│                      BUILD PIPELINE                              │
│                                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │  Code    │───▶│  Build   │───▶│  Test    │───▶│  Image   │  │
│  │  Commit  │    │  Docker  │    │  Image   │    │  Registry│  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘  │
│                                                       │         │
│  ┌────────────────────────────────────────────────────┘         │
│  │                                                               │
│  ▼                                                               │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                   │
│  │  Deploy  │───▶│  Health  │───▶│  Route   │                   │
│  │  New     │    │  Check   │    │  Traffic │                   │
│  │  Instance│    │          │    │          │                   │
│  └──────────┘    └──────────┘    └──────────┘                   │
│                                       │                          │
│                                       ▼                          │
│                              ┌──────────────┐                    │
│                              │   Destroy    │                    │
│                              │   Old        │                    │
│                              │   Instance   │                    │
│                              └──────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

## Implémentation avec Packer + Terraform

### Packer - Création d'image

```hcl
# packer/app.pkr.hcl
packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "app_version" {
  type = string
}

source "amazon-ebs" "app" {
  ami_name      = "myapp-${var.app_version}-{{timestamp}}"
  instance_type = "t3.micro"
  region        = "eu-west-1"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]  # Canonical
    most_recent = true
  }

  ssh_username = "ubuntu"

  tags = {
    Name        = "myapp"
    Version     = var.app_version
    Environment = "production"
  }
}

build {
  sources = ["source.amazon-ebs.app"]

  # Install dependencies
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo systemctl enable docker",
    ]
  }

  # Deploy application
  provisioner "shell" {
    inline = [
      "sudo docker pull myregistry/myapp:${var.app_version}",
      "sudo docker tag myregistry/myapp:${var.app_version} myapp:latest",
    ]
  }

  # Configure systemd
  provisioner "file" {
    source      = "files/myapp.service"
    destination = "/tmp/myapp.service"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/myapp.service /etc/systemd/system/",
      "sudo systemctl enable myapp",
    ]
  }
}
```

### Terraform - Déploiement

```hcl
# terraform/main.tf
variable "ami_id" {
  description = "AMI ID from Packer build"
  type        = string
}

resource "aws_launch_template" "app" {
  name_prefix   = "myapp-"
  image_id      = var.ami_id
  instance_type = "t3.medium"

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Minimal config - app already in AMI
    echo "Starting pre-baked application..."
    systemctl start myapp
  EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "myapp-${var.ami_id}"
  desired_capacity    = 3
  min_size            = 2
  max_size            = 10
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 75
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

## Docker : Immutable par défaut

```dockerfile
# Dockerfile - Image immutable
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app

# User non-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copier uniquement le nécessaire
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules

# Configuration via env vars, pas fichiers
ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080
CMD ["node", "dist/main.js"]
```

## Configuration externalisée

```yaml
# kubernetes/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
data:
  LOG_LEVEL: "info"
  FEATURE_X: "enabled"
---
# kubernetes/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
type: Opaque
data:
  DATABASE_URL: <base64-encoded>
---
# kubernetes/deployment.yaml
spec:
  containers:
  - name: app
    image: myapp:v1.2.3  # Image immutable
    envFrom:
    - configMapRef:
        name: myapp-config
    - secretRef:
        name: myapp-secrets
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Production critique | Prototypes/MVPs |
| Compliance requise | Dev environment |
| Scale horizontal | Applications legacy |
| Cloud native | On-premise contraignant |
| CI/CD mature | Équipe sans automatisation |

## Avantages

- **Reproductibilité** : Même image = même comportement
- **Pas de drift** : Pas de configuration manuelle
- **Rollback facile** : Redéployer ancienne image
- **Scalabilité** : Instances identiques
- **Audit** : Traçabilité des changements
- **Sécurité** : Surface d'attaque réduite

## Inconvénients

- **Temps de build** : Images à reconstruire
- **Stockage** : Images multiples
- **Cold start** : Nouvelles instances
- **Logs/État** : À externaliser
- **Complexité initiale** : Pipeline à construire

## Exemples réels

| Entreprise | Implémentation |
|------------|----------------|
| **Netflix** | AMI baking, Spinnaker |
| **Google** | Borg, Kubernetes |
| **Spotify** | Docker partout |
| **Etsy** | Immutable deploys |
| **HashiCorp** | Packer + Terraform |

## Anti-patterns

| Anti-pattern | Problème | Solution |
|--------------|----------|----------|
| SSH en production | Modifications manuelles | Rebuild image |
| Config locale | Drift configuration | ConfigMap/Secrets |
| Hotfix direct | Non reproductible | Pipeline CI/CD |
| Logs locaux | Perdus au destroy | ELK/CloudWatch |

## Migration path

### Depuis Mutable Infrastructure

```
Phase 1: Containeriser applications
Phase 2: Externaliser configuration
Phase 3: Implémenter pipeline CI/CD
Phase 4: Infrastructure as Code
Phase 5: Éliminer accès SSH production
```

### Checklist migration

- [ ] Applications containerisées
- [ ] Configuration externalisée (env vars)
- [ ] Logs vers service centralisé
- [ ] État vers stockage externe (S3, DB)
- [ ] Pipeline build automatisé
- [ ] Tests sur images
- [ ] Rollback automatisé

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Blue-Green | Déploiement d'images immutables |
| GitOps | Gestion déclarative |
| Infrastructure as Code | Provisionning automatisé |
| Containerisation | Immutabilité au niveau app |

## Sources

- [HashiCorp Packer](https://www.packer.io/)
- [Martin Fowler - Phoenix Server](https://martinfowler.com/bliki/PhoenixServer.html)
- [Netflix Tech Blog](https://netflixtechblog.com/)
- [12 Factor App](https://12factor.net/)
