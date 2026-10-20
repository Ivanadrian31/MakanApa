#!/usr/bin/env bash
# Uji pasang bersih makan-apa di kontainer Ubuntu (PLAN.md 7.6).
# Pasang .deb, jalankan demo, remove (data tetap), lalu purge (paket hilang).
# Pemakaian: make deb && tests/pasang-bersih.sh
# Ganti citra dengan: IMG=ubuntu:22.04 tests/pasang-bersih.sh
set -euo pipefail

IMG=${IMG:-ubuntu:24.04}
cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
    echo "pasang-bersih: docker tidak ditemukan." >&2
    exit 1
fi

shopt -s nullglob
debs=(dist/makan-apa_*_all.deb)
shopt -u nullglob
if (( ${#debs[@]} == 0 )); then
    echo "pasang-bersih: dist/makan-apa_*_all.deb tidak ada. Jalankan 'make deb' dulu." >&2
    exit 1
fi

DEB=$(basename "${debs[-1]}")
VERSI=${DEB#makan-apa_}
VERSI=${VERSI%_all.deb}
echo "pasang-bersih: $DEB di $IMG"

docker run --rm -i \
    -e DEBIAN_FRONTEND=noninteractive \
    -e DEB="$DEB" \
    -e VERSI="$VERSI" \
    -v "$PWD/dist:/deb:ro" \
    "$IMG" bash -euo pipefail -s <<'EOS'
apt-get update -qq
apt-get install -y -qq "/deb/$DEB"

test "$(makan-apa --version)" = "makan-apa $VERSI"
test -x /usr/bin/makan-apa
test -f /usr/share/man/man1/makan-apa.1.gz
test -f /usr/share/bash-completion/completions/makan-apa
for pustaka in umum harga data saring cmd-dasar cmd-pilih cmd-ubah cmd-impor cmd-riwayat; do
    test -f "/usr/share/makan-apa/lib/$pustaka.sh"
done

# Perintah belum di build ini dijawab "belum tersedia" (kontrak P5). Keadaan itu
# boleh sampai A6, jadi demo dilewati untuk perintah itu saja; galat lain
# tetap menggagalkan tes.
demo() {
    local perintah=$1 galat kod
    shift
    if galat=$(makan-apa "$perintah" "$@" 2>&1); then
        printf '%s\n' "$galat"
        return 0
    else
        kod=$?
        if [ "$kod" -eq 3 ] && [[ $galat == *"belum tersedia di build ini"* ]]; then
            echo "  (lewati demo '$perintah': perintah belum tersedia di build ini)"
            return 0
        fi
        printf '%s\n' "$galat" >&2
        return "$kod"
    fi
}

export MAKAN_APA_DATA_DIR=/tmp/data MAKAN_APA_TANGGAL=2026-10-20
mkdir -p "$MAKAN_APA_DATA_DIR"
demo init
demo pilih --budget 20rb
demo riwayat --hari 3
if [ ! -f "$MAKAN_APA_DATA_DIR/tempat.tsv" ]; then
    # init belum tersedia; buat data pengguna sendiri supaya pemeriksaan
    # "data tetap setelah remove/purge" tetap teruji.
    printf 'Bakso Sapi Campur\t14000\t24000\tbakso,berkuah\tporsi jumbo\n' \
        >"$MAKAN_APA_DATA_DIR/tempat.tsv"
fi
chmod 700 "$MAKAN_APA_DATA_DIR"
test -f "$MAKAN_APA_DATA_DIR/tempat.tsv"

# Terpasang bila dpkg melaporkan status "installed" (dpkg-query keluar != 0 setelah
# remove/purge, jadi redirection ke /dev/null tidak cukup).
terpasang() {
    [ "$(dpkg-query -W -f='${db:Status-Status}' makan-apa 2>/dev/null || true)" = installed ]
}

# remove: biner hilang, data pengguna tetap
apt-get remove -y -qq makan-apa
test ! -e /usr/bin/makan-apa
test -f "$MAKAN_APA_DATA_DIR/tempat.tsv"
terpasang || { echo "pasang-bersih: paket masih terpasang setelah remove." >&2; exit 1; }

# purge: paket tidak terpasang, data pengguna tetap
apt-get purge -y -qq makan-apa
test ! -e /usr/bin/makan-apa
test -f "$MAKAN_APA_DATA_DIR/tempat.tsv"
if terpasang; then
    echo "pasang-bersih: paket masih terpasang setelah purge." >&2
    exit 1
fi
test ! -e /usr/share/makan-apa
echo "kontainer: remove dan purge lulus"
EOS

echo "pasang-bersih: OK ($IMG, $DEB)"