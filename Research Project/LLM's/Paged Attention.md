#LLM #Memory-management
PagedAttention offers [[KV Cache]] management inspired by virtual memory . Instead of reserving a large contiguous area for each request, ==the cache is divided into fixed-size blocks==. From the query point of view,==these blocks form a sequence of logical blocks, while they can be placed in non-contiguous physical blocks in memory== . A block table maintains the correspondence between the logical blocks of a query and their physical location. ==Blocks are allocated gradually as the sequence lengthens and can be freed and then reused when a request completes==. This organization thus avoids reserving a large contiguous area from the start for each sequence and greatly reduces memory fragmentation . This organization by blocks makes it possible to better use the available memory and to keep more requests active simultaneously . The scheduling and memory management presented in this section do not, however, constitute isolated mechanisms, since they are integrated into software dedicated to the execution of LLMs, called inference engines.
.A large part of these approaches has been developed for server environments with significant resources, while t==heir use on Edge platforms imposes stronger constraints in computation, memory and energy==, which requires specific adaptations presented in the following section .

==These block can be shared in case they are common between multiple queries saving a lot of calculations.==


Solves the [[Fragmentation]] issue.
[[Kwon et al. 2023]]