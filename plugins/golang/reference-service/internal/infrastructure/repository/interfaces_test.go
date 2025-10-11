package repository_test

// mockIDGenerator is a mock implementation of IDGenerator for testing.
type mockIDGenerator struct {
	generateFunc func() string
}

func (m *mockIDGenerator) Generate() string {
	if m.generateFunc != nil {
		return m.generateFunc()
	}
	return "mock-id"
}
