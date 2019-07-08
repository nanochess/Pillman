# Makefile contributed by jtsiomb

src = pillman.asm

.PHONY: all
all: pillman.img pillman.com

pillman.img: $(src)
	nasm -f bin -o $@ $(src)

pillman.com: $(src)
	nasm -f bin -o $@ -Dcom_file=1 $(src)

.PHONY: clean
clean:
	$(RM) pillman.img pillman.com

.PHONY: rundosbox
rundosbox: pillman.com
	dosbox $<

.PHONY: runqemu
runqemu: pillman.img
	qemu-system-i386 -fda pillman.img
