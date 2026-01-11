# Builder Pattern

> Construire des objets complexes etape par etape avec une interface fluide.

## Intention

Separer la construction d'un objet complexe de sa representation, permettant
au meme processus de construction de creer differentes representations.

## Structure

```go
package main

import (
	"errors"
	"fmt"
)

// 1. Produit complexe
type HTTPRequest struct {
	Method  string
	URL     string
	Headers map[string]string
	Body    string
	Timeout int
	Retries int
}

// 2. Builder avec methodes chainees
type RequestBuilder struct {
	request *HTTPRequest
}

// NewRequestBuilder cree un nouveau builder.
func NewRequestBuilder() *RequestBuilder {
	return &RequestBuilder{
		request: &HTTPRequest{
			Headers: make(map[string]string),
		},
	}
}

// SetMethod configure la methode HTTP.
func (b *RequestBuilder) SetMethod(method string) *RequestBuilder {
	b.request.Method = method
	return b
}

// SetURL configure l'URL.
func (b *RequestBuilder) SetURL(url string) *RequestBuilder {
	b.request.URL = url
	return b
}

// AddHeader ajoute un header.
func (b *RequestBuilder) AddHeader(key, value string) *RequestBuilder {
	b.request.Headers[key] = value
	return b
}

// SetBody configure le corps de la requete.
func (b *RequestBuilder) SetBody(body string) *RequestBuilder {
	b.request.Body = body
	return b
}

// SetTimeout configure le timeout en millisecondes.
func (b *RequestBuilder) SetTimeout(ms int) *RequestBuilder {
	b.request.Timeout = ms
	return b
}

// SetRetries configure le nombre de tentatives.
func (b *RequestBuilder) SetRetries(count int) *RequestBuilder {
	b.request.Retries = count
	return b
}

// Build construit la requete finale avec validation.
func (b *RequestBuilder) Build() (*HTTPRequest, error) {
	if b.request.Method == "" || b.request.URL == "" {
		return nil, errors.New("method and URL are required")
	}
	return b.request, nil
}

// 4. Director (optionnel)
type RequestDirector struct {
	builder *RequestBuilder
}

// NewRequestDirector cree un nouveau director.
func NewRequestDirector(builder *RequestBuilder) *RequestDirector {
	return &RequestDirector{builder: builder}
}

// BuildGetRequest construit une requete GET preconfiguree.
func (d *RequestDirector) BuildGetRequest(url string) (*HTTPRequest, error) {
	return d.builder.
		SetMethod("GET").
		SetURL(url).
		SetTimeout(5000).
		Build()
}

// BuildJSONPostRequest construit une requete POST JSON preconfiguree.
func (d *RequestDirector) BuildJSONPostRequest(url string, data string) (*HTTPRequest, error) {
	return d.builder.
		SetMethod("POST").
		SetURL(url).
		AddHeader("Content-Type", "application/json").
		SetBody(data).
		SetTimeout(10000).
		SetRetries(3).
		Build()
}
```

## Usage

```go
package main

import (
	"encoding/json"
	"fmt"
	"log"
)

func main() {
	// Sans Director (fluent interface)
	request, err := NewRequestBuilder().
		SetMethod("POST").
		SetURL("https://api.example.com/users").
		AddHeader("Authorization", "Bearer token").
		AddHeader("Content-Type", "application/json").
		SetBody(`{"name":"John"}`).
		SetTimeout(5000).
		Build()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Request: %+v\n", request)

	// Avec Director
	director := NewRequestDirector(NewRequestBuilder())
	getRequest, err := director.BuildGetRequest("https://api.example.com/users")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("GET Request: %+v\n", getRequest)

	postRequest, err := director.BuildJSONPostRequest(
		"https://api.example.com/users",
		`{"name":"John"}`,
	)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("POST Request: %+v\n", postRequest)
}
```

## Variantes

### Step Builder (validation a chaque etape)

