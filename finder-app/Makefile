# Default target
all: writer

# Compiler and Flags (Buildroot will override these, but they are good for local testing)
CC ?= $(CROSS_COMPILE)gcc
CFLAGS ?= -g -Wall

writer: writer.o
	$(CC) $(CFLAGS) -o writer writer.o

writer.o: writer.c
	$(CC) $(CFLAGS) -c writer.c

clean:
	rm -f writer *.o
