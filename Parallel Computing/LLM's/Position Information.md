#LLM #Tokenization

Add position embedding to each token to have an embedding with position semantics.

Learned Position-specific embedding: [[Vaswani et al 2017]]
Add a position specific embedding to the token , but it is learning based so if we train the model on smaller sequences then once we prompt longer ones we will have no embeddings for positions in that are longer than what we learned.

Hardcoded position-specific embedding: [[Vaswani et al 2017]]
using sin and cosine functions to add the position embeddings to each token in a sense where smaller indices have a more varying frequency than the larger indices resulting in a much higher embedding as the tokens are closer.
->drawback is that the position embedding is added to the token layer itself which is irrelevant for the [[Feed Forward Network]]

position are relative only in the [[Attention Mechanism]].

Therefore , do a change on the level of the [[Attention Mechanism]].

add a bias to the softmax
-> T5 bias: bias learned per head
-> ALiBi : Bias is linear , deterministic

Common method now:
RoPE: Rotary Position Embeddings
![[Pasted image 20261109174920.png]]
Do not add bias but rotate the q , k matrices by a certain matrix rotation.
This will allow us to have a relation between positions as we compute the qkv matrix result in [[Attention Mechanism]]
![[Pasted image 20261109174944.png]]
the resulting matrix between two position will capture the difference between them in the output.
In this case each token vector will be rotated by a factor of dmodel/2 times for each 2 pairs of indices in the matrix  per attention head.
