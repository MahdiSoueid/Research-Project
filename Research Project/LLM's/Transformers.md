#LLM 
==🟢 A process of blocks utilizing certain weights and attentions to calculate then  predict the next set of words== .

![[Pasted image 20261108142407.png]]
![[Pasted image 20261108184149.png]]
Transformer Types: Encoder , Encoder-Decoder , Decoder.

==🟢[[Encoder]]== Takes an input string to analyze used mainly in classification or information extraction tasks[[Vaswani et al 2017]].
[[BERT]]
![[Pasted image 20261108191525.png]]


==🟢Encoder-Decoder==: Both encoder and decoder which generates a sequence  of output based on the representation from the encoder [[Vaswani et al 2017]]

[[Decoder]]: uses only the section of blocks that outputs words based on the context of previous ones [[Vaswani et al 2017]]
[[GPT]]
![[Pasted image 20261108191556.png]]

Each block is mainly based on three elements: the [[Attention Mechanism]], the [[Feed Forward Network]] (FFN), as well as [[Layer Normalization]] and [[Residual connections]] .

Also we have multi headed attention which works like kernels in image blurring in a way that each kernel/head can allow us to learn different embeddings and relations.




Takes input from [[Tokenization]].



