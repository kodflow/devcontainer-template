# Branch by Abstraction

Pattern pour remplacer progressivement une implémentation par une autre sans branches Git longues.

---

## Qu'est-ce que Branch by Abstraction ?

> Technique de refactoring permettant de faire des changements majeurs sur trunk/main de manière incrémentale et sûre.

```
┌─────────────────────────────────────────────────────────────┐
│                    Branch by Abstraction                     │
│                                                              │
│  1. Créer abstraction    2. Migrer clients    3. Supprimer  │
│                                                              │
│  ┌─────┐                 ┌─────┐              ┌─────┐       │
│  │Old  │ ──abstract──►   │Old  │    ──►       │     │       │
│  │Impl │                 │Impl │              │New  │       │
│  └─────┘                 └──┬──┘              │Impl │       │
│                             │                 └─────┘       │
│                          ┌──┴──┐                            │
│                          │New  │                            │
│                          │Impl │                            │
│                          └─────┘                            │
└─────────────────────────────────────────────────────────────┘
```

**Pourquoi :**

- Éviter les branches Git longues (merge hell)
- Déployer continuellement sur main
- Rollback facile à tout moment
- Travail en parallèle possible

---

## Le Problème : Feature Branches Longues

```
❌ MAUVAIS - Feature branch pendant des mois

main:     A──B──C──D──E──F──G──H──I──J──K──L──M──N──O
               \                                  /
feature:        X──Y──Z──W──V──U──T──S──R──Q──P──┘

Problèmes:
- Merge conflicts énormes
- Intégration retardée
- Tests d'intégration tardifs
- Code review massive
```

```
✅ BON - Branch by Abstraction

main:     A──B──C──D──E──F──G──H──I──J──K──L──M
              │  │  │  │  │  │  │  │  │  │  │
              │  └──┴──┴──┴──┴──┴──┴──┴──┴──┘
              │     Petits commits progressifs
              │
              └── Abstraction créée
```

---

## Étapes du Pattern

### Étape 1 : Créer l'abstraction

```go
// AVANT - Couplage direct
type OrderService struct {
	paymentProcessor *StripeProcessor
}

func (s *OrderService) ProcessPayment(ctx context.Context, order *Order) (*PaymentResult, error) {
	return s.paymentProcessor.Charge(ctx, order.Total)
}

// APRÈS Étape 1 - Interface créée
type PaymentProcessor interface {
	Charge(ctx context.Context, amount Money) (*PaymentResult, error)
	Refund(ctx context.Context, transactionID string) error
}

// L'ancienne implémentation implémente l'interface
type StripeProcessor struct {
	client *stripe.Client
}

func (p *StripeProcessor) Charge(ctx context.Context, amount Money) (*PaymentResult, error) {
	// existing code
	return &PaymentResult{}, nil
}

func (p *StripeProcessor) Refund(ctx context.Context, transactionID string) error {
	// existing code
	return nil
}

// Service avec injection de dépendance
type OrderService struct {
	processor PaymentProcessor
}

func NewOrderService(processor PaymentProcessor) *OrderService {
	return &OrderService{
		processor: processor,
	}
}

func (s *OrderService) ProcessPayment(ctx context.Context, order *Order) (*PaymentResult, error) {
	return s.processor.Charge(ctx, order.Total)
}
```

**Commit 1 :** "Add PaymentProcessor interface" (pas de changement fonctionnel)

---

### Étape 2 : Créer la nouvelle implémentation

```go
// Nouvelle implémentation (peut être incomplète)
type AdyenProcessor struct {
	client *adyen.Client
}

func NewAdyenProcessor(client *adyen.Client) *AdyenProcessor {
	return &AdyenProcessor{
		client: client,
	}
}

func (p *AdyenProcessor) Charge(ctx context.Context, amount Money) (*PaymentResult, error) {
	// Nouvelle implémentation
	result, err := p.client.AuthorizePayment(ctx, &adyen.PaymentRequest{
		Amount:   amount.Cents,
		Currency: amount.Currency,
	})
	if err != nil {
		return nil, fmt.Errorf("adyen charge: %w", err)
	}
	return &PaymentResult{
		TransactionID: result.ID,
		Status:        result.Status,
	}, nil
}

func (p *AdyenProcessor) Refund(ctx context.Context, transactionID string) error {
	// TODO: implement
	return fmt.Errorf("refund not implemented yet")
}
```

**Commit 2 :** "Add AdyenProcessor implementation (WIP)"

---

### Étape 3 : Router vers la nouvelle implémentation

