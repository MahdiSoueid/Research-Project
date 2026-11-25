```c
/**
 * @param addr1 points to the futex word
 * @param tell the syscall what to do
 * @param val1 this value depends on op
 * The ones below are not needed.
 * @param timeout
 * @param addr2
 * @param val3
 * @return
 */
static int futex(void *addr1, int op, int val1, struct timespec *timeout, void *addr2, int val3) {

return syscall(SYS_futex, addr1, op, val1, timeout, addr2, val3);

futex(cond , FUTEX_WAIT /* or FUTEX_WAKE */ , 0, NULL, NULL, 0);

}
```

this is a syscall inside linux originally , which is the bases of  mutex and cond wait locks /mechanisms [[Mutual exclusion]]we can use it to implement a mutex from scratch and cond-wait from scratch.


