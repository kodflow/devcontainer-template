package taskqueue_test

import (
	"testing"
	"time"

	"taskqueue"
)

func TestSession_Creation(t *testing.T) {
	t.Parallel()

	session := taskqueue.Session{
		UserID:    "user-123",
		ExpiresAt: time.Now().Add(time.Hour),
		Data:      map[string]interface{}{"theme": "dark"},
	}

	if session.UserID != "user-123" {
		t.Error("expected user ID to match")
	}
	if session.Data["theme"] != "dark" {
		t.Error("expected data to be set")
	}
}

func TestSession_ZeroValue(t *testing.T) {
	t.Parallel()

	var session taskqueue.Session

	if session.UserID != "" {
		t.Error("expected empty user ID")
	}
	if session.Data != nil {
		t.Error("expected nil data")
	}
	if !session.ExpiresAt.IsZero() {
		t.Error("expected zero expiration time")
	}
}

func TestSession_DataManipulation(t *testing.T) {
	t.Parallel()

	session := taskqueue.Session{
		UserID:    "user-1",
		ExpiresAt: time.Now().Add(time.Hour),
		Data:      make(map[string]interface{}),
	}

	session.Data["key1"] = "value1"
	session.Data["key2"] = 42

	if session.Data["key1"] != "value1" {
		t.Error("expected key1 to be set")
	}
	if session.Data["key2"] != 42 {
		t.Error("expected key2 to be set")
	}
}
