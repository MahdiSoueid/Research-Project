---
title: Lock Algorithms and Futexes
aliases:
  - Locks
  - Spinlock
  - Ticket Lock
  - MCS Lock
  - Bakery Algorithm
  - Futex
course: CSC5101
week: 2
type: concept
tags:
  - csc5101/locks
  - csc5101/synchronization
---

# 03 — Lock Algorithms and Futexes

Up: [[00 - CSC5101 Index (MOC)]] | Prev: [[02 - Cache Coherence and Memory Models]] | Next: [[04 - Non-Blocking Data Structures]]  
Lab: [[Lab 02 - Lock Benchmarks and Futex Mutex]]

---

## 1. Lamport's Bakery Algorithm (1974)

Constructs mutual exclusion using **only atomic word loads/stores** (no hardware RMW instructions, assuming sequential consistency):
- Each thread takes a ticket number `1 + max(num[0..N-1])`.
- Ties are broken by thread ID (`i < self`).

```c
bool entering[N]; // initialized to false
int  num[N];      // initialized to 0

void lock(int self) {
  entering[self] = true;
  num[self] = 1 + max(num[0], ..., num[N-1]);
  entering[self] = false;

  for (int i = 0; i < N; i++) {
    while (entering[i]) { }
    while (num[i] != 0 && (num[i] < num[self] || (num[i] == num[self] && i < self))) { }
  }
}

void unlock(int self) {
  num[self] = 0;
}
```

> [!important] Why `entering[N]` Is Strictly Necessary
> Without `entering[]`: Thread 2 and Thread 3 enter simultaneously. T2 computes `max + 1` (say `1`) and is preempted *before* writing `num[2]`. T3 computes the same `1`, sees `num[2] == 0`, and enters the CS. T2 resumes, writes `num[2] = 1`, sees `num[3] == 1` and `2 < 3`, and **also enters the CS**! `entering[2] == true` forces T3 to wait until T2 finishes storing `num[2]`.

- **Limitation:** Slow — reads at least $4N$ memory locations per acquisition ($O(N)$ reads: computing max, checking `entering`, checking `num`).

---

## 2. Hardware Atomic Load-Modify-Store (LMS) Instructions

Three fundamental C11 RMW primitives (`<stdatomic.h>`):
1. **`atomic_exchange(&addr, val)`**: Atomically swaps `*addr` with `val` and returns the old `*addr`.
2. **`atomic_fetch_add(&addr, delta)`**: Atomically adds `delta` to `*addr` and returns the **old** `*addr`.
3. **`atomic_compare_exchange_strong(&addr, &expected, desired)`**:
   - If `*addr == *expected`: sets `*addr = desired` and returns `true`.
   - Else: **overwrites `*expected = *addr`** and returns `false`.

> [!important] Why Atomic LMS Operations Are Expensive (Key Exam Insight)
> On x86-64, atomicity does **not** require global consensus with other cores — the core simply acquires the cache line in Exclusive state and locks it locally in its **L1 cache** for a few cycles.
>
> **Atomicity itself is NOT the performance bottleneck!** The actual overhead comes from:
> 1. **Cache-line invalidation traffic** caused by the write (evicting copies in all other cores), and
> 2. **Memory ordering constraints** preventing out-of-order CPU execution.

---

## 3. Active Waiting (Spinning) Lock Algorithms

### A. Spinlock (Test-and-Set via `atomic_exchange`)

```c
int _Atomic slock = 0;

void spin_lock(void) {
  while (atomic_exchange(&slock, 1) != 0) {
    asm volatile("pause");
  }
}

void spin_unlock(void) {
  atomic_store(&slock, 0); // release semantics suffice
}
```
- **Pros:** Minimal overhead when uncontended; tiny footprint.
- **Cons:** Terrible under contention — every spin iteration executes a **write** (`atomic_exchange`), invalidating the cache line in every other core and saturating the memory bus. Unfair (starvation possible).

### B. Ticket Lock (via `atomic_fetch_add`)
Used in the Linux kernel. Analogous to a post-office ticket counter + display screen.

```c
struct ticket_lock {
  uint64_t _Atomic counter;
  uint64_t _Atomic screen;
};

void ticket_lock(struct ticket_lock* t) {
  uint64_t my = atomic_fetch_add(&t->counter, 1);
  while (atomic_load(&t->screen) < my) {
    asm volatile("pause");
  }
}

void ticket_unlock(struct ticket_lock* t) {
  atomic_fetch_add(&t->screen, 1);
}
```
- **Pros:** FIFO **fair**; waiting threads spin on a **read-only `atomic_load`** (cache line stays Shared, avoiding continuous invalidation storms during spinning).
- **Cons:** All waiting threads still spin on the **same memory location** (`screen`), so every `unlock` causes a broadcast invalidation across all waiting cores.

