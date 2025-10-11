package taskqueue_test

import (
	"testing"

	"taskqueue"
)

func TestConnection_Creation(t *testing.T) {
	t.Parallel()

	conn := taskqueue.Connection{
		ID:   "conn-1",
		Host: "localhost",
		Port: 5432,
	}
	conn.IsConnected.Store(true)

	if conn.ID != "conn-1" {
		t.Error("expected ID to match")
	}
	if conn.Host != "localhost" {
		t.Error("expected host to match")
	}
	if !conn.IsConnected.Load() {
		t.Error("expected connection to be active")
	}
}

func TestConnection_AtomicOperations(t *testing.T) {
	t.Parallel()

	conn := taskqueue.Connection{ID: "conn-1"}

	conn.IsConnected.Store(true)
	if !conn.IsConnected.Load() {
		t.Error("expected connection to be active")
	}

	conn.IsConnected.Store(false)
	if conn.IsConnected.Load() {
		t.Error("expected connection to be inactive")
	}
}
