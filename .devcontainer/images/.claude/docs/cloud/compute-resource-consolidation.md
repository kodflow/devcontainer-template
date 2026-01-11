# Compute Resource Consolidation Pattern

> Optimiser l'utilisation des ressources en consolidant les workloads.

## Principe

```
┌─────────────────────────────────────────────────────────────────────────┐
│                 AVANT: Resources sous-utilisees                          │
│                                                                          │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│   │    VM 1         │  │    VM 2         │  │    VM 3         │         │
│   │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │         │
│   │ │ Service A   │ │  │ │ Service B   │ │  │ │ Service C   │ │         │
│   │ │ CPU: 10%    │ │  │ │ CPU: 15%    │ │  │ │ CPU: 5%     │ │         │
│   │ │ RAM: 20%    │ │  │ │ RAM: 25%    │ │  │ │ RAM: 10%    │ │         │
│   │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │         │
│   │   4 CPU, 16GB   │  │   4 CPU, 16GB   │  │   4 CPU, 16GB   │         │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘         │
│                                                                          │
│   Total: 12 CPU, 48GB RAM - Utilisation: ~10%                           │
│   Cout: $$$                                                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

                                   │
                                   ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                 APRES: Resources consolidees                             │
│                                                                          │
│              ┌─────────────────────────────────────┐                    │
│              │            Shared Node              │                    │
│              │  ┌───────────┬───────────┬───────┐  │                    │
│              │  │ Service A │ Service B │Svc C  │  │                    │
│              │  │ CPU: 10%  │ CPU: 15%  │CPU:5% │  │                    │
│              │  │ RAM: 20%  │ RAM: 25%  │RAM:10%│  │                    │
│              │  └───────────┴───────────┴───────┘  │                    │
│              │        4 CPU, 16GB RAM              │                    │
│              │     Utilisation: ~50%               │                    │
│              └─────────────────────────────────────┘                    │
│                                                                          │
│   Total: 4 CPU, 16GB RAM - Utilisation: ~50%                            │
│   Cout: $                                                                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Strategies de consolidation

| Strategie | Description | Cas d'usage |
|-----------|-------------|-------------|
| **Bin Packing** | Remplir les nodes au maximum | Workloads stables |
| **Spreading** | Distribuer pour resilience | Workloads critiques |
| **Time-based** | Partager selon horaires | Batch + interactive |
| **Resource Ratio** | Equilibrer CPU/RAM | Mix workloads |

## Exemple Go

```go
package consolidation

import (
	"sort"
)

// Workload represents a workload to be scheduled.
type Workload struct {
	ID         string
	Name       string
	CPURequest int // millicores
	MemRequest int // MB
	Priority   string
}

// Node represents a compute node.
type Node struct {
	ID            string
	CPUCapacity   int
	MemCapacity   int
	CPUAllocated  int
	MemAllocated  int
	Workloads     []Workload
}

// ResourceConsolidator consolidates workloads onto nodes.
type ResourceConsolidator struct {
	targetUtilization float64
	minNodes          int
}

// NewResourceConsolidator creates a new ResourceConsolidator.
func NewResourceConsolidator(targetUtil float64, minNodes int) *ResourceConsolidator {
	return &ResourceConsolidator{
		targetUtilization: targetUtil,
		minNodes:          minNodes,
	}
}

// Consolidate consolidates workloads onto nodes using bin packing.
func (rc *ResourceConsolidator) Consolidate(nodes []Node, workloads []Workload) map[string][]string {
	allocation := make(map[string][]string)

	// Sort workloads by size (largest first for bin packing)
	sortedWorkloads := make([]Workload, len(workloads))
	copy(sortedWorkloads, workloads)
	sort.Slice(sortedWorkloads, func(i, j int) bool {
		sizeI := sortedWorkloads[i].CPURequest + sortedWorkloads[i].MemRequest
		sizeJ := sortedWorkloads[j].CPURequest + sortedWorkloads[j].MemRequest
		return sizeI > sizeJ
	})

	// Sort nodes by available capacity
	availableNodes := make([]Node, len(nodes))
	copy(availableNodes, nodes)
	sort.Slice(availableNodes, func(i, j int) bool {
		return rc.getAvailableScore(&availableNodes[i]) > rc.getAvailableScore(&availableNodes[j])
	})

	for _, workload := range sortedWorkloads {
		targetNode := rc.findBestNode(workload, availableNodes)
		
		if targetNode != nil {
			rc.allocate(targetNode, workload)
			
			nodeAlloc := allocation[targetNode.ID]
			nodeAlloc = append(nodeAlloc, workload.ID)
			allocation[targetNode.ID] = nodeAlloc
		}
	}

	return allocation
}

