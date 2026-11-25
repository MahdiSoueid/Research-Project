---
title: Past Exam 2023-2024 - Lock-Free Memory Allocator
course: CSC5101
year: 2023-2024
type: exam
tags:
  - csc5101/exam
  - csc5101/non-blocking
  - csc5101/memory-model
---

# Past Exam 2023–2024 — Lock-Free Memory Allocator

Up: [[00 - CSC5101 Index (MOC)]] | Concepts: [[02 - Cache Coherence and Memory Models]], [[04 - Non-Blocking Data Structures]]

---

## Exercise I: Memory Model (2 points)
`p = malloc(sizeof(*p)); ok = true;` vs `while (!ok) {} *p = 42;`
- **General case:** Store-Store reordering in T1 or Load-Load reordering in T2 can cause T2 to see `ok == true` while `p` is still `NULL` → **segmentation fault**.
- **Pentium (TSO):** Prevents Store-Store and Load-Load reorderings, so T2 is guaranteed to observe the initialized `p`.

---

## Exercise II: Chunk Memory Allocator (18 points)

```c
struct chunk {
  size_t size;
  union {
    struct chunk* next;
    char content[0];
  };
};
```

### Part II: Lock-Free Allocator via Lock-Free Stack (`mem.c`)
Key idea: Avoid raw atomics inside `alloc_chunk` by treating `free_list` as a **lock-free stack** supporting single `pop()` and batch `push(head, tail)`!

```c
struct chunk* _Atomic free_list = NULL;

struct chunk* pop(void) {
  struct chunk* res;
  do {
    res = atomic_load(&free_list);
    if (res == NULL) return NULL;
  } while (!atomic_compare_exchange_strong(&free_list, &res, res->next));
  return res;
}

void push(struct chunk* head, struct chunk* tail) {
  struct chunk* expected;
  do {
    expected = atomic_load(&free_list);
    tail->next = expected;
  } while (!atomic_compare_exchange_strong(&free_list, &expected, head));
}

void free_chunk(struct chunk* c) {
  push(c, c);
}

struct chunk* create_large_chunk(void) {
  size_t total = 64 * 1024 * 1024;
  struct chunk* c = malloc(total);
  c->size = total - sizeof(struct chunk);
  return c;
}

struct chunk* alloc_chunk(size_t size) {
  struct chunk* tail = pop();
  if (tail == NULL) tail = create_large_chunk();
  struct chunk* head = tail;

  // Pop chunks until we find one large enough, chaining rejected ones locally
  while (head->size < size) {
    struct chunk* c = pop();
    if (c == NULL) c = create_large_chunk();
    c->next = head;
    head = c;
  }

  // head is now large enough; head->next..tail are the smaller popped chunks
  if (head->size >= size + sizeof(struct chunk)) {
    struct chunk* d = (struct chunk*)((uintptr_t)head + sizeof(struct chunk) + size);
    d->size = head->size - size - sizeof(struct chunk);
    head->size = size;
    d->next = (head == tail) ? NULL : head->next;
    push(d, (head == tail) ? d : tail);
  } else if (head != tail) {
    push(head->next, tail);
  }
  return head;
}
```
