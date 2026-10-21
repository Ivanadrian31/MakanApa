VERSION := 0.1.0
SHELL := /bin/bash
PKG := makan-apa_$(VERSION)_all
BUILD := build
DIST := dist
PKGDIR := $(BUILD)/$(PKG)

.PHONY: all check man deb lint uji-pasang versi bersih demo

all: check

check:
	shellcheck --severity=style -x bin/makan-apa lib/*.sh tests/helper.bash
	bats tests/*.bats

man:
	@! groff -man -Tutf8 -ww -z man/makan-apa.1 2>&1 >/dev/null | grep -q .

versi:
	@v_bin=$$(sed -n 's/^VERSI="\(.*\)"$$/\1/p' bin/makan-apa); \
	v_ctl=$$(sed -n 's/^Version: //p' debian/control); \
	v_chg=$$(sed -n '1s/^makan-apa (\(.*\)).*/\1/p' debian/changelog); \
	if [ "$$v_bin" != "$(VERSION)" ] || [ "$$v_ctl" != "$(VERSION)" ] || [ "$$v_chg" != "$(VERSION)" ]; then \
	  echo "versi tidak sinkron: make=$(VERSION) bin=$$v_bin control=$$v_ctl changelog=$$v_chg" >&2; \
	  exit 1; \
	fi; \
	echo "versi $(VERSION) sinkron"

deb: check
	rm -rf "$(PKGDIR)"
	install -d "$(PKGDIR)/DEBIAN" "$(PKGDIR)/usr/bin" "$(PKGDIR)/usr/share/makan-apa/lib" \
	  "$(PKGDIR)/usr/share/man/man1" "$(PKGDIR)/usr/share/bash-completion/completions" \
	  "$(PKGDIR)/usr/share/doc/makan-apa"
	install -m755 bin/makan-apa "$(PKGDIR)/usr/bin/makan-apa"
	install -m644 lib/*.sh "$(PKGDIR)/usr/share/makan-apa/lib/"
	install -m644 data/contoh.tsv "$(PKGDIR)/usr/share/makan-apa/contoh.tsv"
	install -m644 man/makan-apa.1 "$(PKGDIR)/usr/share/man/man1/makan-apa.1"
	gzip -9n "$(PKGDIR)/usr/share/man/man1/makan-apa.1"
	install -m644 completions/makan-apa "$(PKGDIR)/usr/share/bash-completion/completions/makan-apa"
	install -m644 debian/copyright "$(PKGDIR)/usr/share/doc/makan-apa/copyright"
	install -m644 debian/changelog "$(PKGDIR)/usr/share/doc/makan-apa/changelog"
	gzip -9n "$(PKGDIR)/usr/share/doc/makan-apa/changelog"
	install -m644 debian/control "$(PKGDIR)/DEBIAN/control"
	sed -i "s/^Installed-Size:.*/Installed-Size: $$(du -sk "$(PKGDIR)" | cut -f1)/" "$(PKGDIR)/DEBIAN/control"
	install -d "$(DIST)"
	dpkg-deb --build --root-owner-group "$(PKGDIR)" "$(DIST)/$(PKG).deb"

lint:
	lintian "$(DIST)"/*.deb

uji-pasang: deb
	# shortcut: tes pasang dilewati selama tests/pasang-bersih.sh belum ada (B1); hapus
	# penjaga ini saat B1 mendarat supaya tes tidak pernah hilang diam-diam.
	@if [ -f tests/pasang-bersih.sh ]; then bash tests/pasang-bersih.sh; \
	else echo "tes pasang bersih belum ada (menunggu B1)"; fi

bersih:
	rm -rf "$(BUILD)" "$(DIST)"

demo:
	bash demo/demo-2-menit.sh
