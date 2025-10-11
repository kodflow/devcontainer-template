package index_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/index"
)

// mockIndex implements index.Index for testing.
type mockIndex struct {
	addFunc         func(id, status string)
	removeFunc      func(id, status string)
	getByStatusFunc func(status string) []string
	countFunc       func(status string) int
}

func (m *mockIndex) Add(id, status string) {
	if m.addFunc != nil {
		m.addFunc(id, status)
	}
}

func (m *mockIndex) Remove(id, status string) {
	if m.removeFunc != nil {
		m.removeFunc(id, status)
	}
}

func (m *mockIndex) GetByStatus(status string) []string {
	if m.getByStatusFunc != nil {
		return m.getByStatusFunc(status)
	}
	return []string{}
}

func (m *mockIndex) Count(status string) int {
	if m.countFunc != nil {
		return m.countFunc(status)
	}
	return 0
}

// Ensure StatusIndex implements Index interface.
var _ index.Index = (*index.StatusIndex)(nil)

// Ensure mockIndex implements Index interface.
var _ index.Index = (*mockIndex)(nil)

func TestIndexInterface(t *testing.T) {
	t.Parallel()

	mock := &mockIndex{
		addFunc: func(id, status string) {},
		countFunc: func(status string) int {
			return 1
		},
	}

	mock.Add("id1", "status1")
	count := mock.Count("status1")

	if count != 1 {
		t.Errorf("count = %d, want 1", count)
	}
}

func TestStatusIndexImplementsInterface(t *testing.T) {
	t.Parallel()

	// This test verifies at compile time that StatusIndex implements Index.
	// The var _ assignment above ensures this.
	var idx index.Index
	if idx != nil {
		t.Error("index should be nil initially")
	}
}
