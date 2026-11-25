---
title: Lab 03 - Lock-Free Queue, Stack, Radix Tree, Linked List
course: CSC5101
week: 3
type: lab
tags:
  - csc5101/lab
  - csc5101/non-blocking
  - csc5101/reclamation
---

# Lab 03 — Lock-Free Queue, Stack, Radix Tree & Linked List

Up: [[00 - CSC5101 Index (MOC)]] | Concepts: [[04 - Non-Blocking Data Structures]], [[05 - Safe Memory Reclamation (ABA, Hazard Pointers, RCU)]]

---

## Exercise I: Lock-Free Queue & Hazard Pointers
1. Spawn $N$ threads (`N = 10`), each enqueuing $K$ (`1,000,000`) nodes and dequeuing $K$ nodes; verify queue is empty at the end.
2. Compare `pthread_mutex_lock` queue vs. [[04 - Non-Blocking Data Structures#4. Lock-Free FIFO Queue (Michael–Scott)|Michael–Scott lock-free queue]] using `CLOCK_MONOTONIC`.
3. **Freeing in `dequeue`:** Immediately triggers a segfault due to use-after-free and the [[05 - Safe Memory Reclamation (ABA, Hazard Pointers, RCU)#1. Why `free()` Breaks Lock-Free Data Structures|ABA Problem]].
4. **Hazard Pointers for the Queue:**
   - Protect `head` in `dequeue` (publish `head` in `hazard`, re-read `head`, clear after CAS, push removed fake node to `free_nodes`).
   - Protect `tail` in `enqueue` (publish `tail` in `hazard`, re-read `tail`, clear after CAS).
   - Recycle nodes in `enqueue` by popping `Z` from `free_nodes`, checking all threads' `hazard` pointers, and falling back to `malloc` (re-pushing `Z`) if `Z` is hazardous.

## Reference Stack (`stack.c`)
Demonstrates the lock-free Treiber stack with an intentional crash trap (`free(expected)` inside `pop`) to expose ABA/use-after-free under high concurrency.

## Exercise II: Lock-Free Radix Tree (Insert-Only)
Because deletion is disallowed, ABA does not occur! Nodes are lazily allocated on demand via CAS (`NULL -> tmp`; loser frees `tmp`). See the full worked implementation in [[Past Exam 2021-2022 - Radix Tree]].

## Exercise III: Lock-Free Sorted Linked List
Implements [[04 - Non-Blocking Data Structures#5. Lock-Free Sorted Linked List (Tim Harris, DISC 2001)|Tim Harris's bit-marked linked list]]. Adding Hazard Pointers requires protecting both `pred` and `cur` simultaneously (2 hazard pointers per thread).
