#LLM #Memory-management 
As presented previously, the [[KV Cache]] of a request gradually increases with the number of tokens in its context. After [[Prefill Phase]], it contains the information associated with the prompt tokens, then it grows by one token with each [[Decode Phase]]iteration. As the final length of the response is not known in advance, the final size of the [[KV Cache]]of a request cannot therefore be determined precisely at the start of its execution .

In a [[Multi-user inference]], several [[KV Cache]] evolve simultaneously and independently. A classic approach consists of reserving for each request a ==contiguous memory area large enough to contain its cache up to a maximum length==. This allocation simplifies memory management, but can result in two forms of [[Fragmentation]]

![[Pasted image 20261026120342.png]]

