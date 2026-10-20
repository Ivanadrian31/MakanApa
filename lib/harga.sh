# shellcheck shell=bash # dimuat oleh bin/makan-apa (bukan skrip mandiri)
# lib/harga.sh - parse_harga dan format_harga.

# $1 -> HARGA_NILAI (integer). Menerima 25000, 25rb, 25k, 25.000, 25RB, 25K.
parse_harga() {
  local mentah=${1,,} angka
  angka=${mentah//./}
  case $angka in
    *rb)
      angka=${angka%rb}
      angka=$((angka * 1000))
      ;;
    *k) angka=${angka%k}; angka=$((angka * 1000)) ;;
  esac
  case $angka in
    '' | *[!0-9]*)
      die "harga \"$1\" tidak dikenali. Gunakan 25000, 25rb, atau 25k." 1
      ;;
  esac
  if [ "$angka" -gt 100000000 ]; then
    die "harga \"$1\" terlalu besar (maks 100000000)." 1
  fi
  # shellcheck disable=SC2034 # diisi untuk dibaca pemanggil (kontrak 7/8)
  HARGA_NILAI=$((10#$angka))
}

# 25000 -> 25.000 (pisah ribuan), 8000 -> 8.000.
format_angka() {
  local out='' sisa=$1
  while [ "${#sisa}" -gt 3 ]; do
    out=".${sisa: -3}${out}"
    sisa=${sisa:0:${#sisa}-3}
  done
  printf '%s%s' "$sisa" "$out"
}

# $1=min $2=maks -> stdout "Rp15.000-25.000" atau "Rp20.000" bila sama.
format_harga() {
  printf 'Rp%s' "$(format_angka "$1")"
  if [ "$1" != "$2" ]; then
    printf -- '-%s' "$(format_angka "$2")"
  fi
}