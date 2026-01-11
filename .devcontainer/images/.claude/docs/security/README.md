# Security Patterns

Patterns de sécurité applicative.

## Authentication Patterns

### 1. Session-Based Authentication

> Authentification avec session côté serveur.

```typescript
class SessionAuth {
  private sessions = new Map<string, SessionData>();

  async login(credentials: Credentials): Promise<string> {
    const user = await this.validateCredentials(credentials);
    if (!user) throw new UnauthorizedError();

    const sessionId = crypto.randomUUID();
    this.sessions.set(sessionId, {
      userId: user.id,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 3600000), // 1 hour
    });

    return sessionId;
  }

  async validate(sessionId: string): Promise<User | null> {
    const session = this.sessions.get(sessionId);
    if (!session) return null;
    if (new Date() > session.expiresAt) {
      this.sessions.delete(sessionId);
      return null;
    }
    return this.userRepo.findById(session.userId);
  }

  logout(sessionId: string) {
    this.sessions.delete(sessionId);
  }
}

// Middleware
function sessionMiddleware(auth: SessionAuth) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const sessionId = req.cookies.sessionId;
    if (!sessionId) {
      return res.status(401).json({ error: 'Not authenticated' });
    }

    const user = await auth.validate(sessionId);
    if (!user) {
      return res.status(401).json({ error: 'Invalid session' });
    }

    req.user = user;
    next();
  };
}
```

**Avantages :** Révocation immédiate, contrôle serveur.
**Inconvénients :** État serveur, scaling complexe.
**Quand :** Applications monolithiques, besoin de révocation.

---

### 2. Token-Based Authentication (JWT)

> Authentification stateless avec tokens signés.

```typescript
import jwt from 'jsonwebtoken';

interface TokenPayload {
  userId: string;
  role: string;
  permissions: string[];
}

class JWTAuth {
  constructor(
    private secret: string,
    private accessTokenTTL: string = '15m',
    private refreshTokenTTL: string = '7d',
  ) {}

  generateTokens(user: User): { accessToken: string; refreshToken: string } {
    const payload: TokenPayload = {
      userId: user.id,
      role: user.role,
      permissions: user.permissions,
    };

    const accessToken = jwt.sign(payload, this.secret, {
      expiresIn: this.accessTokenTTL,
    });

    const refreshToken = jwt.sign({ userId: user.id }, this.secret, {
      expiresIn: this.refreshTokenTTL,
    });

    return { accessToken, refreshToken };
  }

  verifyAccessToken(token: string): TokenPayload {
    try {
      return jwt.verify(token, this.secret) as TokenPayload;
    } catch (error) {
      throw new UnauthorizedError('Invalid token');
    }
  }

  async refreshTokens(refreshToken: string): Promise<{ accessToken: string; refreshToken: string }> {
    const payload = jwt.verify(refreshToken, this.secret) as { userId: string };
    const user = await this.userRepo.findById(payload.userId);
    if (!user) throw new UnauthorizedError();
    return this.generateTokens(user);
  }
}

// Token rotation for refresh tokens
class RefreshTokenStore {
  private tokens = new Map<string, { userId: string; used: boolean }>();

  store(token: string, userId: string) {
    this.tokens.set(token, { userId, used: false });
  }

  validate(token: string): string | null {
    const data = this.tokens.get(token);
    if (!data || data.used) {
      // Token reuse detected - potential theft
      this.revokeAllForUser(data?.userId);
      return null;
    }
    data.used = true;
    return data.userId;
  }

  revokeAllForUser(userId: string) {
    for (const [token, data] of this.tokens) {
      if (data.userId === userId) {
        this.tokens.delete(token);
      }
    }
  }
}
```

**Avantages :** Stateless, scalable, microservices.
**Inconvénients :** Révocation complexe, taille token.
**Quand :** APIs, SPAs, microservices.

---

### 3. OAuth 2.0 / OpenID Connect

> Authentification déléguée via provider externe.

