package cache_test

import (
	"testing"
	"time"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/cache"
)

func TestNewMemoryCache_Success(t *testing.T) {
	t.Parallel()

	c, err := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if c == nil {
		t.Fatal("expected cache to be created")
	}
}

func TestMemoryCache_SetGet_Success(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	err := c.Set("key1", 42, 1*time.Minute)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	val, err := c.Get("key1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if val != 42 {
		t.Errorf("expected value 42, got %d", val)
	}
}

func TestMemoryCache_Get_NotFound(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	_, err := c.Get("nonexistent")
	if err != cache.ErrNotFound {
		t.Errorf("expected ErrNotFound, got %v", err)
	}
}

func TestMemoryCache_Get_Expired(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	c.Set("key1", 42, 1*time.Millisecond)
	time.Sleep(2 * time.Millisecond)

	_, err := c.Get("key1")
	if err != cache.ErrExpired {
		t.Errorf("expected ErrExpired, got %v", err)
	}
}

func TestMemoryCache_Delete(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	c.Set("key1", 42, 1*time.Minute)
	c.Delete("key1")

	_, err := c.Get("key1")
	if err != cache.ErrNotFound {
		t.Error("expected key to be deleted")
	}
}

func TestMemoryCache_Clear(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	c.Set("key1", 1, 1*time.Minute)
	c.Set("key2", 2, 1*time.Minute)

	if c.Size() != 2 {
		t.Errorf("expected size 2, got %d", c.Size())
	}

	c.Clear()

	if c.Size() != 0 {
		t.Errorf("expected size 0 after clear, got %d", c.Size())
	}
}

func TestMemoryCache_CacheFull(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 2})

	c.Set("key1", 1, 1*time.Minute)
	c.Set("key2", 2, 1*time.Minute)

	err := c.Set("key3", 3, 1*time.Minute)
	if err != cache.ErrCacheFull {
		t.Errorf("expected ErrCacheFull, got %v", err)
	}
}

func TestNewMemoryCache_DefaultMaxEntries(t *testing.T) {
	t.Parallel()

	// Test with MaxEntries = 0 (should use default)
	c, err := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 0})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if c == nil {
		t.Fatal("expected cache to be created with default max entries")
	}

	// Should be able to add at least DefaultMaxEntries items
	// DefaultMaxEntries is 10000, so we test with a reasonable number
	for i := 0; i < 100; i++ {
		err := c.Set(string(rune(i)), i, 1*time.Minute)
		if err != nil {
			t.Fatalf("failed to set item %d: %v", i, err)
		}
	}
}

func TestNewMemoryCache_NegativeMaxEntries(t *testing.T) {
	t.Parallel()

	// Test with negative MaxEntries (should use default)
	c, err := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: -5})
	if err != nil {
		t.Fatalf("expected no error (should use default), got %v", err)
	}

	if c == nil {
		t.Fatal("expected cache to be created with default max entries")
	}
}

func TestMemoryCache_Set_UpdateExisting(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 2})

	// Set initial value
	err := c.Set("key1", 42, 1*time.Minute)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	// Update existing key (should succeed even if cache is "full")
	c.Set("key2", 100, 1*time.Minute) // Fill cache

	// Update key1 - should succeed as it already exists
	err = c.Set("key1", 999, 1*time.Minute)
	if err != nil {
		t.Errorf("expected to update existing key, got error: %v", err)
	}

	// Verify updated value
	val, _ := c.Get("key1")
	if val != 999 {
		t.Errorf("expected updated value 999, got %d", val)
	}
}

func TestMemoryCache_Delete_NonExistent(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	// Delete non-existent key - should not panic
	c.Delete("nonexistent")

	// Verify cache is still functional
	err := c.Set("key1", 42, 1*time.Minute)
	if err != nil {
		t.Error("cache should still be functional after deleting non-existent key")
	}
}

func TestMemoryCache_Size_Empty(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	if c.Size() != 0 {
		t.Errorf("expected size 0 for empty cache, got %d", c.Size())
	}
}

func TestMemoryCache_Size_AfterOperations(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	// Add items
	c.Set("key1", 1, 1*time.Minute)
	c.Set("key2", 2, 1*time.Minute)
	c.Set("key3", 3, 1*time.Minute)

	if c.Size() != 3 {
		t.Errorf("expected size 3, got %d", c.Size())
	}

	// Delete one
	c.Delete("key2")

	if c.Size() != 2 {
		t.Errorf("expected size 2 after delete, got %d", c.Size())
	}

	// Update existing (size should not change)
	c.Set("key1", 999, 1*time.Minute)

	if c.Size() != 2 {
		t.Errorf("expected size 2 after update, got %d", c.Size())
	}
}

