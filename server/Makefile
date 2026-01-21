CC ?= gcc
CFLAGS ?= -g -Wall -Werror
TARGET ?= aesdsocket
LDFLAGS ?= -lrt

all: $(TARGET)

$(TARGET): aesdsocket.c
	$(CC) $(CFLAGS) $(INCLUDES) -o $(TARGET) aesdsocket.c $(LDFLAGS)

clean:
	rm -f $(TARGET) *.o


