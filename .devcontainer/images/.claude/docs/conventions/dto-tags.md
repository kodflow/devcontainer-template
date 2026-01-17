# Convention DTO Tags

> Tag `dto:` pour le groupement de structs DTO dans un meme fichier (exception KTN-STRUCT-ONEFILE).

## Objectif Principal

Le tag `dto:` signale au **KTN-Linter** que les structs marquees sont des DTOs
et doivent etre **exemptees de KTN-STRUCT-ONEFILE**.

```yaml
comportement:
  sans_dto_tag: "Une struct par fichier (regle standard)"
  avec_dto_tag: "Plusieurs structs DTO groupees dans un fichier (exception)"

exemple:
  fichier: "user_dto.go"
  contenu: "CreateUserRequest, UpdateUserRequest, UserResponse, etc."
```

## Format du Tag

```go
dto:"<direction>,<context>,<security>"
```

| Position | Valeurs | Description |
|----------|---------|-------------|
| **direction** | `in`, `out`, `inout` | Sens du flux de donnees |
| **context** | `api`, `cmd`, `query`, `event`, `msg`, `priv` | Type de DTO |
| **security** | `pub`, `priv`, `pii`, `secret` | Classification securite |

## Valeurs

### Direction

| Valeur | Usage | Exemple |
|--------|-------|---------|
| `in` | Donnees entrantes | Request, Command input |
| `out` | Donnees sortantes | Response, Query result |
| `inout` | Bidirectionnel | Update, Patch |

### Context

| Valeur | Usage | Exemple |
|--------|-------|---------|
| `api` | API REST/GraphQL | CreateUserRequest |
| `cmd` | Commande CQRS | TransferMoneyCommand |
| `query` | Requete CQRS | GetOrderQuery |
| `event` | Event sourcing | UserCreatedEvent |
| `msg` | Message broker | OrderPayload |
| `priv` | Interne | ServiceDTO |

### Security

| Valeur | Usage | Logging | Marshaling |
|--------|-------|---------|------------|
| `pub` | Donnees publiques | Affiche | Inclus |
| `priv` | Interne (IDs, timestamps) | Affiche | Inclus |
| `pii` | RGPD (email, nom) | Masque | Conditionnel |
| `secret` | Credentials | REDACTED | Omis |

## Exemples Go

```go
// Fichier: user_dto.go
// PLUSIEURS DTOs groupes grace au tag dto:

// API Request
type CreateUserRequest struct {
    Username string `dto:"in,api,pub" json:"username" validate:"required"`
    Email    string `dto:"in,api,pii" json:"email" validate:"required,email"`
    Password string `dto:"in,api,secret" json:"password" validate:"required,min=8"`
}

// API Response
type UserResponse struct {
    ID        string    `dto:"out,api,pub" json:"id"`
    Username  string    `dto:"out,api,pub" json:"username"`
    Email     string    `dto:"out,api,pii" json:"email"`
    CreatedAt time.Time `dto:"out,api,pub" json:"createdAt"`
}

// CQRS Command
type UpdateUserCommand struct {
    UserID   string `dto:"in,cmd,priv" json:"userId"`
    Email    string `dto:"in,cmd,pii" json:"email,omitempty"`
    Username string `dto:"in,cmd,pub" json:"username,omitempty"`
}

// Event
type UserCreatedEvent struct {
    UserID    string    `dto:"out,event,pub" json:"userId"`
    Email     string    `dto:"out,event,pii" json:"email"`
    CreatedAt time.Time `dto:"out,event,pub" json:"createdAt"`
}
```

## Guide de Decision

```text
1. DIRECTION: D'ou viennent les donnees?
   - Entree utilisateur/client → in
   - Sortie vers utilisateur/client → out
   - Les deux (update/patch) → inout

2. CONTEXT: Ou est utilise ce DTO?
   - API REST/GraphQL externe → api
   - Commande CQRS (write) → cmd
   - Query CQRS (read) → query
   - Event sourcing/messaging → event
   - Queue/Message broker → msg
   - Interne entre services → priv

3. SECURITY: Quelle sensibilite pour CE CHAMP?
   - Peut etre public (nom produit, status) → pub
   - Interne non sensible (IDs, timestamps) → priv
   - Donnees personnelles RGPD (email, nom) → pii
   - Secret (password, token, cle API) → secret
```

## Matrice de Reference

| Type de Champ | Direction | Context | Security | Tag |
|---------------|-----------|---------|----------|-----|
| Username (creation) | in | api | pub | `dto:"in,api,pub"` |
| Email (creation) | in | api | pii | `dto:"in,api,pii"` |
| Password | in | api | secret | `dto:"in,api,secret"` |
| User ID (reponse) | out | api | pub | `dto:"out,api,pub"` |
| API Key | in | priv | secret | `dto:"in,priv,secret"` |
| Order Total | out | query | pub | `dto:"out,query,pub"` |
| Event Timestamp | out | event | pub | `dto:"out,event,pub"` |
| Customer Address | inout | api | pii | `dto:"inout,api,pii"` |

## Suffixes Reconnus

Le linter detecte automatiquement les DTOs par ces suffixes :

```text
Request, Response, DTO, Input, Output,
Payload, Message, Event, Command, Query, Params
```

## Regles Linter

| Regle | Comportement DTOs |
|-------|-------------------|
| KTN-STRUCT-ONEFILE | **Exempte** - DTOs groupables |
| KTN-STRUCT-CTOR | **Exempte** - Pas de constructeur requis |
| KTN-DTO-TAG | **Valide** format `dto:"dir,ctx,sec"` |
| KTN-STRUCT-JSONTAG | **Valide** tags serialisation |
| KTN-STRUCT-PRIVTAG | **Interdit** tags sur champs prives |

## FAQ

**Q: Pourquoi le tag dto: est-il obligatoire?**
A: Pour que le linter sache que ces structs peuvent etre groupees (exception KTN-STRUCT-ONEFILE).

**Q: Puis-je avoir plusieurs DTOs dans un meme fichier?**
A: OUI, c'est le but! Groupez-les par domaine: `user_dto.go`, `order_dto.go`.

**Q: Difference entre priv (security) et priv (context)?**
A: Context priv = DTO interne. Security priv = Champ non sensible mais pas public.

**Q: Comment choisir entre pii et secret?**
A: pii = Donnees personnelles RGPD. secret = Credentials (JAMAIS exposes).

## Patterns Lies

- [DTO Pattern](../enterprise/dto.md)
- [CQRS](../architectural/cqrs.md)
- [Messaging Patterns](../messaging/README.md)
