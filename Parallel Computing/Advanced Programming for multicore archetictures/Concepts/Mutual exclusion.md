A method of letting only 1 process/thread access this code section/variable at a time in a way we say that this section will be executed atomically by any thread/process

- Using a mutex (a lock in mutual exclusion):
	- can be implemented using a [[Futex]]
	- It works by having to states busy and free and then only one thread can mark/utilize the busy state.
	- It has 2 operations which are lock , unlock and are atomic.
```c
int balance = 1000;

pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;

// Thread 1
void credit() {

  pthread_mutex_lock(&m);

  int tmp = balance; 

  tmp = tmp + 100;

  balance = tmp;

  pthread_mutex_unlock(&m);

}
//Thread 2

void debit() {

  pthread_mutex_lock(&m);

  int tmp = balance; 

  tmp = tmp - 1;

  balance = tmp;

  pthread_mutex_unlock(&m);

}
```


- Monitor: 
	- can be implemented using a [[Futex]]
	- Waiting for an action in order to proceed
	- need a mutex and a variable condition utilizes a signal to awake the sleeping/waiting mutex from its sleep to try and reacquire the lock.
	- *`pthread_cond_wait , pthread_cond_signal , pthread_cond_broadcast`*
```c
char* msg = NULL; 
pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t c = PTHREAD_COND_INITIALIZER;

//Thread 1
void send() {

  pthread_mutex_lock(&m);
  msg = "Hello!"; 
  pthread_cond_signal(&c);
  pthread_mutex_unlock(&m);
}

//Thread 2

void recv() {

  pthread_mutex_lock(&m);
  while(msg == NULL)
    pthread_cond_wait(&c, &m);
  printf("Message: %s\n", msg);
  pthread_mutex_unlock(&m);
}

```