# Attribute-Based Access Control (ABAC)

> Permissions dynamiques basees sur attributs du sujet, ressource et contexte.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                         ABAC Decision                           │
│                                                                  │
│   Subject Attributes    Resource Attributes    Environment      │
│   ├── role: editor      ├── owner: user123     ├── time: 14:30 │
│   ├── dept: marketing   ├── status: draft      ├── ip: internal│
│   └── level: senior     └── sensitivity: low   └── device: corp│
│              │                    │                    │        │
│              └────────────────────┼────────────────────┘        │
│                                   ▼                              │
│                        ┌──────────────────┐                     │
│                        │  Policy Engine   │                     │
│                        │                  │                     │
│                        │  IF conditions   │                     │
│                        │  THEN allow/deny │                     │
│                        └────────┬─────────┘                     │
│                                 ▼                                │
│                         ALLOW or DENY                           │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation TypeScript

```typescript
interface Subject {
  id: string;
  role: string;
  department: string;
  level: 'junior' | 'senior' | 'lead';
  teams: string[];
}

interface Resource {
  id: string;
  type: string;
  ownerId: string;
  department: string;
  sensitivity: 'public' | 'internal' | 'confidential' | 'secret';
  status: 'draft' | 'published' | 'archived';
}

interface Environment {
  time: Date;
  ip: string;
  isWorkHours: boolean;
  isInternalNetwork: boolean;
  deviceType: 'corporate' | 'personal' | 'unknown';
}

interface AccessRequest {
  subject: Subject;
  resource: Resource;
  action: string;
  environment: Environment;
}

type Operator = 'eq' | 'neq' | 'in' | 'contains' | 'gt' | 'lt' | 'between';

interface Condition {
  attribute: string;
  operator: Operator;
  value: any;
}

interface Policy {
  id: string;
  name: string;
  description: string;
  effect: 'allow' | 'deny';
  actions: string[];
  conditions: Condition[];
  priority: number;
}

class ABACEngine {
  constructor(private policies: Policy[]) {
    // Sort by priority (lower = higher priority)
    this.policies.sort((a, b) => a.priority - b.priority);
  }

  evaluate(request: AccessRequest): { allowed: boolean; reason: string } {
    for (const policy of this.policies) {
      if (!policy.actions.includes(request.action) && !policy.actions.includes('*')) {
        continue;
      }

      const matches = policy.conditions.every((cond) =>
        this.evaluateCondition(cond, request),
      );

      if (matches) {
        return {
          allowed: policy.effect === 'allow',
          reason: `Policy "${policy.name}" matched`,
        };
      }
    }

    return { allowed: false, reason: 'No matching policy (default deny)' };
  }

  private evaluateCondition(condition: Condition, request: AccessRequest): boolean {
    const value = this.getAttribute(condition.attribute, request);

    switch (condition.operator) {
      case 'eq':
        return value === condition.value;
      case 'neq':
        return value !== condition.value;
      case 'in':
        return condition.value.includes(value);
      case 'contains':
        return Array.isArray(value) && value.includes(condition.value);
      case 'gt':
        return value > condition.value;
      case 'lt':
        return value < condition.value;
      case 'between':
        return value >= condition.value[0] && value <= condition.value[1];
      default:
        return false;
    }
  }

  private getAttribute(path: string, request: AccessRequest): any {
    const [type, ...rest] = path.split('.');
    const obj = request[type as keyof AccessRequest];
    return rest.reduce((o: any, k) => o?.[k], obj);
  }
}
```

## Policies exemples

