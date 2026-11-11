
#LLM #Transformer
A process where input text is cut by a tokenizer into units called tokens. Depending on the tokenization algo, ==🟢a token can correspond to a word, part of a word or even a character==. Each token is then converted into a ==🟢digital representation called embedding==.==🟢Position information is also integrated to emphasize on the order==[[Vaswani et al 2017]]


==Vocabulary== :
==Includes all the possible tokens you can have==.
Depending on the Vocab we can have different sequence lengths

==Special Tokens (some examples)==:
- ==unknown== ( not learned in training) -> same token representation.\[unk]
- ==Beginning of sequence==: \[BS]
- ==End of sequence==:\[ES]
- ==Padding==: \[PAD] used to make sequences consistent in terms of length

Examples: 

==Token = word==
- pros: simple , easy to understand
- cons:Vocab too large to cover all words , risk of having some prompts contain out of vocab words ,
==Token = character.==
- pros: small vocab , robust against mispelings and CASing
- longer seqeuence->more computation , embeddings are more abstract
==Token = Subword== ( root words , prefixes , suffixes for plural , masculine etc...)
- pros: emphasize on roots of words , learned from data
- cons: extra work , depends highly on the quality of training to learn the relations
- ==BPE(Byte-Pair Encoding )==: adds tokens for the most frequent byte pairs ,ie: a - n -> an new token (Learned in Data training)
	- pros: if the prompt has similar words to what was in learning this will result for a shorter sequence 

==Word representations( a way to show relation between tokens):==

==Naive (one-hot)encoding:== 
	example:
	soft=(1,0,0)
	pillow=(0,1,0)
	stone(0,0,1)
- ==Hard to find relations -> dot product is always 0 ( orthogonal)==

==Learned embedding:==

	soft=(0.95 , 0.32 , 0.01)
	pillow=(0.32 , 0.95 , 0.01)
	stone=(0.01 , 0.01 , 0.95)

- ==easier to relate such that soft.pillow ~ 1 and soft.stone~0==


NN that do this:
![[Pasted image 20261029185203.png]]