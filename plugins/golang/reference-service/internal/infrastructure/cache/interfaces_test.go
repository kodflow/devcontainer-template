package cache_test

import "time"

// mockCache is a mock implementation of Cache for testing.
type mockCache[K comparable, V any] struct {
	setFunc    func(key K, value V, ttl time.Duration) error
	getFunc    func(key K) (V, error)
	deleteFunc func(key K)
	clearFunc  func()
	sizeFunc   func() int
}

func (m *mockCache[K, V]) Set(key K, value V, ttl time.Duration) error {
	if m.setFunc != nil {
		return m.setFunc(key, value, ttl)
	}
	return nil
}

func (m *mockCache[K, V]) Get(key K) (V, error) {
	if m.getFunc != nil {
		return m.getFunc(key)
	}
	var zero V
	return zero, nil
}

func (m *mockCache[K, V]) Delete(key K) {
	if m.deleteFunc != nil {
		m.deleteFunc(key)
	}
}

func (m *mockCache[K, V]) Clear() {
	if m.clearFunc != nil {
		m.clearFunc()
	}
}

func (m *mockCache[K, V]) Size() int {
	if m.sizeFunc != nil {
		return m.sizeFunc()
	}
	return 0
}