```go
// Feature toggle pour router
type PaymentProcessorFactory struct {
	features FeatureFlags
}

func NewPaymentProcessorFactory(features FeatureFlags) *PaymentProcessorFactory {
	return &PaymentProcessorFactory{
		features: features,
	}
}

func (f *PaymentProcessorFactory) Create(ctx context.Context, context PaymentContext) PaymentProcessor {
	// Toggle progressif
	if f.features.IsEnabled(ctx, "adyen-payments", context) {
		return NewAdyenProcessor(adyen.NewClient())
	}
	return NewStripeProcessor(stripe.NewClient())
}

// Ou migration par méthode
type HybridProcessor struct {
	legacy   *StripeProcessor
	modern   *AdyenProcessor
	features FeatureFlags
}

func NewHybridProcessor(legacy *StripeProcessor, modern *AdyenProcessor, features FeatureFlags) *HybridProcessor {
	return &HybridProcessor{
		legacy:   legacy,
		modern:   modern,
		features: features,
	}
}

func (p *HybridProcessor) Charge(ctx context.Context, amount Money) (*PaymentResult, error) {
	// Nouvelle implémentation pour charge
	if p.features.IsEnabled(ctx, "adyen-charge", nil) {
		return p.modern.Charge(ctx, amount)
	}
	return p.legacy.Charge(ctx, amount)
}

func (p *HybridProcessor) Refund(ctx context.Context, transactionID string) error {
	// Encore l'ancienne pour refund
	return p.legacy.Refund(ctx, transactionID)
}
```

**Commit 3 :** "Add feature toggle for AdyenProcessor"
**Commit 4 :** "Enable Adyen for 1% of traffic"
**Commit 5 :** "Enable Adyen for 10% of traffic"
...
**Commit N :** "Enable Adyen for 100% of traffic"

---

### Étape 4 : Supprimer l'ancienne implémentation

```go
// Une fois la migration complète et stable

// Supprimer:
// - StripeProcessor struct
// - Feature toggles
// - Code de routing

// Garder:
// - Interface PaymentProcessor (pour futures migrations)
// - AdyenProcessor (maintenant la seule implémentation)
```

**Commit final :** "Remove StripeProcessor (migration complete)"

---

## Variantes

### Strangler Fig Pattern

> Étrangler progressivement l'ancien système.

```go
// Pour migrer un monolithe vers microservices

type OrderFacade struct {
	legacyService *LegacyOrderService
	newService    *OrderMicroservice
	features      FeatureFlags
}

func NewOrderFacade(
	legacy *LegacyOrderService,
	modern *OrderMicroservice,
	features FeatureFlags,
) *OrderFacade {
	return &OrderFacade{
		legacyService: legacy,
		newService:    modern,
		features:      features,
	}
}

func (f *OrderFacade) CreateOrder(ctx context.Context, data *OrderData) (*Order, error) {
	// Route vers le nouveau service progressivement
	if f.shouldUseNewService(ctx, data) {
		return f.newService.Create(ctx, data)
	}
	return f.legacyService.Create(ctx, data)
}

func (f *OrderFacade) shouldUseNewService(ctx context.Context, data *OrderData) bool {
	// Critères de migration
	return data.Region == "EU" && // Europe d'abord
		data.Total.Amount < 10000 && // Petites commandes
		f.features.IsEnabled(ctx, "new-order-service", data)
}
```

### Parallel Run

> Exécuter les deux implémentations et comparer.

```go
type ParallelPaymentProcessor struct {
	primary    PaymentProcessor
	shadow     PaymentProcessor
	comparator ResultComparator
	logger     *slog.Logger
}

func NewParallelPaymentProcessor(
	primary PaymentProcessor,
	shadow PaymentProcessor,
	comparator ResultComparator,
	logger *slog.Logger,
) *ParallelPaymentProcessor {
	return &ParallelPaymentProcessor{
		primary:    primary,
		shadow:     shadow,
		comparator: comparator,
		logger:     logger,
	}
}

func (p *ParallelPaymentProcessor) Charge(ctx context.Context, amount Money) (*PaymentResult, error) {
	type result struct {
		val *PaymentResult
		err error
	}

	// Canaux pour recevoir les résultats
	primaryCh := make(chan result, 1)
	shadowCh := make(chan result, 1)

	// Exécuter en parallèle
	go func() {
		val, err := p.primary.Charge(ctx, amount)
		primaryCh <- result{val: val, err: err}
	}()

	go func() {
		val, err := p.shadow.Charge(ctx, amount)
		shadowCh <- result{val: val, err: err}
	}()

	// Attendre les résultats
	primaryResult := <-primaryCh
	shadowResult := <-shadowCh

	// Comparer (async, non-bloquant)
	go func() {
		if err := p.comparator.Compare(ctx, primaryResult, shadowResult); err != nil {
			p.logger.WarnContext(ctx, "Shadow comparison failed", "error", err)
		}
	}()

	// Retourner seulement le résultat primary
	if primaryResult.err != nil {
		return nil, primaryResult.err
	}
	return primaryResult.val, nil
}

func (p *ParallelPaymentProcessor) Refund(ctx context.Context, transactionID string) error {
	return p.primary.Refund(ctx, transactionID)
}
```

