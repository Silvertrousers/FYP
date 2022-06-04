BIN = SW_Renderer

CFLAGS = -std=c99 -Wall -Wextra -pedantic -Ofast -flto -march=native

CC = gcc

SRC = main.c

PRIMITIVES = primitives.h

all:
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRC) -o $(BIN)

run:
	./$(BIN)

clean:
	rm -f $(BIN)