```typescript
class OAuth2Client {
  constructor(
    private clientId: string,
    private clientSecret: string,
    private redirectUri: string,
    private provider: OAuth2Provider,
  ) {}

  getAuthorizationUrl(state: string, scopes: string[]): string {
    const params = new URLSearchParams({
      client_id: this.clientId,
      redirect_uri: this.redirectUri,
      response_type: 'code',
      scope: scopes.join(' '),
      state,
    });
    return `${this.provider.authorizationEndpoint}?${params}`;
  }

  async exchangeCode(code: string): Promise<TokenResponse> {
    const response = await fetch(this.provider.tokenEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: this.redirectUri,
        client_id: this.clientId,
        client_secret: this.clientSecret,
      }),
    });
    return response.json();
  }

  async getUserInfo(accessToken: string): Promise<UserInfo> {
    const response = await fetch(this.provider.userInfoEndpoint, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    return response.json();
  }
}

// PKCE for public clients (SPAs, mobile)
class PKCEClient {
  generateCodeVerifier(): string {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return base64UrlEncode(array);
  }

  async generateCodeChallenge(verifier: string): Promise<string> {
    const hash = await crypto.subtle.digest(
      'SHA-256',
      new TextEncoder().encode(verifier),
    );
    return base64UrlEncode(new Uint8Array(hash));
  }
}
```

**Flows :**
- **Authorization Code** : Web apps avec backend
- **Authorization Code + PKCE** : SPAs, mobile
- **Client Credentials** : Machine-to-machine
- **Implicit** : Déprécié

**Quand :** Login social, SSO, APIs tierces.

---

### 4. API Key Authentication

> Authentification simple par clé API.

```typescript
class ApiKeyAuth {
  constructor(private keyStore: ApiKeyStore) {}

  async validate(apiKey: string): Promise<ApiKeyData | null> {
    // Hash the key for storage comparison
    const hashedKey = this.hash(apiKey);
    const keyData = await this.keyStore.findByHash(hashedKey);

    if (!keyData) return null;
    if (keyData.expiresAt && new Date() > keyData.expiresAt) return null;
    if (keyData.revokedAt) return null;

    // Update last used
    await this.keyStore.updateLastUsed(keyData.id);

    return keyData;
  }

  async generateKey(userId: string, scopes: string[]): Promise<string> {
    const key = `${this.prefix}_${crypto.randomUUID().replace(/-/g, '')}`;
    const hashedKey = this.hash(key);

    await this.keyStore.create({
      userId,
      hashedKey,
      scopes,
      createdAt: new Date(),
    });

    return key; // Only returned once!
  }

  private hash(key: string): string {
    return crypto.createHash('sha256').update(key).digest('hex');
  }
}

// Rate limiting per API key
class RateLimitedApiKey {
  private limits = new Map<string, { count: number; resetAt: Date }>();

  async checkLimit(apiKey: string, limit: number, windowMs: number): Promise<boolean> {
    const now = new Date();
    const data = this.limits.get(apiKey);

    if (!data || now > data.resetAt) {
      this.limits.set(apiKey, {
        count: 1,
        resetAt: new Date(now.getTime() + windowMs),
      });
      return true;
    }

    if (data.count >= limit) {
      return false;
    }

    data.count++;
    return true;
  }
}
```

**Quand :** APIs publiques, intégrations simples.
**Lié à :** Rate Limiting.

---

## Authorization Patterns

### 5. Role-Based Access Control (RBAC)

> Permissions basées sur les rôles.

```typescript
type Role = 'admin' | 'editor' | 'viewer';
type Permission = 'read' | 'write' | 'delete' | 'admin';

const rolePermissions: Record<Role, Permission[]> = {
  admin: ['read', 'write', 'delete', 'admin'],
  editor: ['read', 'write'],
  viewer: ['read'],
};

class RBAC {
  hasPermission(user: User, permission: Permission): boolean {
    const permissions = rolePermissions[user.role] || [];
    return permissions.includes(permission);
  }

  hasRole(user: User, role: Role): boolean {
    return user.role === role;
  }

  hasAnyRole(user: User, roles: Role[]): boolean {
    return roles.includes(user.role);
  }
}

// Decorator for route protection
function requirePermission(permission: Permission) {
  return (target: any, propertyKey: string, descriptor: PropertyDescriptor) => {
    const original = descriptor.value;
    descriptor.value = async function (...args: any[]) {
      const [req] = args;
      if (!rbac.hasPermission(req.user, permission)) {
        throw new ForbiddenError();
      }
      return original.apply(this, args);
    };
  };
}

// Usage
class ArticleController {
  @requirePermission('write')
  async create(req: Request) {
    // Only users with 'write' permission
  }

  @requirePermission('delete')
  async delete(req: Request) {
    // Only users with 'delete' permission
  }
}
```

