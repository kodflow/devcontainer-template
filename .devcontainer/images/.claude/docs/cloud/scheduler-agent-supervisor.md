# Scheduler-Agent-Supervisor Pattern

> Coordonner les taches distribuees avec un superviseur centralise.

## Principe

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SUPERVISOR                                   │
│                                                                      │
│   ┌─────────────────┐    ┌─────────────────┐    ┌───────────────┐   │
│   │    Scheduler    │    │   State Store   │    │   Recovery    │   │
│   │                 │    │                 │    │   Manager     │   │
│   │ - Planification │    │ - Etat tasks    │    │ - Retry       │   │
│   │ - Priorites     │    │ - Historique    │    │ - Compensation│   │
│   │ - Timing        │    │ - Checkpoints   │    │ - Alerting    │   │
│   └────────┬────────┘    └─────────────────┘    └───────────────┘   │
│            │                                                         │
└────────────┼─────────────────────────────────────────────────────────┘
             │
             │  Dispatch Tasks
             ▼
     ┌───────────────────────────────────────────────────────────┐
     │                        AGENTS                              │
     │                                                            │
     │   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌────────┐ │
     │   │ Agent A │    │ Agent B │    │ Agent C │    │Agent N │ │
     │   │(Worker) │    │(Worker) │    │(Worker) │    │(Worker)│ │
     │   └────┬────┘    └────┬────┘    └────┬────┘    └───┬────┘ │
     │        │              │              │              │      │
     │        └──────────────┴──────────────┴──────────────┘      │
     │                           │                                 │
     │                  Report Status                              │
     └───────────────────────────────────────────────────────────┘
```

## Composants

| Composant | Responsabilite |
|-----------|----------------|
| **Scheduler** | Planifie et assigne les taches |
| **Agent** | Execute les taches atomiques |
| **Supervisor** | Monitore, recupere des echecs |
| **State Store** | Persiste l'etat des taches |

## Exemple TypeScript

```typescript
// Types
interface Task {
  id: string;
  type: string;
  payload: any;
  status: 'pending' | 'running' | 'completed' | 'failed';
  retries: number;
  maxRetries: number;
  assignedAgent?: string;
  createdAt: Date;
  updatedAt: Date;
}

interface Agent {
  id: string;
  status: 'idle' | 'busy' | 'offline';
  capabilities: string[];
  lastHeartbeat: Date;
}

// Scheduler
class Scheduler {
  constructor(
    private readonly taskStore: TaskStore,
    private readonly agentRegistry: AgentRegistry,
  ) {}

  async scheduleTasks(): Promise<void> {
    const pendingTasks = await this.taskStore.findByStatus('pending');
    const idleAgents = await this.agentRegistry.findByStatus('idle');

    for (const task of pendingTasks) {
      const agent = this.findCapableAgent(task, idleAgents);

      if (agent) {
        await this.assignTask(task, agent);
        idleAgents.splice(idleAgents.indexOf(agent), 1);
      }
    }
  }

  private findCapableAgent(task: Task, agents: Agent[]): Agent | undefined {
    return agents.find(a => a.capabilities.includes(task.type));
  }

  private async assignTask(task: Task, agent: Agent): Promise<void> {
    task.status = 'running';
    task.assignedAgent = agent.id;
    task.updatedAt = new Date();

    await this.taskStore.update(task);
    await this.notifyAgent(agent, task);
  }

  private async notifyAgent(agent: Agent, task: Task): Promise<void> {
    await fetch(`http://${agent.id}/tasks`, {
      method: 'POST',
      body: JSON.stringify(task),
    });
  }
}

// Agent
class TaskAgent {
  constructor(
    private readonly id: string,
    private readonly handlers: Map<string, TaskHandler>,
    private readonly supervisor: SupervisorClient,
  ) {}