```go
package main

// MethodStep definit les methodes HTTP disponibles.
type MethodStep interface {
	GET(url string) HeadersStep
	POST(url string) BodyStep
}

// HeadersStep permet d'ajouter des headers.
type HeadersStep interface {
	WithHeader(key, value string) HeadersStep
	Build() (*HTTPRequest, error)
}

// BodyStep necessite un body avant les headers.
type BodyStep interface {
	WithBody(body string) HeadersStep
}

type stepBuilder struct {
	request *HTTPRequest
}

// NewStepBuilder cree un builder avec validation par etapes.
func NewStepBuilder() MethodStep {
	return &stepBuilder{
		request: &HTTPRequest{
			Headers: make(map[string]string),
		},
	}
}

func (b *stepBuilder) GET(url string) HeadersStep {
	b.request.Method = "GET"
	b.request.URL = url
	return b
}

func (b *stepBuilder) POST(url string) BodyStep {
	b.request.Method = "POST"
	b.request.URL = url
	return b
}

func (b *stepBuilder) WithBody(body string) HeadersStep {
	b.request.Body = body
	return b
}

func (b *stepBuilder) WithHeader(key, value string) HeadersStep {
	b.request.Headers[key] = value
	return b
}

func (b *stepBuilder) Build() (*HTTPRequest, error) {
	if b.request.Method == "" || b.request.URL == "" {
		return nil, errors.New("invalid request configuration")
	}
	return b.request, nil
}
```

### Immutable Builder

```go
package main

// ImmutableRequestBuilder cree de nouvelles instances a chaque modification.
type ImmutableRequestBuilder struct {
	config *HTTPRequest
}

// NewImmutableRequestBuilder cree un builder immutable.
func NewImmutableRequestBuilder() *ImmutableRequestBuilder {
	return &ImmutableRequestBuilder{
		config: &HTTPRequest{
			Headers: make(map[string]string),
		},
	}
}

// WithMethod retourne un nouveau builder avec la methode configuree.
func (b *ImmutableRequestBuilder) WithMethod(method string) *ImmutableRequestBuilder {
	newHeaders := make(map[string]string)
	for k, v := range b.config.Headers {
		newHeaders[k] = v
	}
	return &ImmutableRequestBuilder{
		config: &HTTPRequest{
			Method:  method,
			URL:     b.config.URL,
			Headers: newHeaders,
			Body:    b.config.Body,
			Timeout: b.config.Timeout,
			Retries: b.config.Retries,
		},
	}
}

// WithURL retourne un nouveau builder avec l'URL configuree.
func (b *ImmutableRequestBuilder) WithURL(url string) *ImmutableRequestBuilder {
	newHeaders := make(map[string]string)
	for k, v := range b.config.Headers {
		newHeaders[k] = v
	}
	return &ImmutableRequestBuilder{
		config: &HTTPRequest{
			Method:  b.config.Method,
			URL:     url,
			Headers: newHeaders,
			Body:    b.config.Body,
			Timeout: b.config.Timeout,
			Retries: b.config.Retries,
		},
	}
}

// Build retourne une copie de la requete.
func (b *ImmutableRequestBuilder) Build() (*HTTPRequest, error) {
	if b.config.Method == "" || b.config.URL == "" {
		return nil, errors.New("method and URL are required")
	}
	newHeaders := make(map[string]string)
	for k, v := range b.config.Headers {
		newHeaders[k] = v
	}
	return &HTTPRequest{
		Method:  b.config.Method,
		URL:     b.config.URL,
		Headers: newHeaders,
		Body:    b.config.Body,
		Timeout: b.config.Timeout,
		Retries: b.config.Retries,
	}, nil
}
```

## Anti-patterns

```go
// MAUVAIS: Constructeur telescopique
func NewRequest(
	method string,
	url string,
	headers map[string]string,
	body string,
	timeout int,
	retries int,
	// ... 10 autres parametres
) *HTTPRequest {
	// Difficile a lire et maintenir
	return &HTTPRequest{}
}

// MAUVAIS: Builder sans validation
type BadBuilder struct {
	request *HTTPRequest
}

func (b *BadBuilder) Build() *HTTPRequest {
	// Retourne un objet potentiellement invalide
	return b.request
}

// MAUVAIS: Builder mutable reutilise
builder := NewRequestBuilder()
req1, _ := builder.SetURL("/a").Build()
req2, _ := builder.SetURL("/b").Build() // req1 aussi modifie!
```

