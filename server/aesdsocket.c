#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/stat.h>

#define PORT "9000"
#define DATA_FILE "/var/tmp/aesdsocketdata"
#define BUFFER_SIZE 1024

// Global flag for signal handling
volatile sig_atomic_t stop_signal = 0;
int sockfd = -1; // Global so signal handler can close it if stuck in accept

// Signal Handler
void handle_signal(int sig) {
    if (sig == SIGINT || sig == SIGTERM) {
        syslog(LOG_INFO, "Caught signal, exiting");
        stop_signal = 1;
        // Optional: Shutdown socket to force accept() to wake up if blocking
        if (sockfd != -1) {
            shutdown(sockfd, SHUT_RDWR);
        }
    }
}

// Daemonize the process
void daemonize() {
    pid_t pid = fork();

    if (pid < 0) {
        perror("fork failed");
        exit(EXIT_FAILURE);
    }
    if (pid > 0) {
        exit(EXIT_SUCCESS); // Parent exits
    }

    // Create new session
    if (setsid() < 0) {
        perror("setsid failed");
        exit(EXIT_FAILURE);
    }

    // Change working directory to root
    if (chdir("/") < 0) {
        perror("chdir failed");
        exit(EXIT_FAILURE);
    }

    // Redirect standard file descriptors to /dev/null
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);

    int devnull = open("/dev/null", O_RDWR);
    if (devnull != -1) {
        dup2(devnull, STDIN_FILENO);
        dup2(devnull, STDOUT_FILENO);
        dup2(devnull, STDERR_FILENO);
        if (devnull > 2) close(devnull);
    }
}

int main(int argc, char *argv[]) {
    struct addrinfo hints, *res;
    struct sockaddr_storage client_addr;
    socklen_t addr_size;
    int client_fd;
    bool daemon_mode = false;
    char client_ip[INET6_ADDRSTRLEN];

    // Check arguments for daemon mode
    if (argc > 1 && strcmp(argv[1], "-d") == 0) {
        daemon_mode = true;
    }

    // Initialize Syslog
    openlog("aesdsocket", LOG_PID, LOG_USER);

    // Register Signal Handlers
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handle_signal;
    if (sigaction(SIGINT, &sa, NULL) != 0 || sigaction(SIGTERM, &sa, NULL) != 0) {
        perror("sigaction");
        return -1;
    }

    // Setup Socket
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;     // IPv4 or IPv6
    hints.ai_socktype = SOCK_STREAM; // TCP
    hints.ai_flags = AI_PASSIVE;     // Use my IP

    if (getaddrinfo(NULL, PORT, &hints, &res) != 0) {
        perror("getaddrinfo failed");
        return -1;
    }

    sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (sockfd == -1) {
        perror("socket failed");
        freeaddrinfo(res);
        return -1;
    }

    // Allow address reuse (Crucial for restarting tests quickly)
    int yes = 1;
    if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes)) == -1) {
        perror("setsockopt failed");
        freeaddrinfo(res);
        return -1;
    }

    if (bind(sockfd, res->ai_addr, res->ai_addrlen) == -1) {
        perror("bind failed");
        freeaddrinfo(res);
        return -1;
    }

    freeaddrinfo(res);

    // Fork if daemon mode requested
    if (daemon_mode) {
        daemonize();
    }

    if (listen(sockfd, 10) == -1) {
        perror("listen failed");
        return -1;
    }

    // Main Accept Loop
    while (!stop_signal) {
        addr_size = sizeof(client_addr);
        client_fd = accept(sockfd, (struct sockaddr *)&client_addr, &addr_size);

        if (client_fd == -1) {
            if (errno == EINTR) continue; // Signal caught, loop check handles exit
            perror("accept failed");
            continue;
        }

        // Get Client IP for Logging
        if (client_addr.ss_family == AF_INET) {
            inet_ntop(AF_INET, &(((struct sockaddr_in *)&client_addr)->sin_addr), client_ip, sizeof(client_ip));
        } else {
            inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)&client_addr)->sin6_addr), client_ip, sizeof(client_ip));
        }
        syslog(LOG_INFO, "Accepted connection from %s", client_ip);

        // Dynamic Buffer for Reception
        char *buffer = malloc(BUFFER_SIZE);
        if (!buffer) {
            close(client_fd);
            continue;
        }
        size_t current_len = 0;
        size_t capacity = BUFFER_SIZE;
        ssize_t received_bytes;
        bool packet_complete = false;

        // --- RECEIVE LOOP ---
        while ((received_bytes = recv(client_fd, buffer + current_len, capacity - current_len - 1, 0)) > 0) {
            current_len += received_bytes;
            buffer[current_len] = '\0'; // Null terminate for safety

            // Check for newline
            if (strchr(buffer + current_len - received_bytes, '\n')) {
                packet_complete = true;
                break;
            }

            // Expand buffer if full
            if (current_len >= capacity - 1) {
                capacity *= 2;
                char *new_buffer = realloc(buffer, capacity);
                if (!new_buffer) {
                    perror("realloc failed");
                    break;
                }
                buffer = new_buffer;
            }
        }

        if (received_bytes <= 0 && !packet_complete) {
            // Connection closed or error before newline
            free(buffer);
            close(client_fd);
            syslog(LOG_INFO, "Closed connection from %s", client_ip);
            continue;
        }

        // --- WRITE TO FILE ---
        int file_fd = open(DATA_FILE, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (file_fd == -1) {
            perror("File open error");
            syslog(LOG_ERR, "Could not open data file");
        } else {
            if (write(file_fd, buffer, current_len) == -1) {
                perror("File write error");
            }
            close(file_fd);
        }
        free(buffer);

        // --- READ FROM FILE AND SEND BACK ---
        file_fd = open(DATA_FILE, O_RDONLY);
        if (file_fd != -1) {
            char send_buffer[BUFFER_SIZE];
            ssize_t bytes_read;
            while ((bytes_read = read(file_fd, send_buffer, sizeof(send_buffer))) > 0) {
                send(client_fd, send_buffer, bytes_read, 0);
            }
            close(file_fd);
        }

        // Cleanup connection
        close(client_fd);
        syslog(LOG_INFO, "Closed connection from %s", client_ip);
    }

    // --- FINAL CLEANUP ---
    if (sockfd != -1) close(sockfd);
    remove(DATA_FILE);
    closelog();
    
    return 0;
}



