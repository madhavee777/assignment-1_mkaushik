CC ?= gcc
CFLAGS ?= -g -Wall -Werror
LDFLAGS ?= -pthread

all: threading

threading: threading.c
	$(CC) $(CFLAGS) $(LDFLAGS) -c threading.c -o threading.o

clean:
	rm -f *.o threading



