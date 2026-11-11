#LLM #Memory-management 
During autoregressive generation, ==recalculating at each iteration the keys and values ​​corresponding to all the previous tokens would result in many redundant calculations==. 

To avoid these recalculations, ==inference systems use a Key-Value cache,== or KV cache.


During [[Prefill Phase]], the K keys and V values ​​produced for the prompt tokens are kept in memory. 
At each [[Decode Phase]] iteration, ==only those corresponding to the new token are calculated and then added to the cache==, while information relating to previous tokens can be directly reused when calculating attention . ==This reuse reduces the calculation volume necessary during decoding, at the cost of additional memory usage==. The cache must also be consulted at each generation step. Its size increases with the length of the context and also depends on the architecture as well as the digital format used to store keys and values ​​. ==In a multi-user environment, multiple caches must be maintained simultaneously, which increases memory requirements and can limit the number of active queries ==

[[Park et al. 2026]]
[[Kwon et al. 2023]]
