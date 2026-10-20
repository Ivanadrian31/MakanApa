#!/usr/bin/env bash
# Uji pasang bersih makan-apa di kontainer Ubuntu (PLAN.md 7.6).
# Pasang .deb, jalankan demo, remove (data tetap), lalu purge.
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

export MAKAN_APA_DATA_DIR=/tmp/data MAKAN_APA_TANGGAL=2026-10-20
makan-apa init
makan-apa pilih --budget 20rb
makan-apa riwayat --hari 3
test "$(makan-apa daftar --tsv | wc -l)" -eq 8

# remove: biner hilang, data pengguna tetap
apt-get remove -y -qq makan-apa
test ! -e /usr/bin/makan-apa
test -f /tmp/data/tempat.tsv

# purge: paket tidak terpasang, data pengguna tetap
apt-get purge -y -qq makan-apa
test ! -e /usr/bin/makan-apa
if dpkg -s makan-apa >/dev/null 2>&1; then
    echo "pasang-bersih: paket masih terdaftar setelah purge." >&2
    exit 1
fi
test -f /tmp/data/tempat.tsv
echo "kontainer: remove dan purge lulus"
EOS

echo "pasang-bersih: OK ($IMG, $DEB)"
