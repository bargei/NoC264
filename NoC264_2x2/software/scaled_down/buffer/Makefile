src = $(wildcard *.c)
obj = $(src:.c=.o)

LDFLAGS =
CFLAGS	= -O3 -std=gnu99

myprog: $(obj)
	$(CC) -o $@ $^ $(LDFLAGS)

.PHONY: clean
clean:
	rm -f $(obj) myprog