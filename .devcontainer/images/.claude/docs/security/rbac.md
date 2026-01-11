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

## Implementation Go

```go
package rbac

// Role represents a user role.
type Role string

const (
	RoleAdmin     Role = "admin"
	RoleEditor    Role = "editor"
	RoleViewer    Role = "viewer"
	RoleModerator Role = "moderator"
)

// Permission represents an action permission.
type Permission string

const (
	PermCreate   Permission = "create"
	PermRead     Permission = "read"
	PermUpdate   Permission = "update"
	PermDelete   Permission = "delete"
	PermPublish  Permission = "publish"
	PermModerate Permission = "moderate"
)

// Resource represents a resource type.
type Resource string

const (
	ResourceArticles  Resource = "articles"
	ResourceUsers     Resource = "users"
	ResourceComments  Resource = "comments"
	ResourceSettings  Resource = "settings"
)

// rolePermissions maps roles to their permissions per resource.
var rolePermissions = map[Role]map[Resource][]Permission{
	RoleAdmin: {
		ResourceArticles:  {PermCreate, PermRead, PermUpdate, PermDelete, PermPublish},
		ResourceUsers:     {PermCreate, PermRead, PermUpdate, PermDelete},
		ResourceComments:  {PermCreate, PermRead, PermUpdate, PermDelete, PermModerate},
		ResourceSettings:  {PermRead, PermUpdate},
	},
	RoleEditor: {
		ResourceArticles: {PermCreate, PermRead, PermUpdate, PermPublish},
		ResourceUsers:    {PermRead},
		ResourceComments: {PermCreate, PermRead, PermUpdate},
		ResourceSettings: {},
	},
	RoleViewer: {
		ResourceArticles: {PermRead},
		ResourceUsers:    {},
		ResourceComments: {PermCreate, PermRead},
		ResourceSettings: {},
	},
	RoleModerator: {
		ResourceArticles: {PermRead},
		ResourceUsers:    {PermRead},
		ResourceComments: {PermRead, PermDelete, PermModerate},
		ResourceSettings: {},
	},
}

// RBAC provides role-based access control.
type RBAC struct{}

// NewRBAC creates a new RBAC instance.
func NewRBAC() *RBAC {
	return &RBAC{}
}

// HasPermission checks if a role has a permission on a resource.
func (r *RBAC) HasPermission(role Role, resource Resource, permission Permission) bool {
	permissions, ok := rolePermissions[role][resource]
	if !ok {
		return false
	}

	for _, p := range permissions {
		if p == permission {
			return true
		}
	}

	return false
}

// GetPermissions returns all permissions for a role on a resource.
func (r *RBAC) GetPermissions(role Role, resource Resource) []Permission {
	return rolePermissions[role][resource]
}

// GetAllPermissions returns all permissions for a role.
func (r *RBAC) GetAllPermissions(role Role) map[Resource][]Permission {
	return rolePermissions[role]
}
```

## Hierarchie de roles

```go
package rbac

// roleHierarchy defines role inheritance.
var roleHierarchy = map[Role][]Role{
	RoleAdmin:     {RoleEditor, RoleViewer, RoleModerator},
	RoleEditor:    {RoleViewer},
	RoleViewer:    {},
	RoleModerator: {RoleViewer},
}

// HierarchicalRBAC extends RBAC with role hierarchy.
type HierarchicalRBAC struct {
	*RBAC
}

// NewHierarchicalRBAC creates a new hierarchical RBAC.
func NewHierarchicalRBAC() *HierarchicalRBAC {
	return &HierarchicalRBAC{
		RBAC: NewRBAC(),
	}
}

// getInheritedRoles returns all roles inherited by a role.
func (h *HierarchicalRBAC) getInheritedRoles(role Role) []Role {
	inherited := map[Role]bool{role: true}
	queue := []Role{role}

	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]

		parents := roleHierarchy[current]
		for _, parent := range parents {
			if !inherited[parent] {
				inherited[parent] = true
				queue = append(queue, parent)
			}
		}
	}

	result := make([]Role, 0, len(inherited))
	for r := range inherited {
		result = append(result, r)
	}

	return result
}

// HasPermission checks permission with role inheritance.
func (h *HierarchicalRBAC) HasPermission(role Role, resource Resource, permission Permission) bool {
	roles := h.getInheritedRoles(role)
	for _, r := range roles {
		if h.RBAC.HasPermission(r, resource, permission) {
			return true
		}
	}
	return false
}
```

