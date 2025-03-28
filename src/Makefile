%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(FPIC) -Wall -c -o $@ $<

clean:
	rm -f sendat *.o

sendat: main.o openDev.o
	$(CC) $(CFLAGS) -o $@ $^ -lpthread

compile: sendat

install: compile
	mkdir -p $(DESTDIR)/usr/bin
	install -m 0755 sendat $(DESTDIR)/usr/bin/