func TestMemoryCache_Clear_EmptyCache(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	// Clear empty cache - should not panic
	c.Clear()

	if c.Size() != 0 {
		t.Errorf("expected size 0 after clearing empty cache, got %d", c.Size())
	}
}

func TestMemoryCache_MultipleTypes(t *testing.T) {
	t.Parallel()

	// Test with string values
	strCache, _ := cache.NewMemoryCache[string, string](cache.Config{MaxEntries: 10})
	strCache.Set("key", "value", 1*time.Minute)
	strVal, _ := strCache.Get("key")
	if strVal != "value" {
		t.Error("failed to handle string type")
	}

	// Test with struct values
	type testStruct struct {
		Name string
		Age  int
	}
	structCache, _ := cache.NewMemoryCache[string, testStruct](cache.Config{MaxEntries: 10})
	structCache.Set("person", testStruct{Name: "Alice", Age: 30}, 1*time.Minute)
	structVal, _ := structCache.Get("person")
	if structVal.Name != "Alice" || structVal.Age != 30 {
		t.Error("failed to handle struct type")
	}

	// Test with pointer values
	ptrCache, _ := cache.NewMemoryCache[string, *int](cache.Config{MaxEntries: 10})
	num := 42
	ptrCache.Set("ptr", &num, 1*time.Minute)
	ptrVal, _ := ptrCache.Get("ptr")
	if *ptrVal != 42 {
		t.Error("failed to handle pointer type")
	}
}

func TestMemoryCache_TTL_Boundaries(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	// Test very short TTL
	c.Set("short", 1, 1*time.Nanosecond)
	time.Sleep(1 * time.Millisecond)
	_, err := c.Get("short")
	if err != cache.ErrExpired {
		t.Error("expected ErrExpired for very short TTL")
	}

	// Test long TTL
	c.Set("long", 2, 24*time.Hour)
	val, err := c.Get("long")
	if err != nil || val != 2 {
		t.Error("failed to handle long TTL")
	}

	// Test zero TTL (expires immediately)
	c.Set("zero", 3, 0*time.Second)
	_, err = c.Get("zero")
	if err != cache.ErrExpired {
		t.Error("expected ErrExpired for zero TTL")
	}
}

func TestMemoryCache_Get_ReturnZeroOnError(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[string, int](cache.Config{MaxEntries: 100})

	// Get non-existent key - should return zero value of int
	val, err := c.Get("nonexistent")
	if err != cache.ErrNotFound {
		t.Errorf("expected ErrNotFound, got %v", err)
	}
	if val != 0 {
		t.Errorf("expected zero value (0), got %d", val)
	}

	// Get expired key - should return zero value
	c.Set("key1", 42, 1*time.Millisecond)
	time.Sleep(2 * time.Millisecond)

	val, err = c.Get("key1")
	if err != cache.ErrExpired {
		t.Errorf("expected ErrExpired, got %v", err)
	}
	if val != 0 {
		t.Errorf("expected zero value (0) for expired key, got %d", val)
	}
}

func TestMemoryCache_ConcurrentAccess(t *testing.T) {
	t.Parallel()

	c, _ := cache.NewMemoryCache[int, int](cache.Config{MaxEntries: 1000})

	// Concurrent writes
	done := make(chan struct{})
	for i := 0; i < 10; i++ {
		go func(id int) {
			for j := 0; j < 100; j++ {
				c.Set(id*100+j, j, 1*time.Minute)
			}
			done <- struct{}{}
		}(i)
	}

	// Wait for all writes
	for i := 0; i < 10; i++ {
		<-done
	}

	// Concurrent reads
	for i := 0; i < 10; i++ {
		go func(id int) {
			for j := 0; j < 100; j++ {
				c.Get(id*100 + j)
			}
			done <- struct{}{}
		}(i)
	}

	// Wait for all reads
	for i := 0; i < 10; i++ {
		<-done
	}

	// Verify cache is still functional
	if c.Size() != 1000 {
		t.Errorf("expected size 1000 after concurrent operations, got %d", c.Size())
	}
}
