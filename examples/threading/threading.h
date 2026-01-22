#ifndef __THREADING_H
#define __THREADING_H

#include <stdbool.h>
#include <pthread.h>

/**
 * This structure should be dynamically allocated and passed as
 * an argument to your thread using pthread_create.
 * It should be returned by your thread so it can be freed by
 * the joiner.
 */
struct thread_data{
    // 1. Mutex to lock
    pthread_mutex_t *mutex;

    // 2. Time to wait before locking (in ms)
    int wait_to_obtain_ms;

    // 3. Time to wait before releasing (in ms)
    int wait_to_release_ms;

    // 4. Thread completion status (true if successful)
    bool thread_complete_success;
};


bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex,int wait_to_obtain_ms, int wait_to_release_ms);

#endif