  async processTask(task: Task): Promise<void> {
    const handler = this.handlers.get(task.type);

    if (!handler) {
      await this.supervisor.reportFailure(task, 'Unknown task type');
      return;
    }

    try {
      await this.supervisor.reportProgress(task, 'started');

      const result = await handler.execute(task.payload);

      await this.supervisor.reportCompletion(task, result);
    } catch (error) {
      await this.supervisor.reportFailure(task, error.message);
    }
  }

  async sendHeartbeat(): Promise<void> {
    await this.supervisor.heartbeat(this.id, {
      status: 'idle',
      capabilities: Array.from(this.handlers.keys()),
    });
  }
}

// Supervisor
class Supervisor {
  private readonly checkInterval = 30000; // 30s

  constructor(
    private readonly taskStore: TaskStore,
    private readonly agentRegistry: AgentRegistry,
    private readonly alertService: AlertService,
  ) {}

  async start(): Promise<void> {
    setInterval(() => this.checkHealth(), this.checkInterval);
  }

  async checkHealth(): Promise<void> {
    await this.detectStaleAgents();
    await this.recoverStaleTasks();
    await this.retryFailedTasks();
  }

  private async detectStaleAgents(): Promise<void> {
    const agents = await this.agentRegistry.findAll();
    const now = Date.now();

    for (const agent of agents) {
      const lastSeen = agent.lastHeartbeat.getTime();
      if (now - lastSeen > 60000) { // 1 minute
        agent.status = 'offline';
        await this.agentRegistry.update(agent);
        await this.alertService.notify(`Agent ${agent.id} is offline`);
      }
    }
  }

  private async recoverStaleTasks(): Promise<void> {
    const runningTasks = await this.taskStore.findByStatus('running');

    for (const task of runningTasks) {
      const agent = await this.agentRegistry.find(task.assignedAgent!);

      if (!agent || agent.status === 'offline') {
        task.status = 'pending';
        task.assignedAgent = undefined;
        await this.taskStore.update(task);
      }
    }
  }

  private async retryFailedTasks(): Promise<void> {
    const failedTasks = await this.taskStore.findByStatus('failed');

    for (const task of failedTasks) {
      if (task.retries < task.maxRetries) {
        task.status = 'pending';
        task.retries++;
        await this.taskStore.update(task);
      } else {
        await this.alertService.notify(`Task ${task.id} exceeded max retries`);
      }
    }
  }

  async reportCompletion(task: Task, result: any): Promise<void> {
    task.status = 'completed';
    task.updatedAt = new Date();
    await this.taskStore.update(task);
    await this.taskStore.saveResult(task.id, result);
  }

  async reportFailure(task: Task, error: string): Promise<void> {
    task.status = 'failed';
    task.updatedAt = new Date();
    await this.taskStore.update(task);
    await this.taskStore.saveError(task.id, error);
  }
}
```

## Workflow complet

```
1. Client soumet une tache
          │
          ▼
2. Scheduler place en queue
          │
          ▼
3. Scheduler assigne a un Agent idle
          │
          ▼
4. Agent execute la tache
          │
    ┌─────┴─────┐
    ▼           ▼
Success      Failure
    │           │
    ▼           ▼
5a. Report   5b. Report
 completion   failure
    │           │
    └─────┬─────┘
          ▼
6. Supervisor met a jour l'etat
          │
          ▼
7. Supervisor retry si necessaire
```

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Supervisor SPOF | Panne = pas de recovery | Supervisor haute dispo |
| Polling excessif | Charge reseau | Long polling / events |
| Tasks non-idempotentes | Retries causent duplications | Design idempotent |
| Sans timeout | Tasks zombies | Timeout + detection |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Saga | Transactions distribuees |
| Queue-based Load Leveling | Buffer des taches |
| Competing Consumers | Agents multiples |
| Leader Election | Supervisor HA |

## Sources

- [Microsoft - Scheduler Agent Supervisor](https://learn.microsoft.com/en-us/azure/architecture/patterns/scheduler-agent-supervisor)
- [Temporal.io](https://temporal.io/)
