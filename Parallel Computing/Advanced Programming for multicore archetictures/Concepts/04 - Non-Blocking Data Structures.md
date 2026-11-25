---
title: Non-Blocking Data Structures
aliases:
  - Lock-Free Algorithms
  - Treiber Stack
  - Michael-Scott Queue
  - Harris Linked List
  - Amdahl's Law
course: CSC5101
week: 3
type: concept
tags:
  - csc5101/non-blocking
  - lock-free
  - algorithms
---

# 04 — Non-Blocking Data Structures

Up: [[00 - CSC5101 Index (MOC)]] | Prev: [[03 - Lock Algorithms and Futexes]] | Next: [[05 - Safe Memory Reclamation (ABA, Hazard Pointers, RCU)]]  
Lab: [[Lab 03 - Lock-Free Queue, Stack, Radix Tree, Linked List]]

---

## 1. Motivation: Amdahl's Law

Let $T$ be sequential execution time, $p \in [0,1]$ the parallelizable fraction, and $n$ the number of cores:
$$T(n) = T \cdot \left(1 - p + \frac{p}{n}\right) \implies \text{Speedup } a(n) = \frac{1}{1 - p + \frac{p}{n}} \xrightarrow{n \to \infty} \frac{1}{1 - p}$$

- $p = 75\% \implies a_{\max} = 4$ ($3.7$ on 32 cores).
- $p = 95\% \implies a_{\max} = 20$ ($12.55$ on 32 cores, $17.42$ on 128 cores).

Even tiny serial critical sections severely cap multicore scalability.

---

## 2. Progress Guarantees & Linearization Points

From **strongest** to **weakest**:

1. **Wait-free:** Every operation terminates in a **bounded** number of steps (per-thread progress).
2. **Lock-free:** If operations are invoked infinitely often, operations complete infinitely often (**system-wide** progress; an individual thread may starve if others keep winning the CAS).
3. **Obstruction-free:** If a thread executes **alone** from any point, it finishes in a finite number of steps (two threads can still livelock each other).

$$\text{Wait-free} \implies \text{Lock-free} \implies \text{Obstruction-free} \quad (\text{converse is FALSE})$$

> [!warning] Locks Break Obstruction-Freedom
> As soon as an algorithm acquires a lock, it is **not even obstruction-free** (if the lock holder pauses/crashes, a thread running alone can never finish).

- **Linearization Point:** The single atomic instruction (typically a successful CAS) at which a lock-free operation logically takes effect and becomes visible to all threads.

---

## 3. Lock-Free Stack (Treiber / Scott '91)

Principle: atomic CAS on a single `head` pointer.

```c
struct node {
  struct node* _Atomic next;
  int value;
};

struct stack {
  struct node* _Atomic head;
};

void push(struct stack* s, int value) {
  struct node* n = malloc(sizeof(*n));
  n->value = value;
  struct node* expected;
  do {
    expected = atomic_load(&s->head);
    atomic_store(&n->next, expected);
  } while (!atomic_compare_exchange_strong(&s->head, &expected, n));
}

int pop(struct stack* s) {
  struct node* expected;
  do {
    expected = atomic_load(&s->head);
    if (expected == NULL) return -1; // empty
  } while (!atomic_compare_exchange_strong(&s->head, &expected,
                                           atomic_load(&expected->next)));
  return expected->value; // Do NOT free(expected) naively! See Note 05.
}
```
- **Why lock-free?** A thread's CAS fails *only* if another thread succeeded in modifying `head`. Thus the system always makes progress.
- **Why not wait-free?** A thread can be infinitely delayed by other threads repeatedly winning the CAS on `head`.

---

## 4. Lock-Free FIFO Queue (Michael–Scott)

### Design Principles & Invariants
1. **Always keep a dummy (`Fake`) node** in the list (`head = tail = new_fake_node`) to avoid empty-queue edge cases.
2. **Update `tail` lazily (cooperative helping):** Enqueue performs two CASes (link `old->next = node`, then advance `tail = node`). Any thread observing `old->next != NULL` helps advance `tail`.
3. **Invariants (hold at every step):**
   - `head->next` (if non-NULL) is the oldest enqueued element.
   - The linked lists reachable from `head` and from `tail` share at least one common node (`tail` may lag behind, even **behind `head`**!).
   - The last node of both lists is the last enqueued node.

```c
struct qnode {
  struct qnode* _Atomic next;
  int value;
};

struct queue {
  struct qnode* _Atomic head;
  struct qnode* _Atomic tail;
};

void queue_init(struct queue* q) {
  struct qnode* fake = calloc(1, sizeof(*fake));
  atomic_store(&q->head, fake);
  atomic_store(&q->tail, fake);
}

void enqueue(struct queue* q, int value) {
  struct qnode* node = malloc(sizeof(*node));
  node->value = value;
  atomic_store(&node->next, NULL);

  struct qnode* old;
  struct qnode* expected;
  do {
    old = atomic_load(&q->tail);
    struct qnode* next = atomic_load(&old->next);
    while (next != NULL) {
      // Help advance lagging tail
      atomic_compare_exchange_strong(&q->tail, &old, next);
      old = atomic_load(&q->tail);
      next = atomic_load(&old->next);
    }
    expected = NULL;
  } while (!atomic_compare_exchange_strong(&old->next, &expected, node));

  // Best-effort tail swing (if we fail, another enqueuer already helped)
  atomic_compare_exchange_strong(&q->tail, &old, node);
}

int dequeue(struct queue* q) {
  struct qnode* res;
  struct qnode* next;
  do {
    res = atomic_load(&q->head);
    next = atomic_load(&res->next);
    if (next == NULL) return -1; // empty
  } while (!atomic_compare_exchange_strong(&q->head, &res, next));
  // `next` becomes the new Fake node; return its value
  return next->value;
}
```

