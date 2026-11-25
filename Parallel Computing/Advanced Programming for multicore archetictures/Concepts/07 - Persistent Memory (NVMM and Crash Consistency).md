---
title: Persistent Memory (NVMM and Crash Consistency)
aliases:
  - Persistent Memory
  - NVMM
  - PMEM
  - DAX
  - eADR
  - pwb pfence psync
course: CSC5101
week: 5
type: concept
tags:
  - csc5101/nvmm
  - pmem
  - crash-consistency
---

# 07 — Persistent Memory (NVMM and Crash Consistency)

Up: [[00 - CSC5101 Index (MOC)]] | Prev: [[06 - Transactional Memory (STM, HTM, HyTM)]] | Extra: [[08 - NUMA Architecture (Extra)]]  
Lab: [[Lab 05 - NVMM Write-Ahead Cache (NVCache)]]

---

## 1. What Is Persistent Memory (PMEM / NVMM)?

**Non-Volatile Main Memory** combines:
- **Byte-addressability** directly by the CPU over the memory bus using standard `load`/`store` instructions (like DRAM), and
- **Durability** across power failures (like SSD/flash).

### Performance Characteristics (Lecture Benchmarks)

| Technology | Seq. Read | Seq. Write | Seq. BW | Rand. Read | Rand. Write | Rand. BW |
|---|---:|---:|---:|---:|---:|---:|
| **DDR4** | 80 ns | 60 ns | ~100 Gbps | 100 ns | 60 ns | ~100 Gbps |
| **Intel Optane DC (PMEM)** | 160 ns | 60 ns | 40 Gbps | 300 ns | 120 ns | 14 Gbps |
| **NVMe SSD** | 250 µs | 250 µs | 3 Gbps | 250 µs | 250 µs | 3 Gbps |

- Latency: ~2× slower than DDR4, **1,000×–10,000× faster** than NVMe.
- Throughput: 2×–4× lower than DDR4, **4×–10× higher** than NVMe.

---

## 2. Linux DAX Access (`mmap` Without Page Cache)

- **Standard disk `mmap`:** Copies file data from disk into volatile RAM (**Linux Page Cache**), maps page cache into process virtual memory, and later copies dirty pages back to disk.
- **DAX (Direct Access) filesystem (`ext4-dax`) on PMEM:** `mmap` maps the physical PMEM pages **directly** into the process's page table — **zero copy**! Standard loads/stores access PMEM directly, and after power loss, re-mapping the file immediately recovers its contents.

```c
int fd = open("/mnt/pmem/fic1", O_RDWR | O_CREAT, 0644);
ftruncate(fd, size);
// Real DAX NVMM:
void* addr = mmap(NULL, size, PROT_READ | PROT_WRITE,
                  MAP_SHARED_VALIDATE | MAP_SYNC, fd, 0);
// Regular file simulation (without real NVMM hardware):
// use MAP_SHARED instead of (MAP_SHARED_VALIDATE | MAP_SYNC)
```

---

## 3. Crash Consistency & Persistence Ordering

A power failure can happen at **any instruction**, leaving multi-word writes (e.g., `strcpy(id->name, "Pikachu")`) partially written. We want **failure-atomic blocks** (all-or-nothing across crashes), e.g., writing data first and then setting `id->committed = true`.

### Why Normal Memory Fences (`mfence`) Are NOT Enough!
CPU caches are **volatile** (unless eADR is present) and evict dirty cache lines to NVMM in **arbitrary order**. A memory fence (`mfence`) only enforces visibility ordering *between CPU cores* (see [[02 - Cache Coherence and Memory Models]]); it does **not** control the order in which cache lines are flushed to persistent memory!

### The Three Abstract Persistence Primitives (Izraelevitz et al., DISC 2016)

1. **`pwb(addr)`** (*Persistent Write-Back*): Enqueues the 64B cache line containing `addr` into a flush queue toward NVMM.
2. **`pfence()`** (*Persistence Fence*): Ensures all preceding stores and `pwb`s are ordered before all succeeding stores and `pwb`s (guarantees **order**, NOT immediate completion).
3. **`psync()`** (*Persistence Sync*): Acts as a `pfence()` **AND guarantees the flushed cache lines have actually reached NVMM** (needed before sending an external `ack` to a user or returning from a durable API).

