package sync_test

// mockResettable is a mock implementation of Resettable for testing.
type mockResettable struct {
	resetFunc          func()
	isInitializedFunc  func() bool
}

func (m *mockResettable) Reset() {
	if m.resetFunc != nil {
		m.resetFunc()
	}
}

func (m *mockResettable) IsInitialized() bool {
	if m.isInitializedFunc != nil {
		return m.isInitializedFunc()
	}
	return false
}
