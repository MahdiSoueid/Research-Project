#LLM #Decoder
Idea 1: Take the highest predicted probability but this would result in a non optimum joint probability at the sequence end.
![[Pasted image 20261109222529.png]]

Idea 2: Beam Search , Keep the k paths that are most probable but this would also always result in same sequences and will thus lack creativity
![[Pasted image 20261109222816.png]]

These 2 will make the [[GPT]] and [[LLM]] sound robotic.

Idea 3: Sample the token from the probability distribution.
Top K: Sample among the top k most probable tokens.
![[Pasted image 20261109223315.png]]
Top P: Sample among the smallest set of token that satisfy a certain cumulative probability P
![[Pasted image 20261109223323.png]]