### Intel x86-64 Hardware Implementation (`nvmm.h`)

```c
// Compile with -march=native
static void pwb(void* p) { asm volatile("clwb (%0)\n\t" : : "r"(p) : "memory"); }
static void pfence(void) { asm volatile("sfence" ::: "memory"); }
static void psync(void)  { asm volatile("sfence" ::: "memory"); }
```
*(Fallback if CPU lacks `clwb`: `clflushopt` + `sfence`, or `clflush` which is already strongly ordered.)*

> [!important] Recurring Exam Questions: Why Is Intel's `sfence` Sufficient?
> 1. **Why `sfence` suffices for `pfence`:** Intel x86-64 is TSO, so regular stores are already never reordered with each other. `clwb` has **store semantics**, so `sfence` additionally prevents `clwb` from being reordered with stores or other `clwb`s.
> 2. **Why `sfence` suffices for `psync`:** Intel platforms supporting PMEM implement **ADR** (Asynchronous DRAM Refresh), which provides enough residual power on power failure to drain pending memory-controller write queues into NVMM once `sfence` pushes the flush into the ADR domain.
> 3. **What changes with eADR (Enhanced ADR)?** ([[Past Exam 2021-2022 - Radix Tree]]) eADR provides enough residual power to flush **CPU caches** into NVMM on power loss:
>    - **`pwb` is NO LONGER required** (dirty cache lines will be flushed automatically on power failure).
>    - **`pfence` IS STILL required** (eADR does not prevent the CPU from executing stores out-of-order before the crash).

---

## 4. Failure-Atomic Write Pattern

```c
// Thread 1 (durable write before acknowledging to user)
strcpy(id->name, "Pikachu");
pwb(id->name);             // flush payload cache line(s)
pfence();                  // order payload BEFORE commit flag
id->committed = true;
pwb(&id->committed);       // flush commit flag
psync();                   // ensure committed actually reached NVMM
// Safe to acknowledge to user or signal Thread 2 now!
```
At recovery: if `id->committed == true`, we are guaranteed `id->name == "Pikachu"`.

---

## 5. Circular Persistent Log & The `ptail` vs. `vtail` Bug

In [[Lab 05 - NVMM Write-Ahead Cache (NVCache)]], producer threads append entries at `head` into a circular NVMM log, while a background cleanup thread drains entries from `nvmm->tail` to disk (`pwrite` + `fsync`) in batches.

> [!bug] The Batching Crash-Recovery Bug (Why Two Tails Are Needed)
> Suppose the log is full (`head + 1 == tail`), and the cleanup thread batches 2 entries and advances `nvmm->tail += 2` in cache (before `pwb`/`psync` finishes).
> 1. Producer immediately sees space and writes two new entries `e1, e2` into those slots and persists them.
> 2. **Crash occurs before `nvmm->tail` reaches NVMM!**
> 3. On recovery, the old `nvmm->tail` now points at `e2` (the *newest* entry!). Recovery replays `e2` **first**, and then replays an older entry `e0` targeting the same offset, **overwriting newer data with stale data!**
>
> **Fix:** Maintain a persistent `nvmm->tail` (used at recovery) AND a volatile `_Atomic size_t vtail` (checked by producers). The cleanup thread updates `vtail` **only after** `pwb(&nvmm->tail); psync();` completes!

```c
// Cleanup thread batch commit:
nvmm->tail = tail;
pwb(&nvmm->tail);
psync();                    // persistent tail is now durable in NVMM
atomic_store(&vtail, tail); // ONLY NOW allow producers to reuse old slots
```

---

## Related Notes
- [[02 - Cache Coherence and Memory Models]]
- [[Lab 05 - NVMM Write-Ahead Cache (NVCache)]]
- [[Past Exam 2021-2022 - Radix Tree]] (eADR question)
- [[Past Exam 2022-2023 - Barrier and Flat Combining]] (`sfence` for `pfence` and `psync`)
