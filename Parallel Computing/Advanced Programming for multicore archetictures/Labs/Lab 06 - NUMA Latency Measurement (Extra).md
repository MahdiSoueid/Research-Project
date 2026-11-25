---
title: Lab 06 - NUMA Latency Measurement (Extra)
course: CSC5101
week: 6
type: lab
tags:
  - csc5101/lab
  - csc5101/numa
  - csc5101/extra
---

# Lab 06 — NUMA Latency Measurement *(Extra)*

Up: [[Parallel Computing/Advanced Programming for multicore archetictures/Readme]] | Concept: [[08 - NUMA Architecture (Extra)]]

---

## Experimental Setup (`numa/main.c`)
- **Arguments:** `test_pu test_node test_buffer_kb test_workload_kb test_config [noisy_node]` where `test_config` $\in$ `none | spread | overload`.
- **Topology extraction:** Uses `-lhwloc` (`HWLOC_OBJ_NUMANODE` and `HWLOC_OBJ_PU`) to map every PU to its parent NUMA node.
- **Noisy threads:** Run on all PUs except `test_pu`, continuously sweeping 32 MB buffers (`> L3`) located on node `(n + 1) % nb_nodes` (`spread`) or `noisy_node` (`overload`).
- **Cache-line striding & pointer chasing:**
  ```c
  struct cache_line {
    union {
      char _content[64];
      int  value;
    };
  };
  ```
  Pre-populate `lines[i].value` as a single random Hamiltonian cycle visiting every cache line once, then time `cur = lines[cur].value` to measure true random access latency across L1 (2 KB), L2 (128 KB), L3 (1 MB), local DRAM (32 MB), remote DRAM, and contended (`spread`/`overload`) scenarios.
