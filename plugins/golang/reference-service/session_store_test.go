package taskqueue_test

import (
	"sync"
	"testing"
	"time"

	"taskqueue"
)

func TestSessionStore_StoreAndLoad(t *testing.T) {
	t.Parallel()

	store := taskqueue.NewSessionStore()
	session := &taskqueue.Session{
		UserID:    "user-1",
		ExpiresAt: time.Now().Add(time.Hour),
		Data:      map[string]interface{}{"key": "value"},
	}

	store.Store("session-1", session)

	loaded, ok := store.Load("session-1")
	if !ok {
		t.Fatal("expected session to be found")
	}
	if loaded.UserID != "user-1" {
		t.Error("expected user ID to match")
	}
}

func TestSessionStore_LoadExpired(t *testing.T) {
	t.Parallel()

	store := taskqueue.NewSessionStore()
	session := &taskqueue.Session{
		UserID:    "user-1",
		ExpiresAt: time.Now().Add(-time.Hour), // Expired 1 hour ago
		Data:      map[string]interface{}{},
	}

	store.Store("session-1", session)

	// Load should return false for expired session
	_, ok := store.Load("session-1")
	if ok {
		t.Error("expected expired session to not be loaded")
	}

	// Verify session was deleted
	_, ok = store.Load("session-1")
	if ok {
		t.Error("expected expired session to be deleted")
	}
}

func TestSessionStore_CleanExpired(t *testing.T) {
	t.Parallel()

	store := taskqueue.NewSessionStore()

	// Add expired session
	expired := &taskqueue.Session{
		UserID:    "user-1",
		ExpiresAt: time.Now().Add(-time.Hour),
	}
	store.Store("session-1", expired)

	// Add valid sessions
	valid1 := &taskqueue.Session{
		UserID:    "user-2",
		ExpiresAt: time.Now().Add(time.Hour),
	}
	store.Store("session-2", valid1)

	valid2 := &taskqueue.Session{
		UserID:    "user-3",
		ExpiresAt: time.Now().Add(time.Hour),
	}
	store.Store("session-3", valid2)

	// Clean expired
	removed := store.CleanExpired()

	if removed != 1 {
		t.Errorf("expected 1 session removed, got %d", removed)
	}

	// Verify expired session is gone
	_, ok := store.Load("session-1")
	if ok {
		t.Error("expected expired session to be removed")
	}

	// Verify valid sessions remain
	_, ok = store.Load("session-2")
	if !ok {
		t.Error("expected valid session to remain")
	}
	_, ok = store.Load("session-3")
	if !ok {
		t.Error("expected valid session to remain")
	}
}

func TestSessionStore_ConcurrentOperations(t *testing.T) {
	t.Parallel()

	store := taskqueue.NewSessionStore()
	const goroutines = 50
	const operations = 100

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer wg.Done()
			for j := 0; j < operations; j++ {
				sessionID := string(rune(id*operations + j))
				session := &taskqueue.Session{
					UserID:    sessionID,
					ExpiresAt: time.Now().Add(time.Hour),
					Data:      map[string]interface{}{},
				}
				store.Store(sessionID, session)
				store.Load(sessionID)
			}
		}(i)
	}

	wg.Wait()
}
