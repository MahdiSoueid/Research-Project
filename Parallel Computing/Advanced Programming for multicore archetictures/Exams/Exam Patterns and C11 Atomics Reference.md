---
title: Exam Patterns and C11 Atomics Reference
aliases:
  - Exam Cheat Sheet
  - C11 Atomics Reference
course: CSC5101
type: exam
tags:
  - csc5101/exam
  - csc5101/reference
---

# Exam Patterns & C11 Atomics Reference

Up: [[00 - CSC5101 Index (MOC)]]

---

## 1. Exam Structure (1h30, All Documents Allowed, 20 Points)
- **Main Coding Exercise (14–18 pts):** Progressive C implementation starting from single-threaded or POSIX threads (`main` spawning/joining workers), then moving to lock-based, then lock-free / RCU / MCS / Futex / TM.
- **Short Course Questions (2–6 pts):** 2–3 sentence conceptual answers on memory models, cache coherence/LMS cost, lock comparisons, TM (redo/undo, HTM, zombies), NVMM (`pwb`/`pfence`/`psync`, `sfence`, eADR).

## 2. C11 `<stdatomic.h>` Quick Reference

| Operation | Exact C11 Signature / Usage | Critical Trap |
|---|---|---|
| Atomic pointer | `struct node* _Atomic head;` | Put `_Atomic` **after `*`** so the pointer itself is atomic! |
| Thread-local | `_Thread_local struct node my;` | Global scope, one independent copy per thread |
| Load / Store | `atomic_load(&x)` / `atomic_store(&x, v)` | Default is `memory_order_seq_cst` |
| Exchange | `old = atomic_exchange(&x, new)` | Returns **old** value |
| Fetch-Add | `old = atomic_fetch_add(&x, delta)` | Returns **old** value (countdown `N->0`: last thread sees `1`!) |
| CAS | `bool ok = atomic_compare_exchange_strong(&x, &exp, des)` | Takes **`&exp`** (pointer!) and **overwrites `exp`** on failure |

## 3. Recurring Theory Questions Master List

1. **Why can `msg = "hello"; ok = true;` / `while(!ok){} printf(msg);` segfault in general, but not on Intel?**
   → [[02 - Cache Coherence and Memory Models#4. Out-of-Order Execution & Memory Ordering]] (TSO forbids SS and LL; weaker models like ARM/Java allow them).
2. **Why is an atomic LMS instruction slow (and why is atomicity NOT the reason)?**
   → [[03 - Lock Algorithms and Futexes#2. Hardware Atomic Load-Modify-Store (LMS) Instructions]] (L1 local cache-line lock is cheap; cost is write invalidations + ordering fence).
3. **Ticket lock vs. Spinlock vs. MCS lock?**
   → [[03 - Lock Algorithms and Futexes#5. Summary Comparison]] (Ticket spins on loads, avoiding write bounces; MCS spins on per-thread local lines, avoiding unlock broadcast invalidations).
4. **Why does Intel's `sfence` suffice for both `pfence` and `psync`? What changes under eADR?**
   → [[07 - Persistent Memory (NVMM and Crash Consistency)#3. Crash Consistency & Persistence Ordering]].
5. **Redo vs. Undo logs? Why does L1 cache implement HTM's redo log, and what is HTM's main limit?**
   → [[06 - Transactional Memory (STM, HTM, HyTM)#2. TM Runtime Design Space]] & [[06 - Transactional Memory (STM, HTM, HyTM)#4. Implementation Techniques: HTM, STM, HyTM]].
6. **What is a zombie transaction and how does the global clock fix it?**
   → [[06 - Transactional Memory (STM, HTM, HyTM)#3. Zombie Transactions & The Global-Clock STM Algorithm]].
7. **Why do we need bit-marking in Harris's lock-free linked list?**
   → [[04 - Non-Blocking Data Structures#5. Lock-Free Sorted Linked List (Tim Harris, DISC 2001)]].
8. **Why is re-validation required in Hazard Pointers?**
   → [[05 - Safe Memory Reclamation (ABA, Hazard Pointers, RCU)#2. Hazard Pointers (Maged Michael, TPDS 2004)]].
