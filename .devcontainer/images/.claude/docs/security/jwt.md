# JSON Web Tokens (JWT)

> Tokens signes et auto-contenus pour l'authentification stateless.

## Structure

```
header.payload.signature

eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4ifQ.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

## Claims standards

| Claim | Nom | Description |
|-------|-----|-------------|
| `iss` | Issuer | Emetteur du token |
| `sub` | Subject | Identifiant unique user |
| `aud` | Audience | Destinataires autorises |
| `exp` | Expiration | Timestamp d'expiration |
| `nbf` | Not Before | Valide a partir de |
| `iat` | Issued At | Date de creation |
| `jti` | JWT ID | Identifiant unique token |

## Implementation TypeScript

```typescript
import jwt from 'jsonwebtoken';

interface JWTPayload {
  sub: string;
  email: string;
  role: string;
  permissions: string[];
}

interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

class JWTService {
  constructor(
    private readonly accessSecret: string,
    private readonly refreshSecret: string,
    private readonly accessTTL = '15m',
    private readonly refreshTTL = '7d',
  ) {}

  generateTokens(user: User): TokenPair {
    const payload: JWTPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      permissions: user.permissions,
    };

    const accessToken = jwt.sign(payload, this.accessSecret, {
      expiresIn: this.accessTTL,
      issuer: 'my-app',
      audience: 'my-app-users',
    });

    const refreshToken = jwt.sign(
      { sub: user.id, type: 'refresh' },
      this.refreshSecret,
      { expiresIn: this.refreshTTL },
    );

    return { accessToken, refreshToken };
  }

  verifyAccessToken(token: string): JWTPayload {
    try {
      return jwt.verify(token, this.accessSecret, {
        issuer: 'my-app',
        audience: 'my-app-users',
      }) as JWTPayload;
    } catch (error) {
      if (error instanceof jwt.TokenExpiredError) {
        throw new TokenExpiredError();
      }
      if (error instanceof jwt.JsonWebTokenError) {
        throw new InvalidTokenError();
      }
      throw error;
    }
  }

  async refreshTokens(refreshToken: string): Promise<TokenPair> {
    const payload = jwt.verify(refreshToken, this.refreshSecret) as {
      sub: string;
    };
    const user = await this.userRepo.findById(payload.sub);

    if (!user) throw new InvalidTokenError();
    return this.generateTokens(user);
  }
}
```

## Middleware Express

```typescript
function authMiddleware(jwtService: JWTService) {
  return (req: Request, res: Response, next: NextFunction) => {
    const authHeader = req.headers.authorization;

    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing token' });
    }

    const token = authHeader.slice(7);

    try {
      const payload = jwtService.verifyAccessToken(token);
      req.user = payload;
      next();
    } catch (error) {
      if (error instanceof TokenExpiredError) {
        return res.status(401).json({ error: 'Token expired' });
      }
      return res.status(401).json({ error: 'Invalid token' });
    }
  };
}
```

## Rotation des Refresh Tokens

```typescript
class RefreshTokenRotation {
  private usedTokens = new Set<string>();

  async rotate(refreshToken: string): Promise<TokenPair> {
    const jti = this.extractJti(refreshToken);

    // Detect token reuse (potential theft)
    if (this.usedTokens.has(jti)) {
      await this.revokeAllUserTokens(refreshToken);
      throw new SecurityError('Token reuse detected');
    }

    this.usedTokens.add(jti);

    // Generate new pair with new jti
    const user = await this.getUserFromToken(refreshToken);
    return this.generateTokens(user);
  }
}
```

## Algorithmes de signature

| Algo | Type | Recommandation |
|------|------|----------------|
| HS256 | Symetrique (HMAC) | Dev/simple apps |
| RS256 | Asymetrique (RSA) | Production, microservices |
| ES256 | Asymetrique (ECDSA) | Meilleure perf que RSA |
| EdDSA | Asymetrique (Ed25519) | Modern, fast |

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `jsonwebtoken` | Standard Node.js |
| `jose` | Modern, edge-compatible |
| `passport-jwt` | Middleware Passport |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Secret trop court | Brute force possible | Min 256 bits (32 chars) |
| Token dans localStorage | XSS vulnerability | HttpOnly cookie ou memory |
| Pas d'expiration | Token eternel si vole | Toujours `exp` claim |
| Donnees sensibles dans payload | Data exposure | Payload = public, min data |
| Verification sans `aud`/`iss` | Token confusion | Toujours verifier claims |
| HS256 avec secret previsible | Token forgery | Secrets aleatoires cryptographiques |

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| APIs stateless | Oui |
| Microservices | Oui (avec RS256/ES256) |
| SPAs | Oui (avec refresh rotation) |
| Mobile apps | Oui |
| Sessions longues | Non (preferer sessions) |
| Donnees sensibles dans token | Non |

## Bonnes pratiques

```typescript
// 1. Access token court-lived
const accessTokenTTL = '15m'; // Max 1h

// 2. Refresh token long-lived avec rotation
const refreshTokenTTL = '7d';

// 3. Blacklist pour revocation
class TokenBlacklist {
  async revoke(jti: string, exp: number): Promise<void> {
    await redis.set(`blacklist:${jti}`, '1', 'EXAT', exp);
  }

  async isRevoked(jti: string): Promise<boolean> {
    return (await redis.exists(`blacklist:${jti}`)) === 1;
  }
}

// 4. Claims minimaux
const payload = {
  sub: user.id, // Required
  role: user.role, // For authorization
  // NO: email, name, sensitive data
};
```

## Patterns lies

- **OAuth 2.0** : JWT souvent utilise comme access token
- **Session-Auth** : Alternative avec etat serveur
- **RBAC** : Permissions dans claims

## Sources

- [JWT RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519)
- [JWT Best Practices RFC 8725](https://datatracker.ietf.org/doc/html/rfc8725)
- [jwt.io](https://jwt.io/)