---

## 5. Lock-Free Sorted Linked List (Tim Harris, DISC 2001)

### The Core Hazard: Concurrent Insert & Remove
Suppose the list is `A -> B -> C`. Thread 1 removes `B` (`A->next = C`) while Thread 2 concurrently inserts `X` after `B` (`B->next = X`, `X->next = C`). Both CASes target **different pointers** (`A->next` vs `B->next`), so both succeed—and `X` is silently lost inside the detached node `B`!

### Solution: Logical Deletion via Marked ("Colored") Pointers
Because aligned heap pointers have unused low-order bits, embed a **1-bit deletion mark** in the LSB of each `next` pointer:
- **White (LSB = `0`):** Node is active.
- **Grey (LSB = `1`):** Node is logically deleted. Its `next` field is now immutable, so any concurrent insertion trying to CAS `B->next` from `(C, 0)` to `(X, 0)` **automatically fails**!

```c
typedef uintptr_t colored_ptr_t;

struct lnode {
  _Atomic colored_ptr_t next;
  int value;
};

static inline struct lnode* get_ptr(colored_ptr_t p) {
  return (struct lnode*)(p & ~(uintptr_t)1);
}
static inline int is_marked(colored_ptr_t p) {
  return (int)(p & (uintptr_t)1);
}
static inline colored_ptr_t make_marked(colored_ptr_t p) {
  return p | (uintptr_t)1;
}
```

### Two-Phase Deletion & Opportunistic Cleanup
1. **Logical deletion:** CAS `cur->next` from `n` (unmarked) to `n | 1`.
2. **Physical removal:** CAS `*pred` from `cur` to `get_ptr(cur->next)`.
3. **Helping:** *Every* traversal (`add` or `del`) that encounters a marked node opportunistically tries to physically unlink it. If the unlinking CAS fails (because `pred` itself was marked or a node was inserted after `pred`), `goto restart`.

```c
int list_del(_Atomic colored_ptr_t* plist, int value) {
  int found = 0;
restart:
  _Atomic colored_ptr_t* pred = plist;
  while (!found) {
    struct lnode* cur = get_ptr(atomic_load(pred));
    if (cur == NULL || value < cur->value)
      return 0; // not found

    colored_ptr_t cnext = atomic_load(&cur->next);
    if (is_marked(cnext)) {
      colored_ptr_t exp = (colored_ptr_t)cur;
      if (!atomic_compare_exchange_strong(pred, &exp, (colored_ptr_t)get_ptr(cnext)))
        goto restart;
      continue;
    }

    if (cur->value == value) {
      // Phase 1: logically mark cur as deleted
      colored_ptr_t n;
      do {
        n = atomic_load(&cur->next);
        if (is_marked(n)) goto restart; // already deleted by another thread
      } while (!atomic_compare_exchange_strong(&cur->next, &n, make_marked(n)));
      found = 1;
      // Phase 2: best-effort physical removal
      colored_ptr_t exp = (colored_ptr_t)cur;
      atomic_compare_exchange_strong(pred, &exp, (colored_ptr_t)get_ptr(n));
      return 1;
    }
    pred = &cur->next;
  }
  return 0;
}

void list_add(_Atomic colored_ptr_t* plist, int value) {
  struct lnode* node = malloc(sizeof(*node));
  node->value = value;
restart:
  _Atomic colored_ptr_t* pred = plist;
  while (1) {
    struct lnode* cur = get_ptr(atomic_load(pred));
    if (cur != NULL && is_marked(atomic_load(&cur->next))) {
      colored_ptr_t exp = (colored_ptr_t)cur;
      if (!atomic_compare_exchange_strong(pred, &exp,
            (colored_ptr_t)get_ptr(atomic_load(&cur->next))))
        goto restart;
      continue;
    }
    if (cur == NULL || value < cur->value) {
      atomic_store(&node->next, (colored_ptr_t)cur);
      colored_ptr_t exp = (colored_ptr_t)cur;
      if (!atomic_compare_exchange_strong(pred, &exp, (colored_ptr_t)node))
        goto restart; // pred was marked grey OR another node inserted before cur
      return;
    }
    pred = &cur->next;
  }
}
```

---

## Related Notes
- [[05 - Safe Memory Reclamation (ABA, Hazard Pointers, RCU)]] *(crucial: why you cannot just `free()` popped nodes)*
- [[Lab 03 - Lock-Free Queue, Stack, Radix Tree, Linked List]]
- [[Past Exam 2021-2022 - Radix Tree]] | [[Past Exam 2023-2024 - Lock-Free Memory Allocator]] | [[Past Exam 2025-2026 - Work-Stealing Scheduler]]
