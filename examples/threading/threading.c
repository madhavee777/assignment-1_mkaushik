#include "threading.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

// Optional: Use syslog for logging if you like
// #include <syslog.h>

void* threadfunc(void* thread_param)
{
    // Cast the parameter to our structure
    struct thread_data* thread_func_args = (struct thread_data *) thread_param;

    // 1. Wait to obtain the mutex (convert ms to us)
    usleep(thread_func_args->wait_to_obtain_ms * 1000);

    // 2. Obtain the mutex
    int rc = pthread_mutex_lock(thread_func_args->mutex);
    if (rc != 0) {
        printf("ERROR: Failed to obtain mutex\n");
        thread_func_args->thread_complete_success = false;
        return thread_param;
    }

    // 3. Wait to release the mutex
    usleep(thread_func_args->wait_to_release_ms * 1000);

    // 4. Release the mutex
    rc = pthread_mutex_unlock(thread_func_args->mutex);
    if (rc != 0) {
        printf("ERROR: Failed to release mutex\n");
        thread_func_args->thread_complete_success = false;
        return thread_param;
    }

    // If we got here, everything worked!
    thread_func_args->thread_complete_success = true;
    return thread_param;
}

bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex, int wait_to_obtain_ms, int wait_to_release_ms)
{
    // 1. Allocate memory for thread_data
    struct thread_data* data = (struct thread_data*) malloc(sizeof(struct thread_data));
    if (data == NULL) {
        printf("ERROR: Could not allocate memory for thread_data\n");
        return false;
    }

    // 2. Setup the structure
    data->mutex = mutex;
    data->wait_to_obtain_ms = wait_to_obtain_ms;
    data->wait_to_release_ms = wait_to_release_ms;
    data->thread_complete_success = false; 

    // 3. Create the thread
    int rc = pthread_create(thread, NULL, threadfunc, data);
    if (rc != 0) {
        printf("ERROR: Failed to create thread\n");
        free(data); // Don't leak memory if thread creation fails
        return false;
    }

    return true;
}



