// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Defines the Session data structure for user session management.
//
// Responsibilities:
//   - Session data structure definition
//   - User session metadata storage
//
// Features:
//   - None (Pure data structure)
//
// Constraints:
//   - Used with SessionStore for concurrent access
//
package taskqueue

import (
	"time"
)

// Session represents a user session.
type Session struct {
	UserID    string
	ExpiresAt time.Time
	Data      map[string]interface{}
}
