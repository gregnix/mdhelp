# mdhelp4 Makefile -- App, Tests, Modul-Install
#
# mdhelp4 ist eine APP. Externe Module (docir, mdstack, pdf4tcllib)
# muessen vorher installiert sein. Eigene Module liegen in lib/tm/
# und werden im Entwicklungsmodus per tcl::tm::path-add geladen.

PREFIX     ?= /usr/local
INSTALLDIR := $(PREFIX)/lib/tcltk/mdhelp
USERDIR    := $(HOME)/lib/tcltk/mdhelp

.PHONY: install install-user uninstall test pkgindex help

help:
	@echo "Targets:"
	@echo "  make install        # eigene Module nach $(INSTALLDIR)"
	@echo "  make install-user   # nach $(USERDIR)"
	@echo "  make pkgindex       # pkgIndex.tcl neu generieren"
	@echo "  make test           # Tests"

install:
	mkdir -p $(INSTALLDIR)
	cp -r lib/tm/. $(INSTALLDIR)/

install-user:
	mkdir -p $(USERDIR)
	cp -r lib/tm/. $(USERDIR)/

uninstall:
	rm -rf $(INSTALLDIR)

pkgindex:
	tclsh tools/generate-pkgindex.tcl lib/tm --write

test:
	cd tests && tclsh run_all_tests.tcl