**Avantages :** Simple, compréhensible.
**Inconvénients :** Granularité limitée.
**Quand :** Applications avec rôles clairs.

---

### 6. Attribute-Based Access Control (ABAC)

> Permissions basées sur attributs et contexte.

```typescript
interface Policy {
  effect: 'allow' | 'deny';
  conditions: Condition[];
}

interface Condition {
  attribute: string;
  operator: 'eq' | 'in' | 'gt' | 'lt' | 'contains';
  value: any;
}

interface AccessRequest {
  subject: Record<string, any>;  // User attributes
  resource: Record<string, any>; // Resource attributes
  action: string;
  environment: Record<string, any>; // Time, location, etc.
}

class ABAC {
  constructor(private policies: Policy[]) {}

  evaluate(request: AccessRequest): boolean {
    for (const policy of this.policies) {
      const matches = policy.conditions.every((cond) =>
        this.evaluateCondition(cond, request),
      );

      if (matches) {
        return policy.effect === 'allow';
      }
    }
    return false; // Default deny
  }

  private evaluateCondition(condition: Condition, request: AccessRequest): boolean {
    const value = this.getAttribute(condition.attribute, request);

    switch (condition.operator) {
      case 'eq':
        return value === condition.value;
      case 'in':
        return condition.value.includes(value);
      case 'gt':
        return value > condition.value;
      case 'lt':
        return value < condition.value;
      case 'contains':
        return value?.includes?.(condition.value);
      default:
        return false;
    }
  }

  private getAttribute(path: string, request: AccessRequest): any {
    const [type, ...rest] = path.split('.');
    const obj = request[type as keyof AccessRequest];
    return rest.reduce((o, k) => o?.[k], obj);
  }
}

// Example policies
const policies: Policy[] = [
  {
    effect: 'allow',
    conditions: [
      { attribute: 'subject.role', operator: 'eq', value: 'admin' },
    ],
  },
  {
    effect: 'allow',
    conditions: [
      { attribute: 'action', operator: 'eq', value: 'read' },
      { attribute: 'resource.isPublic', operator: 'eq', value: true },
    ],
  },
  {
    effect: 'allow',
    conditions: [
      { attribute: 'resource.ownerId', operator: 'eq', value: '$subject.id' },
    ],
  },
];
```

**Avantages :** Flexible, contextuel.
**Inconvénients :** Complexe, performance.
**Quand :** Règles complexes, multi-tenant, compliance.

---

### 7. Policy-Based Access Control

> Politiques déclaratives.

```typescript
// Policy Definition Language
interface PolicyDocument {
  version: string;
  statements: Statement[];
}

interface Statement {
  effect: 'Allow' | 'Deny';
  actions: string[];
  resources: string[];
  conditions?: Record<string, any>;
}

class PolicyEngine {
  evaluate(
    policies: PolicyDocument[],
    action: string,
    resource: string,
    context: Record<string, any>,
  ): boolean {
    let allowed = false;

    for (const policy of policies) {
      for (const statement of policy.statements) {
        if (!this.matchesAction(statement.actions, action)) continue;
        if (!this.matchesResource(statement.resources, resource)) continue;
        if (!this.matchesConditions(statement.conditions, context)) continue;

        if (statement.effect === 'Deny') {
          return false; // Explicit deny
        }
        allowed = true;
      }
    }

    return allowed;
  }

  private matchesAction(patterns: string[], action: string): boolean {
    return patterns.some((p) => this.matches(p, action));
  }

  private matchesResource(patterns: string[], resource: string): boolean {
    return patterns.some((p) => this.matches(p, resource));
  }

  private matches(pattern: string, value: string): boolean {
    if (pattern === '*') return true;
    const regex = pattern.replace(/\*/g, '.*');
    return new RegExp(`^${regex}$`).test(value);
  }
}

// Example policy (AWS IAM style)
const policy: PolicyDocument = {
  version: '2024-01-01',
  statements: [
    {
      effect: 'Allow',
      actions: ['article:read', 'article:list'],
      resources: ['*'],
    },
    {
      effect: 'Allow',
      actions: ['article:*'],
      resources: ['article/${user.id}/*'],
      conditions: { 'user.emailVerified': true },
    },
    {
      effect: 'Deny',
      actions: ['article:delete'],
      resources: ['article/*/protected'],
    },
  ],
};
```

