// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Map for user session management with expiration.
//
// Responsibilities:
//   - Concurrent session storage and retrieval
//   - Session expiration checking
//   - Periodic cleanup of expired sessions
//
// Features:
//   - None (Pure concurrency primitives)
//
// Constraints:
//   - Optimized for stable keyset (cache pattern)
//   - No range-over-map support (use Range method)
//   - Type assertions required (interface{} storage)
//
package taskqueue

import (
	"sync"
	"time"
)

// SessionStore manages user sessions with sync.Map.
// Demonstrates cache with expiration (stable keyset pattern).
type SessionStore struct {
	sessions sync.Map // key: sessionID (string), value: *Session
}

// NewSessionStore creates a session store.
func NewSessionStore() *SessionStore {
	return &SessionStore{}
}

// Store stores session.
func (s *SessionStore) Store(sessionID string, session *Session) {
	s.sessions.Store(sessionID, session)
}

// Load retrieves session if not expired.
func (s *SessionStore) Load(sessionID string) (*Session, bool) {
	value, ok := s.sessions.Load(sessionID)
	if !ok {
		return nil, false
	}

	session := value.(*Session)
	if time.Now().After(session.ExpiresAt) {
		s.sessions.Delete(sessionID)
		return nil, false
	}

	return session, true
}

// CleanExpired removes expired sessions.
// Should be called periodically in background goroutine.
func (s *SessionStore) CleanExpired() int {
	removed := 0
	now := time.Now()

	s.sessions.Range(func(key, value interface{}) bool {
		session := value.(*Session)
		if now.After(session.ExpiresAt) {
			s.sessions.Delete(key)
			removed++
		}
		return true
	})

	return removed
}
