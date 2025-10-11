// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates Go 1.23+ iterators with range-over-func.
//
// Responsibilities:
//   - Custom iterator implementations
//   - Generator patterns with yield
//   - Iterator composition and transformation
//
// Features:
//   - None (Language-level iteration)
//
// Constraints:
//   - Requires Go 1.23 or later
//   - yield must be called with break-safe design
//
package taskqueue

import (
	"iter"
	"slices"
	"time"
)

// TaskIterator is a function that yields tasks one by one.
// Go 1.23+ allows using this with range loops.
//
// Usage:
//
//	for task := range IterateTasks(tasks) {
//	    process(task)
//	}
type TaskIterator = iter.Seq[*Task]

// TaskPairIterator yields (index, task) pairs.
type TaskPairIterator = iter.Seq2[int, *Task]

// IterateTasks creates an iterator over task slice.
// Demonstrates basic iterator implementation.
func IterateTasks(tasks []*Task) TaskIterator {
	return func(yield func(*Task) bool) {
		for _, task := range tasks {
			if !yield(task) {
				return // Stop if consumer breaks
			}
		}
	}
}

// IterateTasksWithIndex creates an iterator with indices.
// Demonstrates iter.Seq2 for key-value iteration.
func IterateTasksWithIndex(tasks []*Task) TaskPairIterator {
	return func(yield func(int, *Task) bool) {
		for i, task := range tasks {
			if !yield(i, task) {
				return
			}
		}
	}
}

// IterateBackward iterates tasks in reverse order.
// Demonstrates slices.Backward from Go 1.23.
func IterateBackward(tasks []*Task) TaskPairIterator {
	return slices.Backward(tasks)
}

// FilterTasks creates iterator for tasks matching predicate.
// Demonstrates iterator transformation.
func FilterTasks(tasks []*Task, predicate func(*Task) bool) TaskIterator {
	return func(yield func(*Task) bool) {
		for _, task := range tasks {
			if predicate(task) {
				if !yield(task) {
					return
				}
			}
		}
	}
}

// FilterByStatus filters tasks by status.
func FilterByStatus(tasks []*Task, status TaskStatus) TaskIterator {
	return FilterTasks(tasks, func(t *Task) bool {
		return t.Status == status
	})
}

// FilterByType filters tasks by type.
func FilterByType(tasks []*Task, taskType string) TaskIterator {
	return FilterTasks(tasks, func(t *Task) bool {
		return t.Type == taskType
	})
}

// MapTasks transforms tasks using mapper function.
// Demonstrates iterator mapping.
func MapTasks[T any](tasks []*Task, mapper func(*Task) T) iter.Seq[T] {
	return func(yield func(T) bool) {
		for _, task := range tasks {
			if !yield(mapper(task)) {
				return
			}
		}
	}
}

// TaskIDs extracts task IDs using iterator mapping.
func TaskIDs(tasks []*Task) iter.Seq[string] {
	return MapTasks(tasks, func(t *Task) string {
		return t.ID
	})
}

// TaskTypes extracts task types.
func TaskTypes(tasks []*Task) iter.Seq[string] {
	return MapTasks(tasks, func(t *Task) string {
		return t.Type
	})
}

// TakeTasks takes first n tasks from iterator.
// Demonstrates iterator limiting.
func TakeTasks(tasks []*Task, n int) TaskIterator {
	return func(yield func(*Task) bool) {
		count := 0
		for _, task := range tasks {
			if count >= n {
				return
			}
			if !yield(task) {
				return
			}
			count++
		}
	}
}

// SkipTasks skips first n tasks.
func SkipTasks(tasks []*Task, n int) TaskIterator {
	return func(yield func(*Task) bool) {
		for i, task := range tasks {
			if i < n {
				continue
			}
			if !yield(task) {
				return
			}
		}
	}
}

// ChainTasks chains multiple task slices into single iterator.
// Demonstrates iterator composition.
func ChainTasks(taskSlices ...[]*Task) TaskIterator {
	return func(yield func(*Task) bool) {
		for _, tasks := range taskSlices {
			for _, task := range tasks {
				if !yield(task) {
					return
				}
			}
		}
	}
}

