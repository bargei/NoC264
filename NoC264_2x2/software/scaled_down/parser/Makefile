src = $(wildcard *.c)
obj = $(src:.c=.o)

LDFLAGS =
CFLAGS	= -O3 -g -std=gnu99

parser_prog: $(obj)
	$(CC) -o $@ $^ $(LDFLAGS)

.PHONY: clean
clean:
	rm -f $(obj) parser_prog