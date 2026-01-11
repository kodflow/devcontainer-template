# Queue-Based Load Leveling Pattern

> Utiliser une queue comme buffer pour lisser les pics de charge.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │          QUEUE LOAD LEVELING                 │
                    └─────────────────────────────────────────────┘

  SANS QUEUE (pics saturent le service):
                                           ┌─────────┐
  ████████████                            │ Service │
  ██  PEAK  ██ ─────────────────────────▶ │ OVERLOAD│
  ████████████                            │   !!!   │
       │                                   └─────────┘
       │ Capacite max
       ▼
  ═══════════════

  AVEC QUEUE (charge lissee):
                    ┌─────────────┐        ┌─────────┐
  ████████████      │             │        │ Service │
  ██  PEAK  ██ ───▶ │    QUEUE    │ ─────▶ │ Stable  │
  ████████████      │   (buffer)  │        │  Load   │
                    └─────────────┘        └─────────┘
                          │                     │
  Charge entrante         │    Debit constant   │
  ════════════════════════════════════════════════
```

## Comparaison patterns

```
  INPUT RATE        QUEUE DEPTH         OUTPUT RATE
       │                 │                   │
  100  │  ████           │    ████           │
       │  ██████         │      ████████     │ ════════
   50  │    ████████     │        ████████   │ Constant
       │      ████       │          ████     │
    0  └──────────────   └──────────────     └──────────
       Time              Time                Time
```

## Exemple Go

```go
package queueloadleveling

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// Task represents a task to be processed.
type Task struct {
	ID        string
	Type      string
	Payload   interface{}
	CreatedAt time.Time
	Attempts  int
}

// QueueService defines queue operations.
type QueueService interface {
	Push(ctx context.Context, task *Task) error
	Pop(ctx context.Context) (*Task, error)
	Length(ctx context.Context) (int, error)
}

// LoadLevelingQueue manages task queuing with load leveling.
type LoadLevelingQueue struct {
	queue          QueueService
	maxConcurrent  int
	processingDelay time.Duration
}

// NewLoadLevelingQueue creates a new LoadLevelingQueue.
func NewLoadLevelingQueue(queue QueueService, maxConcurrent int, processingDelay time.Duration) *LoadLevelingQueue {
	return &LoadLevelingQueue{
		queue:          queue,
		maxConcurrent:  maxConcurrent,
		processingDelay: processingDelay,
	}
}

// Enqueue adds a task to the queue.
func (llq *LoadLevelingQueue) Enqueue(ctx context.Context, task *Task) error {
	if err := llq.queue.Push(ctx, task); err != nil {
		return fmt.Errorf("enqueuing task: %w", err)
	}

	depth, _ := llq.queue.Length(ctx)
	fmt.Printf("Task %s queued. Queue depth: %d
", task.ID, depth)

	return nil
}

// Depth returns the current queue depth.
func (llq *LoadLevelingQueue) Depth(ctx context.Context) (int, error) {
	return llq.queue.Length(ctx)
}

// LeveledConsumer processes tasks with controlled concurrency.
type LeveledConsumer struct {
	queue           QueueService
	handler         func(context.Context, *Task) error
	maxConcurrent   int
	pollInterval    time.Duration
	running         bool
	active          int
	mu              sync.Mutex
	wg              sync.WaitGroup
}

// NewLeveledConsumer creates a new LeveledConsumer.
func NewLeveledConsumer(
	queue QueueService,
	handler func(context.Context, *Task) error,
	maxConcurrent int,
	pollInterval time.Duration,
) *LeveledConsumer {
	return &LeveledConsumer{
		queue:         queue,
		handler:       handler,
		maxConcurrent: maxConcurrent,
		pollInterval:  pollInterval,
	}
}

// Start starts the consumer.
func (lc *LeveledConsumer) Start(ctx context.Context) error {
	lc.mu.Lock()
	lc.running = true
	lc.mu.Unlock()

	ticker := time.NewTicker(lc.pollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			lc.Stop()
			lc.wg.Wait()
			return ctx.Err()
		case <-ticker.C:
			lc.processAvailable(ctx)
		}
	}
}

func (lc *LeveledConsumer) processAvailable(ctx context.Context) {
	lc.mu.Lock()
	running := lc.running
	active := lc.active
	lc.mu.Unlock()

	if !running {
		return
	}

	// Process up to maxConcurrent tasks
	for active < lc.maxConcurrent {
		task, err := lc.queue.Pop(ctx)
		if err != nil || task == nil {
			break
		}

		lc.mu.Lock()
		lc.active++
		active = lc.active
		lc.mu.Unlock()

		lc.wg.Add(1)
		go lc.processTask(ctx, task)
	}
}

func (lc *LeveledConsumer) processTask(ctx context.Context, task *Task) {
	defer func() {
		lc.wg.Done()
		lc.mu.Lock()
		lc.active--
		lc.mu.Unlock()
	}()

	if err := lc.handler(ctx, task); err != nil {
		fmt.Printf("Task %s failed: %v
", task.ID, err)
		
		// Optionally re-queue for retry
		task.Attempts++
		if task.Attempts < 3 {
			lc.queue.Push(ctx, task)
		}
	}
}

// Stop stops the consumer.
func (lc *LeveledConsumer) Stop() {
	lc.mu.Lock()
	lc.running = false
	lc.mu.Unlock()
}
```

## Implementation avec rate limiting

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Auto-scaling base sur la queue

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Metriques cles

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Services cloud

| Service | Provider | Caracteristiques |
|---------|----------|------------------|
| SQS | AWS | Serverless, auto-scale, 14j retention |
| Azure Queue | Azure | Integre Functions, 7j retention |
| Cloud Tasks | GCP | HTTP targets, scheduling |
| RabbitMQ | Self-hosted | Features avancees, clustering |
| Redis Streams | Redis | Ultra-rapide, persistence |

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Pics de trafic previsibles | Oui |
| Decoupler producteur/consommateur | Oui |
| Service downstream lent | Oui |
| Latence temps reel critique | Non (ajoute delai) |
| Ordre strict requis | Avec FIFO garantie |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Priority Queue | Traitement par importance |
| Competing Consumers | Parallelisation |
| Throttling | Limiter le debit |
| Circuit Breaker | Si consumer defaillant |

## Sources

- [Microsoft - Queue-Based Load Leveling](https://learn.microsoft.com/en-us/azure/architecture/patterns/queue-based-load-leveling)
- [AWS SQS Best Practices](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-best-practices.html)
- [Martin Fowler - Messaging](https://martinfowler.com/articles/integration-patterns.html)
