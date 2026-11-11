#LLM #Inference 
Preceeded by the [[Prefill Phase]]  

![[Pasted image 20261025232856.png]]

The inference continues with the decode phase. At each iteration, the last token generated is processed by the different layers of model  in order to produce a single new token, taking into account the context accumulated until then . Unlike [[Prefill Phase]], the ==parallelism available within a query is lower, since each new token depends on the previous one==. 
The ==model parameters and information associated with the context must also be consulted at each generation step==. ==The decode is therefore generally more constrained by memory accesses==, in particular because this data must be reread at each iteration . ==A longer output thus implies more decode iterations and therefore more repeated access to the data necessary for generation== [[Park et al. 2026]]