
#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

int main(int argc, char *argv[]) {
    // 1. Check for correct number of arguments
    if (argc != 3) {
        // Log error to syslog and exit
        openlog("writer", LOG_PID, LOG_USER);
        syslog(LOG_ERR, "Error: Two arguments required. Usage: ./writer <file> <string>");
        fprintf(stderr, "Usage: ./writer <file> <string>\n");
        return 1;
    }

    char *filename = argv[1];
    char *text = argv[2];

    // 2. Setup syslog
    openlog("writer", LOG_PID, LOG_USER);

    // 3. Open the file
    // O_WRONLY: Write only
    // O_CREAT: Create if doesn't exist
    // O_TRUNC: Overwrite if exists
    // 0644: Permissions (rw-r--r--)
    int fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    
    if (fd == -1) {
        syslog(LOG_ERR, "Error opening file %s: %s", filename, strerror(errno));
        return 1;
    }

    // 4. Log the attempt
    syslog(LOG_DEBUG, "Writing %s to %s", text, filename);

    // 5. Write to the file
    ssize_t nr = write(fd, text, strlen(text));
    if (nr == -1) {
        syslog(LOG_ERR, "Error writing to file: %s", strerror(errno));
        close(fd);
        return 1;
    }

    // 6. Cleanup
    close(fd);
    closelog();

    return 0;
}