func (rc *ResourceConsolidator) findBestNode(workload Workload, nodes []Node) *Node {
	for i := range nodes {
		node := &nodes[i]
		
		cpuAvail := node.CPUCapacity - node.CPUAllocated
		memAvail := node.MemCapacity - node.MemAllocated

		cpuFits := cpuAvail >= workload.CPURequest
		memFits := memAvail >= workload.MemRequest

		// Check utilization target
		projectedCPUUtil := float64(node.CPUAllocated+workload.CPURequest) / float64(node.CPUCapacity)
		projectedMemUtil := float64(node.MemAllocated+workload.MemRequest) / float64(node.MemCapacity)

		withinTarget := projectedCPUUtil <= rc.targetUtilization && 
		                projectedMemUtil <= rc.targetUtilization

		if cpuFits && memFits && withinTarget {
			return node
		}
	}
	
	return nil
}

func (rc *ResourceConsolidator) allocate(node *Node, workload Workload) {
	node.CPUAllocated += workload.CPURequest
	node.MemAllocated += workload.MemRequest
	node.Workloads = append(node.Workloads, workload)
}

func (rc *ResourceConsolidator) getAvailableScore(node *Node) float64 {
	cpuAvail := float64(node.CPUCapacity-node.CPUAllocated) / float64(node.CPUCapacity)
	memAvail := float64(node.MemCapacity-node.MemAllocated) / float64(node.MemCapacity)
	return cpuAvail + memAvail
}

// RecommendScaleDown recommends nodes to remove.
func (rc *ResourceConsolidator) RecommendScaleDown(nodes []Node) []Node {
	var recommendations []Node
	
	// Empty nodes
	for _, node := range nodes {
		if len(node.Workloads) == 0 {
			recommendations = append(recommendations, node)
		}
	}
	
	// Underutilized nodes
	for _, node := range nodes {
		cpuUtil := float64(node.CPUAllocated) / float64(node.CPUCapacity)
		memUtil := float64(node.MemAllocated) / float64(node.MemCapacity)
		
		if cpuUtil < 0.2 && memUtil < 0.2 && len(node.Workloads) > 0 {
			recommendations = append(recommendations, node)
		}
	}
	
	// Respect minimum nodes
	maxRemove := len(nodes) - rc.minNodes
	if maxRemove < 0 {
		maxRemove = 0
	}
	
	if len(recommendations) > maxRemove {
		recommendations = recommendations[:maxRemove]
	}
	
	return recommendations
}
```

## Kubernetes Resource Management

```yaml
# Pod avec resource requests/limits
apiVersion: v1
kind: Pod
metadata:
  name: consolidated-service
spec:
  containers:
    - name: service-a
      image: service-a:latest
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
    - name: service-b
      image: service-b:latest
      resources:
        requests:
          cpu: "200m"
          memory: "256Mi"
        limits:
          cpu: "1000m"
          memory: "1Gi"

---
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: consolidated-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: consolidated-service
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70

---
# Vertical Pod Autoscaler
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: consolidated-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: consolidated-service
  updatePolicy:
    updateMode: Auto
```

## Metriques de consolidation

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Time-based Consolidation

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Sur-consolidation | Contention resources | Target < 80% utilization |
| Noisy neighbors | Performance degradee | Resource limits + QoS |
| Sans isolation | Security risk | Namespaces, network policies |
| Consolidation statique | Gaspillage off-peak | Autoscaling |

## Quand utiliser

- Workloads avec faible utilisation des ressources individuellement
- Environnements de developpement et test non-critiques
- Services complementaires en termes d'utilisation CPU/memoire
- Reduction des couts d'infrastructure cloud
- Applications conteneurisees avec des profils de charge previsibles

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Autoscaling | Ajustement dynamique |
| Throttling | Protection surcharge |
| Bulkhead | Isolation workloads |
| Queue-based Load Leveling | Lissage charge |

## Sources

- [Microsoft - Compute Resource Consolidation](https://learn.microsoft.com/en-us/azure/architecture/patterns/compute-resource-consolidation)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [GCP Rightsizing](https://cloud.google.com/compute/docs/instances/apply-machine-type-recommendations-for-instances)
