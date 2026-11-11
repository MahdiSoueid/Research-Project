
#LLM #Memory-management ![[Pasted image 20261026120342.png]]

==Internal fragmentation:== part of the ==area reserved for a request remains unused when its sequence ends== before reaching the maximum expected size. 

==External fragmentation:== when ==queries of different sizes complete their execution, the freed areas can be dispersed into several non-contiguous spaces==. The total amount of f==ree memory may then be sufficient for a new query without a sufficiently large contiguous area being available==.

