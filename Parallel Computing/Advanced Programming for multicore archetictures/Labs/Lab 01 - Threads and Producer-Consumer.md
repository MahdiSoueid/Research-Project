---
title: Lab 01 - Threads and Producer-Consumer
course: CSC5101
week: 1
type: lab
tags:
  - csc5101/lab
  - csc5101/threads
---

# Lab 01 — Threads and Producer-Consumer

Up: [[Parallel Computing/Advanced Programming for multicore archetictures/Readme]] | Concept: [[01 - Processes, Threads and Monitors]]

---

## Exercise I: First Threads & Lifecycle (`hello.c`)
- **Why "Main quitting" prints early:** Thread scheduling is non-deterministic; `main` runs concurrently with spawned threads.
- **Why fewer than 20 messages print without join/exit:** Returning from `main()` immediately kills the entire process and all still-running threads.
- **Why `pthread_exit(NULL)` fixes missing messages:** Terminates only the `main` thread while keeping the process alive until all other threads exit.
- **How to print "Main quitting" last:** Call `pthread_join(tid[i], &retval)` for every thread before printing.
- **Argument passing:** Allocate `int* p = malloc(sizeof(*p)); *p = i;` (freed by the thread) or cast `(void*)(uintptr_t)i`.

---

## Exercise II: Shared Counter
- Incrementing a global `counter++` from 100 threads loses updates because read-increment-write is not atomic.
- Fix with `pthread_mutex_lock`/`unlock` (or `atomic_fetch_add`) and wait via `pthread_join` (or a condition variable on `counter == N`).

---

## Exercise III: Producer/Consumer Queues

### 1. Unicast Queue (`spsc.c`)
Single linked list with `head` and `tail` protected by one mutex + condition variable:
- **Producer:** Allocates node, locks mutex, appends to `tail` (updating `head` if empty), calls `pthread_cond_signal(&cond)`, unlocks.
- **Consumer:** Locks mutex, `while (head == NULL) pthread_cond_wait(&cond, &mutex);`, pops `head` (sets `tail = NULL` if now empty), unlocks, prints and `free()`s the node.

### 2. Decoupled Multicast Queue (`mpmc.c`)
Each consumer must read **every** message in FIFO order without blocking faster consumers on slower ones:
- **Key trick:** Place a `pthread_mutex_t`, `pthread_cond_t`, and reference counter `size_t cpt = nb_consumers` **inside each node**!
- Start with a shared dummy (`fake`) node; every consumer holds its own cursor `cons` pointing to its current node, while the producer holds `prod`.
- **Producer:** Allocates `next = new_node(nb_consumers)`, locks `prod->mutex`, writes `prod->msg` and `prod->next = next`, calls `pthread_cond_broadcast(&prod->cond)`, unlocks, advances `prod = next`.
- **Consumer:** Locks `cons->mutex`, waits `while (cons->next == NULL) pthread_cond_wait(...)`, copies `cons->msg` and `tmp = cons->next`, decrements `cons->cpt` — **the last consumer (`--cons->cpt == 0`) frees `cons`** — unlocks, advances `cons = tmp`.

> [!bug] Subtle Note on `mpmc.c` Reference Solution
> In `mpmc.c`, `free(cons)` is called *before* `pthread_mutex_unlock(&cons->mutex)` (which unlocks freed memory — undefined behavior). In clean code, record `bool should_free = (--cons->cpt == 0);`, unlock `cons->mutex` first, and then destroy/free `cons` if `should_free` is true!
