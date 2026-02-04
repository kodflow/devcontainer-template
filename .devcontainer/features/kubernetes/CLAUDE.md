# Kubernetes Feature (kind)

## Purpose

Local Kubernetes development using kind (Kubernetes in Docker).

## Components

| Tool | Description |
|------|-------------|
| kind | Kubernetes clusters in Docker |
| kubectl | Kubernetes CLI |
| Helm | Package manager |

## Quick Start

```bash
kind create cluster --name dev    # Create
kubectl cluster-info              # Check
kind delete cluster --name dev    # Delete
```

## Configuration

```json
"features": {
  "./features/kubernetes": {
    "enableHelm": true,
    "enableRegistry": true
  }
}
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `kindVersion` | latest | kind version |
| `kubectlVersion` | latest | kubectl version |
| `helmVersion` | latest | Helm version |
| `enableHelm` | true | Install Helm |
| `enableRegistry` | true | Local registry :5001 |
| `clusterName` | dev | Default cluster name |

## Advanced Usage

### Custom Cluster

```bash
# Multi-node
kind create cluster --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
EOF
```

### Local Registry

```bash
docker tag myapp localhost:5001/myapp && docker push localhost:5001/myapp
kubectl create deployment myapp --image=localhost:5001/myapp
```

### Helm

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install myrelease bitnami/nginx
```

## CI Integration

```yaml
- uses: helm/kind-action@v1
  with:
    cluster_name: test
```
