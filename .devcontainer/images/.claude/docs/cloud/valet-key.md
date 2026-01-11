# Valet Key Pattern

> Fournir un token temporaire pour acces direct aux ressources sans passer par l'application.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │                VALET KEY                     │
                    └─────────────────────────────────────────────┘

  SANS VALET KEY (proxy tout):
  ┌────────┐   Upload   ┌─────────┐   Store   ┌─────────┐
  │ Client │ ─────────▶ │   App   │ ────────▶ │ Storage │
  └────────┘   (5 GB)   │ (proxy) │   (5 GB)  └─────────┘
                        │ BOTTLENECK
                        └─────────┘

  AVEC VALET KEY (acces direct):
  ┌────────┐  1. Request token  ┌─────────┐
  │ Client │ ─────────────────▶ │   App   │
  └────────┘                    └────┬────┘
       │                             │
       │ 2. Token (SAS/presigned)    │
       ◀─────────────────────────────┘
       │
       │ 3. Direct upload with token
       │
       ▼
  ┌─────────┐
  │ Storage │  (pas de proxy!)
  └─────────┘
```

## Flux detaille

```
  ┌────────┐                  ┌─────────┐                  ┌─────────┐
  │ Client │                  │   API   │                  │ Storage │
  └───┬────┘                  └────┬────┘                  └────┬────┘
      │                            │                            │
      │  1. GET /upload-url        │                            │
      │───────────────────────────▶│                            │
      │                            │                            │
      │                            │  2. Generate SAS token     │
      │                            │  (expires: 15min,          │
      │                            │   permissions: write)      │
      │                            │                            │
      │  3. Return presigned URL   │                            │
      │◀───────────────────────────│                            │
      │                            │                            │
      │  4. PUT file directly      │                            │
      │─────────────────────────────────────────────────────────▶│
      │                            │                            │
      │  5. 200 OK                 │                            │
      │◀─────────────────────────────────────────────────────────│
      │                            │                            │
```

## Exemple TypeScript - AWS S3

```typescript
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

class S3ValetKeyService {
  private s3: S3Client;

  constructor(private bucket: string) {
    this.s3 = new S3Client({ region: 'eu-west-1' });
  }

  // Generate upload URL (PUT)
  async getUploadUrl(
    key: string,
    contentType: string,
    expiresInSeconds = 900, // 15 min
  ): Promise<{ url: string; key: string }> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });

    const url = await getSignedUrl(this.s3, command, {
      expiresIn: expiresInSeconds,
    });

    return { url, key };
  }

  // Generate download URL (GET)
  async getDownloadUrl(
    key: string,
    expiresInSeconds = 3600, // 1 hour
  ): Promise<string> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });

    return getSignedUrl(this.s3, command, {
      expiresIn: expiresInSeconds,
    });
  }
}

// API endpoint
class UploadController {
  constructor(private valetService: S3ValetKeyService) {}

  async requestUploadUrl(req: Request): Promise<Response> {
    const { filename, contentType } = req.body;

    // Validation
    if (!this.isAllowedType(contentType)) {
      return Response.json({ error: 'Invalid content type' }, { status: 400 });
    }

    // Generate unique key
    const key = `uploads/${req.user.id}/${Date.now()}-${filename}`;

    const { url } = await this.valetService.getUploadUrl(key, contentType);

    return Response.json({
      uploadUrl: url,
      key,
      expiresIn: 900,
    });
  }

  private isAllowedType(contentType: string): boolean {
    const allowed = ['image/jpeg', 'image/png', 'application/pdf'];
    return allowed.includes(contentType);
  }
}
```

## Exemple Azure Blob Storage

```typescript
import {
  BlobServiceClient,
  BlobSASPermissions,
  generateBlobSASQueryParameters,
  StorageSharedKeyCredential,
} from '@azure/storage-blob';

class AzureValetKeyService {
  private blobService: BlobServiceClient;
  private credential: StorageSharedKeyCredential;

  constructor(
    accountName: string,
    accountKey: string,
    private containerName: string,
  ) {
    this.credential = new StorageSharedKeyCredential(accountName, accountKey);
    this.blobService = new BlobServiceClient(
      `https://${accountName}.blob.core.windows.net`,
      this.credential,
    );
  }

  async getSasUrl(
    blobName: string,
    permissions: 'read' | 'write',
    expiresInMinutes = 15,
  ): Promise<string> {
    const containerClient = this.blobService.getContainerClient(
      this.containerName,
    );
    const blobClient = containerClient.getBlobClient(blobName);

    const startsOn = new Date();
    const expiresOn = new Date(startsOn.getTime() + expiresInMinutes * 60000);

    const sasPermissions = new BlobSASPermissions();
    if (permissions === 'read') sasPermissions.read = true;
    if (permissions === 'write') {
      sasPermissions.write = true;
      sasPermissions.create = true;
    }

    const sasToken = generateBlobSASQueryParameters(
      {
        containerName: this.containerName,
        blobName,
        permissions: sasPermissions,
        startsOn,
        expiresOn,
      },
      this.credential,
    ).toString();

    return `${blobClient.url}?${sasToken}`;
  }
}
```

## Client-side usage

```typescript
// Frontend code
async function uploadFile(file: File): Promise<string> {
  // 1. Get presigned URL from backend
  const { uploadUrl, key } = await fetch('/api/upload-url', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: file.name,
      contentType: file.type,
    }),
  }).then((r) => r.json());

  // 2. Upload directly to storage
  await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': file.type },
    body: file,
  });

  return key;
}
```

## Securite

| Aspect | Recommandation |
|--------|----------------|
| Expiration | 5-15 min pour upload, 1h pour download |
| Permissions | Minimum requis (write-only, read-only) |
| Path | Prefixer avec user ID |
| Content-Type | Valider cote serveur |
| Size | Configurer limite max |
| CORS | Restreindre origines |

```typescript
// Secure token generation
async getSecureUploadUrl(userId: string, filename: string): Promise<string> {
  // Sanitize filename
  const safeName = filename.replace(/[^a-zA-Z0-9.-]/g, '_');

  // User-scoped path
  const key = `users/${userId}/uploads/${Date.now()}-${safeName}`;

  // Short expiration
  return this.getUploadUrl(key, 'application/octet-stream', 300); // 5 min
}
```

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Upload fichiers volumineux | Oui |
| CDN/streaming media | Oui |
| Reduire charge serveur | Oui |
| Audit detaille requis | Avec logs storage |
| Transformation server-side requise | Non (faire apres) |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Static Content Hosting | Distribution assets |
| Gatekeeper | Validation avant token |
| Federated Identity | Auth avant generation |
| Queue Load Leveling | Traitement post-upload |

## Sources

- [Microsoft - Valet Key](https://learn.microsoft.com/en-us/azure/architecture/patterns/valet-key)
- [AWS S3 Presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html)
- [Azure SAS Tokens](https://learn.microsoft.com/en-us/azure/storage/common/storage-sas-overview)