// ChunkTasks groups tasks into chunks of specified size.
// Demonstrates iterator chunking.
func ChunkTasks(tasks []*Task, chunkSize int) iter.Seq[[]*Task] {
	return func(yield func([]*Task) bool) {
		for i := 0; i < len(tasks); i += chunkSize {
			end := i + chunkSize
			if end > len(tasks) {
				end = len(tasks)
			}
			chunk := tasks[i:end]
			if !yield(chunk) {
				return
			}
		}
	}
}

// IterateByStatus groups tasks by status.
// Demonstrates grouping iterator.
func IterateByStatus(tasks []*Task) iter.Seq2[TaskStatus, []*Task] {
	return func(yield func(TaskStatus, []*Task) bool) {
		grouped := make(map[TaskStatus][]*Task)

		// Group tasks
		for _, task := range tasks {
			grouped[task.Status] = append(grouped[task.Status], task)
		}

		// Yield groups
		for status, taskList := range grouped {
			if !yield(status, taskList) {
				return
			}
		}
	}
}

// IteratePending returns iterator for pending tasks only.
func IteratePending(tasks []*Task) TaskIterator {
	return FilterByStatus(tasks, TaskStatusPending)
}

// IterateProcessing returns iterator for processing tasks.
func IterateProcessing(tasks []*Task) TaskIterator {
	return FilterByStatus(tasks, TaskStatusProcessing)
}

// IterateCompleted returns iterator for completed tasks.
func IterateCompleted(tasks []*Task) TaskIterator {
	return FilterByStatus(tasks, TaskStatusCompleted)
}

// IterateFailed returns iterator for failed tasks.
func IterateFailed(tasks []*Task) TaskIterator {
	return FilterByStatus(tasks, TaskStatusFailed)
}

// GenerateTasks generates tasks lazily.
// Demonstrates generator pattern with iterators.
func GenerateTasks(count int) TaskIterator {
	return func(yield func(*Task) bool) {
		for i := 0; i < count; i++ {
			task := &Task{
				ID:        "generated-" + string(rune(i)),
				Type:      "generated",
				Status:    TaskStatusPending,
				CreatedAt: time.Now(),
			}
			if !yield(task) {
				return
			}
		}
	}
}

// IterateWithTimeout yields tasks with timeout protection.
// Stops iteration after timeout, even if not finished.
func IterateWithTimeout(tasks []*Task, timeout time.Duration) TaskIterator {
	return func(yield func(*Task) bool) {
		deadline := time.Now().Add(timeout)

		for _, task := range tasks {
			if time.Now().After(deadline) {
				return // Timeout reached
			}
			if !yield(task) {
				return
			}
		}
	}
}

// IterateWithDelay yields tasks with delay between iterations.
// Useful for rate-limited processing.
func IterateWithDelay(tasks []*Task, delay time.Duration) TaskIterator {
	return func(yield func(*Task) bool) {
		for i, task := range tasks {
			if i > 0 {
				time.Sleep(delay)
			}
			if !yield(task) {
				return
			}
		}
	}
}

// CollectIterator collects all items from iterator into slice.
// Demonstrates iterator consumption.
func CollectIterator(iter TaskIterator) []*Task {
	var result []*Task
	for task := range iter {
		result = append(result, task)
	}
	return result
}

// CountIterator counts items in iterator without allocating slice.
func CountIterator(iter TaskIterator) int {
	count := 0
	for range iter {
		count++
	}
	return count
}

// AnyMatch returns true if any task matches predicate.
// Short-circuits on first match.
func AnyMatch(iter TaskIterator, predicate func(*Task) bool) bool {
	for task := range iter {
		if predicate(task) {
			return true
		}
	}
	return false
}

// AllMatch returns true if all tasks match predicate.
// Short-circuits on first non-match.
func AllMatch(iter TaskIterator, predicate func(*Task) bool) bool {
	for task := range iter {
		if !predicate(task) {
			return false
		}
	}
	return true
}

// FirstMatch returns first task matching predicate.
func FirstMatch(iter TaskIterator, predicate func(*Task) bool) (*Task, bool) {
	for task := range iter {
		if predicate(task) {
			return task, true
		}
	}
	return nil, false
}