## Alternative moderne : Functional Options

```go
package main

import (
	"errors"
	"time"
)

// Option configure une HTTPRequest.
type Option func(*HTTPRequest)

// WithMethod configure la methode HTTP.
func WithMethod(method string) Option {
	return func(r *HTTPRequest) {
		r.Method = method
	}
}

// WithURL configure l'URL.
func WithURL(url string) Option {
	return func(r *HTTPRequest) {
		r.URL = url
	}
}

// WithHeader ajoute un header.
func WithHeader(key, value string) Option {
	return func(r *HTTPRequest) {
		if r.Headers == nil {
			r.Headers = make(map[string]string)
		}
		r.Headers[key] = value
	}
}

// WithTimeout configure le timeout.
func WithTimeout(ms int) Option {
	return func(r *HTTPRequest) {
		r.Timeout = ms
	}
}

// NewHTTPRequest cree une requete avec des options fonctionnelles.
func NewHTTPRequest(opts ...Option) (*HTTPRequest, error) {
	req := &HTTPRequest{
		Headers: make(map[string]string),
		Timeout: 5000, // Valeur par defaut
	}
	for _, opt := range opts {
		opt(req)
	}
	if req.Method == "" || req.URL == "" {
		return nil, errors.New("method and URL are required")
	}
	return req, nil
}

// Usage simple pour cas simples
func ExampleFunctionalOptions() {
	req, err := NewHTTPRequest(
		WithMethod("GET"),
		WithURL("/api/users"),
		WithHeader("Accept", "application/json"),
	)
	if err != nil {
		panic(err)
	}
	_ = req
}
```

## Tests unitaires

```go
package main

import (
	"testing"
)

func TestRequestBuilder_Build(t *testing.T) {
	tests := []struct {
		name    string
		build   func(*RequestBuilder) *RequestBuilder
		wantErr bool
	}{
		{
			name: "valid GET request",
			build: func(b *RequestBuilder) *RequestBuilder {
				return b.SetMethod("GET").SetURL("https://api.example.com")
			},
			wantErr: false,
		},
		{
			name: "missing method",
			build: func(b *RequestBuilder) *RequestBuilder {
				return b.SetURL("/api")
			},
			wantErr: true,
		},
		{
			name: "accumulate headers",
			build: func(b *RequestBuilder) *RequestBuilder {
				return b.
					SetMethod("GET").
					SetURL("/api").
					AddHeader("Accept", "application/json").
					AddHeader("Authorization", "Bearer token")
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			builder := NewRequestBuilder()
			request, err := tt.build(builder).Build()

			if tt.wantErr && err == nil {
				t.Error("expected error, got nil")
			}
			if !tt.wantErr && err != nil {
				t.Errorf("unexpected error: %v", err)
			}
			if !tt.wantErr && request == nil {
				t.Error("expected request, got nil")
			}
		})
	}
}

func TestRequestBuilder_FluentChaining(t *testing.T) {
	builder := NewRequestBuilder()
	result := builder.SetMethod("GET")
	if result != builder {
		t.Error("expected fluent chaining to return same builder")
	}
}

func TestRequestDirector_BuildGetRequest(t *testing.T) {
	director := NewRequestDirector(NewRequestBuilder())
	request, err := director.BuildGetRequest("/api/users")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if request.Method != "GET" {
		t.Errorf("expected GET, got %s", request.Method)
	}
	if request.Timeout != 5000 {
		t.Errorf("expected timeout 5000, got %d", request.Timeout)
	}
}
```

## Quand utiliser

- Objets avec de nombreux parametres optionnels
- Construction complexe en plusieurs etapes
- Meme processus pour differentes representations
- Immutabilite souhaitee pendant la construction

## Patterns lies

- **Abstract Factory** : Peut utiliser Builder pour creer des produits
- **Prototype** : Alternative quand le clonage est plus simple
- **Fluent Interface** : Technique utilisee par Builder

## Sources

- [Refactoring Guru - Builder](https://refactoring.guru/design-patterns/builder)
- [Effective Java - Item 2](https://www.oreilly.com/library/view/effective-java/9780134686097/)
