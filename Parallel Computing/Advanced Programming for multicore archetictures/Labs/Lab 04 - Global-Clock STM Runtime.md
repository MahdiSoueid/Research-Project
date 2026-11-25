---
title: Lab 04 - Global-Clock STM Runtime
course: CSC5101
week: 4
type: lab
tags:
  - csc5101/lab
  - csc5101/tm
---

# Lab 04 — Global-Clock STM Runtime

Up: [[Parallel Computing/Advanced Programming for multicore archetictures/Readme]] | Concept: [[06 - Transactional Memory (STM, HTM, HyTM)]]

---

## Lab Goals & API (`stm/main.c`)
Compare three implementations incrementing shared cell `x = memory.values[0]` across $N$ threads:
1. `atomic` (`__sync_fetch_and_add` / `atomic_fetch_add`)
2. `lock` (`pthread_mutex_lock`)
3. `stm` using the 4-function API:
   - `void startTX(void)`
   - `int readValue(int idx)` (returns `ABORT` sentinel on conflict)
   - `int writeValue(int idx, int value)`
   - `int commitTX(void)` (returns `ABORT` or `0`)

## Usage Loop with Exponential Backoff

```c
restart:
  startTX();
  int x = readValue(0);
  if (x == ABORT) { do_abort(); goto restart; }
  writeValue(0, x + 1);
  if (commitTX() == ABORT) { do_abort(); goto restart; }
```

## Key Implementation Details
- Each memory slot points to an immutable `struct cell { int value; int counter; }`.
- Per-thread transaction descriptor uses `__thread` / `_Thread_local` (`readSet`, `writeSet`, `values`, `clock`, `backoff`).
- `commitTX()` locks `memory.lock`, validates all `readSet` cells have `counter < tx.clock`, allocates new cells with `counter = memory.clock` for `writeSet`, increments `memory.clock++`, and unlocks.
- **Optional Q8 (Memory Recycling):** Reclaim overwritten `struct cell` pointers using [[05 - Safe Memory Reclamation (ABA, Hazard Pointers, RCU)#2. Hazard Pointers (Maged Michael, TPDS 2004)|Hazard Pointers]] so a cell isn't freed while a concurrent `readValue` inspects it.
