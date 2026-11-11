#LLM 
[[Vaswani et al 2017]]

Compute meaningful embeddings of the source text/input.

-Example : translation ( main usage for translation in [[Vaswani et al 2017]])


![[Pasted image 20261108143711.png|240]]]

1- ==Input Embeddings:==
Takes input as text and associate embeddings to each token from other tokens ( not context aware) with the position embeddings.

Positional encoding(embeddings): can be either learned or hardcoded.

2- self attentions phase: Computes representations of tokens as a function of all other tokens [[Attention Mechanism]]. Will learn projection matrices that relate tokens to each other

3- Feed Forward neural network[[Feed Forward Network]]: Project our representation into spaces of higher dimension which allows us to learn non linearities.

Examples: BERT ( Bidirectional Encoder Representations from Transformers)

