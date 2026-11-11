#LLM #Scheduling 
==Order of arrival:
First-Come, First-Served (FCFS):==This policy selects requests according to their ==order of arrival==. It is simple to implement since it does not require any additional information on the queries. However,==a long query arriving first can delay the shorter queries that follow it==, a phenomenon called Head-of-Line blocking .

==Processing time:
Shortest Job First (SJF):==
Seeks to favor requests whose ==processing is the shortest in order to reduce their waiting time==. Its application to LLMs is, however, ==difficult, because the length of the response is generally not known before its generation==. Some work therefore seeks to estimate this length or its relative order in order to approach this type of ordering.

==Priority of requests:==
A priority can also be associated with each request in order to process those considered the most important first. This priority can for example reflect different service levels or different latency constraints. ==When several requests have the same priority, their order of arrival can be used to decide between them== . Scheduling thus makes it possible to increase the work executed in parallel.