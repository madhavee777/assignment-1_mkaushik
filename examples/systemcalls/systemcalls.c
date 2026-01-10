#include "systemcalls.h"
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 * successfully using the system() call, false if an error occurred.
*/
bool do_system(const char *cmd)
{
    int ret = system(cmd);
    
    // system() returns -1 on error, or the exit status of the shell
    if (cmd == NULL) return true; // Special case for system() check
    if (ret == -1) return false;
    
    // WIFEXITED checks if child terminated normally, 
    // WEXITSTATUS checks if return code was 0
    if (WIFEXITED(ret) && WEXITSTATUS(ret) == 0) {
        return true;
    }

    return false;
}

/**
* @param count -The numbers of variables passed to the function.
* @return true if the command was executed successfully using fork/execv/waitpid
*/
bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;

    pid_t pid = fork();
    if (pid == -1) {
        perror("fork");
        va_end(args);
        return false;
    } else if (pid == 0) {
        // Child process: execute the command
        // Using execv because it does NOT perform PATH expansion
        execv(command[0], command);
        // If execv returns, it failed
        perror("execv");
        exit(EXIT_FAILURE);
    }

    // Parent process: wait for child
    int status;
    if (waitpid(pid, &status, 0) == -1) {
        perror("waitpid");
        va_end(args);
        return false;
    }

    va_end(args);
    return (WIFEXITED(status) && WEXITSTATUS(status) == 0);
}

/**
* @param outputfile - The full path to the file to write with command output.
*/
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;

    int fd = open(outputfile, O_WRONLY|O_TRUNC|O_CREAT, 0644);
    if (fd < 0) { 
        perror("open"); 
        va_end(args);
        return false; 
    }

    pid_t pid = fork();
    if (pid == -1) {
        perror("fork");
        close(fd);
        va_end(args);
        return false;
    } else if (pid == 0) {
        // Child process: Redirect STDOUT to the file descriptor
        if (dup2(fd, 1) < 0) {
            perror("dup2");
            exit(EXIT_FAILURE);
        }
        close(fd); // No longer need the original fd after dup2
        
        execv(command[0], command);
        perror("execv");
        exit(EXIT_FAILURE);
    }

    // Parent process
    close(fd);
    int status;
    if (waitpid(pid, &status, 0) == -1) {
        va_end(args);
        return false;
    }

    va_end(args);
    return (WIFEXITED(status) && WEXITSTATUS(status) == 0);
}


