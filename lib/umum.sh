# lib/umum.sh - galat, tanggal, kunci, tulis atomik, validasi dasar.
# Hanya definisi fungsi; dimuat oleh bin/makan-apa.

die() { # $1=pesan $2=kode keluar
  printf 'makan-apa: %s\n' "$1" >&2
  exit "$2"
}

# Galat pemakaian: pesan + baris saran (kontrak K1).
die_opsi() {
  printf 'makan-apa: %s\n' "$1" >&2
  printf "Coba 'makan-apa --help'.\n" >&2
  exit 1
}

peringatan() {
  printf 'makan-apa: peringatan: %s\n' "$1" >&2
}

pangkas() { # stdin->stdout: buang spasi di awal/akhir
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$1"
}

tanggal_valid() { # $1=YYYY-MM-DD -> 0 bila tanggalnya nyata
  local hasil
  case $1 in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) return 1 ;;
  esac
  hasil=$(date -d "$1" +%F 2>/dev/null) || return 1
  [ "$hasil" = "$1" ]
}

hari_ini() {
  if [ -n "${MAKAN_APA_TANGGAL:-}" ]; then
    tanggal_valid "$MAKAN_APA_TANGGAL" ||
      die "MAKAN_APA_TANGGAL harus berformat YYYY-MM-DD dan tanggalnya valid." 1
    HARI_INI=$MAKAN_APA_TANGGAL
  else
    HARI_INI=$(TZ=$ZONA date +%F) || die "gagal membaca tanggal sistem." 3
  fi
}

tanggal_minus() { # $1=jumlah hari -> stdout
  date -d "$HARI_INI - $1 days" +%F
}

siapkan_dir_data() {
  mkdir -p "$DIR_DATA" || die "gagal membuat direktori data: $DIR_DATA" 3
  chmod 700 "$DIR_DATA" || die "gagal mengatur izin direktori data: $DIR_DATA" 3
  if [ ! -e "$FILE_KUNCI" ]; then
    : >"$FILE_KUNCI" || die "gagal membuat berkas kunci: $FILE_KUNCI" 3
  fi
}

ambil_kunci() { # $1=x (eksklusif) atau s (bersama)
  local mode=-s
  if [ "$1" = x ]; then mode=-x; fi
  siapkan_dir_data
  exec 9>>"$FILE_KUNCI" || die "gagal membuka berkas kunci: $FILE_KUNCI" 3
  flock -w 2 "$mode" 9 || die "data sedang dipakai proses lain. Coba lagi sebentar." 4
}

tulis_atomik() { # stdin -> $1, lewat .tmp.$$ lalu mv
  local tujuan=$1
  TMP="$DIR_DATA/.tmp.$$"
  if ! cat >"$TMP" || ! chmod 600 "$TMP" || ! mv -f "$TMP" "$tujuan"; then
    rm -f "$TMP"
    TMP=
    return 1
  fi
  TMP=
}

bersihkan_tmp() {
  if [ -n "${TMP:-}" ]; then rm -f "$TMP"; fi
}

validasi_nama() { # $1 -> NAMA_BERSIH
  local nama
  nama=$(pangkas "$1")
  case $nama in
    '') die "nama tempat tidak boleh kosong." 1 ;;
    '#'*) die "nama tempat tidak boleh diawali '#'." 1 ;;
    *$'\t'* | *$'\n'*) die "nama tempat tidak boleh mengandung tab atau baris baru." 1 ;;
  esac
  if [ "${#nama}" -gt 80 ]; then
    die "nama tempat maksimal 80 karakter." 1
  fi
  NAMA_BERSIH=$nama
}

normalisasi_tag() { # $1 -> TAG_BERSIH (satu tag)
  local tag=${1,,}
  if ! [[ $tag =~ ^[a-z0-9][a-z0-9_-]{0,19}$ ]]; then
    die "tag \"$1\" tidak valid. Gunakan huruf kecil, angka, '-' atau '_' (maks 20 karakter)." 1
  fi
  TAG_BERSIH=$tag
}
