# Active Record

> "An object that wraps a row in a database table or view, encapsulates the database access, and adds domain logic on that data." - Martin Fowler, PoEAA

## Concept

Active Record combine les donnees et le comportement de persistance dans un seul objet. Chaque instance represente une ligne de la base de donnees et sait comment se sauvegarder, se charger et se supprimer.

## Caracteristiques

1. **Mapping 1:1** : Une classe = une table
2. **CRUD integre** : Methodes save(), find(), delete()
3. **Logique metier** : Peut contenir des validations et comportements
4. **Simplicite** : Pas de couche de mapping separee

## Implementation Go

```go
package activerecord

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"golang.org/x/crypto/bcrypt"
)

// Database is a global database connection.
var db *sql.DB

// SetDatabase sets the global database connection.
func SetDatabase(database *sql.DB) {
	db = database
}

// User is an Active Record representing a user.
type User struct {
	ID           string
	Email        string
	PasswordHash string
	Role         string
	LastLoginAt  *time.Time
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// Find loads a user by ID.
func (u *User) Find(ctx context.Context, id string) error {
	err := db.QueryRowContext(ctx,
		`SELECT id, email, password_hash, role, last_login_at, created_at, updated_at
		 FROM users WHERE id = ?`,
		id,
	).Scan(&u.ID, &u.Email, &u.PasswordHash, &u.Role, &u.LastLoginAt, &u.CreatedAt, &u.UpdatedAt)

	if err == sql.ErrNoRows {
		return fmt.Errorf("user not found")
	}
	return err
}

// FindByEmail loads a user by email.
func FindUserByEmail(ctx context.Context, email string) (*User, error) {
	user := &User{}
	err := db.QueryRowContext(ctx,
		`SELECT id, email, password_hash, role, last_login_at, created_at, updated_at
		 FROM users WHERE email = ?`,
		email,
	).Scan(&user.ID, &user.Email, &user.PasswordHash, &user.Role, &user.LastLoginAt, &user.CreatedAt, &user.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return user, nil
}

// FindAll loads all users.
func FindAllUsers(ctx context.Context) ([]*User, error) {
	rows, err := db.QueryContext(ctx,
		`SELECT id, email, password_hash, role, last_login_at, created_at, updated_at FROM users`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []*User
	for rows.Next() {
		user := &User{}
		if err := rows.Scan(&user.ID, &user.Email, &user.PasswordHash, &user.Role, &user.LastLoginAt, &user.CreatedAt, &user.UpdatedAt); err != nil {
			return nil, err
		}
		users = append(users, user)
	}

	return users, rows.Err()
}

// Save saves the user (insert or update).
func (u *User) Save(ctx context.Context) error {
	if err := u.validate(); err != nil {
		return err
	}

	if u.ID == "" {
		return u.insert(ctx)
	}
	return u.update(ctx)
}

// Delete deletes the user.
func (u *User) Delete(ctx context.Context) error {
	if u.ID == "" {
		return fmt.Errorf("cannot delete unsaved user")
	}

	_, err := db.ExecContext(ctx, `DELETE FROM users WHERE id = ?`, u.ID)
	return err
}

// SetPassword sets and hashes the password.
func (u *User) SetPassword(password string) error {
	if len(password) < 8 {
		return fmt.Errorf("password must be at least 8 characters")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}

	u.PasswordHash = string(hash)
	return nil
}

// CheckPassword verifies a password.
func (u *User) CheckPassword(password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password))
	return err == nil
}

// IsAdmin checks if the user is an admin.
func (u *User) IsAdmin() bool {
	return u.Role == "admin"
}

// RecordLogin records a login timestamp.
func (u *User) RecordLogin() {
	now := time.Now()
	u.LastLoginAt = &now
}

func (u *User) validate() error {
	if u.Email == "" || !contains(u.Email, "@") {
		return fmt.Errorf("invalid email")
	}
	if u.PasswordHash == "" {
		return fmt.Errorf("password is required")
	}
	return nil
}

func (u *User) insert(ctx context.Context) error {
	u.ID = generateID()
	now := time.Now()
	u.CreatedAt = now
	u.UpdatedAt = now

	_, err := db.ExecContext(ctx,
		`INSERT INTO users (id, email, password_hash, role, last_login_at, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		u.ID, u.Email, u.PasswordHash, u.Role, u.LastLoginAt, u.CreatedAt, u.UpdatedAt,
	)
	return err
}

func (u *User) update(ctx context.Context) error {
	u.UpdatedAt = time.Now()

	_, err := db.ExecContext(ctx,
		`UPDATE users
		 SET email = ?, password_hash = ?, role = ?, last_login_at = ?, updated_at = ?
		 WHERE id = ?`,
		u.Email, u.PasswordHash, u.Role, u.LastLoginAt, u.UpdatedAt, u.ID,
	)
	return err
}

