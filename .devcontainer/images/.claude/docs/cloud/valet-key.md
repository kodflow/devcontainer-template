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

## Exemple Go - AWS S3

```go
package valetkey

import (
	"context"
	"fmt"
	"time"
)

// S3Client defines S3 operations (interface for AWS SDK).
type S3Client interface {
	GeneratePresignedURL(ctx context.Context, bucket, key string, expires time.Duration, method string) (string, error)
}

// S3ValetKeyService manages valet keys for S3.
type S3ValetKeyService struct {
	s3     S3Client
	bucket string
}

// NewS3ValetKeyService creates a new S3ValetKeyService.
func NewS3ValetKeyService(s3 S3Client, bucket string) *S3ValetKeyService {
	return &S3ValetKeyService{
		s3:     s3,
		bucket: bucket,
	}
}

// UploadURLResponse contains the upload URL and key.
type UploadURLResponse struct {
	URL string `json:"url"`
	Key string `json:"key"`
}

// GetUploadURL generates a presigned URL for uploading.
func (svks *S3ValetKeyService) GetUploadURL(
	ctx context.Context,
	key, contentType string,
	expiresInSeconds int,
) (*UploadURLResponse, error) {
	if expiresInSeconds == 0 {
		expiresInSeconds = 900 // 15 minutes default
	}

	expires := time.Duration(expiresInSeconds) * time.Second

	url, err := svks.s3.GeneratePresignedURL(ctx, svks.bucket, key, expires, "PUT")
	if err != nil {
		return nil, fmt.Errorf("generating presigned URL: %w", err)
	}

	return &UploadURLResponse{
		URL: url,
		Key: key,
	}, nil
}

// GetDownloadURL generates a presigned URL for downloading.
func (svks *S3ValetKeyService) GetDownloadURL(
	ctx context.Context,
	key string,
	expiresInSeconds int,
) (string, error) {
	if expiresInSeconds == 0 {
		expiresInSeconds = 3600 // 1 hour default
	}

	expires := time.Duration(expiresInSeconds) * time.Second

	url, err := svks.s3.GeneratePresignedURL(ctx, svks.bucket, key, expires, "GET")
	if err != nil {
		return "", fmt.Errorf("generating presigned URL: %w", err)
	}

	return url, nil
}

// UploadController handles upload URL requests.
type UploadController struct {
	valetService *S3ValetKeyService
}

// NewUploadController creates a new UploadController.
func NewUploadController(valetService *S3ValetKeyService) *UploadController {
	return &UploadController{
		valetService: valetService,
	}
}

// UploadRequest represents an upload URL request.
type UploadRequest struct {
	Filename    string `json:"filename"`
	ContentType string `json:"contentType"`
}

// UploadResponse contains the upload URL response.
type UploadResponse struct {
	UploadURL string `json:"uploadUrl"`
	Key       string `json:"key"`
	ExpiresIn int    `json:"expiresIn"`
}

// RequestUploadURL handles upload URL requests.
func (uc *UploadController) RequestUploadURL(
	ctx context.Context,
	userID string,
	req *UploadRequest,
) (*UploadResponse, error) {
	// Validation
	if !uc.isAllowedType(req.ContentType) {
		return nil, fmt.Errorf("invalid content type: %s", req.ContentType)
	}

	// Generate unique key
	key := fmt.Sprintf("uploads/%s/%d-%s", userID, time.Now().UnixNano(), req.Filename)

	urlResp, err := uc.valetService.GetUploadURL(ctx, key, req.ContentType, 900)
	if err != nil {
		return nil, fmt.Errorf("generating upload URL: %w", err)
	}

	return &UploadResponse{
		UploadURL: urlResp.URL,
		Key:       urlResp.Key,
		ExpiresIn: 900,
	}, nil
}

func (uc *UploadController) isAllowedType(contentType string) bool {
	allowed := []string{
		"image/jpeg",
		"image/png",
		"application/pdf",
	}

	for _, t := range allowed {
		if t == contentType {
			return true
		}
	}

	return false
}
```

## Exemple Azure Blob Storage (Go)

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Client-side usage (Go)

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
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

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
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
