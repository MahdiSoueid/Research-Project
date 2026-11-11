#LLM #Inference

![[Pasted image 20261025232850.png]]The prefill phase corresponds to the ==processing of the initial context==  , prompt, provided by the user. 
All the tokens in the prompt are processed by the Transformer blocks in order to construct their representations and produce the information necessary for generating the first token [[Park et al. 2026]].
As the ==prompt tokens are available from the start of the inference, the operations associated with them can be carried out in parallel==.
The main matrix operations are thus applied to several tokens simultaneously, which promotes good exploitation of the available calculation units. The amount of calculation carried out during prefill, however, ==strongly depends on the length of the input context: when this increases, the calculation volume and the quantity of data handled also increase== 

proceeded by [[Decode Phase]]
Summary: Can be carried in parallel since all the prompt is available at start