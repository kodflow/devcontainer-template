package repository_test

import (
	"context"
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/repository"
)

func TestNewRepository_Success(t *testing.T) {
	t.Parallel()

	repo, err := repository.NewRepository(repository.Config{})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if repo == nil {
		t.Fatal("expected repository to be created")
	}
}

func TestRepository_Create_Success(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	td, _ := todo.NewTodo("Test", "Description", todo.PriorityMedium)

	created, err := repo.Create(context.Background(), td)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if created.ID == "" {
		t.Error("expected ID to be assigned")
	}
}

func TestRepository_Create_NilTodo(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	_, err := repo.Create(context.Background(), nil)
	if err != todo.ErrNilTodo {
		t.Errorf("expected ErrNilTodo, got %v", err)
	}
}

func TestRepository_GetByID_Success(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	td, _ := todo.NewTodo("Test", "Description", todo.PriorityMedium)
	created, _ := repo.Create(context.Background(), td)

	found, err := repo.GetByID(context.Background(), created.ID)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if found.ID != created.ID {
		t.Errorf("expected ID %s, got %s", created.ID, found.ID)
	}
}

func TestRepository_GetByID_NotFound(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	_, err := repo.GetByID(context.Background(), "nonexistent")
	if err != todo.ErrTodoNotFound {
		t.Errorf("expected ErrTodoNotFound, got %v", err)
	}
}

func TestRepository_GetByID_EmptyID(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	_, err := repo.GetByID(context.Background(), "")
	if err != todo.ErrEmptyID {
		t.Errorf("expected ErrEmptyID, got %v", err)
	}
}

func TestRepository_Update_Success(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	td, _ := todo.NewTodo("Test", "Description", todo.PriorityMedium)
	created, _ := repo.Create(context.Background(), td)

	created.Title = "Updated"
	err := repo.Update(context.Background(), created)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	updated, _ := repo.GetByID(context.Background(), created.ID)
	if updated.Title != "Updated" {
		t.Errorf("expected title 'Updated', got '%s'", updated.Title)
	}
}

func TestRepository_Update_NotFound(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	td, _ := todo.NewTodo("Test", "Description", todo.PriorityMedium)
	td.ID = "nonexistent"

	err := repo.Update(context.Background(), td)
	if err != todo.ErrTodoNotFound {
		t.Errorf("expected ErrTodoNotFound, got %v", err)
	}
}

func TestRepository_Update_NilTodo(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	err := repo.Update(context.Background(), nil)
	if err != todo.ErrNilTodo {
		t.Errorf("expected ErrNilTodo, got %v", err)
	}
}

func TestRepository_Delete_Success(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	td, _ := todo.NewTodo("Test", "Description", todo.PriorityMedium)
	created, _ := repo.Create(context.Background(), td)

	err := repo.Delete(context.Background(), created.ID)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	_, err = repo.GetByID(context.Background(), created.ID)
	if err != todo.ErrTodoNotFound {
		t.Error("expected todo to be deleted")
	}
}

func TestRepository_Delete_NotFound(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	err := repo.Delete(context.Background(), "nonexistent")
	if err != todo.ErrTodoNotFound {
		t.Errorf("expected ErrTodoNotFound, got %v", err)
	}
}

func TestRepository_Delete_EmptyID(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	err := repo.Delete(context.Background(), "")
	if err != todo.ErrEmptyID {
		t.Errorf("expected ErrEmptyID, got %v", err)
	}
}

func TestRepository_List_Success(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	td1, _ := todo.NewTodo("Test1", "Desc1", todo.PriorityMedium)
	td2, _ := todo.NewTodo("Test2", "Desc2", todo.PriorityHigh)
	repo.Create(context.Background(), td1)
	repo.Create(context.Background(), td2)

	results, err := repo.List(context.Background(), todo.Filter{Limit: 10})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(results) != 2 {
		t.Errorf("expected 2 results, got %d", len(results))
	}
}

func TestRepository_List_WithFilter(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	td1, _ := todo.NewTodo("Test1", "Desc1", todo.PriorityMedium)
	td2, _ := todo.NewTodo("Test2", "Desc2", todo.PriorityHigh)
	td1.Status = todo.StatusActive
	repo.Create(context.Background(), td1)
	repo.Create(context.Background(), td2)

	filter := todo.Filter{
		Statuses: []string{todo.StatusActive},
		Limit:    10,
	}
	results, err := repo.List(context.Background(), filter)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(results) != 1 {
		t.Errorf("expected 1 result, got %d", len(results))
	}
}

func TestRepository_Count_Success(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	td1, _ := todo.NewTodo("Test1", "Desc1", todo.PriorityMedium)
	td2, _ := todo.NewTodo("Test2", "Desc2", todo.PriorityHigh)
	repo.Create(context.Background(), td1)
	repo.Create(context.Background(), td2)

	count, err := repo.Count(context.Background(), todo.Filter{})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if count != 2 {
		t.Errorf("expected count 2, got %d", count)
	}
}

