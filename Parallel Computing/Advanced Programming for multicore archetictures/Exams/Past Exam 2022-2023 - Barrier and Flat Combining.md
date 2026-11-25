---
title: Past Exam 2022-2023 - Barrier and Flat Combining
course: CSC5101
year: 2022-2023
type: exam
tags:
  - csc5101/exam
  - csc5101/locks
  - csc5101/threads
  - csc5101/tm
  - csc5101/nvmm
---

# Past Exam 2022–2023 — Barrier & Flat Combining

Up: [[Parallel Computing/Advanced Programming for multicore archetictures/Readme]] | Concepts: [[01 - Processes, Threads and Monitors]], [[03 - Lock Algorithms and Futexes]], [[06 - Transactional Memory (STM, HTM, HyTM)]], [[07 - Persistent Memory (NVMM and Crash Consistency)]]

---

## Exercise I: 4 Implementations of a Barrier (11 points)

### Q2: POSIX Monitor Barrier (3.5 pts)
```c
struct barrier {
  int n;
  pthread_mutex_t mutex;
  pthread_cond_t  cond;
};

void barrier_init(struct barrier* b, int n) {
  b->n = n;
  pthread_mutex_init(&b->mutex, NULL);
  pthread_cond_init(&b->cond, NULL);
}

void barrier_wait(struct barrier* b) {
  pthread_mutex_lock(&b->mutex);
  if (--b->n > 0) {
    while (b->n > 0)
      pthread_cond_wait(&b->cond, &b->mutex);
  } else {
    pthread_cond_broadcast(&b->cond);
  }
  pthread_mutex_unlock(&b->mutex);
}
```

### Q3: Atomic Busy-Wait Barrier (2 pts)
```c
struct barrier { _Atomic int n; };

void barrier_init(struct barrier* b, int n) { atomic_store(&b->n, n); }

void barrier_wait(struct barrier* b) {
  // fetch_add returns OLD value: last thread sees 1
  if (atomic_fetch_add(&b->n, -1) > 1)
    while (atomic_load(&b->n) > 0) { }
}
```

### Q4: Futex Sleeping Barrier (2 pts)
```c
struct barrier {
  int max;
  _Atomic int n;
};

void barrier_init(struct barrier* b, int n) {
  b->max = n;
  atomic_store(&b->n, n);
}

void barrier_wait(struct barrier* b) {
  int prev = atomic_fetch_add(&b->n, -1);
  if (prev > 1) {
    int cur = prev - 1;
    while (cur > 0) {
      futex_wait(&b->n, cur);
      cur = atomic_load(&b->n);
    }
  } else {
    futex_wake(&b->n, b->max);
  }
}
```

### Q5: Transactional Memory Barrier (1.5 pts)
```c
struct barrier { int n; };
void barrier_init(struct barrier* b, int n) { b->n = n; }
void barrier_wait(struct barrier* b) {
  atomic { b->n--; }
  atomic { if (b->n > 0) retry; } // Must be a SEPARATE atomic block so decrement commits!
}
```
> [!warning] Why Two Separate `atomic` Blocks in Q5?
> If `b->n--` and `retry` were in the same `atomic` block, `retry` would **abort and roll back** `b->n--`, causing permanent deadlock!

---

## Exercise II: Course Questions (2 points)
1. **Why `sfence` implements `pfence`:** Intel TSO already orders stores; `clwb` has store semantics, so `sfence` prevents reordering `clwb` with stores.
2. **Why `sfence` implements `psync`:** Intel ADR provides residual power on crash to flush pending memory-controller queues into PMEM once `sfence` completes.

---

## Exercise III: MCS-Based Flat Combining (7 points)

Instead of passing the lock on every critical section, the thread that acquires the MCS lock becomes a **combiner** and executes up to `256` queued jobs in batch (dramatic cache locality win!), handing off the combiner role to the next waiter when done.

```c
typedef void (*job_t)(void);

struct node {
  struct node* _Atomic next;
  job_t _Atomic job;
  bool _Atomic is_combiner;
};

_Thread_local struct node my;
struct node* _Atomic lock = NULL;

void execute_in_cs(job_t job) {
  my.next = NULL;
  atomic_store(&my.job, job);
  atomic_store(&my.is_combiner, false);

  struct node* p = atomic_exchange(&lock, &my);
  if (p != NULL) {
    atomic_store(&p->next, &my);
    do {
      if (atomic_load(&my.job) == NULL)
        return; // a combiner executed my job!
    } while (!atomic_load(&my.is_combiner));
  }

  // I am the combiner: execute my own job first
  job();

  int n = 1;
  struct node* cur = &my;
  while (1) {
    struct node* expected = cur;
    if (atomic_compare_exchange_strong(&lock, &expected, NULL))
      return; // queue empty, lock released

    while (!atomic_load(&cur->next)) { }
    struct node* next = atomic_load(&cur->next);

    if (n++ >= 256) {
      atomic_store(&next->is_combiner, true); // hand off combiner role to next
      return;
    }

    cur = next;
    cur->job();
    atomic_store(&cur->job, NULL); // signal waiter its job is done
  }
}
```
> [!bug] Subtle Typo in Repo's `flat.c`
> In the repo's `flat.c`, line 51 wrote `atomic_store(&cur->is_combiner, true);` instead of `cur->next->is_combiner`! Handing off to `cur->next` (the next unexecuted waiter) is what wakes the new combiner. Similarly, in `mcs.c`, `atomic_store(&my.next->is_busy, true)` should be `false`.
