#LLM #Multi-Head-Attention  #GPU-Kernel #Memory-management 
Flash attention is a way to compute the [[Attention Mechanism]]faster by minimizing the reads and writes from the GPU global memory to the shared memory.
![[Pasted image 20261110230353.png]]
Usually the global memory is big and slow and the shared memory is fast and small.
In normal attention , we first import the q , k  to shared to compute their result which is in \[N.N] size then we write it back to global memory .Then we do the softmax to it which required recopying data from global to shared. Then we multiply by -> recopying.

In Flash attention we only copy the values once in the sense that we compute the output gradually from the imported tiles of q , k , v while applying the softmax iteratively resulting in an output with less copying between shared and global memory.
![[Pasted image 20261110230428.png]]

q1 is fixed in shared memory while Ki , Vi are copied iteratively and in the same time the output is iteratively computed by the first picture.(fa2).

This result in a faster computation by drastically decreasing the memory copying.

There fa1 which basically flips the loops and makes kv outer and q inner so we had to compute o1,o2 ...On and write them back but this is solved in fa2 by keeping q1 and looping over kn,vn to write o1 once.

Fa3 optimizes it based on the hopper nvidia series
fa4 optimizes it based on the blackwell nvidia series.
