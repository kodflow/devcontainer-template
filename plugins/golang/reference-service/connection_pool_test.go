package taskqueue_test

import (
	"log/slog"
	"sync"
	"testing"

	"taskqueue"
)

func TestConnectionPool_Singleton(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetConnectionPool returns global singleton

	pool1 := taskqueue.GetConnectionPool(slog.Default())
	pool2 := taskqueue.GetConnectionPool(slog.Default())

	if pool1 != pool2 {
		t.Error("expected GetConnectionPool to return same instance")
	}
}

func TestConnectionPool_GetConnection(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetConnectionPool returns global singleton

	pool := taskqueue.GetConnectionPool(slog.Default())

	conn1 := pool.GetConnection("host1")
	conn2 := pool.GetConnection("host1")

	// Same host should return same connection
	if conn1 != conn2 {
		t.Error("expected same connection for same host")
	}

	conn3 := pool.GetConnection("host2")

	// Different host should return different connection
	if conn1 == conn3 {
		t.Error("expected different connection for different host")
	}
}

func TestConnectionPool_ConcurrentAccess(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetConnectionPool returns global singleton

	pool := taskqueue.GetConnectionPool(slog.Default())
	const goroutines = 50

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer wg.Done()
			host := string(rune(id + 2000))
			pool.GetConnection(host)
		}(i)
	}

	wg.Wait()
}
