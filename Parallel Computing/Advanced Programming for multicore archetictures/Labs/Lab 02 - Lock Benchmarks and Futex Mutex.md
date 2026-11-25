---
title: Lab 02 - Lock Benchmarks and Futex Mutex
course: CSC5101
week: 2
type: lab
tags:
  - csc5101/lab
  - csc5101/locks
---

# Lab 02 — Lock Benchmarks and Futex Mutex

Up: [[Parallel Computing/Advanced Programming for multicore archetictures/Readme]] | Concept: [[03 - Lock Algorithms and Futexes]]

---

## Benchmark Architecture (`locks.c`)
- **CLI Arguments:** `nb-threads it csd cd algo` (`csd` = critical section delay in ns, `cd` = compute delay outside CS in ns, `algo` $\in$ `none | posix | spinlock | ticket | mcs | futex`).
- **Timing:** `clock_gettime(CLOCK_MONOTONIC, &ts)` for monotonic nanosecond timing.
- **Start Barrier:** All threads execute `atomic_fetch_add(&nb_started, 1); while (atomic_load(&nb_started) < n) asm_pause();` so contention begins simultaneously.
- **Integrity Check:** Increment a non-atomic `uint32_t z++` inside the CS and assert `z == n * it` at the end.
- **Reported Metric:** Average lock acquire+release overhead $= \frac{\sum \text{elapsed}_i \cdot 10^9}{n \cdot \text{it}} - \text{cd} - \text{csd}$.

## Custom Futex Syscall Wrapper (`futexlock.c`)

```c
#define _GNU_SOURCE
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/futex.h>

long futex(void* addr1, int op, int val1, struct timespec* timeout,
           void* addr2, int val3) {
  return syscall(SYS_futex, addr1, op, val1, timeout, addr2, val3);
}

void futex_wait(void* addr, int val) {
  futex(addr, FUTEX_WAIT, val, NULL, NULL, 0);
}

void futex_wake(void* addr, int nb_threads) {
  futex(addr, FUTEX_WAKE, nb_threads, NULL, NULL, 0);
}
```
- The 3-state futex mutex (`FREE`, `BUSY_NO_WAITER`, `BUSY_WITH_WAITERS`) is detailed in [[03 - Lock Algorithms and Futexes#4. Passive Waiting & Linux Futexes]].
- **Performance takeaway:** Spinlock degrades sharply as thread count increases due to cache-line bouncing; Ticket and MCS scale better on high contention until `#threads > #cores`, where MCS suffers convoy effects and passive Futex/POSIX locks win.