// Post is another Active Record example.
type Post struct {
	ID        string
	Title     string
	Content   string
	AuthorID  string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// GetAuthor loads the post's author.
func (p *Post) GetAuthor(ctx context.Context) (*User, error) {
	user := &User{}
	if err := user.Find(ctx, p.AuthorID); err != nil {
		return nil, err
	}
	return user, nil
}

// GetComments loads the post's comments.
func (p *Post) GetComments(ctx context.Context) ([]*Comment, error) {
	rows, err := db.QueryContext(ctx,
		`SELECT id, post_id, content, created_at FROM comments WHERE post_id = ?`,
		p.ID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var comments []*Comment
	for rows.Next() {
		comment := &Comment{}
		if err := rows.Scan(&comment.ID, &comment.PostID, &comment.Content, &comment.CreatedAt); err != nil {
			return nil, err
		}
		comments = append(comments, comment)
	}

	return comments, rows.Err()
}

// Save saves the post.
func (p *Post) Save(ctx context.Context) error {
	if p.ID == "" {
		return p.insert(ctx)
	}
	return p.update(ctx)
}

func (p *Post) insert(ctx context.Context) error {
	p.ID = generateID()
	now := time.Now()
	p.CreatedAt = now
	p.UpdatedAt = now

	_, err := db.ExecContext(ctx,
		`INSERT INTO posts (id, title, content, author_id, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		p.ID, p.Title, p.Content, p.AuthorID, p.CreatedAt, p.UpdatedAt,
	)
	return err
}

func (p *Post) update(ctx context.Context) error {
	p.UpdatedAt = time.Now()

	_, err := db.ExecContext(ctx,
		`UPDATE posts SET title = ?, content = ?, updated_at = ? WHERE id = ?`,
		p.Title, p.Content, p.UpdatedAt, p.ID,
	)
	return err
}

// Comment represents a comment.
type Comment struct {
	ID        string
	PostID    string
	Content   string
	CreatedAt time.Time
}

// Usage example
func ExampleUsage() error {
	ctx := context.Background()

	// Create user
	user := &User{
		Email: "john@example.com",
		Role:  "user",
	}
	if err := user.SetPassword("securepassword123"); err != nil {
		return err
	}
	if err := user.Save(ctx); err != nil {
		return err
	}

	// Find and login
	found, err := FindUserByEmail(ctx, "john@example.com")
	if err != nil {
		return err
	}
	if found != nil && found.CheckPassword("securepassword123") {
		found.RecordLogin()
		if err := found.Save(ctx); err != nil {
			return err
		}
	}

	return nil
}

// Helper functions
func generateID() string {
	return fmt.Sprintf("id-%d", time.Now().UnixNano())
}

func contains(s, substr string) bool {
	for i := 0; i < len(s)-len(substr)+1; i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
```

## Comparaison avec alternatives

| Aspect | Active Record | Data Mapper | Table Gateway |
|--------|---------------|-------------|---------------|
| Couplage | Fort (DB in entity) | Faible | Moyen |
| Simplicite | Elevee | Faible | Moyenne |
| Testabilite | Moyenne | Elevee | Moyenne |
| Rich Domain | Difficile | Facile | Non applicable |
| Frameworks | Rails, Laravel, Django | Hibernate, Doctrine | - |

## Quand utiliser

**Utiliser Active Record quand :**

- Schema DB = modele objet (1:1)
- Logique metier simple a moderee
- Prototypage rapide
- Applications CRUD
- Equipe familiere avec Rails/Laravel

**Eviter Active Record quand :**

- Domain Model complexe avec invariants
- Schema DB different du modele objet
- Tests unitaires purs necessaires
- Logique metier riche

## Relation avec DDD

Active Record est **deconseille en DDD** car :

1. **Couplage fort** : L'entite connait sa persistance
2. **Testabilite reduite** : Besoin de DB pour tester
3. **Anemic tendance** : Logique migre vers services

## Frameworks populaires

| Framework | Langage | Active Record |
|-----------|---------|---------------|
| Ruby on Rails | Ruby | ActiveRecord |
| Laravel | PHP | Eloquent |
| Django | Python | ORM Models |
| GORM | Go | Active Record mode |

## Patterns liés

- [Data Mapper](./data-mapper.md) - Alternative avec separation domaine/persistance
- [Domain Model](./domain-model.md) - Alternative pour logique metier riche
- [Transaction Script](./transaction-script.md) - Alternative procedurale simple
- [Repository](./repository.md) - Abstraction de persistance pour Domain Model

## Sources

- Martin Fowler, PoEAA, Chapter 10
- [Active Record - martinfowler.com](https://martinfowler.com/eaaCatalog/activeRecord.html)
- Rails Guides - Active Record Basics
