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

## Exemple TypeScript

```typescript
interface ClaimCheckMessage {
  claimId: string;
  metadata: {
    contentType: string;
    size: number;
    createdAt: Date;
    ttl?: number;
  };
  payload?: any; // Optionnel: petits payloads inline
}

interface StorageProvider {
  store(data: Buffer, options?: StoreOptions): Promise<string>;
  retrieve(claimId: string): Promise<Buffer>;
  delete(claimId: string): Promise<void>;
}

class ClaimCheckService {
  private readonly inlineThreshold = 1024; // 1KB

  constructor(
    private readonly storage: StorageProvider,
    private readonly queue: MessageQueue,
  ) {}

  async send(data: any, options?: SendOptions): Promise<void> {
    const serialized = Buffer.from(JSON.stringify(data));
    const size = serialized.byteLength;

    let message: ClaimCheckMessage;

    if (size <= this.inlineThreshold) {
      // Small payload: inline
      message = {
        claimId: '',
        metadata: {
          contentType: 'application/json',
          size,
          createdAt: new Date(),
        },
        payload: data,
      };
    } else {
      // Large payload: claim check
      const claimId = await this.storage.store(serialized, {
        ttl: options?.ttl ?? 86400, // 24h default
      });

      message = {
        claimId,
        metadata: {
          contentType: 'application/json',
          size,
          createdAt: new Date(),
          ttl: options?.ttl,
        },
      };
    }

    await this.queue.publish(message);
  }

  async receive(): Promise<any> {
    const message = await this.queue.consume<ClaimCheckMessage>();

    if (message.payload) {
      // Inline payload
      return message.payload;
    }

    // Retrieve from storage
    const data = await this.storage.retrieve(message.claimId);
    return JSON.parse(data.toString());
  }
}

// Storage implementation (S3/Azure Blob/GCS)
class S3StorageProvider implements StorageProvider {
  constructor(private readonly s3Client: S3Client) {}

  async store(data: Buffer, options?: StoreOptions): Promise<string> {
    const claimId = `claim-${crypto.randomUUID()}`;

    await this.s3Client.send(
      new PutObjectCommand({
        Bucket: process.env.CLAIM_BUCKET,
        Key: claimId,
        Body: data,
        Metadata: {
          ttl: options?.ttl?.toString() ?? '',
        },
      }),
    );

    return claimId;
  }

  async retrieve(claimId: string): Promise<Buffer> {
    const response = await this.s3Client.send(
      new GetObjectCommand({
        Bucket: process.env.CLAIM_BUCKET,
        Key: claimId,
      }),
    );

    return Buffer.from(await response.Body!.transformToByteArray());
  }

  async delete(claimId: string): Promise<void> {
    await this.s3Client.send(
      new DeleteObjectCommand({
        Bucket: process.env.CLAIM_BUCKET,
        Key: claimId,
      }),
    );
  }
}
```

## Usage

```typescript
// Producer
const claimCheck = new ClaimCheckService(s3Storage, rabbitQueue);

// Envoyer un gros payload
const largeReport = {
  id: 'report-123',
  data: generateLargeDataset(), // 10MB
};

await claimCheck.send(largeReport, { ttl: 3600 }); // 1h TTL

// Consumer
const report = await claimCheck.receive();
console.log(report.id); // 'report-123'
```

## Gestion du cycle de vie

```typescript
class ClaimCheckLifecycleManager {
  async cleanup(): Promise<void> {
    // Option 1: TTL automatique (S3 lifecycle rules)
    // Option 2: Cleanup apres consommation
    // Option 3: Scheduled job
  }

  async onMessageConsumed(claimId: string): Promise<void> {
    // Delete claim after successful processing
    await this.storage.delete(claimId);
  }

  async onProcessingFailed(claimId: string): Promise<void> {
    // Keep for retry or dead letter analysis
    await this.extendTtl(claimId, 86400); // +24h
  }
}
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
