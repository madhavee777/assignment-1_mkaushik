#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <string.h>

int main(int argc, char *argv[]) {
    // Check for correct number of arguments
    if (argc != 3) {
        openlog("writer", LOG_PID, LOG_USER);
        syslog(LOG_ERR, "Error: Two arguments required: <file> <string>");
        closelog();
        return 1;
    }

    char *filename = argv[1];
    char *content = argv[2];

    openlog("writer", LOG_PID, LOG_USER);
    syslog(LOG_DEBUG, "Writing %s to %s", content, filename);

    FILE *file = fopen(filename, "w");
    if (file == NULL) {
        syslog(LOG_ERR, "Error: Could not open file %s", filename);
        closelog();
        return 1;
    }

    fprintf(file, "%s", content);
    fclose(file);
    closelog();

    return 0;
}

