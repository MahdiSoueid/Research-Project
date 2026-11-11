#LLM #Inference 
The model successively generates the tokens composing the response 
![[Pasted image 20261025225917.png]]

using this formula the model calculates the probabilities of each token based on the token that precedes it.

During inference, the text provided by the user, ==called a prompt, constitutes the initial context==. From this context, the ==model calculates a probability distribution over its vocabulary in order to select the next token==. This is then added to the context and used with the previous tokens to generate the next one. ==This process is repeated until an end-of-sequence token is generated== or until a generation limit is reached.

This dependence between tokens imposes a sequential nature on generation, since ==a new token can only be produced once the previous one is available== . Although the generation is autoregressive, ==the processing of the initial context and the generation of subsequent tokens do not have the same execution characteristics==.

![[Pasted image 20261025230430.png]]

The inference process is mainly broken down into two phases: the [[Prefill Phase]], devoted to processing the input context and the generation of the first token, then the [[Decode Phase]], during which the following tokens are generated successively [[Park et al. 2026]]. 

These two phases have different calculation and memory characteristics and rely on the use of the [[KV Cache]]