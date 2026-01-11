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

## Exemple TypeScript

```typescript
interface Workload {
  id: string;
  name: string;
  cpuRequest: number; // millicores
  memoryRequest: number; // MB
  priority: 'critical' | 'standard' | 'low';
  affinityRules?: AffinityRule[];
}

interface Node {
  id: string;
  cpuCapacity: number;
  memoryCapacity: number;
  cpuAllocated: number;
  memoryAllocated: number;
  workloads: Workload[];
}

class ResourceConsolidator {
  constructor(
    private readonly targetUtilization = 0.7, // 70%
    private readonly minNodes = 1,
  ) {}

  consolidate(nodes: Node[], workloads: Workload[]): Map<string, string[]> {
    const allocation = new Map<string, string[]>();

    // Sort workloads by size (largest first for bin packing)
    const sortedWorkloads = [...workloads].sort(
      (a, b) => b.cpuRequest + b.memoryRequest - (a.cpuRequest + a.memoryRequest),
    );

    // Sort nodes by available capacity
    const availableNodes = [...nodes].sort(
      (a, b) => this.getAvailableScore(b) - this.getAvailableScore(a),
    );

    for (const workload of sortedWorkloads) {
      const targetNode = this.findBestNode(workload, availableNodes);

      if (targetNode) {
        this.allocate(targetNode, workload);

        const nodeAllocation = allocation.get(targetNode.id) ?? [];
        nodeAllocation.push(workload.id);
        allocation.set(targetNode.id, nodeAllocation);
      } else {
        console.warn(`No suitable node for workload: ${workload.id}`);
      }
    }

    return allocation;
  }

  private findBestNode(workload: Workload, nodes: Node[]): Node | undefined {
    return nodes.find((node) => {
      const cpuAvailable = node.cpuCapacity - node.cpuAllocated;
      const memAvailable = node.memoryCapacity - node.memoryAllocated;

      const cpuFits = cpuAvailable >= workload.cpuRequest;
      const memFits = memAvailable >= workload.memoryRequest;

      // Check utilization target
      const projectedCpuUtil =
        (node.cpuAllocated + workload.cpuRequest) / node.cpuCapacity;
      const projectedMemUtil =
        (node.memoryAllocated + workload.memoryRequest) / node.memoryCapacity;

      const withinTarget =
        projectedCpuUtil <= this.targetUtilization &&
        projectedMemUtil <= this.targetUtilization;

      return cpuFits && memFits && withinTarget;
    });
  }

  private allocate(node: Node, workload: Workload): void {
    node.cpuAllocated += workload.cpuRequest;
    node.memoryAllocated += workload.memoryRequest;
    node.workloads.push(workload);
  }

  private getAvailableScore(node: Node): number {
    const cpuAvailable = (node.cpuCapacity - node.cpuAllocated) / node.cpuCapacity;
    const memAvailable =
      (node.memoryCapacity - node.memoryAllocated) / node.memoryCapacity;
    return cpuAvailable + memAvailable;
  }

  recommendScaleDown(nodes: Node[]): Node[] {
    const emptyNodes = nodes.filter((n) => n.workloads.length === 0);
    const underutilized = nodes.filter((n) => {
      const cpuUtil = n.cpuAllocated / n.cpuCapacity;
      const memUtil = n.memoryAllocated / n.memoryCapacity;
      return cpuUtil < 0.2 && memUtil < 0.2 && n.workloads.length > 0;
    });

    return [...emptyNodes, ...underutilized].slice(
      0,
      Math.max(0, nodes.length - this.minNodes),
    );
  }
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

```typescript
interface ConsolidationMetrics {
  totalNodes: number;
  activeNodes: number;
  avgCpuUtilization: number;
  avgMemoryUtilization: number;
  estimatedSavings: number;
}

function calculateMetrics(nodes: Node[]): ConsolidationMetrics {
  const activeNodes = nodes.filter((n) => n.workloads.length > 0);

  const avgCpu =
    activeNodes.reduce((sum, n) => sum + n.cpuAllocated / n.cpuCapacity, 0) /
    activeNodes.length;

  const avgMem =
    activeNodes.reduce(
      (sum, n) => sum + n.memoryAllocated / n.memoryCapacity,
      0,
    ) / activeNodes.length;

  const idleNodes = nodes.length - activeNodes.length;
  const estimatedSavings = idleNodes * 100; // $100/node/month estimate

  return {
    totalNodes: nodes.length,
    activeNodes: activeNodes.length,
    avgCpuUtilization: avgCpu * 100,
    avgMemoryUtilization: avgMem * 100,
    estimatedSavings,
  };
}
```

## Time-based Consolidation

```typescript
// Partage de ressources selon horaires
const scheduleConfig = {
  batchJobs: {
    schedule: '0 2 * * *', // 2h du matin
    duration: 4 * 60 * 60 * 1000, // 4 heures
    resources: { cpu: '4', memory: '8Gi' },
  },
  interactiveServices: {
    schedule: '0 8 * * 1-5', // 8h-18h semaine
    resources: { cpu: '2', memory: '4Gi' },
  },
};
```

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Sur-consolidation | Contention resources | Target < 80% utilization |
| Noisy neighbors | Performance degradee | Resource limits + QoS |
| Sans isolation | Security risk | Namespaces, network policies |
| Consolidation statique | Gaspillage off-peak | Autoscaling |

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
