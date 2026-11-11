#LLM #Transformer #Decoder-only 
Large Language Model:

A model that associates some probabilities to a sequence of tokens to compute the next token.
Large: Model size in billions of parameters , training data is in billions of tokens and takes a lot of compute

Is a decoder only [[Transformers]]: 
![[Pasted image 20261108194520.png]]

The LLM uses [[MoE]] in the [[Feed Forward Network]] since most the compute relies there and it is where the meaningful relations are found.
