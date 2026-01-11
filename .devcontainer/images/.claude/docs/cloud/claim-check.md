# Claim Check Pattern

> Separer le message de son payload volumineux via une reference.

## Principe

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLAIM CHECK PATTERN                              │
│                                                                          │
│   PRODUCER                                                               │
│   ┌─────────┐                                                           │
│   │  Data   │──┐                                                        │
│   │  (10MB) │  │                                                        │
│   └─────────┘  │                                                        │
│                │                                                        │
│                ▼                                                        │
│   ┌────────────────────┐         ┌─────────────────────────────────┐   │
│   │   1. Store Data    │────────▶│         BLOB STORAGE            │   │
│   └────────────────────┘         │   ┌─────────────────────────┐   │   │
│                │                 │   │  claim-id-123.json      │   │   │
│                │ claim_id        │   │  (actual data 10MB)     │   │   │
│                ▼                 │   └─────────────────────────┘   │   │
│   ┌────────────────────┐         └─────────────────────────────────┘   │
│   │ 2. Send Claim Only │                        ▲                       │
│   │   { claim: "123" } │                        │                       │
│   └────────────────────┘                        │                       │
│                │                                │                       │
│                ▼                                │                       │
│   ┌────────────────────┐                        │                       │
│   │    MESSAGE QUEUE   │                        │                       │
│   │  (small message)   │                        │                       │
│   └────────────────────┘                        │                       │
│                │                                │                       │
│                ▼                                │                       │
│   ┌────────────────────┐                        │                       │
│   │ 3. Consume Message │                        │                       │
│   └────────────────────┘                        │                       │
│                │                                │                       │
│                ▼                                │                       │
│   ┌────────────────────┐         ┌──────────────┘                       │
│   │ 4. Retrieve Data   │─────────┘                                      │
│   └────────────────────┘                                                │
│                │                                                        │
│                ▼                                                        │
│   CONSUMER                                                              │
│   ┌─────────┐                                                           │
│   │  Data   │                                                           │
│   │  (10MB) │                                                           │
│   └─────────┘                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

## Probleme resolu

| Approche | Message Queue | Latence | Cout |
|----------|---------------|---------|------|
| **Sans Claim Check** | 10MB par message | Haute | Eleve |
| **Avec Claim Check** | ~100 bytes | Basse | Faible |

## Exemple Go

```go
package claimcheck

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"
)

// ClaimCheckMessage represents a message with optional inline payload or claim reference.
type ClaimCheckMessage struct {
	ClaimID  string                 `json:"claimId"`
	Metadata ClaimCheckMetadata     `json:"metadata"`
	Payload  interface{}            `json:"payload,omitempty"`
}

// ClaimCheckMetadata contains message metadata.
type ClaimCheckMetadata struct {
	ContentType string    `json:"contentType"`
	Size        int       `json:"size"`
	CreatedAt   time.Time `json:"createdAt"`
	TTL         *int      `json:"ttl,omitempty"`
}

// StorageProvider defines storage operations for claims.
type StorageProvider interface {
	Store(ctx context.Context, data []byte, ttl int) (string, error)
	Retrieve(ctx context.Context, claimID string) ([]byte, error)
	Delete(ctx context.Context, claimID string) error
}

// MessageQueue defines queue operations.
type MessageQueue interface {
	Publish(ctx context.Context, msg ClaimCheckMessage) error
	Consume(ctx context.Context) (*ClaimCheckMessage, error)
}

// ClaimCheckService implements the claim check pattern.
type ClaimCheckService struct {
	storage         StorageProvider
	queue           MessageQueue
	inlineThreshold int
}

// NewClaimCheckService creates a new ClaimCheckService.
func NewClaimCheckService(storage StorageProvider, queue MessageQueue) *ClaimCheckService {
	return &ClaimCheckService{
		storage:         storage,
		queue:           queue,
		inlineThreshold: 1024, // 1KB
	}
}

// Send sends data using claim check pattern.
func (s *ClaimCheckService) Send(ctx context.Context, data interface{}, ttl int) error {
	serialized, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("marshaling data: %w", err)
	}

	size := len(serialized)
	msg := ClaimCheckMessage{
		Metadata: ClaimCheckMetadata{
			ContentType: "application/json",
			Size:        size,
			CreatedAt:   time.Now(),
		},
	}

	if size <= s.inlineThreshold {
		// Small payload: inline
		msg.Payload = data
	} else {
		// Large payload: claim check
		claimID, err := s.storage.Store(ctx, serialized, ttl)
		if err != nil {
			return fmt.Errorf("storing claim: %w", err)
		}
		msg.ClaimID = claimID
		msg.Metadata.TTL = &ttl
	}

	if err := s.queue.Publish(ctx, msg); err != nil {
		return fmt.Errorf("publishing message: %w", err)
	}

	return nil
}

// Receive receives data using claim check pattern.
func (s *ClaimCheckService) Receive(ctx context.Context) (interface{}, error) {
	msg, err := s.queue.Consume(ctx)
	if err != nil {
		return nil, fmt.Errorf("consuming message: %w", err)
	}

	if msg.Payload != nil {
		// Inline payload
		return msg.Payload, nil
	}

	// Retrieve from storage
	data, err := s.storage.Retrieve(ctx, msg.ClaimID)
	if err != nil {
		return nil, fmt.Errorf("retrieving claim: %w", err)
	}

	var result interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, fmt.Errorf("unmarshaling data: %w", err)
	}

	return result, nil
}

func generateClaimID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return "claim-" + hex.EncodeToString(b)
}
```

## Usage

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Gestion du cycle de vie

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Configuration S3 Lifecycle

```json
{
  "Rules": [
    {
      "ID": "ClaimCheckCleanup",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "claim-"
      },
      "Expiration": {
        "Days": 1
      }
    }
  ]
}
```

## Cas d'usage

| Scenario | Taille typique | Benefice |
|----------|----------------|----------|
| **Documents PDF** | 1-50 MB | Queue legere |
| **Images/Videos** | 1 MB - 1 GB | Traitement async |
| **Rapports** | 10-100 MB | Scalabilite |
| **Backups** | 100+ MB | Decouplage |
| **ETL data** | GB+ | Performance |

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Sans TTL | Accumulation storage | TTL obligatoire |
| Claim non-unique | Collisions | UUID ou hash |
| Sans retry | Perte de donnees | Retry + DLQ |
| Cleanup synchrone | Latence | Async/lifecycle rules |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Content Enricher | Inverse (add data) |
| Message Expiration | TTL des claims |
| Dead Letter | Claims non-consommes |
| Event Sourcing | Stocker events volumineux |

## Sources

- [Microsoft - Claim Check](https://learn.microsoft.com/en-us/azure/architecture/patterns/claim-check)
- [Enterprise Integration Patterns](https://www.enterpriseintegrationpatterns.com/StoreInLibrary.html)
