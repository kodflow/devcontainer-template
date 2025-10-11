package taskqueue_test

import (
	"context"
	"log/slog"
	"sync"
	"testing"
	"time"

	"taskqueue"
)

func TestConfigLoader_LoadOnce(t *testing.T) {
	t.Parallel()

	loader := taskqueue.NewConfigLoader("config.yaml", slog.Default())
	ctx := context.Background()

	config1, err1 := loader.Load(ctx)
	if err1 != nil {
		t.Fatalf("first load failed: %v", err1)
	}

	config2, err2 := loader.Load(ctx)
	if err2 != nil {
		t.Fatalf("second load failed: %v", err2)
	}

	// Should return same config instance
	if config1 != config2 {
		t.Error("expected same config instance on multiple loads")
	}

	// Verify config has expected defaults
	if config1.WorkerCount != taskqueue.DefaultWorkerCount {
		t.Errorf("expected WorkerCount %d, got %d", taskqueue.DefaultWorkerCount, config1.WorkerCount)
	}
}

func TestConfigLoader_ConcurrentLoads(t *testing.T) {
	t.Parallel()

	loader := taskqueue.NewConfigLoader("config.yaml", slog.Default())
	ctx := context.Background()
	const goroutines = 50

	configs := make([]*taskqueue.WorkerConfig, goroutines)
	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func(idx int) {
			defer wg.Done()
			config, err := loader.Load(ctx)
			if err != nil {
				t.Errorf("load failed: %v", err)
				return
			}
			configs[idx] = config
		}(i)
	}

	wg.Wait()

	// All should return same instance
	firstConfig := configs[0]
	for i := 1; i < goroutines; i++ {
		if configs[i] != firstConfig {
			t.Errorf("config at index %d is different instance", i)
		}
	}
}

func TestConfigLoader_ContextCancellation(t *testing.T) {
	t.Parallel()

	loader := taskqueue.NewConfigLoader("config.yaml", slog.Default())
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // Cancel immediately

	_, err := loader.Load(ctx)
	if err != context.Canceled {
		t.Errorf("expected context.Canceled error, got %v", err)
	}
}

func TestConfigLoader_Timeout(t *testing.T) {
	t.Parallel()

	loader := taskqueue.NewConfigLoader("config.yaml", slog.Default())
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()

	_, err := loader.Load(ctx)
	if err != context.DeadlineExceeded {
		t.Errorf("expected context.DeadlineExceeded error, got %v", err)
	}
}
