
#LLM 
Since ==during generation only one token is made==  at a time ==this motivates to exploit parallelism and run multiple queries to exploit and utilize the gpu fully== [[Kwon et al. 2023]]. It is therefore necessary to organize their execution while taking into account the available resources  since queries order cannot be predicted. In this work, we are mainly interested in two aspects of this management:query scheduling([[Batching]]
[[Scheduling Policy]]) and [[Memory Management]]


 ==but the number of requests that can be maintained simultaneously remains constrained in particular by the memory ==necessary for their execution, which leads to the second aspect of multi-user processing: [[Memory Management]]