package taskqueue_test

import (
	"testing"
	"time"

	"taskqueue"
)

func TestStatsSnapshot_Creation(t *testing.T) {
	t.Parallel()

	snapshot := taskqueue.StatsSnapshot{
		TasksSubmitted:   100,
		TasksProcessed:   95,
		TasksFailed:      3,
		TasksRetried:     2,
		ActiveWorkers:    5,
		AverageTime:      time.Millisecond * 150,
		SuccessRate:      0.95,
		TotalProcessTime: time.Second * 15,
	}

	if snapshot.TasksSubmitted != 100 {
		t.Error("expected TasksSubmitted to be 100")
	}
	if snapshot.TasksProcessed != 95 {
		t.Error("expected TasksProcessed to be 95")
	}
	if snapshot.TasksFailed != 3 {
		t.Error("expected TasksFailed to be 3")
	}
	if snapshot.SuccessRate != 0.95 {
		t.Error("expected SuccessRate to be 0.95")
	}
}

func TestStatsSnapshot_ZeroValue(t *testing.T) {
	t.Parallel()

	var snapshot taskqueue.StatsSnapshot

	if snapshot.TasksSubmitted != 0 {
		t.Error("expected TasksSubmitted to be 0")
	}
	if snapshot.ActiveWorkers != 0 {
		t.Error("expected ActiveWorkers to be 0")
	}
	if snapshot.SuccessRate != 0 {
		t.Error("expected SuccessRate to be 0")
	}
}

func TestStatsSnapshot_Immutability(t *testing.T) {
	t.Parallel()

	snapshot1 := taskqueue.StatsSnapshot{
		TasksSubmitted: 100,
		TasksProcessed: 95,
	}

	snapshot2 := snapshot1

	snapshot2.TasksSubmitted = 200

	if snapshot1.TasksSubmitted != 100 {
		t.Error("original snapshot should not be modified")
	}
	if snapshot2.TasksSubmitted != 200 {
		t.Error("copy should be modified")
	}
}
