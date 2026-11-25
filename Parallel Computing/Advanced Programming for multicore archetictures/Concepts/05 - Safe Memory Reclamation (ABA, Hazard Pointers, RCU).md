---
title: Safe Memory Reclamation (ABA, Hazard Pointers, RCU)
aliases:
  - ABA Problem
  - Hazard Pointers
  - RCU
  - Read-Copy-Update
  - Safe Memory Reclamation
course: CSC5101
week: 3
type: concept
tags:
  - csc5101/reclamation
  - csc5101/non-blocking
  - aba
  - hazard-pointers
  - rcu
---

# 05 — Safe Memory Reclamation (ABA, Hazard Pointers, RCU)

Up: [[Parallel Computing/Advanced Programming for multicore archetictures/Readme]] | Prev: [[04 - Non-Blocking Data Structures]] | Next: [[06 - Transactional Memory (STM, HTM, HyTM)]]

---

## 1. Why `free()` Breaks Lock-Free Data Structures

In [[04 - Non-Blocking Data Structures]], `pop()` and `dequeue()` never called `free()` on removed nodes. Calling `free()` immediately causes **two catastrophic bugs**:

### Bug 1: Use-After-Free (Segmentation Fault)
1. Stack is `A -> B`. Thread 1 loads `exp = A`, then pauses *before* reading `exp->next`.
2. Thread 2 pops `A` and executes `free(A)`.
3. Thread 1 resumes and dereferences `exp->next` → **Segmentation Fault**.

### Bug 2: The ABA Problem
Even if memory isn't unmapped, `malloc()` can recycle the exact same address `A`:
1. Stack is `A -> B -> C`. Thread 1 reads `exp = A` and `next = B`, then pauses before its CAS.
2. Thread 2 pops `A`, pops `B` (and frees `B`), reallocates a new node at address `A`, and pushes `A` back. Stack is now `A -> C`.
3. Thread 1 resumes and executes `CAS(&head, A, B)`. Since `head == A`, **the CAS succeeds!** `head` now points to the **freed node `B`**, corrupting the stack and leaking `C`.

---

## 2. Hazard Pointers (Maged Michael, TPDS 2004)

**Principle:** Prevent any node `X` from being freed or reused while *any* thread holds a local pointer to `X` and intends to dereference or CAS it.

### Protocol
1. Each thread owns a globally visible `_Atomic` slot (`all_threads[i].hazard`), accessible via `_Thread_local self->hazard`.
2. **Protect before dereferencing:**
   - Load `X = atomic_load(&shared_ptr)`.
   - Publish `atomic_store(&self->hazard, X)`.
   - **Re-validate:** Check `if (atomic_load(&shared_ptr) != X) retry;`.
3. **Clear after operation:** `atomic_store(&self->hazard, NULL)`.
4. **Deferred Reclamation (`free_nodes`):**
   - Instead of calling `free(X)`, push `X` onto a lock-free retirement stack `free_nodes`.
   - When allocating a node, pop `Z` from `free_nodes`. Scan all threads' `hazard` pointers:
     - If `Z` is found in any thread's `hazard` slot → re-push `Z` to `free_nodes` and call `malloc()`.
     - Otherwise → `Z` is guaranteed unreferenced and can be safely reused!

```c
bool is_hazardous(struct node* ptr) {
  for (size_t i = 0; i < nb_threads; i++)
    if (atomic_load(&all_threads[i].hazard) == ptr)
      return true;
  return false;
}

int safe_pop(void) {
  struct node *n, *next;
  while (true) {
    n = atomic_load(&stack_head);
    if (!n) {
      atomic_store(&self->hazard, NULL);
      return -1;
    }
    atomic_store(&self->hazard, n);
    if (atomic_load(&stack_head) != n)
      continue; // Mandatory re-validation!

    next = atomic_load(&n->next);
    if (atomic_compare_exchange_strong(&stack_head, &n, next))
      break;
  }
  int val = n->value;
  atomic_store(&self->hazard, NULL);
  free_list_push(n);
  return val;
}
```

> [!warning] Why Re-Validation Is Strictly Mandatory
> Without `if (atomic_load(&stack_head) != n) continue;`: T1 loads `n = A` and pauses *before* writing `self->hazard = A`. T2 pops `A`, retires `A`, scans all hazard slots (does not see `A`), and recycles/frees `A`. T1 then writes `self->hazard = A` *too late* and dereferences a freed/reused node!

> [!question] Lab 03 Bonus Question: Why can a node never appear twice in `free_nodes`?
> A node enters `free_nodes` only from the single thread whose CAS atomically unlinked it from the data structure (or when `alloc_node` popped it exclusively from `free_nodes` and re-pushed it). It cannot re-enter the data structure until a single thread exclusively pops it from `free_nodes`, so two threads can never simultaneously retire the same node.

---

## 3. Read-Copy-Update (RCU)

**Principle:** Optimized for read-heavy workloads. Readers run **completely lock-free with near-zero overhead** (just setting a per-thread flag). Deletion is split into two phases:
1. **Removal phase:** Atomically unlink the object from the data structure (invisible to future readers, but in-flight readers may still hold a pointer to it).
2. **Grace period (`rcu_synchronize`) & Free phase:** Wait until every thread has passed through a quiescent state (not inside an RCU read section), then safely `free()`.

### Userspace RCU Implementation (from [[Past Exam 2024-2025 - Userspace RCU]])

```c
struct thread {
  pthread_t tid;
  _Atomic bool is_reader;
};

_Thread_local struct thread* self;
struct thread* all_threads;
size_t nb_threads;

void rcu_read_lock(void)   { atomic_store(&self->is_reader, true); }
void rcu_read_unlock(void) { atomic_store(&self->is_reader, false); }

void rcu_synchronize(void) {
  for (size_t i = 0; i < nb_threads; i++) {
    while (atomic_load(&all_threads[i].is_reader)) {
      /* wait for thread i to exit its read-side critical section */
    }
  }
}
```

### Usage Pattern (Readers vs. Writers)
- **Readers:** `rcu_read_lock()` → traverse with `atomic_load` → `rcu_read_unlock()`.
- **Writers:** RCU protects readers from writers, **not writers from other writers**! Serialize writers with a `pthread_mutex_t write_lock`:
  1. Lock `write_lock`.
  2. Unlink node via `atomic_store(&prev->next, cur->next)` (or update head).
  3. Unlock `write_lock`.
  4. Call `rcu_synchronize()` *(outside `write_lock` to avoid blocking other writers unnecessarily, or inside if simpler)*.
  5. Call `free(deleted)`.

> [!note] Correctness Intuition
> Suppose T1 unlinks `obj` and then calls `rcu_synchronize()`. The moment `rcu_synchronize()` observes `all_threads[i].is_reader == false`, thread `i` holds no reference to `obj`. Because `obj` was already unlinked before `rcu_synchronize()` began, thread `i` can never acquire a pointer to `obj` again—even if thread `i` immediately re-enters `rcu_read_lock()`.

---

## Related Notes
- [[04 - Non-Blocking Data Structures]]
- [[06 - Transactional Memory (STM, HTM, HyTM)]] *(STM also needs GC or Hazard Pointers to reclaim old `(value, counter)` cells)*
- [[Lab 03 - Lock-Free Queue, Stack, Radix Tree, Linked List]]
- [[Past Exam 2024-2025 - Userspace RCU]]
