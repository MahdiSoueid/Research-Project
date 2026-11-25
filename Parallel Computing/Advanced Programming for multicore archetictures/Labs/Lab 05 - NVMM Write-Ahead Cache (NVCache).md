---
title: Lab 05 - NVMM Write-Ahead Cache (NVCache)
course: CSC5101
week: 5
type: lab
tags:
  - csc5101/lab
  - csc5101/nvmm
---

# Lab 05 — NVMM Write-Ahead Cache (NVCache)

Up: [[Parallel Computing/Advanced Programming for multicore archetictures/Readme]] | Concept: [[07 - Persistent Memory (NVMM and Crash Consistency)]]

---

## Architecture (Dulong et al., DSN '21)
Accelerate durable `pwrite` + `fsync` by logging writes synchronously into a circular **NVMM write-ahead log** (`my_pwrite`), while an asynchronous **cleanup thread** drains committed entries to disk in batches.

### Two-Cache-Line Log Entry (`struct.h`)

```c
#define NB_ENTRIES (64 * 1024)
#define CACHE_LINE 64

struct operation {
  union {
    struct {
      _Atomic bool committed;
      int          fd;
      size_t       n;
      off_t        off;
    };
    char first_cache_line[CACHE_LINE];
  };
  union {
    char buf[CACHE_LINE];
    char second_cache_line[CACHE_LINE];
  };
};

struct nvmm {
  struct operation operation[NB_ENTRIES];
  size_t           tail; // persistent tail
};
```

## Critical Persistence Ordering (`soluce.c`)
1. **`my_pwrite`:**
   - Claim slot `index` via CAS on `_Atomic size_t head` while `(index + 1) % NB_ENTRIES != atomic_load(&vtail)`.
   - Copy payload into `cur->buf`, `pwb(cur->second_cache_line)`.
   - Fill `fd, n, off`, `pwb(cur->first_cache_line)`, **`pfence()`** (data & metadata durable before commit flag).
   - `atomic_store(&cur->committed, true)`, `pwb(cur->first_cache_line)`, **`psync()`** (durable before returning).
2. **`cleanup_thread` (Batching):**
   - Drain up to `NB_ENTRIES / 2` entries via `pwrite` + `fsync` (once per batch!).
   - Clear `committed = false`, flush with `pwb` + `pfence`.
   - Advance `nvmm->tail = tail`, `pwb(&nvmm->tail)`, **`psync()`**.
   - **Only then** advance `atomic_store(&vtail, tail)` — prevents the [[07 - Persistent Memory (NVMM and Crash Consistency)#5. Circular Persistent Log & The `ptail` vs. `vtail` Bug|`ptail`/`vtail` wrap-around corruption bug]].
3. **`recovery(fd)`:**
   - Scan circularly from `nvmm->tail` for `NB_ENTRIES`, replaying every `op->committed` entry to `fd` via `pwrite`, then `fsync(fd)`.
   - Clear `committed = false` **oldest-to-newest** with `pwb` + `pfence()` after each (safe against crashes *during* recovery!).
   - Reset `nvmm->tail = 0`, `pwb(&nvmm->tail)`, `psync()`.

> [!tip] Compilation Flag
> Always compile with `gcc -march=native` so `__CLWB__` or `__CLFLUSHOPT__` macros activate in `nvmm.h`.
