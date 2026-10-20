# lib/data.sh - baca/tulis tempat.tsv (kontrak 3.2).
# Hanya definisi fungsi; dimuat oleh bin/makan-apa.

# Isi KOLOM[] dari satu baris TSV; tab di akhir baris tetap menghasilkan kolom kosong.
pecah_kolom() {
  local sisa=$1
  KOLOM=()
  while :; do
    if [[ $sisa == *$'\t'* ]]; then
      KOLOM+=("${sisa%%$'\t'*}")
      sisa=${sisa#*$'\t'}
    else
      KOLOM+=("$sisa")
      break
    fi
  done
}

harga_sah() { # $1 -> 0 bila bilangan bulat 0..100000000
  [[ $1 =~ ^[0-9]+$ ]] || return 1
  [ "$((10#$1))" -le 100000000 ]
}

# Baca tempat.tsv -> TEMPAT[] (baris ternormalisasi) + TEMPAT_TOTAL.
baca_tempat() {
  TEMPAT=()
  TEMPAT_TOTAL=0
  [ -f "$FILE_TEMPAT" ] || return 0
  local baris n=0 rusak=0 nama hmin hmax tag catatan
  while IFS= read -r baris || [ -n "$baris" ]; do
    n=$((n + 1))
    baris=${baris%$'\r'}
    case $(pangkas "$baris") in
      '' | '#'*) continue ;;
    esac
    pecah_kolom "$baris"
    if [ "${#KOLOM[@]}" -ne 5 ]; then
      peringatan "baris $n rusak (${#KOLOM[@]} kolom, seharusnya 5) - dilewati."
      rusak=$((rusak + 1))
      continue
    fi
    nama=$(pangkas "${KOLOM[0]}")
    hmin=$(pangkas "${KOLOM[1]}")
    hmax=$(pangkas "${KOLOM[2]}")
    tag=$(pangkas "${KOLOM[3]}")
    catatan=$(pangkas "${KOLOM[4]}")
    if ! harga_sah "$hmin" || ! harga_sah "$hmax" ||
      [ "$((10#$hmin))" -gt "$((10#$hmax))" ] || [ -z "$nama" ]; then
      peringatan "baris $n rusak (nama atau harga tidak valid) - dilewati."
      rusak=$((rusak + 1))
      continue
    fi
    TEMPAT+=("$nama"$'\t'"$hmin"$'\t'"$hmax"$'\t'"$tag"$'\t'"$catatan")
    TEMPAT_TOTAL=$((TEMPAT_TOTAL + 1))
  done <"$FILE_TEMPAT"
  if [ "$TEMPAT_TOTAL" -eq 0 ] && [ "$rusak" -gt 0 ]; then
    die "data tempat rusak: tidak ada baris valid di $FILE_TEMPAT." 3
  fi
}

# stdin (baris 5 kolom) -> tempat.tsv, atomik.
tulis_tempat() {
  {
    printf '# data tempat makan-apa - silakan diedit\n'
    printf '# nama<TAB>harga_min<TAB>harga_max<TAB>tag<TAB>catatan\n'
    cat
  } | tulis_atomik "$FILE_TEMPAT" ||
    die "gagal menulis $FILE_TEMPAT." 3
}
