# Leader Election Pattern

> Coordonner les actions en elisant un leader parmi les instances distribuees.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │              LEADER ELECTION                 │
                    └─────────────────────────────────────────────┘

  SANS LEADER (chaos):
  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ Node 1  │  │ Node 2  │  │ Node 3  │
  │ Process │  │ Process │  │ Process │  <-- Tous executent = duplication
  └─────────┘  └─────────┘  └─────────┘

  AVEC LEADER:
  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ Node 1  │  │ Node 2  │  │ Node 3  │
  │ LEADER  │  │Follower │  │Follower │
  │ Process │  │ Standby │  │ Standby │
  └────┬────┘  └────┬────┘  └────┬────┘
       │            │            │
       └────────────┼────────────┘
                    │
            ┌───────▼───────┐
            │  Coordination │
            │   (etcd/ZK)   │
            └───────────────┘
```

## Mecanismes d'election

```
1. BULLY ALGORITHM
   - Plus haute ID devient leader
   - Simple mais pas tolerant aux partitions

2. RAFT CONSENSUS
   ┌─────────────────────────────────────────┐
   │  Follower ──▶ Candidate ──▶ Leader     │
   │      │             │           │        │
   │      │   timeout   │  majority │        │
   │      │   no leader │  votes    │        │
   │      │             │           │        │
   │      └─────────────────────────┘        │
   │              heartbeat                  │
   └─────────────────────────────────────────┘

3. LEASE-BASED (lock distribue)
   - Acquiert un lock avec TTL
   - Renouvelle avant expiration
   - Lock expire = nouvelle election
```

## Exemple TypeScript avec Redis

```typescript
interface LeaderElection {
  tryBecomeLeader(): Promise<boolean>;
  isLeader(): boolean;
  resign(): Promise<void>;
  onLeadershipChange(callback: (isLeader: boolean) => void): void;
}

class RedisLeaderElection implements LeaderElection {
  private _isLeader = false;
  private renewalInterval?: NodeJS.Timeout;
  private listeners: ((isLeader: boolean) => void)[] = [];

  constructor(
    private redis: Redis,
    private lockKey: string,
    private nodeId: string,
    private leaseTtlSeconds = 30,
    private renewIntervalMs = 10000,
  ) {}

  async tryBecomeLeader(): Promise<boolean> {
    // SET NX = only if not exists, EX = with expiration
    const acquired = await this.redis.set(
      this.lockKey,
      this.nodeId,
      'EX',
      this.leaseTtlSeconds,
      'NX',
    );

    if (acquired === 'OK') {
      this._isLeader = true;
      this.startRenewal();
      this.notifyListeners(true);
      return true;
    }

    // Check if we already own it
    const currentLeader = await this.redis.get(this.lockKey);
    if (currentLeader === this.nodeId) {
      this._isLeader = true;
      return true;
    }

    return false;
  }

  isLeader(): boolean {
    return this._isLeader;
  }

  async resign(): Promise<void> {
    if (this.renewalInterval) {
      clearInterval(this.renewalInterval);
    }

    // Only delete if we own it (Lua script for atomicity)
    const script = `
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
      else
        return 0
      end
    `;
    await this.redis.eval(script, 1, this.lockKey, this.nodeId);
    this._isLeader = false;
    this.notifyListeners(false);
  }

  onLeadershipChange(callback: (isLeader: boolean) => void): void {
    this.listeners.push(callback);
  }

  private startRenewal(): void {
    this.renewalInterval = setInterval(async () => {
      try {
        await this.renewLease();
      } catch (error) {
        console.error('Lease renewal failed:', error);
        this._isLeader = false;
        this.notifyListeners(false);
      }
    }, this.renewIntervalMs);
  }

  private async renewLease(): Promise<void> {
    // Extend TTL only if we own the lock
    const script = `
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("expire", KEYS[1], ARGV[2])
      else
        return 0
      end
    `;
    const result = await this.redis.eval(
      script,
      1,
      this.lockKey,
      this.nodeId,
      this.leaseTtlSeconds,
    );

    if (result === 0) {
      throw new Error('Lost leadership');
    }
  }

  private notifyListeners(isLeader: boolean): void {
    this.listeners.forEach((cb) => cb(isLeader));
  }
}
```

## Usage avec tache periodique

```typescript
class ScheduledTaskRunner {
  private election: LeaderElection;

  constructor(redis: Redis, taskName: string) {
    this.election = new RedisLeaderElection(
      redis,
      `leader:${taskName}`,
      `node:${process.env.HOSTNAME}`,
    );

    this.election.onLeadershipChange((isLeader) => {
      if (isLeader) {
        console.log('Became leader, starting scheduled tasks');
        this.startTasks();
      } else {
        console.log('Lost leadership, stopping tasks');
        this.stopTasks();
      }
    });
  }

  async start(): Promise<void> {
    // Try to become leader on startup
    const isLeader = await this.election.tryBecomeLeader();

    if (!isLeader) {
      // Watch for leader failure
      this.watchForLeaderFailure();
    }
  }

  private watchForLeaderFailure(): void {
    setInterval(async () => {
      if (!this.election.isLeader()) {
        await this.election.tryBecomeLeader();
      }
    }, 5000); // Check every 5 seconds
  }

  private startTasks(): void {
    // Only leader runs these
    this.runDailyCleanup();
    this.runMetricsAggregation();
  }

  private stopTasks(): void {
    // Cancel running tasks
  }
}
```

## Solutions cloud natives

| Service | Usage |
|---------|-------|
| **etcd** | Kubernetes, consensus Raft |
| **Consul** | HashiCorp, sessions et locks |
| **ZooKeeper** | Apache, znodes ephemeres |
| **Redis** | Redlock algorithm |
| **DynamoDB** | Conditional writes |

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Taches cron distribuees | Oui |
| Coordination cluster | Oui |
| Master/Replica database | Oui |
| Toutes les instances equivalentes | Non (pas besoin) |
| Stateless pur | Non |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Singleton (distribue) | Garantir une seule instance |
| Bulkhead | Isolation leader/followers |
| Health Check | Detection leader defaillant |
| Sharding | Leader par shard |

## Sources

- [Microsoft - Leader Election](https://learn.microsoft.com/en-us/azure/architecture/patterns/leader-election)
- [Raft Consensus Algorithm](https://raft.github.io/)
- [Redis Distributed Locks](https://redis.io/docs/manual/patterns/distributed-locks/)
