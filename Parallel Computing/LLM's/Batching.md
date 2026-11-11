#LLM #Scheduling
Grouping some of them within  the same group, is called batching. The way in which this group is constituted and evolves during execution then depends on the batching strategy used .
Three main strategies :


==Static:== It uses a ==fixed number of requests per group== which is unchanged until all queries have completed. This approach can introduce a ==wait before the start of the inference since it is first necessary to form a complete group== and a wait at the end of the inference when the output lengths differ: a short query can finish its generation well before the others, while the group remains busy until the longest query finishes.
![[Pasted image 20261026114655.png]]

==Dynamic batching==: Dynamic batching, presented in seeks in particular to reduce the waiting time necessary to form a complete group. Instead of systematically waiting for a fixed number of requests, ==they are grouped for a short period of time and execution begins when the maximum group size is reached or when this timeout expires.== The batch size can therefore vary depending on the available requests. ==Once execution begins, however, its composition remains fixed==, so that short queries remain constrained by those whose generation takes longer 

==Continuous batching:==  on the contrary allows the ==composition of the group to evolve during generation==. It is based on scheduling on the scale of iterations where at ==each iteration of decode, completed requests can leave the group and be replaced by new pending requests,== without waiting for the termination of other sequences . Continuous batching is now ==widely adopted in LLM inference systems== and is a common mechanism to improve resource utilization when processing concurrent queries .


![[Pasted image 20261026114817.png]]



When this capacity is reached,==additional requests remain pending. As resources become free, the system must then determine which ones to admit== into the active batch, according to a scheduling policy that can be based on different criteria

[[Sarathi-Serve]]
[[Scheduling Policy]]