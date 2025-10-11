package taskqueue_test

import (
	"testing"
	"time"

	"taskqueue"
)

func TestIterateTasks(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
		{ID: "task-3"},
	}

	count := 0
	for task := range taskqueue.IterateTasks(tasks) {
		if task == nil {
			t.Error("expected non-nil task")
		}
		count++
	}

	if count != 3 {
		t.Errorf("expected 3 tasks, got %d", count)
	}
}

func TestIterateTasksWithIndex(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
	}

	indices := []int{}
	for i, task := range taskqueue.IterateTasksWithIndex(tasks) {
		if task == nil {
			t.Error("expected non-nil task")
		}
		indices = append(indices, i)
	}

	if len(indices) != 2 {
		t.Errorf("expected 2 indices, got %d", len(indices))
	}
	if indices[0] != 0 || indices[1] != 1 {
		t.Error("expected indices 0, 1")
	}
}

func TestIterateBackward(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
		{ID: "task-3"},
	}

	ids := []string{}
	for _, task := range taskqueue.IterateBackward(tasks) {
		ids = append(ids, task.ID)
	}

	if len(ids) != 3 {
		t.Fatal("expected 3 tasks")
	}
	if ids[0] != "task-3" || ids[1] != "task-2" || ids[2] != "task-1" {
		t.Error("expected reverse order")
	}
}

func TestFilterTasks(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1", Status: taskqueue.TaskStatusPending},
		{ID: "task-2", Status: taskqueue.TaskStatusCompleted},
		{ID: "task-3", Status: taskqueue.TaskStatusPending},
	}

	predicate := func(t *taskqueue.Task) bool {
		return t.Status == taskqueue.TaskStatusPending
	}

	count := 0
	for range taskqueue.FilterTasks(tasks, predicate) {
		count++
	}

	if count != 2 {
		t.Errorf("expected 2 pending tasks, got %d", count)
	}
}

func TestFilterByStatus(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1", Status: taskqueue.TaskStatusPending},
		{ID: "task-2", Status: taskqueue.TaskStatusCompleted},
		{ID: "task-3", Status: taskqueue.TaskStatusPending},
	}

	count := 0
	for range taskqueue.FilterByStatus(tasks, taskqueue.TaskStatusPending) {
		count++
	}

	if count != 2 {
		t.Errorf("expected 2 pending tasks, got %d", count)
	}
}

func TestFilterByType(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1", Type: "email"},
		{ID: "task-2", Type: "sms"},
		{ID: "task-3", Type: "email"},
	}

	count := 0
	for range taskqueue.FilterByType(tasks, "email") {
		count++
	}

	if count != 2 {
		t.Errorf("expected 2 email tasks, got %d", count)
	}
}

func TestMapTasks(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
	}

	ids := []string{}
	for id := range taskqueue.TaskIDs(tasks) {
		ids = append(ids, id)
	}

	if len(ids) != 2 {
		t.Fatalf("expected 2 IDs, got %d", len(ids))
	}
	if ids[0] != "task-1" || ids[1] != "task-2" {
		t.Error("expected task-1, task-2")
	}
}

func TestTaskTypes(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1", Type: "email"},
		{ID: "task-2", Type: "sms"},
	}

	types := []string{}
	for taskType := range taskqueue.TaskTypes(tasks) {
		types = append(types, taskType)
	}

	if len(types) != 2 {
		t.Fatalf("expected 2 types, got %d", len(types))
	}
	if types[0] != "email" || types[1] != "sms" {
		t.Error("expected email, sms")
	}
}

func TestTakeTasks(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
		{ID: "task-3"},
		{ID: "task-4"},
	}

	count := 0
	for range taskqueue.TakeTasks(tasks, 2) {
		count++
	}

	if count != 2 {
		t.Errorf("expected 2 tasks, got %d", count)
	}
}

func TestSkipTasks(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
		{ID: "task-3"},
	}

	ids := []string{}
	for task := range taskqueue.SkipTasks(tasks, 1) {
		ids = append(ids, task.ID)
	}

	if len(ids) != 2 {
		t.Fatalf("expected 2 tasks, got %d", len(ids))
	}
	if ids[0] != "task-2" || ids[1] != "task-3" {
		t.Error("expected task-2, task-3")
	}
}

func TestChainTasks(t *testing.T) {
	t.Parallel()

	tasks1 := []*taskqueue.Task{{ID: "task-1"}}
	tasks2 := []*taskqueue.Task{{ID: "task-2"}}
	tasks3 := []*taskqueue.Task{{ID: "task-3"}}

	count := 0
	for range taskqueue.ChainTasks(tasks1, tasks2, tasks3) {
		count++
	}

	if count != 3 {
		t.Errorf("expected 3 tasks, got %d", count)
	}
}

