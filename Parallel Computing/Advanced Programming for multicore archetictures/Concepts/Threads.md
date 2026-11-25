It is a lightweight [[Process]] of type *`pthread_t`* and identifier of *`pthread_t pthread_self()`* in runtime

*`Creation:`* 
```c
int pthread_create(pthread_t* tid, pthread_attr_t* attr, void* (*start_routine)(void*), void* arg)


void* f(void* arg) { printf("f is running\n"); return NULL; }

  

int main(int argc, char** argv) {

  pthread_t tid;

  pthread_create(&tid, NULL, f, NULL);

  printf("main is running in parallel with f\n");

}


```


*`Waiting for thread termination:`*

```c
int pthread_join(pthread_t thread, void** pretval);


void* f(void* arg) { 

  printf("f is running\n"); 

  return (void*)0x42; 

}

  

int main(int argc, char** argv) {

  pthread_t tid;

  void* retval;

  pthread_create(&tid, NULL, f, NULL);

  printf("main is running in parallel with f\n");

  pthread_join(tid, &retval);

  printf("f terminated with retval %p\n", retval);

}
```

Two or more threads working on the same shared variables causes race conditions so if we wanna have such implementation we need to have the variables accessed in [[Mutual exclusion]] and we treat this section of the code as a critical section.


