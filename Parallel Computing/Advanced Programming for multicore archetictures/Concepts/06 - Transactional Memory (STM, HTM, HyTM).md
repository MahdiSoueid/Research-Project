---
title: Transactional Memory (STM, HTM, HyTM)
aliases:
  - Transactional Memory
  - STM
  - HTM
  - HyTM
  - Zombie Transactions
course: CSC5101
week: 4
type: concept
tags:
  - csc5101/tm
  - stm
  - htm
  - concurrency
---

# 06 — Transactional Memory (STM, HTM, HyTM)

Up: [[00 - CSC5101 Index (MOC)]] | Prev: [[05 - Safe Memory Reclamation (ABA, Hazard Pointers, RCU)]] | Next: [[07 - Persistent Memory (NVMM and Crash Consistency)]]  
Lab: [[Lab 04 - Global-Clock STM Runtime]]

---

## 1. Motivation & High-Level API

### Why Locks and Lock-Free Algorithms Hurt Productivity
- Coarse-grained locks bottleneck concurrency ([[04 - Non-Blocking Data Structures#1. Motivation: Amdahl's Law|Amdahl's Law]]).
- Fine-grained locking and lock-free algorithms are complex, hard to prove, prone to lock-ordering deadlocks, and **not composable** (you cannot trivially compose two lock-free queues into an atomic `move(src, dst)`).

### The Universal Construct: `atomic { ... }`
A block of code that appears to execute instantaneously (all-or-nothing, isolated from other transactions). No locks to name or order; avoids deadlocks and starvation.

### Composability, `retry`, and `orElse`
1. **Nested composition:** Calling two `atomic` functions inside an outer `atomic` block executes both atomically as one transaction:
   ```c
   atomic void move(Queue dst, Queue src) {
     Elmt e = src.deq(); // atomic
     dst.enq(e);         // atomic
   }
   ```
2. **`retry` (Harris '05) — replaces condition variables:**
   - Aborts the transaction and puts the thread to sleep until **any variable in its read-set is modified**, then restarts.
   - **Composable:** A `retry` inside a nested transaction restarts from the **outermost** transaction!
   ```c
   atomic {
     while (!x) retry; // waits with read-set = {x}
   }
   ```
3. **`orElse` — composability by alternative:**
   - Converts a blocking operation (using `retry`) into a non-blocking one. If the first block executes `retry`, control rolls back and executes the `orElse` block instead:
   ```c
   Elmt deqNoWait() {
     atomic {
       return deq();   // retries if queue is empty
     } orElse {
       return NULL;
     }
   }
   ```

---

## 2. TM Runtime Design Space

### Pessimistic vs. Optimistic
- **Pessimistic:** Acquire one global lock around every `atomic` block → simple, terrible parallelism.
- **Optimistic:** Execute concurrently without locking; track read-set and write-set; **abort & restart** if a conflict occurs.

### Read-Write Conflicts
A conflict occurs when a transaction cannot be serialized atomically:
1. **Double-write conflict (dirty read):** Tx X writes `b` then `c` to `A`; Tx Y reads ephemeral `b` (which would never exist if X were atomic).
2. **Double-read conflict (non-repeatable read):** Tx Y reads `a` then `b` from `A` while Tx X modifies `A` to `b` during Y's execution.

### Update Strategy: Deferred (Redo Log) vs. Immediate (Undo Log)

| Aspect | Deferred Update (Redo Log) | Immediate Update (Undo Log) |
|---|---|---|
| **Writes during Tx** | Buffered in thread-local redo log | Written directly to main memory; old values saved in undo log |
| **On Commit** | Replay redo log into main memory (more work on commit) | Discard undo log (fast commit) |
| **On Abort** | Discard local log (fast abort) | Replay undo log to restore memory (more work on abort) |
| **Best Workload** | Many aborts | Many commits |
| **Conflicts** | **Eliminates double-write conflicts by design** (only double-read remains) | Subject to **both** double-write and double-read conflicts |

### Conflict Detection: Eager vs. Lazy
- **Eager:** Check for conflicts on every read/write (higher instrumentation overhead, catches conflicts immediately).
- **Lazy:** Validate conflicts only at commit time (less overhead, **but suffers from Zombie Transactions**).

---

## 3. Zombie Transactions & The Global-Clock STM Algorithm

### What Is a Zombie Transaction?
In a purely lazy STM, a doomed transaction continues executing on an **inconsistent memory snapshot** before reaching commit:
1. **Example 1 (Null Dereference):** `atomic { if (x != NULL) x->f(); }` — reads `x != NULL`, concurrent Tx sets `x = NULL` and commits, first Tx re-reads `x` and crashes with `NullPointerException` / segfault before reaching commit validation!
2. **Example 2 (Invariant Violation / Divide-by-Zero):** Initially `x = 4, y = 5` (invariant `x != y`). Tx1 reads `t1 = x` (`4`). Tx2 updates `x = 217, y = 4` and commits. Tx1 reads `t2 = y` (`4`) and computes `1 / (t1 - t2)` → **division by zero!** Simply re-checking `x`'s counter doesn't help because `y` had never been read before!

### Solution: Global Version Clock (TL2-Style STM)
- Memory is an array of pointers to **immutable** `(value, counter)` cells (never mutate an existing cell in place — allocate a new cell and swap the pointer).
- Maintain a monotonic global `memory.clock` (initialized to `1`).
- **Invariant:** Every read by transaction `tx` must see `cell->counter < tx.clock`.

```c
struct cell { int value; int counter; };
struct memory {
  pthread_mutex_t lock;
  struct cell* _Atomic values[N];
  _Atomic int clock;
};
struct tx {
  int readSet[N], writeSet[N], values[N];
  int clock;
  long long backoff;
};
_Thread_local struct tx tx;

void startTX(void) {
  memset(tx.readSet, 0, sizeof(tx.readSet));
  memset(tx.writeSet, 0, sizeof(tx.writeSet));
  tx.clock = atomic_load(&memory.clock);
}

void writeValue(int idx, int val) {
  tx.writeSet[idx] = 1;
  tx.values[idx] = val; // deferred update (redo log)
}

int readValue(int idx) {
  if (tx.writeSet[idx])
    return tx.values[idx]; // read-your-own-writes

  tx.readSet[idx] = 1;
  struct cell* c = atomic_load(&memory.values[idx]);
  if (c->counter >= tx.clock)
    return ABORT; // kills zombie transactions immediately!
  return c->value;
}

int commitTX(void) {
  pthread_mutex_lock(&memory.lock);
  for (int i = 0; i < N; i++) {
    if (tx.readSet[i] && atomic_load(&memory.values[i])->counter >= tx.clock) {
      pthread_mutex_unlock(&memory.lock);
      return ABORT;
    }
  }
  int commit_clk = atomic_load(&memory.clock);
  for (int i = 0; i < N; i++) {
    if (tx.writeSet[i])
      atomic_store(&memory.values[i], newValue(tx.values[i], commit_clk));
  }
  atomic_store(&memory.clock, commit_clk + 1);
  pthread_mutex_unlock(&memory.lock);
  return 0;
}
```

> [!bug] Subtle Bug in Repo's `stm/main.c`
> In the course repository's `stm/main.c`, `readValue` checks `if (value->counter >= memory.clock)` instead of `tx.clock` (the slides correctly use `tx.clock`!). Checking against `tx.clock` is what guarantees a consistent snapshot from the transaction's start time and eliminates Example 2's zombie transaction.

### Practical Issues in STM
- **Memory Reclamation:** Old `(value, counter)` cells cannot be immediately freed on commit because concurrent readers may still hold pointers to them → requires garbage collection or [[05 - Safe Memory Reclamation (ABA, Hazard Pointers, RCU)#2. Hazard Pointers (Maged Michael, TPDS 2004)|Hazard Pointers]].
- **Livelock & Exponential Backoff:** Two conflicting transactions can abort each other endlessly. On abort, sleep/spin for a random delay in `[0, backoff)` and double `backoff` (capped, e.g., at 512). *Slide benchmark (100 threads × 10,000 increments, 2 cores): 3.0s STM without backoff → 0.48s STM with backoff → 0.19s mutex lock.*
- **I/O inside Transactions (`launchMissile()`):** External side effects cannot be rolled back on abort. Before executing I/O, the runtime must validate the transaction and mark it **irrevocable / unabortable** (complicates runtime).

---

## 4. Implementation Techniques: HTM, STM, HyTM

| Technique | How It Works | Pros | Cons / Main Limitation |
|---|---|---|---|
| **HTM** (Hardware TM) | CPU **L1 cache naturally implements the redo log** (speculative writes stay buffered in private cache lines until commit, discarded on abort; cache coherence protocol detects read/write conflicts) | Very fast (hardware speed) | **Limited to L1 cache capacity** — large transactions (or interrupts/syscalls) always abort |
| **STM** (Software TM) | Compiler instruments reads/writes in software | Unlimited transaction size | High instrumentation overhead; slower than fine-grained locks |
| **HyTM** (Hybrid TM) | Attempts HTM first; falls back to STM on capacity/persistent abort | Best of both in theory | Switching & coordinating between HTM and STM paths is costly |

---

## Related Notes
- [[Lab 04 - Global-Clock STM Runtime]]
- [[Past Exam 2021-2022 - Radix Tree]] (Q6: adapting radix tree to TM)
- [[Past Exam 2022-2023 - Barrier and Flat Combining]] (Q5: barrier with `atomic` + `retry`)
- [[Past Exam 2024-2025 - Userspace RCU]] (Redo vs Undo logs)
- [[Past Exam 2025-2026 - Work-Stealing Scheduler]] (HTM redo log & limitation)
