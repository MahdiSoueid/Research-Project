#LLM #Feed-Forward-Network
Mixture of Experts:


![[Pasted image 20261108195637.png]]

Relating each token to the correct expert to use and to what extent.

Dense MoE:
Output is weighted average of all experts. Each expert contributes to a certain part of the output.
![[Pasted image 20261108195853.png]]

Sparse MoE (Used in [[LLM]]):
Output is weighted average of selected expert outputs and ignores all the others( Top K experts where K is chosen by us)
![[Pasted image 20261108200005.png]]

Routing collapse: Sometimes this causes certain experts to be consulted more than others which leaves them untrained and under tuned. Therefore , we force others to be part of the consultation via auxiliary loss.

Recent Trends:
We have also shared experts which minimizes redundant information between experts
![[Pasted image 20261108220130.png]]

Fine grained: Increase number of experts which makes each one more experienced in a special field.