**Quand :** Multi-tenant, cloud resources, fine-grained.
**Lié à :** ABAC.

---

## Security Patterns

### 8. Input Validation & Sanitization

> Valider et nettoyer toutes les entrées.

```typescript
import { z } from 'zod';

// Schema-based validation
const userSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(100),
  name: z.string().min(2).max(50).regex(/^[a-zA-Z\s]+$/),
  age: z.number().int().min(0).max(150),
});

function validateInput<T>(schema: z.ZodSchema<T>, data: unknown): T {
  return schema.parse(data);
}

// Sanitization
class Sanitizer {
  // SQL Injection prevention
  escapeSQL(input: string): string {
    return input.replace(/'/g, "''");
  }

  // XSS prevention
  escapeHTML(input: string): string {
    return input
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // Path traversal prevention
  sanitizePath(input: string): string {
    return input.replace(/\.\./g, '').replace(/^\/+/, '');
  }

  // Command injection prevention
  escapeShell(input: string): string {
    return `'${input.replace(/'/g, "'\\''")}'`;
  }
}

// Parameterized queries (best practice)
async function findUser(email: string): Promise<User | null> {
  // GOOD - parameterized
  return db.query('SELECT * FROM users WHERE email = $1', [email]);

  // BAD - string concatenation
  // return db.query(`SELECT * FROM users WHERE email = '${email}'`);
}
```

**Quand :** TOUJOURS pour les entrées utilisateur.

---

### 9. Password Hashing

> Stockage sécurisé des mots de passe.

```typescript
import bcrypt from 'bcrypt';
import argon2 from 'argon2';

class PasswordService {
  private readonly saltRounds = 12;

  // BCrypt
  async hashBcrypt(password: string): Promise<string> {
    return bcrypt.hash(password, this.saltRounds);
  }

  async verifyBcrypt(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }

  // Argon2 (recommended)
  async hashArgon2(password: string): Promise<string> {
    return argon2.hash(password, {
      type: argon2.argon2id,
      memoryCost: 65536,    // 64MB
      timeCost: 3,          // iterations
      parallelism: 4,       // threads
    });
  }

  async verifyArgon2(password: string, hash: string): Promise<boolean> {
    return argon2.verify(hash, password);
  }

  // Password strength validation
  validateStrength(password: string): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (password.length < 12) {
      errors.push('Password must be at least 12 characters');
    }
    if (!/[A-Z]/.test(password)) {
      errors.push('Password must contain uppercase letter');
    }
    if (!/[a-z]/.test(password)) {
      errors.push('Password must contain lowercase letter');
    }
    if (!/[0-9]/.test(password)) {
      errors.push('Password must contain number');
    }
    if (!/[!@#$%^&*]/.test(password)) {
      errors.push('Password must contain special character');
    }

    return { valid: errors.length === 0, errors };
  }
}
```

**Algorithmes recommandés :** Argon2id > bcrypt > PBKDF2.
**Quand :** TOUJOURS pour les mots de passe.

---

### 10. CSRF Protection

> Protection contre Cross-Site Request Forgery.

```typescript
class CSRFProtection {
  private tokens = new Map<string, { token: string; expiresAt: Date }>();

  generateToken(sessionId: string): string {
    const token = crypto.randomBytes(32).toString('hex');
    this.tokens.set(sessionId, {
      token,
      expiresAt: new Date(Date.now() + 3600000), // 1 hour
    });
    return token;
  }

  validateToken(sessionId: string, token: string): boolean {
    const stored = this.tokens.get(sessionId);
    if (!stored) return false;
    if (new Date() > stored.expiresAt) {
      this.tokens.delete(sessionId);
      return false;
    }
    return crypto.timingSafeEqual(
      Buffer.from(stored.token),
      Buffer.from(token),
    );
  }
}

