# Static Content Hosting Pattern

> Servir les assets statiques depuis un CDN ou storage dedie pour performance et scalabilite.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │          STATIC CONTENT HOSTING              │
                    └─────────────────────────────────────────────┘

  SANS (app sert tout):
  ┌────────┐   /api/data     ┌─────────┐
  │ Client │ ───────────────▶│   App   │  CPU: API + assets
  └────────┘   /img/logo.png │ Server  │  Bandwidth: sature
               /css/app.css  └─────────┘

  AVEC (separation):
  ┌────────┐   /api/data     ┌─────────┐
  │ Client │ ───────────────▶│   App   │  CPU: API only
  └────────┘                 └─────────┘
       │
       │     /assets/*       ┌─────────┐     ┌─────────┐
       └────────────────────▶│   CDN   │◀────│ Storage │
                             │ (cache) │     │ (origin)│
                             └─────────┘     └─────────┘

  Architecture CDN:
                        ┌───────────────┐
                        │    Origin     │
                        │  (S3/Blob)    │
                        └───────┬───────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
       ┌────▼────┐         ┌────▼────┐         ┌────▼────┐
       │ Edge EU │         │Edge USA │         │Edge Asia│
       └────┬────┘         └────┬────┘         └────┬────┘
            │                   │                   │
       ┌────▼────┐         ┌────▼────┐         ┌────▼────┐
       │ Users EU│         │Users USA│         │Users Asia│
       └─────────┘         └─────────┘         └─────────┘
```

## Configuration TypeScript

```typescript
interface CDNConfig {
  originBucket: string;
  cdnDomain: string;
  cacheControl: {
    static: string;
    dynamic: string;
  };
}

class StaticContentService {
  constructor(private config: CDNConfig) {}

  // Generate CDN URL for asset
  getAssetUrl(path: string): string {
    return `https://${this.config.cdnDomain}/${path}`;
  }

  // Generate versioned URL (cache busting)
  getVersionedUrl(path: string, version: string): string {
    return `https://${this.config.cdnDomain}/${path}?v=${version}`;
  }

  // Content hash for immutable caching
  getHashedUrl(path: string, hash: string): string {
    const ext = path.split('.').pop();
    const base = path.replace(`.${ext}`, '');
    return `https://${this.config.cdnDomain}/${base}.${hash}.${ext}`;
  }
}
```

## Upload avec metadata cache

```typescript
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

class AssetUploader {
  private s3: S3Client;

  constructor(
    private bucket: string,
    private cdnDomain: string,
  ) {
    this.s3 = new S3Client({ region: 'eu-west-1' });
  }

  async uploadAsset(
    key: string,
    content: Buffer,
    contentType: string,
    isImmutable = false,
  ): Promise<string> {
    const cacheControl = isImmutable
      ? 'public, max-age=31536000, immutable' // 1 year
      : 'public, max-age=86400'; // 1 day

    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: content,
        ContentType: contentType,
        CacheControl: cacheControl,
      }),
    );

    return `https://${this.cdnDomain}/${key}`;
  }

  // Upload avec hash dans le nom (immutable)
  async uploadWithHash(
    originalPath: string,
    content: Buffer,
    contentType: string,
  ): Promise<string> {
    const hash = this.computeHash(content);
    const ext = originalPath.split('.').pop();
    const base = originalPath.replace(`.${ext}`, '');
    const hashedPath = `${base}.${hash}.${ext}`;

    return this.uploadAsset(hashedPath, content, contentType, true);
  }

  private computeHash(content: Buffer): string {
    const crypto = require('crypto');
    return crypto.createHash('md5').update(content).digest('hex').slice(0, 8);
  }
}
```

## Build pipeline integration

```typescript
// Webpack/Vite output handling
interface BuildOutput {
  assets: Map<string, { path: string; content: Buffer }>;
  manifest: Record<string, string>; // original -> hashed
}

class CDNDeployer {
  constructor(
    private uploader: AssetUploader,
    private cdnDomain: string,
  ) {}

  async deployBuild(output: BuildOutput): Promise<Record<string, string>> {
    const urlMap: Record<string, string> = {};

    for (const [originalPath, asset] of output.assets) {
      const contentType = this.getContentType(originalPath);
      const url = await this.uploader.uploadWithHash(
        originalPath,
        asset.content,
        contentType,
      );
      urlMap[originalPath] = url;
    }

    // Upload manifest for server-side rendering
    await this.uploader.uploadAsset(
      'manifest.json',
      Buffer.from(JSON.stringify(urlMap)),
      'application/json',
      false, // Manifest can change
    );

    return urlMap;
  }

  private getContentType(path: string): string {
    const ext = path.split('.').pop()?.toLowerCase();
    const types: Record<string, string> = {
      js: 'application/javascript',
      css: 'text/css',
      html: 'text/html',
      json: 'application/json',
      png: 'image/png',
      jpg: 'image/jpeg',
      svg: 'image/svg+xml',
      woff2: 'font/woff2',
    };
    return types[ext || ''] || 'application/octet-stream';
  }
}
```

## Cache strategies

```typescript
const cacheStrategies = {
  // Immutable: fichiers avec hash (app.a1b2c3d4.js)
  immutable: 'public, max-age=31536000, immutable',

  // Static longue duree: logos, fonts
  longTerm: 'public, max-age=2592000', // 30 days

  // Frequemment mis a jour: index.html
  shortTerm: 'public, max-age=3600, must-revalidate', // 1 hour

  // Dynamique: API responses cached at edge
  dynamic: 'public, max-age=60, stale-while-revalidate=300',

  // Prive: user-specific content
  private: 'private, max-age=0, no-store',
};
```

## Headers de securite

```typescript
const securityHeaders = {
  // Prevent MIME sniffing
  'X-Content-Type-Options': 'nosniff',

  // XSS protection
  'X-XSS-Protection': '1; mode=block',

  // Referrer policy
  'Referrer-Policy': 'strict-origin-when-cross-origin',

  // CORS for fonts/scripts
  'Access-Control-Allow-Origin': 'https://myapp.com',

  // CSP for static assets
  'Content-Security-Policy': "default-src 'self'",

  // HSTS
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
};
```

## Services cloud

| Service | Provider | Features |
|---------|----------|----------|
| CloudFront | AWS | Lambda@Edge, signed URLs |
| Azure CDN | Azure | Rules engine, WAF |
| Cloud CDN | GCP | Cloud Armor, media CDN |
| Cloudflare | - | Workers, R2 storage |
| Fastly | - | Instant purge, VCL |

## Invalidation cache

```typescript
import { CloudFrontClient, CreateInvalidationCommand } from '@aws-sdk/client-cloudfront';

class CDNCacheManager {
  private cloudfront: CloudFrontClient;

  constructor(private distributionId: string) {
    this.cloudfront = new CloudFrontClient({ region: 'us-east-1' });
  }

  async invalidatePaths(paths: string[]): Promise<void> {
    await this.cloudfront.send(
      new CreateInvalidationCommand({
        DistributionId: this.distributionId,
        InvalidationBatch: {
          CallerReference: Date.now().toString(),
          Paths: {
            Quantity: paths.length,
            Items: paths.map((p) => (p.startsWith('/') ? p : `/${p}`)),
          },
        },
      }),
    );
  }

  // Invalidate all
  async invalidateAll(): Promise<void> {
    await this.invalidatePaths(['/*']);
  }
}
```

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Assets frontend (JS, CSS, images) | Oui |
| Media/video streaming | Oui |
| Audience geographiquement distribuee | Oui |
| Contenu personnalise par user | Non (ou avec edge compute) |
| Donnees temps reel | Non |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Valet Key | Upload direct |
| Cache-Aside | Caching dynamique |
| Backends for Frontends | API + static separation |
| Gateway Offloading | Decharger l'app server |

## Sources

- [Microsoft - Static Content Hosting](https://learn.microsoft.com/en-us/azure/architecture/patterns/static-content-hosting)
- [AWS CloudFront Best Practices](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/best-practices.html)
- [Google Cloud CDN](https://cloud.google.com/cdn/docs)
