#Transformer 
Bidirectional Encoder Representations From Transformers
Take only encoder parts of the transformer and leverage the multi head layer in order to have all the input tokens attend to one another to make a representation to do a task.

Classification ,  is this token noun or verb?

How to train (strategy):
Step1:  Pretraining with proxy tasks:
Goal is to understand how the text is written . Proxy task are not an end goal but are used to achieve an end goal which is in this case understanding text.
Very expensive and is mainly done once
Masked Language Modeling (MLM):
![[Pasted image 20261108190937.png]]
-> Masking some tokens and then computing the attention using these corrupted tokens to predict these masked tokens which will allow it learn how to write text.

Next Sentence Prediction ( NSP): 
![[Pasted image 20261108190715.png]]
->Goal is to understand how sentences are sequenced.
Adding a \[sep] token and testing the model to see if these sentences follow each other or no

Step2: Finetuning for Given tasks.
->Assume model understands text better
->adapt the model to a specific use case we are interested in.
Takes a \[cls] token that carries the representation of the sentence and projects it with the states of interest in this case positive and negative
For example: Sentiment extraction to see if the sentence is positive or negative.

Cons: Bad for some texts such as text generation