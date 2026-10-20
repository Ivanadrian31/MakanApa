# lib/data.sh - baca/tulis tempat.tsv (kontrak 3.2).
# shellcheck shell=bash # dimuat oleh bin/makan-apa (bukan skrip mandiri)
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
# Komentar pengguna dipertahankan; header bawaan hanya dipakai bila belum ada komentar.
tulis_tempat() {
  local baris komentar=()
  if [ -f "$FILE_TEMPAT" ]; then
    while IFS= read -r baris || [ -n "$baris" ]; do
      baris=${baris%$'\r'}
      case $(pangkas "$baris") in
        '#'*) komentar+=("$baris") ;;
      esac
    done <"$FILE_TEMPAT"
  fi
  if [ "${#komentar[@]}" -eq 0 ]; then
    komentar=('# data tempat makan-apa - silakan diedit'
      '# nama<TAB>harga_min<TAB>harga_max<TAB>tag<TAB>catatan')
  fi
  {
    printf '%s\n' "${komentar[@]}"
    cat
  } | tulis_atomik "$FILE_TEMPAT" ||
    die "gagal menulis $FILE_TEMPAT." 3
}

# Baca config -> RIWAYAT_HARI. Berkas tidak ada = nilai default (kontrak 6.3).
muat_config() {
  # shellcheck disable=SC2034 # diisi untuk dibaca pemanggil (kontrak 7/8)
  RIWAYAT_HARI=3
  [ -f "$FILE_CONFIG" ] || return 0
  local baris kunci nilai
  while IFS= read -r baris || [ -n "$baris" ]; do
    baris=${baris%$'\r'}
    case $(pangkas "$baris") in
      '' | '#'*) continue ;;
    esac
    kunci=$(pangkas "${baris%%=*}")
    nilai=$(pangkas "${baris#*=}")
    case $kunci in
      riwayat_hari)
        case $nilai in
          '' | *[!0-9]*) die "nilai \"$nilai\" untuk riwayat_hari tidak valid (0-365)." 3 ;;
        esac
        if [ "$((10#$nilai))" -gt 365 ]; then
          die "nilai \"$nilai\" untuk riwayat_hari tidak valid (0-365)." 3
        fi
  # shellcheck disable=SC2034 # diisi untuk dibaca pemanggil (kontrak 7/8)
        RIWAYAT_HARI=$((10#$nilai))
        ;;
      *) peringatan "kunci konfigurasi \"$kunci\" tidak dikenal." ;;
    esac
  done <"$FILE_CONFIG"
}

# Baca riwayat.tsv -> RIWAYAT[] (tanggal<TAB>nama) + RIWAYAT_TOTAL. HARI_INI harus sudah
# diisi pemanggil. Tanggal tidak valid dan masa depan dilewati tanpa menghapus berkas.
baca_riwayat() {
  # shellcheck disable=SC2034 # diisi untuk dibaca pemanggil (kontrak 7/8)
  RIWAYAT=()
  RIWAYAT_TOTAL=0
  [ -f "$FILE_RIWAYAT" ] || return 0
  local baris n=0 masa_depan=0 tanggal nama
  while IFS= read -r baris || [ -n "$baris" ]; do
    n=$((n + 1))
    baris=${baris%$'\r'}
    case $(pangkas "$baris") in
      '' | '#'*) continue ;;
    esac
    pecah_kolom "$baris"
    if [ "${#KOLOM[@]}" -ne 2 ]; then
      peringatan "baris $n riwayat rusak (${#KOLOM[@]} kolom, seharusnya 2) - dilewati."
      continue
    fi
    tanggal=$(pangkas "${KOLOM[0]}")
    nama=$(pangkas "${KOLOM[1]}")
    if ! tanggal_valid "$tanggal"; then
      peringatan "baris $n riwayat rusak (tanggal tidak valid) - dilewati."
      continue
    fi
    if [[ $tanggal > $HARI_INI ]]; then
      masa_depan=$((masa_depan + 1))
      continue
    fi
    RIWAYAT+=("$tanggal"$'\t'"$nama")
  # shellcheck disable=SC2034 # diisi untuk dibaca pemanggil (kontrak 7/8)
    RIWAYAT_TOTAL=$((RIWAYAT_TOTAL + 1))
  done <"$FILE_RIWAYAT"
  if [ "$masa_depan" -gt 0 ]; then
    peringatan "$masa_depan baris riwayat bertanggal masa depan diabaikan."
  fi
}

# stdin (baris tanggal<TAB>nama) -> riwayat.tsv, atomik; entri > 90 hari dipangkas.
tulis_riwayat() {
  local batas tanggal nama baris
  batas=$(tanggal_minus 90)
  {
    printf '# tanggal<TAB>nama\n'
    while IFS= read -r baris || [ -n "$baris" ]; do
      baris=${baris%$'\r'}
      pecah_kolom "$baris"
      [ "${#KOLOM[@]}" -eq 2 ] || continue
      tanggal=$(pangkas "${KOLOM[0]}")
      nama=$(pangkas "${KOLOM[1]}")
      tanggal_valid "$tanggal" || continue
      if [[ $tanggal < $batas ]]; then continue; fi
      printf '%s\t%s\n' "$tanggal" "$nama"
    done
  } | tulis_atomik "$FILE_RIWAYAT" ||
    die "gagal menulis $FILE_RIWAYAT." 3
}