## Middleware HTTP

```go
package middleware

import (
	"fmt"
	"net/http"
)

// User represents an authenticated user.
type User struct {
	ID   string
	Role rbac.Role
}

// Authorize returns a middleware that checks RBAC permissions.
func Authorize(resource rbac.Resource, permission rbac.Permission) func(http.Handler) http.Handler {
	rbacEngine := rbac.NewHierarchicalRBAC()

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			user := GetUser(r.Context())
			if user == nil {
				http.Error(w, "Not authenticated", http.StatusUnauthorized)
				return
			}

			if !rbacEngine.HasPermission(user.Role, resource, permission) {
				w.WriteHeader(http.StatusForbidden)
				fmt.Fprintf(w, `{
					"error": "Forbidden",
					"required": {"resource": "%s", "permission": "%s"},
					"userRole": "%s"
				}`, resource, permission, user.Role)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// Usage example
func SetupRoutes(mux *http.ServeMux) {
	mux.Handle("/articles", 
		Authorize(rbac.ResourceArticles, rbac.PermRead)(http.HandlerFunc(listArticles)))
	mux.Handle("/articles/create", 
		Authorize(rbac.ResourceArticles, rbac.PermCreate)(http.HandlerFunc(createArticle)))
	mux.Handle("/articles/update", 
		Authorize(rbac.ResourceArticles, rbac.PermUpdate)(http.HandlerFunc(updateArticle)))
	mux.Handle("/articles/delete", 
		Authorize(rbac.ResourceArticles, rbac.PermDelete)(http.HandlerFunc(deleteArticle)))
}
```

## Database Model

```go
package rbac

import (
	"context"
	"database/sql"
	"fmt"
)

// Permission represents a database permission.
type DBPermission struct {
	ID       string
	Name     string
	Resource string
	Action   string
}

// DBRole represents a database role.
type DBRole struct {
	ID          string
	Name        string
	Permissions []DBPermission
}

// DBUser represents a database user.
type DBUser struct {
	ID    string
	Roles []DBRole
}

// DatabaseRBAC provides database-backed RBAC.
type DatabaseRBAC struct {
	db *sql.DB
}

// NewDatabaseRBAC creates a new database-backed RBAC.
func NewDatabaseRBAC(db *sql.DB) *DatabaseRBAC {
	return &DatabaseRBAC{db: db}
}

// HasPermission checks if a user has a permission.
func (d *DatabaseRBAC) HasPermission(ctx context.Context, userID, resource, action string) (bool, error) {
	query := `
		SELECT 1 FROM user_roles ur
		JOIN role_permissions rp ON ur.role_id = rp.role_id
		JOIN permissions p ON rp.permission_id = p.id
		WHERE ur.user_id = $1
			AND p.resource = $2
			AND p.action = $3
		LIMIT 1
	`

	var exists int
	err := d.db.QueryRowContext(ctx, query, userID, resource, action).Scan(&exists)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("querying permission: %w", err)
	}

	return true, nil
}

// GetUserPermissions retrieves all permissions for a user.
func (d *DatabaseRBAC) GetUserPermissions(ctx context.Context, userID string) ([]DBPermission, error) {
	query := `
		SELECT DISTINCT p.id, p.name, p.resource, p.action
		FROM permissions p
		JOIN role_permissions rp ON p.id = rp.permission_id
		JOIN user_roles ur ON rp.role_id = ur.role_id
		WHERE ur.user_id = $1
	`

	rows, err := d.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("querying permissions: %w", err)
	}
	defer rows.Close()

	var permissions []DBPermission
	for rows.Next() {
		var p DBPermission
		if err := rows.Scan(&p.ID, &p.Name, &p.Resource, &p.Action); err != nil {
			return nil, fmt.Errorf("scanning permission: %w", err)
		}
		permissions = append(permissions, p)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating permissions: %w", err)
	}

	return permissions, nil
}
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `github.com/casbin/casbin/v2` | RBAC/ABAC flexible |
| `github.com/ory/ladon` | Access control policies |

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