// Double Submit Cookie pattern
function csrfMiddleware() {
  return (req: Request, res: Response, next: NextFunction) => {
    if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(req.method)) {
      const cookieToken = req.cookies['csrf-token'];
      const headerToken = req.headers['x-csrf-token'];

      if (!cookieToken || !headerToken || cookieToken !== headerToken) {
        return res.status(403).json({ error: 'Invalid CSRF token' });
      }
    }
    next();
  };
}

// SameSite Cookie (modern approach)
res.cookie('session', sessionId, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict', // or 'lax'
});
```

**Quand :** Forms, state-changing requests.

---

### 11. Rate Limiting

> Limiter le nombre de requêtes.

```typescript
interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
}

class RateLimiter {
  private requests = new Map<string, { count: number; resetAt: number }>();

  constructor(private config: RateLimitConfig) {}

  check(identifier: string): { allowed: boolean; remaining: number; resetAt: number } {
    const now = Date.now();
    const data = this.requests.get(identifier);

    if (!data || now > data.resetAt) {
      const resetAt = now + this.config.windowMs;
      this.requests.set(identifier, { count: 1, resetAt });
      return { allowed: true, remaining: this.config.maxRequests - 1, resetAt };
    }

    if (data.count >= this.config.maxRequests) {
      return { allowed: false, remaining: 0, resetAt: data.resetAt };
    }

    data.count++;
    return {
      allowed: true,
      remaining: this.config.maxRequests - data.count,
      resetAt: data.resetAt,
    };
  }
}

// Sliding window with Redis
class RedisRateLimiter {
  async check(key: string, limit: number, windowSeconds: number): Promise<boolean> {
    const now = Date.now();
    const windowStart = now - windowSeconds * 1000;

    const pipeline = this.redis.pipeline();
    pipeline.zremrangebyscore(key, 0, windowStart); // Remove old entries
    pipeline.zadd(key, now, `${now}-${Math.random()}`); // Add current
    pipeline.zcard(key); // Count
    pipeline.expire(key, windowSeconds); // Set TTL

    const results = await pipeline.exec();
    const count = results[2][1] as number;

    return count <= limit;
  }
}
```

**Quand :** APIs, login, resource protection.
**Lié à :** Circuit Breaker.

---

### 12. Secrets Management

> Gestion sécurisée des secrets.

```typescript
// Environment variables (basic)
const config = {
  dbPassword: process.env.DB_PASSWORD,
  apiKey: process.env.API_KEY,
};

// Vault client
class VaultClient {
  constructor(
    private vaultAddr: string,
    private token: string,
  ) {}

  async getSecret(path: string): Promise<Record<string, string>> {
    const response = await fetch(`${this.vaultAddr}/v1/${path}`, {
      headers: { 'X-Vault-Token': this.token },
    });
    const data = await response.json();
    return data.data.data;
  }

  async setSecret(path: string, data: Record<string, string>): Promise<void> {
    await fetch(`${this.vaultAddr}/v1/${path}`, {
      method: 'POST',
      headers: {
        'X-Vault-Token': this.token,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ data }),
    });
  }
}

// Secret rotation
class SecretRotation {
  async rotateDbCredentials() {
    // 1. Generate new credentials
    const newPassword = crypto.randomBytes(32).toString('base64');

    // 2. Update in database
    await this.db.execute('ALTER USER app PASSWORD ?', [newPassword]);

    // 3. Update in vault
    await this.vault.setSecret('database/creds', { password: newPassword });

    // 4. Notify applications to reload
    await this.notifyApplications();
  }
}
```

**Best practices :**
- Ne jamais commit de secrets
- Rotation régulière
- Least privilege
- Audit logging

---

## Tableau de décision

| Besoin | Pattern |
|--------|---------|
| Login utilisateur | Session / JWT |
| Login social | OAuth 2.0 |
| API authentication | API Keys / JWT |
| Permissions simples | RBAC |
| Permissions complexes | ABAC / Policy |
| Validation entrées | Schema validation |
| Stockage passwords | Argon2 / bcrypt |
| Protection forms | CSRF tokens |
| Limite requêtes | Rate Limiting |
| Gestion secrets | Vault / Env vars |

## Sources

- [OWASP Cheat Sheets](https://cheatsheetseries.owasp.org/)
- [OAuth 2.0 Spec](https://oauth.net/2/)
- [NIST Guidelines](https://pages.nist.gov/800-63-3/)
