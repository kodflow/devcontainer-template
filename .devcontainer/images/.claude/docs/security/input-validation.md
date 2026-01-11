# Input Validation & Sanitization

> Valider et nettoyer toutes les entrees utilisateur pour prevenir les injections.

## Principe

```
┌──────────────────────────────────────────────────────────────┐
│                    Input Processing Pipeline                  │
│                                                               │
│   Raw Input ──► Validation ──► Sanitization ──► Safe Input   │
│                     │              │                          │
│                     ▼              ▼                          │
│               Reject if       Remove/Escape                   │
│               invalid         dangerous chars                 │
└──────────────────────────────────────────────────────────────┘
```

## Schema Validation avec Zod

```typescript
import { z } from 'zod';

// User registration schema
const userSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z
    .string()
    .min(12, 'Password must be at least 12 characters')
    .max(100, 'Password too long')
    .regex(/[A-Z]/, 'Must contain uppercase')
    .regex(/[a-z]/, 'Must contain lowercase')
    .regex(/[0-9]/, 'Must contain number')
    .regex(/[!@#$%^&*]/, 'Must contain special character'),
  name: z
    .string()
    .min(2, 'Name too short')
    .max(50, 'Name too long')
    .regex(/^[a-zA-Z\s'-]+$/, 'Name contains invalid characters'),
  age: z.number().int().min(0).max(150).optional(),
  website: z.string().url().optional(),
});

// Article schema with transformations
const articleSchema = z.object({
  title: z
    .string()
    .min(1)
    .max(200)
    .transform((s) => s.trim()),
  slug: z
    .string()
    .regex(/^[a-z0-9-]+$/, 'Slug must be lowercase alphanumeric with hyphens'),
  content: z.string().min(10).max(50000),
  tags: z.array(z.string().max(30)).max(10),
  publishAt: z.coerce.date().optional(),
});

// Validation function
function validate<T>(schema: z.ZodSchema<T>, data: unknown): T {
  const result = schema.safeParse(data);

  if (!result.success) {
    const errors = result.error.issues.map((issue) => ({
      path: issue.path.join('.'),
      message: issue.message,
    }));
    throw new ValidationError(errors);
  }

  return result.data;
}

// Usage in Express
const createUser = async (req: Request, res: Response) => {
  try {
    const userData = validate(userSchema, req.body);
    // userData is now typed and validated
    const user = await userService.create(userData);
    res.status(201).json(user);
  } catch (error) {
    if (error instanceof ValidationError) {
      return res.status(400).json({ errors: error.errors });
    }
    throw error;
  }
};
```

## Sanitization

```typescript
import DOMPurify from 'isomorphic-dompurify';

class Sanitizer {
  // HTML/XSS prevention
  static html(input: string): string {
    return DOMPurify.sanitize(input, {
      ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
      ALLOWED_ATTR: ['href'],
    });
  }

  // Plain text - escape HTML entities
  static escapeHtml(input: string): string {
    return input
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // SQL - use parameterized queries instead!
  // This is for display/logging only
  static escapeSql(input: string): string {
    return input.replace(/'/g, "''");
  }

  // Path traversal prevention
  static sanitizePath(input: string): string {
    return input
      .replace(/\.\./g, '') // Remove ..
      .replace(/^\/+/, '') // Remove leading /
      .replace(/[<>:"|?*]/g, ''); // Remove illegal chars
  }

  // Filename sanitization
  static sanitizeFilename(input: string): string {
    return input
      .replace(/[^a-zA-Z0-9._-]/g, '_')
      .replace(/\.{2,}/g, '.')
      .substring(0, 255);
  }

  // Shell command arguments - escape for safety
  static escapeShell(input: string): string {
    return `'${input.replace(/'/g, "'\\''")}'`;
  }

  // URL sanitization
  static sanitizeUrl(input: string): string | null {
    try {
      const url = new URL(input);
      // Only allow http/https
      if (!['http:', 'https:'].includes(url.protocol)) {
        return null;
      }
      return url.toString();
    } catch {
      return null;
    }
  }
}
```

## SQL Injection Prevention

```typescript
// NEVER do this
async function badQuery(email: string) {
  return db.query(`SELECT * FROM users WHERE email = '${email}'`);
  // Vulnerable to: ' OR '1'='1
}

// ALWAYS use parameterized queries
async function goodQuery(email: string) {
  return db.query('SELECT * FROM users WHERE email = $1', [email]);
}

// With query builder (Knex)
async function findUsers(filters: { email?: string; role?: string }) {
  let query = knex('users');

  if (filters.email) {
    query = query.where('email', filters.email); // Safe
  }
  if (filters.role) {
    query = query.where('role', filters.role); // Safe
  }

  return query;
}

// With ORM (Prisma)
async function findUser(email: string) {
  return prisma.user.findUnique({
    where: { email }, // Safe - Prisma handles escaping
  });
}
```

## XSS Prevention

```typescript
// React - automatic escaping
function UserProfile({ user }: { user: User }) {
  return (
    <div>
      {/* Safe - React escapes by default */}
      <h1>{user.name}</h1>

      {/* Dangerous - avoid dangerouslySetInnerHTML */}
      <div dangerouslySetInnerHTML={{ __html: user.bio }} />

      {/* Safe - sanitize if HTML is needed */}
      <div
        dangerouslySetInnerHTML={{
          __html: DOMPurify.sanitize(user.bio),
        }}
      />
    </div>
  );
}

// Server-side rendering - always escape
import { escape } from 'html-escaper';

function renderTemplate(user: User): string {
  return `
    <div class="profile">
      <h1>${escape(user.name)}</h1>
      <p>${escape(user.bio)}</p>
    </div>
  `;
}
```

## Request Validation Middleware

```typescript
import { z } from 'zod';

function validateBody<T>(schema: z.ZodSchema<T>) {
  return (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);

    if (!result.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: result.error.issues,
      });
    }

    req.body = result.data;
    next();
  };
}

function validateParams<T>(schema: z.ZodSchema<T>) {
  return (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.params);

    if (!result.success) {
      return res.status(400).json({
        error: 'Invalid parameters',
        details: result.error.issues,
      });
    }

    req.params = result.data as any;
    next();
  };
}

// Usage
const idParamSchema = z.object({
  id: z.string().uuid(),
});

router.get('/users/:id', validateParams(idParamSchema), getUser);
router.post('/users', validateBody(userSchema), createUser);
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `zod` | Schema validation (TypeScript-first) |
| `joi` | Schema validation (runtime) |
| `class-validator` | Decorator-based validation |
| `dompurify` | HTML sanitization |
| `validator` | String validation utilities |
| `xss` | XSS filter |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Validation cote client seulement | Bypass facile | Toujours valider serveur |
| Blacklist au lieu de whitelist | Bypass possible | Whitelist stricte |
| Sanitize sans valider | Donnees corrompues | Valider puis sanitizer |
| Echapper trop tard | Injection avant escape | Echapper a la sortie |
| Trust Content-Type | Body parsing attack | Verifier et valider |

## Quand utiliser

| Technique | Quand |
|-----------|-------|
| Schema validation | Toute entree structuree |
| HTML sanitization | Contenu HTML utilisateur |
| SQL parameterization | TOUJOURS pour SQL |
| Path sanitization | Upload, file access |
| URL validation | Liens utilisateur |

## Patterns lies

- **CSRF Protection** : Valider origine des requetes
- **Rate Limiting** : Limiter abuse
- **Content Security Policy** : Defense XSS supplementaire

## Sources

- [OWASP Input Validation](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)
- [OWASP XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
