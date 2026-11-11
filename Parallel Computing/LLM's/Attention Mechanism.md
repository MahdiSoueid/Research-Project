#LLM #Transformer
It originates from the attention is all you need paper by [[Vaswani et al 2017]].
The attention mechanism allows the model to relate the different tokens in the sequence and determine which context information is most relevant to process a given token.
![[Pasted image 20261029191152.png]]
==🟠Connects words and routes context across tokens .It uses cross tokens and accounts to 33% of the model==, 
==🟢a query represents the information sought by a token( what do you offer)==, ==🔴the keys make it possible to evaluate the relevance of other tokens in relation to this query==, while ==🔵the values ​​contain the information that will actually be combined==.
"The $Q \cdot K$ multiplication tells us how relevant token $B$ is to token $A$ (both in meaning and in relative distance via RoPE). Then, the attention weight acts as a volume slider on $V$, pulling in whichever specific slice of meaning that particular head's $W_v$ was trained to extract

Mathematically:

Matrix Q \[N,1]
Matrix K \[N,1]
Matrix V \[N,1]
==> Q . K(transpose) ->Matrix QK \[N,N]
Attention = Q.K(transpose).V -> matrix \[N,1]


![[Pasted image 20261025215853.png]]


dk represents the dimension of the key vectors
M the causal mask which  prevents a token from taking into account the tokens located after it in the sequence

The QKT product provides scores representing the relationship between queries and keys
In the original Transformer architecture, several attention calculations, called attention heads, are performed in parallel according to the Multi-Head Attention (MHA) mechanism. Each head uses different q , k , v matrices that compute different aspects of context. ( for example , type of words : nouns , verbs. subject verb agreements , classifications etc...)

Variations:
[[Sliding window attention]] a variation in [[LLM]] and [[Decoder]] only models.
[[Group-Query attention]] 
[[Flash attention]]
[[Position Information]]
