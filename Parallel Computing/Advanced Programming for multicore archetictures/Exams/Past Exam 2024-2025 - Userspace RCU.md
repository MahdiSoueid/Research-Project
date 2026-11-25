---
title: Past Exam 2024-2025 - Userspace RCU
course: CSC5101
year: 2024-2025
type: exam
tags:
  - csc5101/exam
  - csc5101/reclamation
  - csc5101/tm
  - csc5101/memory-model
---

# Past Exam 2024–2025 — Userspace RCU

Up: [[00 - CSC5101 Index (MOC)]] | Concepts: [[05 - Safe Memory Reclamation (ABA, Hazard Pointers, RCU)]], [[06 - Transactional Memory (STM, HTM, HyTM)]], [[02 - Cache Coherence and Memory Models]]

---

## Exercise I: Userspace RCU & Sorted Linked List (17 points)

RCU core primitives (`rcu_read_lock`, `rcu_read_unlock`, `rcu_synchronize`) are documented in [[05 - Safe Memory Reclamation (ABA, Hazard Pointers, RCU)#3. Read-Copy-Update (RCU)]].

### Sorted RCU Linked List (`print`, `delete`, `insert`)

```c
struct node {
  struct node* _Atomic next;
  int key;
  _Atomic int value;
};

pthread_mutex_t write_lock = PTHREAD_MUTEX_INITIALIZER;
struct node* _Atomic head = NULL;

void print(int key) {
  rcu_read_lock();
  struct node* cur = atomic_load(&head);
  while (cur != NULL && cur->key < key)
    cur = atomic_load(&cur->next);

  if (cur != NULL && cur->key == key)
    printf("%d\n", atomic_load(&cur->value));
  else
    printf("Not found\n");
  rcu_read_unlock();
}

void delete(int key) {
  pthread_mutex_lock(&write_lock);
  struct node* _Atomic* pred = &head;
  struct node* cur = atomic_load(pred);

  while (cur != NULL && cur->key < key) {
    pred = &cur->next;
    cur = atomic_load(pred);
  }

  struct node* deleted = NULL;
  if (cur != NULL && cur->key == key) {
    deleted = cur;
    atomic_store(pred, atomic_load(&cur->next)); // Phase 1: remove
  }
  pthread_mutex_unlock(&write_lock);

  if (deleted != NULL) {
    rcu_synchronize(); // Wait for all active readers
    free(deleted);     // Phase 2: safe free
  }
}

void insert(int key, int value) {
  pthread_mutex_lock(&write_lock);
  struct node* _Atomic* pred = &head;
  struct node* cur = atomic_load(pred);

  while (cur != NULL && cur->key < key) {
    pred = &cur->next;
    cur = atomic_load(pred);
  }

  if (cur != NULL && cur->key == key) {
    atomic_store(&cur->value, value); // update in place
  } else {
    struct node* n = malloc(sizeof(*n));
    n->key = key;
    atomic_store(&n->value, value);
    atomic_store(&n->next, cur);      // publish next BEFORE linking into list!
    atomic_store(pred, n);
  }
  pthread_mutex_unlock(&write_lock);
}
```

---

## Exercise II: Course Questions (3 points)
1. **Redo vs. Undo logs (1.5 pts):** Used in [[06 - Transactional Memory (STM, HTM, HyTM)|Transactional Memory]] (and crash-consistent storage/databases) to guarantee atomicity of transactions/updates. A **redo log** (deferred update) buffers writes locally and applies them only on commit (fast aborts, avoids dirty reads/double-write conflicts). An **undo log** (immediate update) writes directly to memory while saving old values to roll back on abort (fast commits).
2. **Memory ordering segfault (1.5 pts):** `msg = "hello"; ok = true;` / `while(!ok){} printf(msg);` — see [[02 - Cache Coherence and Memory Models#4. Out-of-Order Execution & Memory Ordering]].
