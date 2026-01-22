#include "threading.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

#define MS_TO_US(x) ((x) * 1000)

void* threadfunc(void* thread_param)
{
    struct thread_data* thread_func_args = (struct thread_data *) thread_param;

    // 1. Wait, obtain mutex
    usleep(MS_TO_US(thread_func_args->wait_to_obtain_ms));

    // 2. Obtain mutex
    int rc = pthread_mutex_lock(thread_func_args->mutex);
    if (rc != 0) {
        perror("pthread_mutex_lock failed");
        thread_func_args->thread_complete_success = false;
        return thread_param;
    }

    // 3. Wait, release mutex
    usleep(MS_TO_US(thread_func_args->wait_to_release_ms));

    // 4. Release mutex
    rc = pthread_mutex_unlock(thread_func_args->mutex);
    if (rc != 0) {
        perror("pthread_mutex_unlock failed");
        thread_func_args->thread_complete_success = false;
        return thread_param;
    }

    thread_func_args->thread_complete_success = true;
    return thread_param;
}

bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex,int wait_to_obtain_ms, int wait_to_release_ms)
{
    struct thread_data *data = (struct thread_data *)malloc(sizeof(struct thread_data));
    if (data == NULL) {
        perror("malloc failed");
        return false;
    }

    data->mutex = mutex;
    data->wait_to_obtain_ms = wait_to_obtain_ms;
    data->wait_to_release_ms = wait_to_release_ms;
    data->thread_complete_success = false;

    int rc = pthread_create(thread, NULL, threadfunc, data);
    if (rc != 0) {
        perror("pthread_create failed");
        free(data);
        return false;
    }

    return true;
}



