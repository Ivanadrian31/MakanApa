# lib/cmd-impor.sh - cmd_impor (milik B, tahap B3).
# shellcheck shell=bash # dimuat oleh bin/makan-apa (bukan skrip mandiri)
# Hanya definisi fungsi; dimuat oleh bin/makan-apa.

# Normalisasi satu baris impor -> stdout "nama\thmin\thmax\ttag\tcatatan".
# Dijalankan di subshell pemanggil: galat validasi (yang memanggil die) hanya
# menggagalkan baris itu, bukan seluruh impor - nomor barisnya dikumpulkan dulu.
# Kolom divalidasi dengan fungsi yang sama seperti cmd_tambah (kontrak 7).
impor_normalisasi() { # $1=baris mentah
  pecah_kolom "$1"
  [ "${#KOLOM[@]}" -eq 5 ] || return 1
  local nama hmin hmax tag catatan
  nama=$(pangkas "${KOLOM[0]}")
  hmin=$(pangkas "${KOLOM[1]}")
  hmax=$(pangkas "${KOLOM[2]}")
  tag=$(pangkas "${KOLOM[3]}")
  catatan=$(pangkas "${KOLOM[4]}")
  validasi_nama "$nama"
  nama=$NAMA_BERSIH
  parse_harga "$hmin"
  hmin=$HARGA_NILAI
  parse_harga "$hmax"
  hmax=$HARGA_NILAI
  if [ "$hmin" -gt "$hmax" ]; then return 1; fi
  tag=$(gabung_tag "$tag")
  printf '%s\t%s\t%s\t%s\t%s' "$nama" "$hmin" "$hmax" "$tag" "$catatan"
}

# Nomor baris tidak valid -> "3, 7, 11" (maks 5 nomor, kontrak 5.3).
impor_daftar_baris() { # $@=nomor baris
  local hasil='' nomor jumlah=0
  for nomor in "$@"; do
    [ "$jumlah" -lt 5 ] || break
    hasil="${hasil:+$hasil, }$nomor"
    jumlah=$((jumlah + 1))
  done
  printf '%s' "$hasil"
}

cmd_impor() {
  # Arity 1 (kontrak 4.2): BERKAS wajib, tidak ada argumen tambahan.
  if [ "$#" -eq 0 ]; then
    die_opsi "perintah \"impor\" membutuhkan BERKAS."
  fi
  if [ "$#" -gt 1 ]; then
    die_opsi "perintah \"impor\" tidak menerima argumen posisional tambahan."
  fi
  local berkas=$1
  [ -f "$berkas" ] || die "berkas \"$berkas\" tidak ditemukan." 3

  # Tahap 1: validasi SELURUH berkas. Tidak ada yang ditulis bila ada satu baris salah.
  local baris nomor=0 hasil
  local -a valid=() rusak=()
  while IFS= read -r baris || [ -n "$baris" ]; do
    nomor=$((nomor + 1))
    baris=${baris%$'\r'}
    case $(pangkas "$baris") in
      '' | '#'*) continue ;;
    esac
    if hasil=$(impor_normalisasi "$baris" 2>/dev/null); then
      valid+=("$hasil")
    else
      rusak+=("$nomor")
    fi
  done <"$berkas"

  if [ "${#rusak[@]}" -gt 0 ]; then
    die "berkas impor tidak valid pada baris $(impor_daftar_baris "${rusak[@]}"). Tidak ada data yang diubah." 3
  fi

  # Tahap 2: kunci, baca daftar yang ada, saring duplikat (yang pertama menang).
  ambil_kunci x
  local -A terlihat=()
  local i nama dilewati=0
  if [ "$OPT_GANTI" != 1 ]; then
    baca_tempat
    for (( i = 0; i < TEMPAT_TOTAL; i++ )); do
      terlihat[${TEMPAT[i]%%$'\t'*}]=1
    done
  fi
  local -a baru=()
  for baris in "${valid[@]}"; do
    nama=${baris%%$'\t'*}
    if [ -n "${terlihat[$nama]:-}" ]; then
      dilewati=$((dilewati + 1))
      continue
    fi
    terlihat[$nama]=1
    baru+=("$baris")
  done

  # Tahap 3: tulis atomik lewat tulis_tempat (komentar berkas lama dipertahankan).
  if [ "$OPT_GANTI" = 1 ]; then
    if [ "${#baru[@]}" -gt 0 ]; then
      printf '%s\n' "${baru[@]}" | tulis_tempat
    else
      printf '\n' | tulis_tempat
    fi
  else
    {
      if [ "$TEMPAT_TOTAL" -gt 0 ]; then printf '%s\n' "${TEMPAT[@]}"; fi
      if [ "${#baru[@]}" -gt 0 ]; then printf '%s\n' "${baru[@]}"; fi
    } | tulis_tempat
  fi

  printf 'Diimpor %d tempat, %d dilewati karena namanya sudah ada.\n' \
    "${#baru[@]}" "$dilewati"
}
