# Role-Based Access Control (RBAC)

> Permissions basees sur les roles assignes aux utilisateurs.

## Principe

```
┌──────────────────────────────────────────────────────────────┐
│                         RBAC Model                            │
│                                                               │
│   User ──────► Role ──────► Permission ──────► Resource      │
│                                                               │
│   Alice ──────► Admin ─────► create, read,  ──► /articles   │
│                              update, delete                   │
│                                                               │
│   Bob ────────► Editor ────► create, read,  ──► /articles   │
│                              update                           │
│                                                               │
│   Carol ──────► Viewer ────► read           ──► /articles   │
└──────────────────────────────────────────────────────────────┘
```

## Implementation TypeScript

```typescript
type Role = 'admin' | 'editor' | 'viewer' | 'moderator';
type Permission = 'create' | 'read' | 'update' | 'delete' | 'publish' | 'moderate';
type Resource = 'articles' | 'users' | 'comments' | 'settings';

// Role-Permission mapping
const rolePermissions: Record<Role, Record<Resource, Permission[]>> = {
  admin: {
    articles: ['create', 'read', 'update', 'delete', 'publish'],
    users: ['create', 'read', 'update', 'delete'],
    comments: ['create', 'read', 'update', 'delete', 'moderate'],
    settings: ['read', 'update'],
  },
  editor: {
    articles: ['create', 'read', 'update', 'publish'],
    users: ['read'],
    comments: ['create', 'read', 'update'],
    settings: [],
  },
  viewer: {
    articles: ['read'],
    users: [],
    comments: ['create', 'read'],
    settings: [],
  },
  moderator: {
    articles: ['read'],
    users: ['read'],
    comments: ['read', 'delete', 'moderate'],
    settings: [],
  },
};

class RBAC {
  hasPermission(role: Role, resource: Resource, permission: Permission): boolean {
    const permissions = rolePermissions[role]?.[resource] || [];
    return permissions.includes(permission);
  }

  getPermissions(role: Role, resource: Resource): Permission[] {
    return rolePermissions[role]?.[resource] || [];
  }

  getAllPermissions(role: Role): Record<Resource, Permission[]> {
    return rolePermissions[role] || {};
  }
}
```

## Hierarchie de roles

```typescript
// Role hierarchy - higher roles inherit lower permissions
const roleHierarchy: Record<Role, Role[]> = {
  admin: ['editor', 'viewer', 'moderator'],
  editor: ['viewer'],
  viewer: [],
  moderator: ['viewer'],
};

class HierarchicalRBAC extends RBAC {
  private getInheritedRoles(role: Role): Role[] {
    const inherited = new Set<Role>([role]);
    const queue = [role];

    while (queue.length > 0) {
      const current = queue.shift()!;
      const parents = roleHierarchy[current] || [];

      for (const parent of parents) {
        if (!inherited.has(parent)) {
          inherited.add(parent);
          queue.push(parent);
        }
      }
    }

    return [...inherited];
  }

  hasPermission(role: Role, resource: Resource, permission: Permission): boolean {
    const roles = this.getInheritedRoles(role);
    return roles.some((r) => super.hasPermission(r, resource, permission));
  }
}
```

## Middleware Express

```typescript
function authorize(resource: Resource, permission: Permission) {
  return (req: Request, res: Response, next: NextFunction) => {
    const user = req.user;

    if (!user) {
      return res.status(401).json({ error: 'Not authenticated' });
    }

    const rbac = new HierarchicalRBAC();

    if (!rbac.hasPermission(user.role, resource, permission)) {
      return res.status(403).json({
        error: 'Forbidden',
        required: { resource, permission },
        userRole: user.role,
      });
    }

    next();
  };
}

// Usage
const router = express.Router();

router.get('/articles', authorize('articles', 'read'), listArticles);
router.post('/articles', authorize('articles', 'create'), createArticle);
router.put('/articles/:id', authorize('articles', 'update'), updateArticle);
router.delete('/articles/:id', authorize('articles', 'delete'), deleteArticle);
```

## Decorators (NestJS style)

```typescript
// Permission decorator
function RequirePermission(resource: Resource, permission: Permission) {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      const req = args[0];
      const rbac = new RBAC();

      if (!rbac.hasPermission(req.user.role, resource, permission)) {
        throw new ForbiddenError(
          `Requires ${permission} permission on ${resource}`,
        );
      }

      return originalMethod.apply(this, args);
    };
  };
}

// Role decorator
function RequireRole(...roles: Role[]) {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      const req = args[0];

      if (!roles.includes(req.user.role)) {
        throw new ForbiddenError(`Requires one of roles: ${roles.join(', ')}`);
      }

      return originalMethod.apply(this, args);
    };
  };
}

// Usage
class ArticleController {
  @RequirePermission('articles', 'create')
  async create(req: Request) {
    // Only users with 'create' permission on 'articles'
  }

  @RequireRole('admin', 'editor')
  async publish(req: Request) {
    // Only admin or editor roles
  }
}
```

## Database Model

```typescript
// Flexible RBAC with database
interface Permission {
  id: string;
  name: string;
  resource: string;
  action: string;
}

interface Role {
  id: string;
  name: string;
  permissions: Permission[];
}

interface User {
  id: string;
  roles: Role[];
}

class DatabaseRBAC {
  async hasPermission(
    userId: string,
    resource: string,
    action: string,
  ): Promise<boolean> {
    const result = await this.db.query(
      `
      SELECT 1 FROM user_roles ur
      JOIN role_permissions rp ON ur.role_id = rp.role_id
      JOIN permissions p ON rp.permission_id = p.id
      WHERE ur.user_id = $1
        AND p.resource = $2
        AND p.action = $3
      LIMIT 1
    `,
      [userId, resource, action],
    );

    return result.rowCount > 0;
  }

  async getUserPermissions(userId: string): Promise<Permission[]> {
    const result = await this.db.query(
      `
      SELECT DISTINCT p.* FROM permissions p
      JOIN role_permissions rp ON p.id = rp.permission_id
      JOIN user_roles ur ON rp.role_id = ur.role_id
      WHERE ur.user_id = $1
    `,
      [userId],
    );

    return result.rows;
  }
}
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `casbin` | RBAC/ABAC flexible |
| `accesscontrol` | RBAC simple Node.js |
| `@casl/ability` | Permissions isomorphiques |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Role explosion | Maintenance difficile | Hierarchie + permissions granulaires |
| Hardcoded roles | Inflexible | Store en DB |
| Check role au lieu de permission | Couplage fort | Toujours checker permissions |
| Pas de separation resource/action | Granularite insuffisante | resource:action pattern |
| Roles par feature | Explosion combinatoire | Roles par responsabilite |

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| Applications avec roles clairs | Oui |
| Backoffice/Admin panels | Oui |
| Multi-tenant simple | Oui |
| Permissions tres granulaires | Non (preferer ABAC) |
| Permissions contextuelles | Non (preferer ABAC) |

## Patterns lies

- **ABAC** : Extension avec attributs et contexte
- **JWT** : Role souvent dans claims
- **Policy-Based** : Declaratif, plus flexible

## Sources

- [NIST RBAC](https://csrc.nist.gov/projects/role-based-access-control)
- [OWASP Access Control](https://owasp.org/www-community/Access_Control)
