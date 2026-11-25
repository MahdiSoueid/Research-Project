---
title: Past Exam 2025-2026 - Work-Stealing Scheduler
course: CSC5101
year: 2025-2026
type: exam
tags:
  - csc5101/exam
  - csc5101/non-blocking
  - csc5101/tm
  - csc5101/locks
  - csc5101/numa
---

# Past Exam 2025–2026 — Work-Stealing Scheduler

Up: [[00 - CSC5101 Index (MOC)]] | Concepts: [[04 - Non-Blocking Data Structures]], [[06 - Transactional Memory (STM, HTM, HyTM)]], [[03 - Lock Algorithms and Futexes]]

---

## Exercise I: Lock-Free Task-Stealing Scheduler & Termination (17 points)

### Data Structures (Q1–Q2)
Inspired by the [[04 - Non-Blocking Data Structures#4. Lock-Free FIFO Queue (Michael–Scott)|Michael–Scott lock-free queue]] (with a dummy `Fake` node):

```c
struct task_t {
  void (*func)(void*);
  void* arg;
  struct task_t* _Atomic next;
};

struct queue_t {
  struct task_t* _Atomic head;
  struct task_t* _Atomic tail;
};
```
`enqueue(queue, task)` and `dequeue(queue)` follow the exact Michael–Scott algorithm (remember: `dequeue` returns the payload from `res->next` and `res->next` becomes the new dummy node).

### Lock-Free 3-Mode Termination Worker (Q6–Q7)

Global state:
```c
size_t nb_threads;
struct queue_t* queues;
_Atomic size_t nb_stealers = 0;
_Atomic size_t nb_terminates = 0;
```

```c
void* worker(void* arg) {
  struct queue_t* my_queue = (struct queue_t*)arg;
  struct task_t* task;

normal:
  task = dequeue(my_queue);
  if (task != NULL) {
    task->func(task->arg);
    goto normal;
  }
  atomic_fetch_add(&nb_stealers, 1);

steal:
  for (size_t i = 0; i < nb_threads; i++) {
    task = dequeue(&queues[i]);
    if (task != NULL) {
      atomic_fetch_add(&nb_stealers, -1);
      task->func(task->arg);
      goto normal;
    }
  }
  atomic_fetch_add(&nb_terminates, 1);

termination:
  // If any thread is NOT in steal/termination mode (i.e. running a task that
  // could spawn new tasks), nb_stealers < nb_threads -> go back to steal mode!
  if (atomic_load(&nb_stealers) < nb_threads) {
    atomic_fetch_add(&nb_terminates, -1);
    goto steal;
  }
  if (atomic_load(&nb_terminates) < nb_threads)
    goto termination;

  return NULL; // All threads have verified all queues empty and entered termination
}
```

> [!important] Subtlety in Q7's Condition (`nb_stealers < nb_threads` vs `!= 0`)
> Notice that a thread entering `termination` mode **keeps its increment in `nb_stealers`** (it does not decrement `nb_stealers` when moving from `steal` to `termination`). Therefore, all threads are idle iff `nb_stealers == nb_threads`, and if any thread steals work and returns to `normal` mode, it decrements `nb_stealers` so `nb_stealers < nb_threads`, waking terminating threads back into `steal` mode!

---

## Exercise II: Course Questions (3 points)

1. **HTM Redo Log & Main Limitation (1 pt):** A CPU's L1 cache naturally acts as a redo log because speculative writes stay buffered in private cache lines until commit (discarded on abort) while cache coherence detects read/write conflicts automatically. Its **main limitation** is L1 cache capacity: transactions exceeding cache size (or hitting cache associativity evictions) always abort. See [[06 - Transactional Memory (STM, HTM, HyTM)#4. Implementation Techniques: HTM, STM, HyTM]].
2. **Ticket Lock vs. Spinlock vs. MCS Lock (1 pt):** A **ticket lock** is more efficient than a TAS spinlock because waiting threads spin on read-only `atomic_load`s instead of write-heavy `atomic_exchange`s, avoiding continuous cache-line invalidation storms (and ensuring FIFO fairness). An **MCS lock** improves on the ticket lock because each waiter spins on its own private cache line (`my.is_free`) rather than a single shared `screen` variable, avoiding broadcast invalidations on unlock. See [[03 - Lock Algorithms and Futexes]].
3. **Interleaved vs. First-Touch under Unknown Behavior (1 pt):** When application access patterns are unknown, **interleaved** evenly distributes pages across all NUMA nodes, balancing load across memory controllers and interconnects and avoiding severe single-node bottlenecks caused by first-touch if one thread initializes shared data. See [[08 - NUMA Architecture (Extra)]].