func TestChunkTasks(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
		{ID: "task-3"},
		{ID: "task-4"},
		{ID: "task-5"},
	}

	chunks := 0
	for chunk := range taskqueue.ChunkTasks(tasks, 2) {
		chunks++
		if len(chunk) > 2 {
			t.Error("expected chunk size <= 2")
		}
	}

	if chunks != 3 {
		t.Errorf("expected 3 chunks, got %d", chunks)
	}
}

func TestIterateByStatus(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1", Status: taskqueue.TaskStatusPending},
		{ID: "task-2", Status: taskqueue.TaskStatusCompleted},
		{ID: "task-3", Status: taskqueue.TaskStatusPending},
	}

	groups := 0
	for status, taskList := range taskqueue.IterateByStatus(tasks) {
		groups++
		if status == taskqueue.TaskStatusPending {
			if len(taskList) != 2 {
				t.Errorf("expected 2 pending tasks, got %d", len(taskList))
			}
		}
	}

	if groups != 2 {
		t.Errorf("expected 2 groups, got %d", groups)
	}
}

func TestIteratePending(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1", Status: taskqueue.TaskStatusPending},
		{ID: "task-2", Status: taskqueue.TaskStatusCompleted},
		{ID: "task-3", Status: taskqueue.TaskStatusPending},
	}

	count := 0
	for range taskqueue.IteratePending(tasks) {
		count++
	}

	if count != 2 {
		t.Errorf("expected 2 pending tasks, got %d", count)
	}
}

func TestGenerateTasks(t *testing.T) {
	t.Parallel()

	count := 0
	for range taskqueue.GenerateTasks(5) {
		count++
	}

	if count != 5 {
		t.Errorf("expected 5 generated tasks, got %d", count)
	}
}

func TestIterateWithTimeout(t *testing.T) {
	t.Parallel()

	tasks := make([]*taskqueue.Task, 100)
	for i := range tasks {
		tasks[i] = &taskqueue.Task{ID: string(rune(i))}
	}

	count := 0
	for range taskqueue.IterateWithTimeout(tasks, 10*time.Millisecond) {
		time.Sleep(time.Millisecond) // Slow iteration
		count++
	}

	// Should stop before all tasks due to timeout
	if count >= 100 {
		t.Error("expected iteration to stop due to timeout")
	}
}

func TestCollectIterator(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
	}

	collected := taskqueue.CollectIterator(taskqueue.IterateTasks(tasks))

	if len(collected) != 2 {
		t.Errorf("expected 2 collected tasks, got %d", len(collected))
	}
}

func TestCountIterator(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
		{ID: "task-3"},
	}

	count := taskqueue.CountIterator(taskqueue.IterateTasks(tasks))

	if count != 3 {
		t.Errorf("expected count 3, got %d", count)
	}
}

func TestAnyMatch(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1", Status: taskqueue.TaskStatusPending},
		{ID: "task-2", Status: taskqueue.TaskStatusCompleted},
	}

	predicate := func(t *taskqueue.Task) bool {
		return t.Status == taskqueue.TaskStatusCompleted
	}

	if !taskqueue.AnyMatch(taskqueue.IterateTasks(tasks), predicate) {
		t.Error("expected match found")
	}
}

func TestAllMatch(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1", Status: taskqueue.TaskStatusPending},
		{ID: "task-2", Status: taskqueue.TaskStatusPending},
	}

	predicate := func(t *taskqueue.Task) bool {
		return t.Status == taskqueue.TaskStatusPending
	}

	if !taskqueue.AllMatch(taskqueue.IterateTasks(tasks), predicate) {
		t.Error("expected all tasks to match")
	}
}

func TestFirstMatch(t *testing.T) {
	t.Parallel()

	tasks := []*taskqueue.Task{
		{ID: "task-1", Status: taskqueue.TaskStatusPending},
		{ID: "task-2", Status: taskqueue.TaskStatusCompleted},
	}

	predicate := func(t *taskqueue.Task) bool {
		return t.Status == taskqueue.TaskStatusCompleted
	}

	task, found := taskqueue.FirstMatch(taskqueue.IterateTasks(tasks), predicate)

	if !found {
		t.Fatal("expected match found")
	}
	if task.ID != "task-2" {
		t.Error("expected task-2")
	}
}
