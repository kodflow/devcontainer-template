package index_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/index"
)

func TestStatusIndex_Add(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()
	idx.Add("id1", todo.StatusPending)

	count := idx.Count(todo.StatusPending)
	if count != 1 {
		t.Errorf("expected count 1, got %d", count)
	}
}

func TestStatusIndex_GetByStatus(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()
	idx.Add("id1", todo.StatusPending)
	idx.Add("id2", todo.StatusPending)

	ids := idx.GetByStatus(todo.StatusPending)
	if len(ids) != 2 {
		t.Errorf("expected 2 ids, got %d", len(ids))
	}
}

func TestStatusIndex_Remove(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()
	idx.Add("id1", todo.StatusPending)
	idx.Remove("id1", todo.StatusPending)

	count := idx.Count(todo.StatusPending)
	if count != 0 {
		t.Errorf("expected count 0 after remove, got %d", count)
	}
}

func TestStatusIndex_Add_Idempotent(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()
	idx.Add("id1", todo.StatusPending)
	idx.Add("id1", todo.StatusPending) // Add same ID again
	idx.Add("id1", todo.StatusPending) // And again

	count := idx.Count(todo.StatusPending)
	if count != 1 {
		t.Errorf("expected count 1 (idempotent), got %d", count)
	}
}

func TestStatusIndex_Remove_NonExistentStatus(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()
	// Remove from status that was never added - should not panic
	idx.Remove("id1", "non-existent-status")

	// Should succeed without error
	count := idx.Count("non-existent-status")
	if count != 0 {
		t.Errorf("expected count 0 for non-existent status, got %d", count)
	}
}

func TestStatusIndex_Remove_NonExistentID(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()
	idx.Add("id1", todo.StatusPending)

	// Remove ID that doesn't exist - should not panic
	idx.Remove("non-existent-id", todo.StatusPending)

	count := idx.Count(todo.StatusPending)
	if count != 1 {
		t.Errorf("expected count 1 (original ID still there), got %d", count)
	}
}

func TestStatusIndex_GetByStatus_NonExistent(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()
	ids := idx.GetByStatus("non-existent-status")

	if ids == nil {
		t.Error("expected non-nil slice for non-existent status")
	}

	if len(ids) != 0 {
		t.Errorf("expected empty slice for non-existent status, got %d items", len(ids))
	}
}

func TestStatusIndex_Count_NonExistent(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()
	count := idx.Count("non-existent-status")

	if count != 0 {
		t.Errorf("expected count 0 for non-existent status, got %d", count)
	}
}

func TestStatusIndex_MultipleStatuses(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()

	// Add todos to different statuses
	idx.Add("id1", todo.StatusPending)
	idx.Add("id2", todo.StatusPending)
	idx.Add("id3", todo.StatusActive)
	idx.Add("id4", todo.StatusCompleted)
	idx.Add("id5", todo.StatusCompleted)
	idx.Add("id6", todo.StatusCompleted)

	// Verify counts per status
	if idx.Count(todo.StatusPending) != 2 {
		t.Errorf("expected 2 pending, got %d", idx.Count(todo.StatusPending))
	}

	if idx.Count(todo.StatusActive) != 1 {
		t.Errorf("expected 1 active, got %d", idx.Count(todo.StatusActive))
	}

	if idx.Count(todo.StatusCompleted) != 3 {
		t.Errorf("expected 3 completed, got %d", idx.Count(todo.StatusCompleted))
	}

	// Verify GetByStatus returns correct IDs
	pendingIDs := idx.GetByStatus(todo.StatusPending)
	if len(pendingIDs) != 2 {
		t.Errorf("expected 2 pending IDs, got %d", len(pendingIDs))
	}
}

func TestStatusIndex_AddRemoveSequence(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()

	// Add multiple IDs
	idx.Add("id1", todo.StatusPending)
	idx.Add("id2", todo.StatusPending)
	idx.Add("id3", todo.StatusPending)

	if idx.Count(todo.StatusPending) != 3 {
		t.Fatalf("expected count 3 after adds, got %d", idx.Count(todo.StatusPending))
	}

	// Remove one
	idx.Remove("id2", todo.StatusPending)

	if idx.Count(todo.StatusPending) != 2 {
		t.Errorf("expected count 2 after remove, got %d", idx.Count(todo.StatusPending))
	}

	// Verify remaining IDs
	ids := idx.GetByStatus(todo.StatusPending)
	hasID1 := false
	hasID3 := false
	for _, id := range ids {
		if id == "id1" {
			hasID1 = true
		}
		if id == "id3" {
			hasID3 = true
		}
		if id == "id2" {
			t.Error("id2 should have been removed")
		}
	}

	if !hasID1 || !hasID3 {
		t.Error("expected id1 and id3 to remain after removing id2")
	}
}

func TestStatusIndex_GetByStatus_ReturnsNewSlice(t *testing.T) {
	t.Parallel()

	idx := index.NewStatusIndex()
	idx.Add("id1", todo.StatusPending)

	// Get slice twice
	slice1 := idx.GetByStatus(todo.StatusPending)
	slice2 := idx.GetByStatus(todo.StatusPending)

	// Modify first slice
	if len(slice1) > 0 {
		slice1[0] = "modified"
	}

	// Second slice should not be affected (proves it's a copy)
	if len(slice2) > 0 && slice2[0] == "modified" {
		t.Error("modifying one slice affected another - slices are not independent")
	}
}
