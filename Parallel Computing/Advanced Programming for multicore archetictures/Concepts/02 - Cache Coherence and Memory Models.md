---
title: Cache Coherence and Memory Models
aliases:
  - Memory Models
  - Cache Coherence
  - TSO
  - C11 Atomics
course: CSC5101
week: 2
type: concept
tags:
  - csc5101/memory-model
  - csc5101/hardware
  - atomics
---

# 02 — Cache Coherence and Memory Models

Up: [[Parallel Computing/Advanced Programming for multicore archetictures/Readme]] | Prev: [[01 - Processes, Threads and Monitors]] | Next: [[03 - Lock Algorithms and Futexes]]

---

## 1. Why the Naive Abstract Machine Fails

When reasoning about algorithms like [[03 - Lock Algorithms and Futexes#1. Lamport's Bakery Algorithm (1974)|Lamport's Bakery]], we initially assume a simple machine that:
1. Atomically reads and writes machine words (32-bit / 64-bit), and
2. Never reorders instructions.

**Neither assumption holds in general** across modern CPUs, compilers, and languages!

---

## 2. Hardware Cache Coherence Protocol

CPU caches hold copies of memory in **64-byte cache lines** (on x86-64/Pentium). The coherence protocol acts like a hardware **read-write lock** per cache line:
- **Shared state:** Multiple cores may hold read-only copies simultaneously.
- **Exclusive state:** At most **one** core holds the line to perform a write (preventing lost writes when two threads write adjacent elements in the same 64B cache line, e.g., `tab[0] = 42` and `tab[1] = 666`).

### State Transitions
1. **Load miss (not in cache):** Fetch line from another core or RAM; ensure no other core keeps it in Exclusive state; mark **Shared**.
2. **Store miss (not in cache):** Fetch line; **invalidate** all copies in other cores; mark **Exclusive**.
3. **Store hit on Shared line:** **Invalidate** all copies in other cores; upgrade to **Exclusive**.

> [!important] Core Consequence for Multicore Algorithms
> Whenever multiple threads running on different cores **write to the same cache line**, the cache line bounces between cores and **saturates the memory bus**. Good synchronization algorithms avoid concurrent writes to the same memory location (see [[03 - Lock Algorithms and Futexes]]).

---

## 3. Load/Store Atomicity in C11

Without atomic operations, a word write such as `x = 0x101` (from `0`) is not guaranteed to be atomic in general—another thread could observe torn values like `0x100` or `0x001`.

In C11 (`<stdatomic.h>`):
- Declare shared variables with `_Atomic`:
  - `int _Atomic var;`
  - `struct node* _Atomic ptr;` *(an atomic pointer to `struct node`, NOT a pointer to an atomic struct!)*
- Access them via `atomic_load(&var)` and `atomic_store(&var, val)`.
- These guarantee **both atomicity and sequential consistency** by default.

---

## 4. Out-of-Order Execution & Memory Ordering

A CPU (or compiler) may reorder instructions on **different memory addresses** as long as single-thread semantics are preserved (a thread always reads its own last write).

The **4 possible reorderings** on distinct addresses `@a1 != @a2`:
1. **Store-Store (SS):** `store @a1, v1` reordered with `store @a2, v2`
2. **Load-Load (LL):** `load @a1` reordered with `load @a2`
3. **Load-Store (LS):** `load @a1` reordered with `store @a2, v2`
4. **Store-Load (SL):** `store @a1, v1` reordered with `load @a2`

### Hardware & Language Models

| Architecture / Model | Guarantees | Allowed Reorderings |
|---|---|---|
| **Intel x86-64 / Pentium (TSO — Total Store Order)** | Atomic 64-bit loads/stores; forbids **LL, SS, LS** | **Store-Load (SL) ONLY** |
| **ARM** | Weaker than TSO | SS, LL, LS, SL (all 4) |
| **Java Memory Model (JMM)** | Ordered only around `volatile` and `synchronized` | Any reordering otherwise |
| **C non-atomic / `memory_order_relaxed`** | `relaxed` guarantees word atomicity only | Any reordering |

### Classic Message-Passing Example (Exam Favorite!)

```c
bool ok = false;
char* msg = NULL;

// Thread 1                 // Thread 2
msg = "hello";              while (!ok) { }
ok = true;                  printf(msg);
```

- **On Intel x86-64 (TSO):** **Safe** (cannot segfault). Thread 1 performs Store-Store (never reordered on TSO) and Thread 2 performs Load-Load (never reordered on TSO).
- **On ARM / Java / Relaxed C:** **Can segfault!** Thread 1 may reorder `ok = true` before `msg = "hello"` (SS), OR Thread 2 may speculatively load `msg` (`NULL`) before `ok` becomes `true` (LL), passing `NULL` to `printf`.
- **Store-Buffering (SL) Counterexample on TSO:** If Thread 1 runs `x = 1; r1 = y;` and Thread 2 runs `y = 1; r2 = x;`, then **`r1 == 0 && r2 == 0` IS possible even on Intel TSO**, because TSO allows Store-Load reordering!

> [!example] 3-Thread Transitivity Puzzle ([[Past Exam 2021-2022 - Radix Tree]])
> `ok1 = ok2 = msg1 = msg2 = 0;`
> - T1: `a. msg1 = 42; b. ok1 = 1;`
> - T2: `c. while(ok1 == 0){} d. msg2 = msg1; e. ok2 = 1;`
> - T3: `f. while(ok2 == 0){} g. printf("%d %d\n", msg1, msg2);`
>
> Even on a machine forbidding LL and SS, **Load-Store** reordering lets T2 reorder `d` and `e` *before* `c` (since `c` is a read and `d, e` are writes). Possible outputs: `"0 0"`, `"42 0"`, `"42 42"`. Output `"0 42"` is **impossible** (if `msg2 == 42`, `msg1` had already been written `42` before `d`).

---

## 5. Hardware Memory Fences (x86-64)

- **`mfence`:** Full fence — prevents reordering of any loads or stores across it.
- **`lfence`:** Load fence — prevents reordering of loads across it (useful for instructions with load semantics like `rdtsc`).
- **`sfence`:** Store fence — prevents reordering of stores across it (critical for instructions with store semantics like `clwb` in [[07 - Persistent Memory (NVMM and Crash Consistency)]]).

---

## 6. C11 Memory Ordering Semantics

Using `atomic_load_explicit(&addr, order)` and `atomic_store_explicit(&addr, val, order)`:

1. **`memory_order_relaxed`:** Atomicity only (no torn reads/writes), any reordering allowed.
2. **`memory_order_consume`:** Like `acquire`, but only for variables carrying a data dependency. *Confusing and buggy in compilers — discouraged.*
3. **`memory_order_release` / `memory_order_acquire`:**
   - Every visible effect *before* a `release` store is visible to any thread that observes that store via an `acquire` load.
   - No effect *after* an `acquire` load can be reordered before the matching `release` store.
   - Sufficient for message passing and mutex/spinlock lock (`acquire`) & unlock (`release`)!
4. **`memory_order_acq_rel`:** Both `acquire` and `release` (for RMW operations).
5. **`memory_order_seq_cst` (Default):** Release-acquire **plus** a single global total order of all `seq_cst` operations seen identically by all threads.

### Why `seq_cst` Is Strictly Stronger Than `release`/`acquire` (IRIW Example)

```c
_Atomic int x = 0, y = 0;
// T1: atomic_store(&x, 1);                     // A
// T2: atomic_store(&y, 1);                     // B
// T3: r1 = atomic_load(&x); r2 = atomic_load(&y);
// T4: r3 = atomic_load(&x); r4 = atomic_load(&y);
```
- Under **`seq_cst`**: If T3 observes `r1 = 1, r2 = 0` (`A` before `B`), T4 **cannot** observe `r3 = 0, r4 = 1` (`B` before `A`).
- Under **`release`/`acquire` alone**: `r1 = 1, r2 = 0` AND `r3 = 0, r4 = 1` **is possible** because there is no global consensus on the order of unrelated stores `A` and `B`.

---

## Related Notes
- [[03 - Lock Algorithms and Futexes]] (how cache coherence & memory ordering govern atomic LMS cost)
- [[07 - Persistent Memory (NVMM and Crash Consistency)]] (why `mfence` alone does NOT guarantee persistence ordering)
- [[Past Exam 2021-2022 - Radix Tree]] | [[Past Exam 2023-2024 - Lock-Free Memory Allocator]] | [[Past Exam 2024-2025 - Userspace RCU]]
