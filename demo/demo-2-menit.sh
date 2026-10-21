#!/usr/bin/env bash
# demo/demo-2-menit.sh - demo 2 menit (PLAN.md §1) yang dapat diulang persis.
#
# Sumber acak dikunci (MAKAN_APA_SEED) dan tanggal dipalsukan
# (MAKAN_APA_TANGGAL), jadi keluarannya sama setiap kali skrip ini dijalankan
# dan sama dengan transkrip di README.md. Data demo ditulis ke direktori
# terpisah, jadi data pengguna asli tidak tersentuh.
#
# Pemakaian: demo/demo-2-menit.sh              # cetak transkrip ke stdout
#            demo/demo-2-menit.sh > demo.txt   # simpan transkrip
set -euo pipefail

DEMO_DIR=${MAKAN_APA_DEMO_DIR:-/tmp/makan-apa-demo}
case $DEMO_DIR in ''|/) echo "demo: direktori demo tidak aman: '$DEMO_DIR'" >&2; exit 1 ;; esac
MAKAN_APA_DATA_DIR=$DEMO_DIR
MAKAN_APA_SEED=${MAKAN_APA_SEED:-11}
export MAKAN_APA_DATA_DIR MAKAN_APA_SEED

# Biner yang dipakai: yang terpasang di sistem, atau repo ini kalau paket
# belum dipasang. Teks yang ditampilkan tetap "makan-apa ..." supaya
# transkripnya sama dengan README.md.
if command -v makan-apa >/dev/null 2>&1; then
    MAKAN_APA_BIN=makan-apa
else
    MAKAN_APA_BIN="$(cd "$(dirname "$0")/.." && pwd)/bin/makan-apa"
fi

# Blok pertama ("$ makan-apa init") tidak didahului baris kosong; blok
# berikutnya dipisah satu baris kosong, seperti transkrip README.md.
pertama=1

jalankan() { # jalankan <teks yang ditampilkan> <perintah...>
    local tampil=$1
    shift
    if [ "$pertama" = 1 ]; then
        pertama=0
    else
        printf '\n'
    fi
    printf '$ %s\n' "$tampil"
    "$@" 2>&1
}

rm -rf "$MAKAN_APA_DATA_DIR"

printf '$ export MAKAN_APA_DATA_DIR=%s\n' "$MAKAN_APA_DATA_DIR"
jalankan "makan-apa init" "$MAKAN_APA_BIN" init
jalankan "MAKAN_APA_TANGGAL=2026-10-18 makan-apa pilih" \
    env MAKAN_APA_TANGGAL=2026-10-18 "$MAKAN_APA_BIN" pilih
jalankan "MAKAN_APA_TANGGAL=2026-10-19 makan-apa pilih" \
    env MAKAN_APA_TANGGAL=2026-10-19 "$MAKAN_APA_BIN" pilih
jalankan "MAKAN_APA_TANGGAL=2026-10-20 makan-apa pilih" \
    env MAKAN_APA_TANGGAL=2026-10-20 "$MAKAN_APA_BIN" pilih
jalankan "MAKAN_APA_TANGGAL=2026-10-20 makan-apa riwayat --hari 3" \
    env MAKAN_APA_TANGGAL=2026-10-20 "$MAKAN_APA_BIN" riwayat --hari 3
jalankan "MAKAN_APA_TANGGAL=2026-10-20 makan-apa pilih --ulang --budget 20rb --ketat" \
    env MAKAN_APA_TANGGAL=2026-10-20 "$MAKAN_APA_BIN" pilih --ulang --budget 20rb --ketat
jalankan "MAKAN_APA_TANGGAL=2026-10-20 makan-apa riwayat --hari 1" \
    env MAKAN_APA_TANGGAL=2026-10-20 "$MAKAN_APA_BIN" riwayat --hari 1