### C. MCS Lock (Mellor-Crummey & Scott, ASPLOS 1991)
Maintains an explicit FIFO queue of `_Thread_local` nodes so every waiting thread spins on its **own private cache line**.

```c
struct node {
  struct node* _Atomic next;
  bool _Atomic is_free;
};

_Thread_local struct node my;
struct node* _Atomic lock = NULL; // points to tail of waiting queue

void mcs_lock(void) {
  my.next = NULL;
  my.is_free = false;
  struct node* pred = atomic_exchange(&lock, &my);
  if (pred != NULL) {
    atomic_store(&pred->next, &my);
    while (!atomic_load(&my.is_free)) {
      asm volatile("pause");
    }
  }
}

void mcs_unlock(void) {
  struct node* expected = &my;
  if (!atomic_load(&my.next) &&
      atomic_compare_exchange_strong(&lock, &expected, NULL))
    return; // no successor

  // A successor swapped lock, wait until it links pred->next = &its_node
  while (!atomic_load(&my.next)) {
    asm volatile("pause");
  }
  atomic_store(&my.next->is_free, true);
}
```
- **Pros:** Totally fair (FIFO); zero shared-line spinning (each waiter spins locally on `my.is_free`); `unlock` wakes **only** `my.next` (1 cache-line transfer).
- **Cons:** Subject to the **convoy effect** when `#threads > #cores` (if the next thread in FIFO order is preempted by the OS, everyone behind it stalls waiting for it to be scheduled).

> [!tip] Why `asm volatile("pause")` Matters on Intel CPUs
> Intel processors execute spinloops speculatively, queueing many loads assuming the condition stays false. When the condition flips to true, the CPU must abort and flush the speculative pipeline, adding latency. `pause` throttles speculative loads and improves reactivity upon lock handoff.

---

## 4. Passive Waiting & Linux Futexes

Active waiting burns CPU cycles when critical sections are long or threads outnumber cores. POSIX mutexes (`pthread_mutex_t`) use **passive waiting** via Linux **futexes** (*Fast Userspace Mutexes*):
- `futex_wait(addr, val)`: Atomically sleeps in the kernel **if and only if** `*addr == val` (prevents lost wakeups!).
- `futex_wake(addr, n)`: Wakes up to `n` threads sleeping on `addr`.

### 3-State Futex Mutex (Fast-Path Optimization)
By distinguishing `BUSY_NO_WAITER` from `BUSY_WITH_WAITERS`, uncontended lock/unlock performs **zero system calls**.

```c
enum { FREE = 0, BUSY_NO_WAITER = 1, BUSY_WITH_WAITERS = 2 };
typedef struct { uint32_t _Atomic state; } futex_lock_t;

void futex_lock(futex_lock_t* l) {
  uint32_t exp = FREE;
  if (!atomic_compare_exchange_strong(&l->state, &exp, BUSY_NO_WAITER)) {
    do {
      if (exp == BUSY_WITH_WAITERS ||
          atomic_compare_exchange_strong(&l->state, &exp, BUSY_WITH_WAITERS))
        futex_wait(&l->state, BUSY_WITH_WAITERS);
      exp = FREE;
    } while (!atomic_compare_exchange_strong(&l->state, &exp, BUSY_WITH_WAITERS));
  }
}

void futex_unlock(futex_lock_t* l) {
  uint32_t exp = BUSY_NO_WAITER;
  if (!atomic_compare_exchange_strong(&l->state, &exp, FREE)) {
    atomic_store(&l->state, FREE);
    futex_wake(&l->state, 1);
  }
}
```

---

## 5. Summary Comparison

| Algorithm | Waiting Mode | Fair? | Contention Behavior | Main Drawback |
|---|---|---|---|---|
| **Bakery** | Active | Yes | $O(N)$ reads per lock | High read overhead |
| **Spinlock (TAS)** | Active | No | Write on every spin → bus saturation | Cache-line bouncing, unfair |
| **Ticket** | Active | Yes | Read-only spin on shared `screen` | Broadcast invalidation on unlock |
| **MCS** | Active | Yes | Local-only spin; point-to-point wakeup | Convoy effect if oversubscribed |
| **Futex / POSIX** | Passive | OS-dep. | Yields CPU to OS when contended | Syscall overhead on contention |

---

## Related Notes
- [[02 - Cache Coherence and Memory Models]]
- [[Lab 02 - Lock Benchmarks and Futex Mutex]]
- [[Past Exam 2022-2023 - Barrier and Flat Combining]] (Futex barrier & MCS-based Flat Combining)
- [[Past Exam 2025-2026 - Work-Stealing Scheduler]] (Theory Q2: Ticket vs Spinlock vs MCS)
