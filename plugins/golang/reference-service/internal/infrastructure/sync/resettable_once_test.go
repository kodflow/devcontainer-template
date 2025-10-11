package sync_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/sync"
)

func TestNewResettableOnce(t *testing.T) {
	t.Parallel()

	once := sync.NewResettableOnce()
	if once == nil {
		t.Fatal("expected ResettableOnce to be created")
	}

	if once.IsInitialized() {
		t.Error("expected IsInitialized to be false initially")
	}
}

func TestResettableOnce_Do_Single(t *testing.T) {
	t.Parallel()

	once := sync.NewResettableOnce()
	count := 0

	once.Do(func() {
		count++
	})

	if count != 1 {
		t.Errorf("expected count 1, got %d", count)
	}

	if !once.IsInitialized() {
		t.Error("expected IsInitialized to be true")
	}
}

func TestResettableOnce_Do_Multiple(t *testing.T) {
	t.Parallel()

	once := sync.NewResettableOnce()
	count := 0

	once.Do(func() {
		count++
	})

	once.Do(func() {
		count++
	})

	once.Do(func() {
		count++
	})

	if count != 1 {
		t.Errorf("expected count 1, got %d", count)
	}
}

func TestResettableOnce_Reset(t *testing.T) {
	t.Parallel()

	once := sync.NewResettableOnce()
	count := 0

	once.Do(func() {
		count++
	})

	if count != 1 {
		t.Errorf("expected count 1 after first Do, got %d", count)
	}

	once.Reset()

	if once.IsInitialized() {
		t.Error("expected IsInitialized to be false after Reset")
	}

	once.Do(func() {
		count++
	})

	if count != 2 {
		t.Errorf("expected count 2 after reset and second Do, got %d", count)
	}
}

func TestResettableOnce_Concurrent(t *testing.T) {
	t.Parallel()

	once := sync.NewResettableOnce()
	count := 0

	done := make(chan struct{})

	for i := 0; i < 100; i++ {
		go func() {
			once.Do(func() {
				count++
			})
			done <- struct{}{}
		}()
	}

	for i := 0; i < 100; i++ {
		<-done
	}

	if count != 1 {
		t.Errorf("expected count 1 with concurrent calls, got %d", count)
	}
}
