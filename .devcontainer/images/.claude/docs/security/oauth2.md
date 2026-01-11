# OAuth 2.0 Flows

> Protocole d'autorisation pour l'accès delegue aux ressources.

## Flows disponibles

| Flow | Client | Usage |
|------|--------|-------|
| **Authorization Code** | Web apps (backend) | Standard securise |
| **Authorization Code + PKCE** | SPAs, Mobile | Public clients |
| **Client Credentials** | Machine-to-machine | Services, APIs |
| **Device Code** | CLI, TV, IoT | Input-limited devices |
| **Implicit** | -- | DEPRECIE (utiliser PKCE) |

## Authorization Code Flow

```go
package oauth2

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
)

// Config holds OAuth2 configuration.
type Config struct {
	ClientID              string
	ClientSecret          string
	RedirectURI           string
	AuthorizationEndpoint string
	TokenEndpoint         string
}

// TokenResponse represents an OAuth2 token response.
type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token,omitempty"`
	Scope        string `json:"scope,omitempty"`
}

// AuthorizationCode handles the authorization code flow.
type AuthorizationCode struct {
	config Config
	client *http.Client
}

// NewAuthorizationCode creates a new authorization code flow handler.
func NewAuthorizationCode(cfg Config) *AuthorizationCode {
	return &AuthorizationCode{
		config: cfg,
		client: &http.Client{},
	}
}

// GetAuthorizationURL generates the authorization URL.
func (a *AuthorizationCode) GetAuthorizationURL(state string, scopes []string) string {
	params := url.Values{}
	params.Set("client_id", a.config.ClientID)
	params.Set("redirect_uri", a.config.RedirectURI)
	params.Set("response_type", "code")
	params.Set("scope", joinScopes(scopes))
	params.Set("state", state) // CSRF protection

	return a.config.AuthorizationEndpoint + "?" + params.Encode()
}

// ExchangeCode exchanges an authorization code for tokens.
func (a *AuthorizationCode) ExchangeCode(ctx context.Context, code string) (*TokenResponse, error) {
	data := url.Values{}
	data.Set("grant_type", "authorization_code")
	data.Set("code", code)
	data.Set("redirect_uri", a.config.RedirectURI)
	data.Set("client_id", a.config.ClientID)
	data.Set("client_secret", a.config.ClientSecret)

	req, err := http.NewRequestWithContext(ctx, "POST", a.config.TokenEndpoint, 
		strings.NewReader(data.Encode()))
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := a.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("token request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("token exchange failed: %s", body)
	}

	var tokenResp TokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &tokenResp, nil
}

func joinScopes(scopes []string) string {
	return strings.Join(scopes, " ")
}
```

## Authorization Code + PKCE (Public Clients)

```go
package oauth2

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"net/url"
	"strings"
)

// PKCE handles the PKCE extension for public clients.
type PKCE struct {
	config Config
	client *http.Client
}

// NewPKCE creates a new PKCE flow handler.
func NewPKCE(cfg Config) *PKCE {
	return &PKCE{
		config: cfg,
		client: &http.Client{},
	}
}

// GenerateCodeVerifier generates a PKCE code verifier.
func (p *PKCE) GenerateCodeVerifier() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("generating random bytes: %w", err)
	}
	return base64URLEncode(b), nil
}

// GenerateCodeChallenge generates a PKCE code challenge from a verifier.
func (p *PKCE) GenerateCodeChallenge(verifier string) string {
	hash := sha256.Sum256([]byte(verifier))
	return base64URLEncode(hash[:])
}

// GetAuthorizationURL generates the authorization URL with PKCE.
func (p *PKCE) GetAuthorizationURL(verifier, challenge, state string, scopes []string) string {
	params := url.Values{}
	params.Set("client_id", p.config.ClientID)
	params.Set("redirect_uri", p.config.RedirectURI)
	params.Set("response_type", "code")
	params.Set("scope", strings.Join(scopes, " "))
	params.Set("state", state)
	params.Set("code_challenge", challenge)
	params.Set("code_challenge_method", "S256")

	return p.config.AuthorizationEndpoint + "?" + params.Encode()
}

// ExchangeCode exchanges a code for tokens using PKCE.
func (p *PKCE) ExchangeCode(ctx context.Context, code, verifier string) (*TokenResponse, error) {
	data := url.Values{}
	data.Set("grant_type", "authorization_code")
	data.Set("code", code)
	data.Set("redirect_uri", p.config.RedirectURI)
	data.Set("client_id", p.config.ClientID)
	data.Set("code_verifier", verifier) // Proof of possession

	req, err := http.NewRequestWithContext(ctx, "POST", p.config.TokenEndpoint,
		strings.NewReader(data.Encode()))
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := p.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("token request: %w", err)
	}
	defer resp.Body.Close()

	var tokenResp TokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &tokenResp, nil
}

func base64URLEncode(data []byte) string {
	return strings.TrimRight(base64.URLEncoding.EncodeToString(data), "=")
}
```

## Client Credentials Flow (M2M)

```go
package oauth2

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
)

// ClientCredentials handles machine-to-machine authentication.
type ClientCredentials struct {
	clientID      string
	clientSecret  string
	tokenEndpoint string
	client        *http.Client
}

// NewClientCredentials creates a new client credentials flow handler.
func NewClientCredentials(clientID, clientSecret, tokenEndpoint string) *ClientCredentials {
	return &ClientCredentials{
		clientID:      clientID,
		clientSecret:  clientSecret,
		tokenEndpoint: tokenEndpoint,
		client:        &http.Client{},
	}
}

// GetToken obtains an access token using client credentials.
func (c *ClientCredentials) GetToken(ctx context.Context, scopes []string) (*TokenResponse, error) {
	credentials := base64.StdEncoding.EncodeToString(
		[]byte(c.clientID + ":" + c.clientSecret))

	data := url.Values{}
	data.Set("grant_type", "client_credentials")
	data.Set("scope", strings.Join(scopes, " "))

	req, err := http.NewRequestWithContext(ctx, "POST", c.tokenEndpoint,
		strings.NewReader(data.Encode()))
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Authorization", "Basic "+credentials)

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("token request: %w", err)
	}
	defer resp.Body.Close()

	var tokenResp TokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &tokenResp, nil
}
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `golang.org/x/oauth2` | Client OAuth2 complet |
| `github.com/go-oauth2/oauth2/v4` | Serveur OAuth2 |
| `github.com/coreos/go-oidc/v3` | OpenID Connect client |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Pas de state parameter | CSRF attacks | Toujours generer un state unique |
| Stocker tokens en localStorage | XSS exposure | HttpOnly cookies ou memory |
| Implicit flow en 2024 | Insecure | Migrer vers PKCE |
| Client secret en frontend | Secret expose | PKCE pour public clients |
| Pas de token refresh | UX degradee | Implementer refresh_token flow |

## Quand utiliser

| Scenario | Flow recommande |
|----------|-----------------|
| Web app avec backend | Authorization Code |
| SPA (React, Vue, Angular) | Authorization Code + PKCE |
| Mobile app | Authorization Code + PKCE |
| CLI tool | Device Code |
| Microservice to microservice | Client Credentials |
| Backend batch jobs | Client Credentials |

## Patterns lies

- **JWT** : Format typique des access tokens
- **Session-Auth** : Alternative pour apps monolithiques
- **RBAC/ABAC** : Gestion des permissions post-auth

## Sources

- [OAuth 2.0 RFC 6749](https://oauth.net/2/)
- [OAuth 2.0 Security Best Practices](https://oauth.net/2/oauth-best-practice/)
- [PKCE RFC 7636](https://oauth.net/2/pkce/)