func TestNewRepository_WithCustomIDGenerator(t *testing.T) {
	t.Parallel()

	// Create mock ID generator
	mockGen := &mockIDGenerator{prefix: "TEST-"}
	repo, err := repository.NewRepository(repository.Config{IDGenerator: mockGen})

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	td, _ := todo.NewTodo("Test", "Description", todo.PriorityMedium)
	created, _ := repo.Create(context.Background(), td)

	if created.ID[:5] != "TEST-" {
		t.Errorf("expected ID to start with 'TEST-', got %s", created.ID)
	}
}

func TestNewRepository_DefaultMaxTodos(t *testing.T) {
	t.Parallel()

	// Test with MaxTodos = 0 (should use default)
	repo, err := repository.NewRepository(repository.Config{MaxTodos: 0})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if repo == nil {
		t.Fatal("expected repository to be created with default max todos")
	}
}

func TestNewRepository_NegativeMaxTodos(t *testing.T) {
	t.Parallel()

	// Test with negative MaxTodos (should use default)
	repo, err := repository.NewRepository(repository.Config{MaxTodos: -10})
	if err != nil {
		t.Fatalf("expected no error (should use default), got %v", err)
	}

	if repo == nil {
		t.Fatal("expected repository to be created with default max todos")
	}
}

func TestRepository_Create_ExceedsLimit(t *testing.T) {
	t.Parallel()

	// Create repository with small limit
	repo, _ := repository.NewRepository(repository.Config{MaxTodos: 2})

	td1, _ := todo.NewTodo("Test1", "Desc1", todo.PriorityMedium)
	td2, _ := todo.NewTodo("Test2", "Desc2", todo.PriorityMedium)
	td3, _ := todo.NewTodo("Test3", "Desc3", todo.PriorityMedium)

	// Create first two todos
	_, err := repo.Create(context.Background(), td1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	_, err = repo.Create(context.Background(), td2)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	// Third should fail
	_, err = repo.Create(context.Background(), td3)
	if err != todo.ErrTodoLimitExceeded {
		t.Errorf("expected ErrTodoLimitExceeded, got %v", err)
	}
}

func TestRepository_Update_EmptyID(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	td, _ := todo.NewTodo("Test", "Description", todo.PriorityMedium)
	td.ID = ""

	err := repo.Update(context.Background(), td)
	if err != todo.ErrEmptyID {
		t.Errorf("expected ErrEmptyID, got %v", err)
	}
}

func TestRepository_List_WithPagination(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	// Create 5 todos
	for i := 0; i < 5; i++ {
		td, _ := todo.NewTodo("Test", "Description", todo.PriorityMedium)
		repo.Create(context.Background(), td)
	}

	// Get first page (2 items)
	page1, err := repo.List(context.Background(), todo.Filter{Limit: 2, Offset: 0})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(page1) != 2 {
		t.Errorf("expected 2 results on first page, got %d", len(page1))
	}

	// Get second page (2 items)
	page2, err := repo.List(context.Background(), todo.Filter{Limit: 2, Offset: 2})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(page2) != 2 {
		t.Errorf("expected 2 results on second page, got %d", len(page2))
	}

	// Get third page (1 item)
	page3, err := repo.List(context.Background(), todo.Filter{Limit: 2, Offset: 4})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(page3) != 1 {
		t.Errorf("expected 1 result on third page, got %d", len(page3))
	}
}

func TestRepository_List_EmptyResults(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	results, err := repo.List(context.Background(), todo.Filter{Limit: 10})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(results) != 0 {
		t.Errorf("expected empty results, got %d", len(results))
	}
}

func TestRepository_List_FilterByPriority(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	td1, _ := todo.NewTodo("Test1", "Desc1", todo.PriorityLow)
	td2, _ := todo.NewTodo("Test2", "Desc2", todo.PriorityHigh)
	td3, _ := todo.NewTodo("Test3", "Desc3", todo.PriorityHigh)

	repo.Create(context.Background(), td1)
	repo.Create(context.Background(), td2)
	repo.Create(context.Background(), td3)

	// Filter by high priority
	filter := todo.Filter{
		Priority: todo.PriorityHigh,
		Limit:    10,
	}
	results, err := repo.List(context.Background(), filter)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(results) != 2 {
		t.Errorf("expected 2 high-priority todos, got %d", len(results))
	}
}

func TestRepository_List_FilterByFlags(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	td1, _ := todo.NewTodo("Test1", "Desc1", todo.PriorityMedium)
	td2, _ := todo.NewTodo("Test2", "Desc2", todo.PriorityMedium)
	td3, _ := todo.NewTodo("Test3", "Desc3", todo.PriorityMedium)

	td1.Flags = todo.FlagUrgent
	td2.Flags = todo.FlagUrgent | todo.FlagImportant
	td3.Flags = todo.FlagImportant

	repo.Create(context.Background(), td1)
	repo.Create(context.Background(), td2)
	repo.Create(context.Background(), td3)

	// Filter by FlagsAll: must have both Urgent and Important
	filter := todo.Filter{
		FlagsAll: todo.FlagUrgent | todo.FlagImportant,
		Limit:    10,
	}
	results, err := repo.List(context.Background(), filter)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(results) != 1 {
		t.Errorf("expected 1 todo with both flags, got %d", len(results))
	}
}

func TestRepository_List_FilterByFlagsAny(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	td1, _ := todo.NewTodo("Test1", "Desc1", todo.PriorityMedium)
	td2, _ := todo.NewTodo("Test2", "Desc2", todo.PriorityMedium)
	td3, _ := todo.NewTodo("Test3", "Desc3", todo.PriorityMedium)

	td1.Flags = todo.FlagUrgent
	td2.Flags = todo.FlagImportant
	td3.Flags = 0 // No flags

	repo.Create(context.Background(), td1)
	repo.Create(context.Background(), td2)
	repo.Create(context.Background(), td3)

	// Filter by FlagsAny: must have at least Urgent OR Important
	filter := todo.Filter{
		FlagsAny: todo.FlagUrgent | todo.FlagImportant,
		Limit:    10,
	}
	results, err := repo.List(context.Background(), filter)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(results) != 2 {
		t.Errorf("expected 2 todos with at least one flag, got %d", len(results))
	}
}

func TestRepository_List_MultipleFilters(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	td1, _ := todo.NewTodo("Test1", "Desc1", todo.PriorityHigh)
	td2, _ := todo.NewTodo("Test2", "Desc2", todo.PriorityHigh)
	td3, _ := todo.NewTodo("Test3", "Desc3", todo.PriorityLow)

	td1.Status = todo.StatusActive
	td2.Status = todo.StatusCompleted
	td3.Status = todo.StatusActive

	repo.Create(context.Background(), td1)
	repo.Create(context.Background(), td2)
	repo.Create(context.Background(), td3)

	// Filter by status AND priority
	filter := todo.Filter{
		Statuses: []string{todo.StatusActive},
		Priority: todo.PriorityHigh,
		Limit:    10,
	}
	results, err := repo.List(context.Background(), filter)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(results) != 1 {
		t.Errorf("expected 1 active high-priority todo, got %d", len(results))
	}
}

func TestRepository_Count_WithFilter(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	td1, _ := todo.NewTodo("Test1", "Desc1", todo.PriorityMedium)
	td2, _ := todo.NewTodo("Test2", "Desc2", todo.PriorityHigh)
	td3, _ := todo.NewTodo("Test3", "Desc3", todo.PriorityHigh)

	td1.Status = todo.StatusActive
	td2.Status = todo.StatusActive
	td3.Status = todo.StatusCompleted

	repo.Create(context.Background(), td1)
	repo.Create(context.Background(), td2)
	repo.Create(context.Background(), td3)

	// Count active todos
	filter := todo.Filter{
		Statuses: []string{todo.StatusActive},
	}
	count, err := repo.Count(context.Background(), filter)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if count != 2 {
		t.Errorf("expected count 2, got %d", count)
	}
}

func TestRepository_Count_EmptyRepository(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	count, err := repo.Count(context.Background(), todo.Filter{})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if count != 0 {
		t.Errorf("expected count 0 for empty repository, got %d", count)
	}
}

func TestRepository_ConcurrentWrites(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{MaxTodos: 100})

	// Create todos concurrently
	done := make(chan struct{})
	for i := 0; i < 10; i++ {
		go func(id int) {
			for j := 0; j < 5; j++ {
				td, _ := todo.NewTodo("Test", "Description", todo.PriorityMedium)
				repo.Create(context.Background(), td)
			}
			done <- struct{}{}
		}(i)
	}

	// Wait for all goroutines
	for i := 0; i < 10; i++ {
		<-done
	}

	// Verify count
	count, _ := repo.Count(context.Background(), todo.Filter{})
	if count != 50 {
		t.Errorf("expected 50 todos after concurrent writes, got %d", count)
	}
}

func TestRepository_ConcurrentReads(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})

	// Create a todo
	td, _ := todo.NewTodo("Test", "Description", todo.PriorityMedium)
	created, _ := repo.Create(context.Background(), td)

	// Read concurrently
	done := make(chan struct{})
	for i := 0; i < 10; i++ {
		go func() {
			for j := 0; j < 100; j++ {
				repo.GetByID(context.Background(), created.ID)
			}
			done <- struct{}{}
		}()
	}

	// Wait for all goroutines
	for i := 0; i < 10; i++ {
		<-done
	}

	// Verify todo still exists
	found, err := repo.GetByID(context.Background(), created.ID)
	if err != nil || found.ID != created.ID {
		t.Error("concurrent reads affected data integrity")
	}
}

// Mock ID generator for testing
type mockIDGenerator struct {
	prefix string
	count  int
}

func (m *mockIDGenerator) Generate() string {
	m.count++
	return m.prefix + string(rune(m.count))
}
