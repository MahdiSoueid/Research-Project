---
title: NUMA Architecture (Extra)
aliases:
  - NUMA
  - First-Touch Policy
  - Interleaved Policy
  - hwloc
course: CSC5101
week: 6
type: concept
tags:
  - csc5101/numa
  - csc5101/extra
  - hardware
---

# 08 — NUMA Architecture *(Extra Module)*

Up: [[Parallel Computing/Advanced Programming for multicore archetictures/Readme]] | Prev: [[07 - Persistent Memory (NVMM and Crash Consistency)]]  
Lab: [[Lab 06 - NUMA Latency Measurement (Extra)]]

> [!note] Exam Scope Notice
> Marked as **Extra** in the course schedule and excluded from the current exam scope. Kept here for completeness and for understanding past exam questions ([[Past Exam 2021-2022 - Radix Tree]], [[Past Exam 2025-2026 - Work-Stealing Scheduler]]).

---

## 1. NUMA Architecture Basics

In a **Non-Uniform Memory Access (NUMA)** machine, CPUs are grouped into **nodes**, each with its own local DRAM bank and memory controller, connected via inter-node **interconnect links** (e.g., Intel UPI / AMD Infinity Fabric).
- **Local memory access:** Fast, uses only the local memory controller.
- **Remote memory access:** Slower (higher latency) and traverses one or more interconnect links, potentially saturating both links and the remote memory controller.

---

## 2. Page Placement Policies

### First-Touch Policy (Linux Default)
- A virtual page is physically allocated on the NUMA node of the thread that **first touches (writes to)** it.
- **Best case:** Each worker thread initializes its own private partition → 100% local accesses.
- **Worst case:** The main thread allocates and initializes the entire dataset on Node 0 before spawning threads → **all threads funnel traffic to Node 0**, saturating the links into Node 0 and/or Node 0's memory controller.

### Interleaved Policy
- Physical pages are allocated round-robin across all NUMA nodes.
- **Why Interleaved is best when application behavior is unknown** ([[Past Exam 2025-2026 - Work-Stealing Scheduler]]): It evenly spreads memory accesses across all memory controllers and interconnect links, avoiding worst-case single-node hotspots even if one thread initializes all memory or threads share data unpredictably.

---

## 3. Bandwidth Bottleneck Analysis (Worked Exam Method)

From [[Past Exam 2021-2022 - Radix Tree]]:
- **Topology:** 4 nodes `A, B, C, D` in a ring (`A–B–C–D–A`). Each node has 10 cores and a **5 GB/s** memory controller. Each of the 4 interconnect links has **1 GB/s** capacity.
- **Workload:** 40 threads (10 per node), each generating **0.1 GB/s** uniform memory traffic (total demand = **4 GB/s**). Data initialized by the initial thread on node A.

| Policy | Link & Controller Analysis | Total Throughput |
|---|---|---:|
| **Interleaved** | 4 GB/s split evenly across 4 links (1 GB/s per link ≤ 1 GB/s cap) and 4 memory controllers (1 GB/s each ≤ 5 GB/s cap). No bottlenecks. | **4 GB/s** |
| **First-Touch** | All data sits on Node A. Node A's controller (5 GB/s) doesn't saturate, **but** Node A only has 2 incoming links (`AB` and `AD`), capping remote traffic from B, C, D at `1 + 1 = 2 GB/s`. Plus Node A's own 10 local threads (`1 GB/s`) = `2 + 1`. | **3 GB/s** |

**Winner:** Interleaved (`4 GB/s > 3 GB/s`).

---

## 4. Measuring True Memory Latency with `hwloc`

1. Inspect topology with `lstopo-no-graphics` (nodes, DRAM per node, PUs per node, L1/L2/L3 sizes).
2. Pin thread to a specific PU: `hwloc_set_cpubind(topology, pu->cpuset, HWLOC_CPUBIND_THREAD)`.
3. Bind memory to a specific NUMA node:
   ```c
   char* buf = hwloc_alloc_membind(
       topology, size, node->nodeset, HWLOC_MEMBIND_BIND,
       HWLOC_MEMBIND_STRICT | HWLOC_MEMBIND_BYNODESET | HWLOC_MEMBIND_NOCPUBIND);
   ```
4. **Defeating Cache & Prefetching:**
   - Access one field per **64-byte `struct cache_line`** (avoids L1 spatial hits).
   - Use a buffer larger than L3 (e.g., 32 MB) to force main-memory accesses.
   - Pre-build a **random single-cycle pointer chain** (`cur = lines[cur].value`) to defeat hardware sequential prefetchers without `rand()` overhead inside the timing loop.
   - Accumulate results into a global variable so `-O2`/`-O3` doesn't optimize the loop away.

---

## Related Notes
- [[Lab 06 - NUMA Latency Measurement (Extra)]]
- [[Past Exam 2021-2022 - Radix Tree]]
- [[Past Exam 2025-2026 - Work-Stealing Scheduler]]
