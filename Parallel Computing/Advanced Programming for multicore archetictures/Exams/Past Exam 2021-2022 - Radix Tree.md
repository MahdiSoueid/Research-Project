---
title: Past Exam 2021-2022 - Radix Tree
course: CSC5101
year: 2021-2022
type: exam
tags:
  - csc5101/exam
  - csc5101/non-blocking
  - csc5101/memory-model
  - csc5101/nvmm
  - csc5101/numa
---

# Past Exam 2021–2022 — Radix Tree

Up: [[00 - CSC5101 Index (MOC)]] | Ref: [[Exam Patterns and C11 Atomics Reference]]

---

## Exercise I: Course Questions (6 points)

1. **NUMA (2 pts):** 4-node ring (A–B–C–D–A), 10 cores & 5 GB/s controller per node, 1 GB/s per link; 40 threads × 0.1 GB/s, initialized by main thread on A.
   - **Answer:** **Interleaved (4 GB/s)** beats **First-touch (3 GB/s)**. See full breakdown in [[08 - NUMA Architecture (Extra)#3. Bandwidth Bottleneck Analysis (Worked Exam Method)]].
2. **Memory Model (2 pts):** 3-thread transitivity (`ok1, ok2, msg1, msg2`).
   - **Answer:** Possible outputs are `"0 0"`, `"42 0"`, `"42 42"` (both under relaxed and under no-LL/no-SS, because Load-Store reordering still allows `d, e` before `c`). `"0 42"` is impossible. See [[02 - Cache Coherence and Memory Models#4. Out-of-Order Execution & Memory Ordering]].
3. **Persistent Memory / eADR (2 pts):** Are `pwb` and `pfence` still needed with eADR?
   - **Answer:** `pwb` is **no longer required** (residual power flushes CPU caches on power loss). `pfence` **is still required** to prevent CPU out-of-order execution from reordering stores before a crash. See [[07 - Persistent Memory (NVMM and Crash Consistency)#3. Crash Consistency & Persistence Ordering]].

---

## Exercise II: Lock-Free Radix Tree (14 points)

Insert-only 256-way trie (`struct node { void* _Atomic value; struct node* _Atomic nexts[256]; };`).

### Lock-Free Solution (Clean C11 Version of `radix-free.c`)

```c
struct node {
  void* _Atomic value;
  struct node* _Atomic nexts[256];
};

struct node* _Atomic root = NULL;

struct node* get_next(struct node* _Atomic* p) {
  struct node* cur = atomic_load(p);
  if (cur == NULL) {
    struct node* tmp = calloc(1, sizeof(*tmp));
    struct node* expected = NULL;
    if (!atomic_compare_exchange_strong(p, &expected, tmp)) {
      free(tmp);
      return expected; // winning thread's node
    }
    return tmp;
  }
  return cur;
}

void* insert(const char* key, void* value) {
  struct node* _Atomic* cur = &root;
  for (int i = 0; key[i] != '\0'; i++) {
    struct node* node = get_next(cur);
    cur = &node->nexts[(unsigned char)key[i]];
  }
  struct node* leaf = get_next(cur);
  return atomic_exchange(&leaf->value, value);
}

void* get(const char* key) {
  struct node* _Atomic* cur = &root;
  for (int i = 0; key[i] != '\0'; i++) {
    struct node* node = atomic_load(cur);
    if (node == NULL) return NULL;
    cur = &node->nexts[(unsigned char)key[i]];
  }
  struct node* leaf = atomic_load(cur);
  return leaf ? atomic_load(&leaf->value) : NULL;
}
```

### Question 6: Adapting to Transactional Memory (1 pt)
Wrap the single-threaded bodies of `insert` and `get` inside `atomic { ... }` blocks (removing locks and atomic CASes; note that `calloc` inside TM must be transaction-safe or rolled back on abort).

> [!bug] Typos Noted in Repo's `radix-free.c`
> The repo's quick solution file had `&lead->value` instead of `&leaf->value`, `cur->nexts` instead of `node->nexts` in `get()`, and non-atomic `!*cur`. The C11 version above fixes all three.
