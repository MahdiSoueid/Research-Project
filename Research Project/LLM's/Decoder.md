#LLM #Transformer
[[Vaswani et al 2017]]

Use the meaningful representations from the encoder along with some internal embeddings that are being computed to generate next tokens.

1- output embeddings: will start with the beginning  of sequence token to signal the model plus the positional encoding of that element in the sequence.

![[Pasted image 20261108144346.png|202]]

2- First self attention mechanism [[Attention Mechanism]]: expresses each token as function of itself and all the generated tokens so far .From  \[BS] till \[ES].

3- Second self attention mechanism [[Attention Mechanism]]: 
Let the representation from the generated token so far interact and relate to tokens from the input/encoder .
query from decoder and key & value from the encoder.

4- Feed forward neural network[[Feed Forward Network]]:

5- Project the meaningful outputs to the space of the vocab to get probabilities that correspond to the next token

6- Repeat with the newly generated token as an output embedding till you finish the sequence


Examples: 

GPT = Generative Pre-trained Transformer