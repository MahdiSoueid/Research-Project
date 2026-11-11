#LLM #Scheduling 

A long [[Prefill Phase]] can mobilize resources for a significant period of time and delay the [[Decode Phase]] iterations of already active requests, which leads Sarathi-Serve 
to c==ut the prefill into several smaller fragments, called chunks, in order to gradually integrate them into the generation iterations.==