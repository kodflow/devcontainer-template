# Session-Based Authentication

> Authentification avec etat cote serveur et cookie de session.

## Principe

```
┌────────┐        ┌────────────┐        ┌──────────────┐
│ Client │◄──────►│   Server   │◄──────►│ Session Store│
└────────┘        └────────────┘        └──────────────┘
     │                  │                      │
     │ 1. Login         │                      │
     ├─────────────────►│                      │
     │                  │ 2. Create session    │
     │                  ├─────────────────────►│
     │                  │                      │
     │ 3. Set-Cookie    │                      │
     │◄─────────────────┤                      │
     │                  │                      │
     │ 4. Request +     │                      │
     │    Cookie        │ 5. Validate session  │
     ├─────────────────►├─────────────────────►│
     │                  │                      │
```

## Implementation TypeScript

```typescript
import crypto from 'crypto';

interface Session {
  id: string;
  userId: string;
  data: Record<string, unknown>;
  createdAt: Date;
  expiresAt: Date;
  lastAccessedAt: Date;
}

interface SessionStore {
  get(id: string): Promise<Session | null>;
  set(session: Session): Promise<void>;
  delete(id: string): Promise<void>;
  touch(id: string): Promise<void>;
}

class SessionManager {
  constructor(
    private store: SessionStore,
    private ttlMs = 24 * 60 * 60 * 1000, // 24h
    private slidingWindow = true,
  ) {}

  async create(userId: string, data?: Record<string, unknown>): Promise<string> {
    const sessionId = crypto.randomBytes(32).toString('hex');
    const now = new Date();

    const session: Session = {
      id: sessionId,
      userId,
      data: data || {},
      createdAt: now,
      expiresAt: new Date(now.getTime() + this.ttlMs),
      lastAccessedAt: now,
    };

    await this.store.set(session);
    return sessionId;
  }

  async validate(sessionId: string): Promise<Session | null> {
    if (!sessionId) return null;

    const session = await this.store.get(sessionId);
    if (!session) return null;

    // Check expiration
    if (new Date() > session.expiresAt) {
      await this.store.delete(sessionId);
      return null;
    }

    // Sliding window - extend expiration on access
    if (this.slidingWindow) {
      await this.store.touch(sessionId);
    }

    return session;
  }

  async destroy(sessionId: string): Promise<void> {
    await this.store.delete(sessionId);
  }

  async destroyAllForUser(userId: string): Promise<void> {
    // Implementation depends on store
    await this.store.deleteByUserId(userId);
  }
}
```

## Session Store Redis

```typescript
class RedisSessionStore implements SessionStore {
  constructor(private redis: Redis, private prefix = 'sess:') {}

  async get(id: string): Promise<Session | null> {
    const data = await this.redis.get(`${this.prefix}${id}`);
    if (!data) return null;

    const session = JSON.parse(data);
    return {
      ...session,
      createdAt: new Date(session.createdAt),
      expiresAt: new Date(session.expiresAt),
      lastAccessedAt: new Date(session.lastAccessedAt),
    };
  }

  async set(session: Session): Promise<void> {
    const ttl = Math.floor((session.expiresAt.getTime() - Date.now()) / 1000);
    await this.redis.setex(
      `${this.prefix}${session.id}`,
      ttl,
      JSON.stringify(session),
    );
  }

  async delete(id: string): Promise<void> {
    await this.redis.del(`${this.prefix}${id}`);
  }

  async touch(id: string): Promise<void> {
    const session = await this.get(id);
    if (session) {
      session.lastAccessedAt = new Date();
      session.expiresAt = new Date(Date.now() + this.ttlMs);
      await this.set(session);
    }
  }
}
```

## Middleware Express

```typescript
import { CookieOptions, Request, Response, NextFunction } from 'express';

const cookieOptions: CookieOptions = {
  httpOnly: true, // Prevent XSS access
  secure: true, // HTTPS only
  sameSite: 'strict', // CSRF protection
  maxAge: 24 * 60 * 60 * 1000, // 24h
  path: '/',
};

function sessionMiddleware(manager: SessionManager) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const sessionId = req.cookies.sessionId;

    if (sessionId) {
      const session = await manager.validate(sessionId);
      if (session) {
        req.session = session;
        req.userId = session.userId;
      }
    }

    // Helper to create session
    req.createSession = async (userId: string) => {
      const newSessionId = await manager.create(userId);
      res.cookie('sessionId', newSessionId, cookieOptions);
      return newSessionId;
    };

    // Helper to destroy session
    req.destroySession = async () => {
      if (req.session) {
        await manager.destroy(req.session.id);
        res.clearCookie('sessionId');
      }
    };

    next();
  };
}
```

## Protection contre les attaques

```typescript
class SecureSessionManager extends SessionManager {
  // Session fixation prevention
  async regenerate(oldSessionId: string): Promise<string> {
    const session = await this.store.get(oldSessionId);
    if (!session) throw new Error('Invalid session');

    // Create new session with same data
    const newSessionId = await this.create(session.userId, session.data);
    // Delete old session
    await this.destroy(oldSessionId);

    return newSessionId;
  }

  // Concurrent session limit
  async createWithLimit(userId: string, maxSessions = 3): Promise<string> {
    const userSessions = await this.store.getByUserId(userId);

    if (userSessions.length >= maxSessions) {
      // Remove oldest session
      const oldest = userSessions.sort(
        (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
      )[0];
      await this.destroy(oldest.id);
    }

    return this.create(userId);
  }

  // IP binding (optional, can cause issues with mobile)
  async validateWithIP(sessionId: string, ip: string): Promise<Session | null> {
    const session = await this.validate(sessionId);
    if (session && session.data.boundIP !== ip) {
      await this.destroy(sessionId);
      return null;
    }
    return session;
  }
}
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `express-session` | Session middleware standard |
| `connect-redis` | Store Redis pour express-session |
| `iron-session` | Session chiffree sans store |
| `cookie-session` | Session dans cookie (petites donnees) |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Session ID previsible | Session hijacking | `crypto.randomBytes(32)` |
| Pas de `httpOnly` | XSS peut voler cookie | Toujours `httpOnly: true` |
| Pas de `secure` | MITM peut intercepter | Toujours `secure: true` en prod |
| `sameSite: 'none'` | CSRF vulnerable | `strict` ou `lax` |
| Store en memoire | Perte au restart | Redis, PostgreSQL, etc. |
| Session ID dans URL | Leakage via Referer | Cookie only |

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| Application monolithique | Oui |
| Besoin de revocation instantanee | Oui |
| Multi-page apps traditionnelles | Oui |
| APIs stateless | Non (preferer JWT) |
| Microservices | Non (preferer JWT) |
| SPAs avec backend BFF | Oui |

## Patterns lies

- **JWT** : Alternative stateless
- **OAuth 2.0** : Combine souvent sessions + OAuth
- **CSRF Protection** : Necessaire avec sessions

## Sources

- [OWASP Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
- [express-session docs](https://github.com/expressjs/session)
