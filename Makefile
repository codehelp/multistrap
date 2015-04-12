
DESTDIR ?=
PREFIX ?= /usr
DEST = $(DESTDIR)$(PREFIX)

all: docbuild
	$(MAKE) -C po

docbuild:
	po4a-build

install:
	$(MAKE) -C po install DESTDIR=../debian/multistrap

clean:
	$(RM) *~
	$(MAKE) -C doc clean
	$(MAKE) -C po clean
	$(RM) po/*.gmo po/*.mo

# adds the POT file to the source tarball
native-dist: Makefile
	po4a-build --pot-only
	$(MAKE) -C po pot
