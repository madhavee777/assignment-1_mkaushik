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

volatile sig_atomic_t stop_signal = 0;
int sockfd = -1;

void handle_signal(int sig) {
    if (sig == SIGINT || sig == SIGTERM) {
        stop_signal = 1;
        if (sockfd != -1) shutdown(sockfd, SHUT_RDWR);
    }
}

void daemonize() {
    pid_t pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);

    if (setsid() < 0) exit(EXIT_FAILURE);
    if (chdir("/") < 0) exit(EXIT_FAILURE);

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
    char client_ip[INET6_ADDRSTRLEN];
    bool daemon_mode = (argc > 1 && strcmp(argv[1], "-d") == 0);

    // SAFETY CLEANUP: Ensure clean state
    remove(DATA_FILE);

    openlog("aesdsocket", LOG_PID, LOG_USER);
    
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handle_signal;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;

    if (getaddrinfo(NULL, PORT, &hints, &res) != 0) return -1;

    sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (sockfd == -1) {
        freeaddrinfo(res);
        return -1;
    }

    int yes = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    if (bind(sockfd, res->ai_addr, res->ai_addrlen) == -1) {
        freeaddrinfo(res);
        return -1;
    }
    freeaddrinfo(res);

    if (daemon_mode) {
        daemonize();
    }

    if (listen(sockfd, 10) == -1) return -1;

    while (!stop_signal) {
        addr_size = sizeof(client_addr);
        client_fd = accept(sockfd, (struct sockaddr *)&client_addr, &addr_size);
        
        if (client_fd == -1) continue;

        if (client_addr.ss_family == AF_INET) {
            inet_ntop(AF_INET, &(((struct sockaddr_in *)&client_addr)->sin_addr), client_ip, sizeof(client_ip));
        } else {
            inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)&client_addr)->sin6_addr), client_ip, sizeof(client_ip));
        }
        syslog(LOG_INFO, "Accepted connection from %s", client_ip);

        char *buffer = malloc(BUFFER_SIZE);
        if (!buffer) {
            close(client_fd);
            continue;
        }
        
        size_t current_len = 0;
        size_t capacity = BUFFER_SIZE;
        ssize_t received_bytes;
        bool packet_complete = false;

        while (1) {
            received_bytes = recv(client_fd, buffer + current_len, capacity - current_len - 1, 0);
            
            if (received_bytes <= 0) {
                // If disconnected but we have data, mark complete
                if (current_len > 0) packet_complete = true;
                break;
            }

            current_len += received_bytes;
            buffer[current_len] = '\0';

            if (strchr(buffer, '\n')) {
                packet_complete = true;
                break;
            }

            if (current_len >= capacity - 1) {
                capacity *= 2;
                char *tmp = realloc(buffer, capacity);
                if (!tmp) break;
                buffer = tmp;
            }
        }

        if (packet_complete) {
            int file_fd = open(DATA_FILE, O_WRONLY | O_CREAT | O_APPEND, 0644);
            if (file_fd != -1) {
                write(file_fd, buffer, current_len);
                close(file_fd);
            }

            file_fd = open(DATA_FILE, O_RDONLY);
            if (file_fd != -1) {
                char send_buffer[BUFFER_SIZE];
                ssize_t bytes_read;
                while ((bytes_read = read(file_fd, send_buffer, sizeof(send_buffer))) > 0) {
                    send(client_fd, send_buffer, bytes_read, 0);
                }
                close(file_fd);
            }
        }

        free(buffer);
        close(client_fd);
        syslog(LOG_INFO, "Closed connection from %s", client_ip);
    }

    if (sockfd != -1) close(sockfd);
    remove(DATA_FILE);
    closelog();
    return 0;
}