```typescript
const policies: Policy[] = [
  // Deny all access to secret documents from personal devices
  {
    id: 'deny-secret-personal',
    name: 'Block secret access from personal devices',
    description: 'Secret documents only accessible from corporate devices',
    effect: 'deny',
    actions: ['*'],
    conditions: [
      { attribute: 'resource.sensitivity', operator: 'eq', value: 'secret' },
      { attribute: 'environment.deviceType', operator: 'eq', value: 'personal' },
    ],
    priority: 1,
  },

  // Allow owners to access their own resources
  {
    id: 'owner-access',
    name: 'Owner full access',
    description: 'Resource owners have full access',
    effect: 'allow',
    actions: ['read', 'update', 'delete'],
    conditions: [
      { attribute: 'resource.ownerId', operator: 'eq', value: '$subject.id' },
    ],
    priority: 10,
  },

  // Allow same department read access
  {
    id: 'dept-read',
    name: 'Department read access',
    description: 'Users can read resources from their department',
    effect: 'allow',
    actions: ['read'],
    conditions: [
      { attribute: 'subject.department', operator: 'eq', value: '$resource.department' },
      { attribute: 'resource.sensitivity', operator: 'in', value: ['public', 'internal'] },
    ],
    priority: 20,
  },

  // Senior employees can access confidential during work hours
  {
    id: 'senior-confidential',
    name: 'Senior confidential access',
    description: 'Senior employees can access confidential during work hours',
    effect: 'allow',
    actions: ['read'],
    conditions: [
      { attribute: 'subject.level', operator: 'in', value: ['senior', 'lead'] },
      { attribute: 'resource.sensitivity', operator: 'eq', value: 'confidential' },
      { attribute: 'environment.isWorkHours', operator: 'eq', value: true },
      { attribute: 'environment.isInternalNetwork', operator: 'eq', value: true },
    ],
    priority: 30,
  },
];
```

## Dynamic attribute resolution

```typescript
class DynamicABACEngine extends ABACEngine {
  private resolvers: Map<string, (request: AccessRequest) => any> = new Map();

  registerResolver(attribute: string, resolver: (request: AccessRequest) => any) {
    this.resolvers.set(attribute, resolver);
  }

  protected getAttribute(path: string, request: AccessRequest): any {
    // Check for dynamic resolvers
    const resolver = this.resolvers.get(path);
    if (resolver) {
      return resolver(request);
    }

    // Check for variable references ($subject.id)
    const value = super.getAttribute(path, request);
    if (typeof value === 'string' && value.startsWith('$')) {
      return super.getAttribute(value.slice(1), request);
    }

    return value;
  }
}

// Usage
const engine = new DynamicABACEngine(policies);

// Dynamic resolver for team membership
engine.registerResolver('subject.isTeamMember', (request) => {
  return request.subject.teams.includes(request.resource.teamId);
});
```

## Middleware Express

```typescript
function abacMiddleware(engine: ABACEngine) {
  return (resource: string, action: string) => {
    return async (req: Request, res: Response, next: NextFunction) => {
      const request: AccessRequest = {
        subject: req.user,
        resource: req.resource, // Loaded by previous middleware
        action,
        environment: {
          time: new Date(),
          ip: req.ip,
          isWorkHours: isWorkHours(new Date()),
          isInternalNetwork: isInternalIP(req.ip),
          deviceType: getDeviceType(req),
        },
      };

      const { allowed, reason } = engine.evaluate(request);

      if (!allowed) {
        return res.status(403).json({
          error: 'Access denied',
          reason,
        });
      }

      next();
    };
  };
}
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `casbin` | Policy engine flexible |
| `@casl/ability` | Permissions isomorphiques |
| `oso` | Policy as code (Polar) |
| `open-policy-agent` | OPA (Rego language) |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Policies trop complexes | Maintenance difficile | Decomposer, documenter |
| Pas de default deny | Security hole | Toujours default deny |
| Evaluation lente | Performance | Cache, indexation |
| Policies contradictoires | Comportement imprevisible | Priorites claires |
| Pas d'audit | Compliance issues | Logger toutes decisions |

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| Permissions contextuelles | Oui |
| Multi-tenant complexe | Oui |
| Compliance (GDPR, HIPAA) | Oui |
| Regles dynamiques | Oui |
| Permissions simples | Non (RBAC suffit) |
| Haute performance requise | Avec prudence (cache) |

## Patterns lies

- **RBAC** : ABAC peut inclure le role comme attribut
- **Policy-Based** : Syntaxe declarative pour policies
- **JWT** : Transporter attributs dans claims

## Sources

- [NIST ABAC Guide](https://nvlpubs.nist.gov/nistpubs/specialpublications/NIST.SP.800-162.pdf)
- [XACML Standard](http://docs.oasis-open.org/xacml/3.0/xacml-3.0-core-spec-os-en.html)
