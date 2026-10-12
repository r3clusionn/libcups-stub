CC ?= cc
CFLAGS ?= -O2

libcups.so.2: cups_stub.c
	$(CC) $(CFLAGS) -shared -fPIC -Wl,-soname,libcups.so.2 -o $@ cups_stub.c

check: libcups.so.2
	sh check-symbols.sh $(LIBCEF) libcups.so.2

clean:
	rm -f libcups.so.2

.PHONY: check clean
