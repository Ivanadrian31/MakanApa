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

# Skrip dalam kontainer ditulis ke berkas lalu dibaca bash sebagai argumen, bukan
# lewat stdin: apt-get membaca stdin dan akan memakan sisa heredoc.
docker run --rm \
    -e DEBIAN_FRONTEND=noninteractive \
    -e DEB="$DEB" \
    -e VERSI="$VERSI" \
    -v "$PWD/dist:/deb:ro" \
    "$IMG" bash -euo pipefail -c "$(
        cat <<'EOS'
cek() { # cek <keterangan> <perintah...>
    local keterangan=$1
    shift
    if "$@"; then
        printf '  ok  %s\n' "$keterangan"
    else
        printf '  GAGAL %s\n' "$keterangan" >&2
        return 1
    fi
}

# apt-get tidak boleh membaca stdin skrip ini.
apt-get update -qq </dev/null

# Kontrak 10: 15 berkas, mode 0755 (biner) dan 0644 (lainnya). dpkg-deb -c juga
# mencantumkan direktori, jadi hanya entri berkas biasa yang dihitung.
ISI_PAKET=$(dpkg-deb -c "/deb/$DEB" |
    awk '$1 ~ /^-/ {print substr($1, 1, 10), $NF}' |
    sed 's#^\(.*\) \./#\1 /#' | sort)
ada_di_paket() { grep -qxF -e "$1 $2" <<<"$ISI_PAKET"; }
cek "paket berisi 15 path" test "$(wc -l <<<"$ISI_PAKET")" -eq 15
for path in /usr/share/makan-apa/lib/umum.sh /usr/share/makan-apa/lib/harga.sh \
    /usr/share/makan-apa/lib/data.sh /usr/share/makan-apa/lib/saring.sh \
    /usr/share/makan-apa/lib/cmd-dasar.sh /usr/share/makan-apa/lib/cmd-pilih.sh \
    /usr/share/makan-apa/lib/cmd-ubah.sh /usr/share/makan-apa/lib/cmd-impor.sh \
    /usr/share/makan-apa/lib/cmd-riwayat.sh /usr/share/makan-apa/contoh.tsv \
    /usr/share/man/man1/makan-apa.1.gz /usr/share/bash-completion/completions/makan-apa \
    /usr/share/doc/makan-apa/copyright /usr/share/doc/makan-apa/changelog.gz; do
    cek "paket berisi $path" ada_di_paket -rw-r--r-- "$path"
done
cek "paket berisi /usr/bin/makan-apa" ada_di_paket -rwxr-xr-x /usr/bin/makan-apa

apt-get install -y -qq "/deb/$DEB" </dev/null

# dpkg pada citra kontainer mengecualikan /usr/share/man dan /usr/share/doc saat
# mengekstrak, jadi berkas yang sudah terpasang diperiksa lewat daftar berkas paket
# (dpkg-query -L), sedangkan berkas tanpa pengecualian diperiksa langsung.
TERPASANG=$(dpkg-query -L makan-apa)
terdaftar() { grep -qxF -e "$1" <<<"$TERPASANG"; }
cek "terpasang: biner" terdaftar /usr/bin/makan-apa
cek "terpasang: man page" terdaftar /usr/share/man/man1/makan-apa.1.gz
cek "terpasang: dokumentasi" terdaftar /usr/share/doc/makan-apa/copyright
cek "terpasang: changelog" terdaftar /usr/share/doc/makan-apa/changelog.gz

cek "biner terpasang dan executable" test -x "/usr/bin/makan-apa"
cek "completion terpasang" test -f "/usr/share/bash-completion/completions/makan-apa"
for pustaka in umum harga data saring cmd-dasar cmd-pilih cmd-ubah cmd-impor cmd-riwayat; do
    cek "pustaka $pustaka.sh terpasang" test -f "/usr/share/makan-apa/lib/$pustaka.sh"
done
cek "isi contoh terpasang" test -f "/usr/share/makan-apa/contoh.tsv"
cek "versi sesuai nama paket" test "$(makan-apa --version)" = "makan-apa $VERSI"

# Perintah belum ada di build ini dijawab "belum tersedia" (kontrak P5). Keadaan itu
# boleh sampai A6, jadi demo dilewati untuk perintah itu saja; galat lain tetap
# menggagalkan tes.
demo() {
    local perintah=$1 galat kod
    shift
    if galat=$(makan-apa "$perintah" "$@" 2>&1); then
        printf '  demo %s -> %s\n' "$perintah" "$galat"
        return 0
    else
        kod=$?
        if [ "$kod" -eq 3 ] && [[ $galat == *"belum tersedia di build ini"* ]]; then
            printf '  demo %s dilewati: perintah belum tersedia di build ini\n' "$perintah"
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
    # init belum tersedia; buat data pengguna sendiri supaya pemeriksaan "data
    # tetap setelah remove/purge" tetap teruji.
    printf 'Bakso Sapi Campur\t14000\t24000\tbakso,berkuah\tporsi jumbo\n' \
        >"$MAKAN_APA_DATA_DIR/tempat.tsv"
fi
chmod 700 "$MAKAN_APA_DATA_DIR"
cek "data pengguna ada sebelum remove" test -f "$MAKAN_APA_DATA_DIR/tempat.tsv"

# Terpasang bila dpkg melaporkan status "installed" (dpkg-query keluar != 0 setelah
# remove/purge, jadi redirection ke /dev/null tidak cukup).
terpasang() {
    [ "$(dpkg-query -W -f='${db:Status-Status}' makan-apa 2>/dev/null || true)" = installed ]
}

# remove: biner hilang, data pengguna tetap
apt-get remove -y -qq makan-apa </dev/null
cek "biner hilang setelah remove" test ! -e "/usr/bin/makan-apa"
cek "data tetap setelah remove" test -f "$MAKAN_APA_DATA_DIR/tempat.tsv"
if terpasang; then
    echo "pasang-bersih: paket masih terpasang setelah remove." >&2
    exit 1
fi

# purge: paket tidak terpasang, data pengguna tetap
apt-get purge -y -qq makan-apa </dev/null
cek "biner hilang setelah purge" test ! -e "/usr/bin/makan-apa"
cek "data tetap setelah purge" test -f "$MAKAN_APA_DATA_DIR/tempat.tsv"
if terpasang; then
    echo "pasang-bersih: paket masih terpasang setelah purge." >&2
    exit 1
fi
cek "berkas paket hilang setelah purge" test ! -e "/usr/share/makan-apa"
echo "kontainer: remove dan purge lulus"
EOS
    )"

echo "pasang-bersih: OK ($IMG, $DEB)"