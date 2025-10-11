// Package taskqueue_test task request validation tests
//
// Purpose:
//   Tests for CreateTaskRequest validation logic.
//
// Responsibilities:
//   - Test request validation rules
//   - Test edge cases and invalid inputs
//
// Features:
//   - None (Test code only)
//
// Constraints:
//   - Use table-driven tests
//   - Test all validation paths
//
package taskqueue_test

import (
	"testing"

	"taskqueue"
)

func TestCreateTaskRequest_Validate_Success(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		req  taskqueue.CreateTaskRequest
	}{
		{
			name: "valid request with all fields",
			req: taskqueue.CreateTaskRequest{
				Type:       "email",
				Data:       map[string]interface{}{"to": "test@example.com"},
				MaxRetries: 3,
			},
		},
		{
			name: "valid request with zero retries",
			req: taskqueue.CreateTaskRequest{
				Type:       "notification",
				Data:       map[string]interface{}{"message": "hello"},
				MaxRetries: 0,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			err := tt.req.Validate()
			AssertNoError(t, err)
		})
	}
}

func TestCreateTaskRequest_Validate_Failure(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name        string
		req         taskqueue.CreateTaskRequest
		expectedErr string
	}{
		{
			name: "empty type",
			req: taskqueue.CreateTaskRequest{
				Type:       "",
				Data:       map[string]interface{}{"key": "value"},
				MaxRetries: 3,
			},
			expectedErr: "task type is required",
		},
		{
			name: "nil data",
			req: taskqueue.CreateTaskRequest{
				Type:       "email",
				Data:       nil,
				MaxRetries: 3,
			},
			expectedErr: "task data is required",
		},
		{
			name: "negative retries",
			req: taskqueue.CreateTaskRequest{
				Type:       "email",
				Data:       map[string]interface{}{"key": "value"},
				MaxRetries: -1,
			},
			expectedErr: "max retries cannot be negative",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			err := tt.req.Validate()
			AssertError(t, err, tt.expectedErr)
		})
	}
}

func TestBuildTestCreateRequest_WithOptions(t *testing.T) {
	t.Parallel()

	req := BuildTestCreateRequest(t,
		WithRequestType("email"),
	)

	if req.Type != "email" {
		t.Errorf("expected 'email', got %s", req.Type)
	}

	if req.Data == nil {
		t.Error("expected non-nil data")
	}
}
