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

```go
package staticcontent

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
)

// CDNConfig defines CDN configuration.
type CDNConfig struct {
	OriginBucket string
	CDNDomain    string
	CacheControl struct {
		Static  string
		Dynamic string
	}
}

// StaticContentService manages static content URLs.
type StaticContentService struct {
	config CDNConfig
}

// NewStaticContentService creates a new StaticContentService.
func NewStaticContentService(config CDNConfig) *StaticContentService {
	return &StaticContentService{
		config: config,
	}
}

// GetAssetURL generates a CDN URL for an asset.
func (scs *StaticContentService) GetAssetURL(path string) string {
	return fmt.Sprintf("https://%s/%s", scs.config.CDNDomain, path)
}

// GetVersionedURL generates a versioned URL for cache busting.
func (scs *StaticContentService) GetVersionedURL(path, version string) string {
	return fmt.Sprintf("https://%s/%s?v=%s", scs.config.CDNDomain, path, version)
}

// GetHashedURL generates a URL with content hash for immutable caching.
func (scs *StaticContentService) GetHashedURL(path, hash string) string {
	// Extract extension
	ext := ""
	for i := len(path) - 1; i >= 0; i-- {
		if path[i] == '.' {
			ext = path[i:]
			path = path[:i]
			break
		}
	}
	
	return fmt.Sprintf("https://%s/%s.%s%s", scs.config.CDNDomain, path, hash, ext)
}

// AssetUploader uploads assets to CDN origin.
type AssetUploader struct {
	bucket    string
	cdnDomain string
}

// NewAssetUploader creates a new AssetUploader.
func NewAssetUploader(bucket, cdnDomain string) *AssetUploader {
	return &AssetUploader{
		bucket:    bucket,
		cdnDomain: cdnDomain,
	}
}

// UploadAsset uploads an asset with cache control headers.
func (au *AssetUploader) UploadAsset(
	key string,
	content []byte,
	contentType string,
	isImmutable bool,
) (string, error) {
	cacheControl := "public, max-age=86400" // 1 day
	if isImmutable {
		cacheControl = "public, max-age=31536000, immutable" // 1 year
	}

	// In production, upload to S3/Azure Blob/GCS
	// s3Client.PutObject(&s3.PutObjectInput{
	//     Bucket:       aws.String(au.bucket),
	//     Key:          aws.String(key),
	//     Body:         bytes.NewReader(content),
	//     ContentType:  aws.String(contentType),
	//     CacheControl: aws.String(cacheControl),
	// })

	return fmt.Sprintf("https://%s/%s", au.cdnDomain, key), nil
}

// UploadWithHash uploads an asset with hash in the filename for immutable caching.
func (au *AssetUploader) UploadWithHash(
	originalPath string,
	content []byte,
	contentType string,
) (string, error) {
	hash := au.computeHash(content)
	
	// Extract extension
	ext := ""
	base := originalPath
	for i := len(originalPath) - 1; i >= 0; i-- {
		if originalPath[i] == '.' {
			ext = originalPath[i:]
			base = originalPath[:i]
			break
		}
	}
	
	hashedPath := fmt.Sprintf("%s.%s%s", base, hash, ext)
	
	return au.UploadAsset(hashedPath, content, contentType, true)
}

func (au *AssetUploader) computeHash(content []byte) string {
	h := md5.New()
	h.Write(content)
	fullHash := hex.EncodeToString(h.Sum(nil))
	return fullHash[:8] // First 8 characters
}
```

## Upload avec metadata cache

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Build pipeline integration

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Cache strategies

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Headers de securite

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
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

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
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
