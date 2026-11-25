---
title: Processes, Threads and Monitors
aliases:
  - POSIX Threads
  - Pthreads
  - Monitors
course: CSC5101
week: 1
type: concept
tags:
  - csc5101/threads
  - csc5101/synchronization
  - posix
---

# 01 — Processes, Threads and Monitors

Up: [[00 - CSC5101 Index (MOC)]] | Next: [[02 - Cache Coherence and Memory Models]]  
Lab: [[Lab 01 - Threads and Producer-Consumer]]

---

## 1. Processes vs. Threads

### Process
A **process** is a running instance of a program (roughly a virtualization of a complete machine). The operating system is responsible for:
- Managing process lifecycle (start, stop).
- Isolating processes (**no shared memory by default**).
- Providing IPC mechanisms (signals, pipes, sockets, etc.).
- Regularly scheduling processes onto CPUs.

### Call Frames and Thread Definition
Every function call allocates a **call frame** on a stack containing:
- Function arguments,
- Local variables,
- Link (return address) to the caller.

A **thread** is an execution context schedulable by the OS, consisting of:
1. A **stack of call frames**, and
2. The **next instruction to execute** (program counter).

A process always contains:
- A shared **memory space** (code, global data, heap), and
- One or more **threads** (each with its own stack and instruction pointer).

> [!important] Process Termination Rules
> A process always starts with a single thread (`main`). The process dies—and the OS immediately terminates **all** remaining threads—when:
> - The last thread terminates,
> - `main()` returns, or
> - Any thread calls `exit()`.
>
> Calling `pthread_exit(NULL)` at the end of `main()` terminates only the `main` thread, allowing spawned threads to finish running before the process exits.

---

## 2. POSIX Threads API (`<pthread.h>`)

| Function / Type | Purpose |
|---|---|
| `pthread_t` | Type holding a thread identifier |
| `pthread_t pthread_self(void)` | Returns the calling thread's ID |
| `int pthread_create(pthread_t *tid, const pthread_attr_t *attr, void *(*fn)(void*), void *arg)` | Creates and starts a new thread executing `fn(arg)` |
| `void pthread_exit(void *retval)` | Terminates the calling thread cleanly |
| `int pthread_join(pthread_t tid, void **pretval)` | Blocks until `tid` exits and retrieves its return value |
| `int pthread_detach(pthread_t tid)` | Marks thread as detached (resources auto-freed on exit; cannot be joined) |

### Joinable vs. Detached Mode
- **Joinable (default):** When a thread finishes, the OS retains its return value and metadata until another thread calls `pthread_join`. Failing to join leaks system resources.
- **Detached (`pthread_detach` or `pthread_attr_t`):** Resources are reclaimed immediately upon thread exit; its return value cannot be retrieved.

### Idiomatic Thread Creation & Joining

```c
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

void* worker(void* arg) {
  int id = (int)(uintptr_t)arg;
  printf("[%llx] Hello from thread %d\n", (unsigned long long)pthread_self(), id);
  return NULL;
}

int main(int argc, char** argv) {
  int n = atoi(argv[1]);
  pthread_t tids[n];

  for (int i = 0; i < n; i++)
    pthread_create(&tids[i], NULL, worker, (void*)(uintptr_t)i);

  for (int i = 0; i < n; i++)
    pthread_join(tids[i], NULL);

  printf("Main quitting\n");
  return 0;
}
```

> [!warning] Classic Exam Trap: Passing `&i` to `pthread_create`
> Never write `pthread_create(&tids[i], NULL, worker, &i);` inside a loop. The loop modifies `i` concurrently with the newly created threads, causing a data race where multiple threads read the same (or out-of-bounds) value. Pass `(void*)(uintptr_t)i`, `&array[i]`, or a heap-allocated (`malloc`) argument instead.

---

## 3. Shared Variables, Race Conditions & Mutual Exclusion

Because threads share the same heap and global variables, concurrent non-atomic read-modify-write sequences lose updates.

**Example (Lost Update):** `int balance = 1000;`
- Thread 1 (`credit`): `tmp = balance; tmp += 100; balance = tmp;`
- Thread 2 (`debit`): `tmp = balance; tmp -= 1; balance = tmp;`
- Schedule: T2 reads `1000` → T1 executes completely (`balance = 1100`) → T2 computes `999` and writes `balance = 999`. The `+100` credit is lost.

### Critical Sections & Mutexes
A **critical section** is a code region executed in **mutual exclusion** (at most one thread inside at a time, so critical sections appear to execute atomically one after another).

```c
pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
// Or dynamically: pthread_mutex_init(&m, NULL);

void credit(void) {
  pthread_mutex_lock(&m);
  balance += 100;
  pthread_mutex_unlock(&m);
}
```

> [!note] Under the Hood
> How `pthread_mutex_lock` is actually implemented (using hardware atomics and Linux futexes for passive waiting) is covered in [[03 - Lock Algorithms and Futexes]] and [[Lab 02 - Lock Benchmarks and Futex Mutex]].

---

## 4. Monitors (Mutex + Condition Variable)

A **monitor** lets threads wait passively until a shared condition becomes true without wasting CPU cycles spinning.

- `pthread_cond_wait(&cond, &mutex)`: Atomically **releases `mutex`**, puts the calling thread to sleep on `cond`, and **re-acquires `mutex`** before returning.
- `pthread_cond_signal(&cond)`: Wakes **one** thread waiting on `cond`.
- `pthread_cond_broadcast(&cond)`: Wakes **all** threads waiting on `cond`.

```c
char* msg = NULL;
pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t  c = PTHREAD_COND_INITIALIZER;

void send(const char* text) {
  pthread_mutex_lock(&m);
  msg = (char*)text;
  pthread_cond_signal(&c);
  pthread_mutex_unlock(&m);
}

void recv(void) {
  pthread_mutex_lock(&m);
  while (msg == NULL)           // ALWAYS use while, never if!
    pthread_cond_wait(&c, &m);
  printf("Message: %s\n", msg);
  pthread_mutex_unlock(&m);
}
```

> [!warning] Always Wait in a `while` Loop
> Between the signal and when the woken thread re-acquires `mutex`, another thread may have consumed the condition (or a spurious wakeup may occur). Always re-check the predicate with `while (!cond)`.

---

## Related Notes
- [[Lab 01 - Threads and Producer-Consumer]] (SPSC and decoupled MPMC queues)
- [[Past Exam 2022-2023 - Barrier and Flat Combining]] (POSIX monitor barrier)
- [[06 - Transactional Memory (STM, HTM, HyTM)]] (how `retry` replaces condition variables in TM)