### Dark Launch

> Nouvelle implémentation activée mais résultat ignoré.

```go
type DarkLaunchProcessor struct {
	legacy  PaymentProcessor
	modern  PaymentProcessor
	metrics MetricsRecorder
	logger  *slog.Logger
}

func NewDarkLaunchProcessor(
	legacy PaymentProcessor,
	modern PaymentProcessor,
	metrics MetricsRecorder,
	logger *slog.Logger,
) *DarkLaunchProcessor {
	return &DarkLaunchProcessor{
		legacy:  legacy,
		modern:  modern,
		metrics: metrics,
		logger:  logger,
	}
}

func (p *DarkLaunchProcessor) Charge(ctx context.Context, amount Money) (*PaymentResult, error) {
	// Toujours utiliser legacy pour le résultat réel
	result, err := p.legacy.Charge(ctx, amount)

	// Tester le nouveau en arrière-plan
	go func() {
		modernResult, modernErr := p.modern.Charge(ctx, amount)
		if modernErr != nil {
			p.metrics.Record(ctx, "dark-launch-failure", 1)
			p.logger.ErrorContext(ctx, "Dark launch error", "error", modernErr)
			return
		}

		p.metrics.Record(ctx, "dark-launch-success", 1)
		if !p.resultsMatch(result, modernResult) {
			p.logger.WarnContext(ctx, "Dark launch mismatch",
				"legacy", result,
				"modern", modernResult)
		}
	}()

	return result, err
}

func (p *DarkLaunchProcessor) Refund(ctx context.Context, transactionID string) error {
	return p.legacy.Refund(ctx, transactionID)
}

func (p *DarkLaunchProcessor) resultsMatch(a, b *PaymentResult) bool {
	if a == nil && b == nil {
		return true
	}
	if a == nil || b == nil {
		return false
	}
	return a.TransactionID == b.TransactionID && a.Status == b.Status
}
```

---

## Exemple complet : Migration de base de données

