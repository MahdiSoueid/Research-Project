#Edge #LLM

Several approaches can be used to make the models adapt to the edge environment, including the use of more compact models, quantification, pruning and distillation [[Zheng et al. (2025)]]


==Compact models==: A first approach consists of directly ==using models with fewer parameters. Small Language Models (SLM)== thus seek to maintain comprehension and generation capabilities while== reducing calculation and memory requirements==, which facilitates their execution on platforms with limited resources 

==Quantification:== Quantization consists of ==representing model parameters with a reduced number of bits==, for example by moving from an ==FP16 representation to 8-bit or 4-bit formats==. This reduction directly ==reduces the memory required for storing the model and the volume of data handled during inference==, while ==performance gains depend on the ability of the engine and hardware ==to efficiently exploit the format in question. It also introduces a 11 numerical approximation whose impact depends on the model and the format used .

==Pruning==: Pruning consists of==removing parameters or structures considered unimportant in order to reduce the size of the mode==l and the amount of calculation necessary for its execution. It can be applied to ==individual weights or to entire network structures==, such as certain attention heads or layers. The gains obtained at runtime, however, ==depend on the ability of the hardware and the engine to exploit the structure obtained ==

==Distillation:==Distillation involves==training a smaller model, called student, to reproduce the behavior of a larger model, called teacher==. It thus makes it possible to obtain a model requiring ==less memory and calculation while seeking to retain part of the capabilities of the initial model ==