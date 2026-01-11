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

```typescript
interface OAuth2Config {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  authorizationEndpoint: string;
  tokenEndpoint: string;
}

class OAuth2AuthorizationCode {
  constructor(private config: OAuth2Config) {}

  getAuthorizationUrl(state: string, scopes: string[]): string {
    const params = new URLSearchParams({
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      response_type: 'code',
      scope: scopes.join(' '),
      state, // CSRF protection
    });
    return `${this.config.authorizationEndpoint}?${params}`;
  }

  async exchangeCode(code: string): Promise<TokenResponse> {
    const response = await fetch(this.config.tokenEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: this.config.redirectUri,
        client_id: this.config.clientId,
        client_secret: this.config.clientSecret,
      }),
    });

    if (!response.ok) {
      throw new OAuth2Error('Token exchange failed');
    }
    return response.json();
  }
}

interface TokenResponse {
  access_token: string;
  token_type: 'Bearer';
  expires_in: number;
  refresh_token?: string;
  scope?: string;
}
```

## Authorization Code + PKCE (Public Clients)

```typescript
class OAuth2PKCE {
  generateCodeVerifier(): string {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return this.base64UrlEncode(array);
  }

  async generateCodeChallenge(verifier: string): Promise<string> {
    const encoder = new TextEncoder();
    const data = encoder.encode(verifier);
    const hash = await crypto.subtle.digest('SHA-256', data);
    return this.base64UrlEncode(new Uint8Array(hash));
  }

  getAuthorizationUrl(
    verifier: string,
    challenge: string,
    state: string,
    scopes: string[],
  ): string {
    const params = new URLSearchParams({
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      response_type: 'code',
      scope: scopes.join(' '),
      state,
      code_challenge: challenge,
      code_challenge_method: 'S256',
    });
    return `${this.config.authorizationEndpoint}?${params}`;
  }

  async exchangeCode(code: string, verifier: string): Promise<TokenResponse> {
    const response = await fetch(this.config.tokenEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: this.config.redirectUri,
        client_id: this.config.clientId,
        code_verifier: verifier, // Proof of possession
      }),
    });
    return response.json();
  }

  private base64UrlEncode(buffer: Uint8Array): string {
    return btoa(String.fromCharCode(...buffer))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }
}
```

## Client Credentials Flow (M2M)

```typescript
class OAuth2ClientCredentials {
  async getToken(scopes: string[]): Promise<TokenResponse> {
    const credentials = btoa(`${this.clientId}:${this.clientSecret}`);

    const response = await fetch(this.tokenEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Basic ${credentials}`,
      },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        scope: scopes.join(' '),
      }),
    });

    return response.json();
  }
}
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `openid-client` | OpenID Connect client complet |
| `passport-oauth2` | Middleware Express/Passport |
| `oidc-provider` | Serveur OIDC Node.js |
| `next-auth` | Auth pour Next.js |

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