```go
// Migration de MySQL vers PostgreSQL

// Étape 1: Abstraction
type UserRepository interface {
	FindByID(ctx context.Context, id string) (*User, error)
	Save(ctx context.Context, user *User) error
	FindByEmail(ctx context.Context, email string) (*User, error)
}

// Étape 2: Implémentations
type MySQLUserRepository struct {
	db *sql.DB
}

func NewMySQLUserRepository(db *sql.DB) *MySQLUserRepository {
	return &MySQLUserRepository{db: db}
}

func (r *MySQLUserRepository) FindByID(ctx context.Context, id string) (*User, error) {
	// Implémentation existante MySQL
	var user User
	err := r.db.QueryRowContext(ctx, "SELECT * FROM users WHERE id = ?", id).Scan(&user)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("mysql find by id: %w", err)
	}
	return &user, nil
}

func (r *MySQLUserRepository) Save(ctx context.Context, user *User) error {
	_, err := r.db.ExecContext(ctx, "INSERT INTO users (...) VALUES (?)", user)
	if err != nil {
		return fmt.Errorf("mysql save: %w", err)
	}
	return nil
}

func (r *MySQLUserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	// Implementation
	return nil, nil
}

type PostgresUserRepository struct {
	db *sql.DB
}

func NewPostgresUserRepository(db *sql.DB) *PostgresUserRepository {
	return &PostgresUserRepository{db: db}
}

func (r *PostgresUserRepository) FindByID(ctx context.Context, id string) (*User, error) {
	// Nouvelle implémentation Postgres
	var user User
	err := r.db.QueryRowContext(ctx, "SELECT * FROM users WHERE id = $1", id).Scan(&user)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("postgres find by id: %w", err)
	}
	return &user, nil
}

func (r *PostgresUserRepository) Save(ctx context.Context, user *User) error {
	_, err := r.db.ExecContext(ctx, "INSERT INTO users (...) VALUES ($1)", user)
	if err != nil {
		return fmt.Errorf("postgres save: %w", err)
	}
	return nil
}

func (r *PostgresUserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	// Implementation
	return nil, nil
}

// Étape 3: Double-write pour migration
type MigratingUserRepository struct {
	mysql          *MySQLUserRepository
	postgres       *PostgresUserRepository
	migrationState *MigrationState
	logger         *slog.Logger
}

func NewMigratingUserRepository(
	mysql *MySQLUserRepository,
	postgres *PostgresUserRepository,
	state *MigrationState,
	logger *slog.Logger,
) *MigratingUserRepository {
	return &MigratingUserRepository{
		mysql:          mysql,
		postgres:       postgres,
		migrationState: state,
		logger:         logger,
	}
}

func (r *MigratingUserRepository) Save(ctx context.Context, user *User) error {
	// Écrire dans les deux
	var wg sync.WaitGroup
	errCh := make(chan error, 2)

	wg.Add(2)
	go func() {
		defer wg.Done()
		if err := r.mysql.Save(ctx, user); err != nil {
			errCh <- fmt.Errorf("mysql save: %w", err)
		}
	}()

	go func() {
		defer wg.Done()
		if err := r.postgres.Save(ctx, user); err != nil {
			errCh <- fmt.Errorf("postgres save: %w", err)
		}
	}()

	wg.Wait()
	close(errCh)

	// Retourner la première erreur si présente
	for err := range errCh {
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *MigratingUserRepository) FindByID(ctx context.Context, id string) (*User, error) {
	// Lire du primary selon l'état de migration
	if r.migrationState.IsComplete() {
		return r.postgres.FindByID(ctx, id)
	}

	// Pendant migration: lire de MySQL, vérifier Postgres
	mysqlUser, err := r.mysql.FindByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("mysql find: %w", err)
	}

	postgresUser, err := r.postgres.FindByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("postgres find: %w", err)
	}

	if !r.usersMatch(mysqlUser, postgresUser) {
		r.logger.WarnContext(ctx, "Data mismatch during migration", "id", id)
		// Self-heal: copier de MySQL vers Postgres
		if mysqlUser != nil {
			if err := r.postgres.Save(ctx, mysqlUser); err != nil {
				r.logger.ErrorContext(ctx, "Failed to heal data", "error", err)
			}
		}
	}

	return mysqlUser, nil // MySQL reste primary pendant migration
}

func (r *MigratingUserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	// Similar to FindByID
	return nil, nil
}

func (r *MigratingUserRepository) usersMatch(a, b *User) bool {
	if a == nil && b == nil {
		return true
	}
	if a == nil || b == nil {
		return false
	}
	return a.ID == b.ID && a.Email == b.Email
}

// Étape 4: Cutover progressif
type MigrationState struct {
	mu               sync.RWMutex
	readFromPostgres int // 0-100%
}

func NewMigrationState() *MigrationState {
	return &MigrationState{
		readFromPostgres: 0,
	}
}

func (m *MigrationState) IsComplete() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.readFromPostgres == 100
}

func (m *MigrationState) ShouldReadFromPostgres(userID string) bool {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// Canary basé sur hash du userID
	hash := m.hashCode(userID)
	return (hash % 100) < m.readFromPostgres
}

func (m *MigrationState) IncrementPercentage(increment int) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.readFromPostgres = min(100, m.readFromPostgres+increment)
	return m.persist()
}

func (m *MigrationState) hashCode(s string) int {
	h := 0
	for _, c := range s {
		h = 31*h + int(c)
	}
	if h < 0 {
		h = -h
	}
	return h
}

func (m *MigrationState) persist() error {
	// Persister l'état dans une config
	return nil
}
```

---

## Tableau de décision

| Situation | Approche |
|-----------|----------|
| Refactoring interne simple | Git branch + PR |
| Migration API/Service | Branch by Abstraction |
| Migration base de données | Double-write + Parallel Run |
| Remplacement dépendance | Strangler Fig |
| Test nouvelle implémentation | Dark Launch |
| Rollout progressif | Feature Toggle + Canary |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Feature Toggles** | Mécanisme de routing |
| **Adapter** | Interface commune |
| **Strategy** | Interchangeabilité |
| **Strangler Fig** | Variante pour legacy |
| **Parallel Run** | Validation de migration |

---

## Avantages vs Inconvénients

### Avantages

- Intégration continue (pas de merge hell)
- Rollback instantané (toggle off)
- Code review incrémentales
- Tests d'intégration continus
- Déploiement à tout moment

### Inconvénients

- Code temporairement plus complexe
- Toggle debt si pas nettoyé
- Besoin de discipline d'équipe
- Monitoring plus complexe

---

## Sources

- [Martin Fowler - Branch by Abstraction](https://martinfowler.com/bliki/BranchByAbstraction.html)
- [Paul Hammant - Trunk Based Development](https://trunkbaseddevelopment.com/branch-by-abstraction/)
- [Strangler Fig Application](https://martinfowler.com/bliki/StranglerFigApplication.html)
