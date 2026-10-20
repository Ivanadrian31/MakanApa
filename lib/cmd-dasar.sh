# shellcheck shell=bash # dimuat oleh bin/makan-apa (bukan skrip mandiri)
# lib/cmd-dasar.sh - cmd_init, cmd_tambah, cmd_daftar, cmd_hapus.

# Cari data contoh (kontrak 2.3): MAKAN_APA_CONTOH, repo, paket, sistem.
cari_contoh() {
  local kandidat dir_skrip
  dir_skrip=$(dirname "$0")
  for kandidat in "${MAKAN_APA_CONTOH:-}" "$dir_skrip/../share/makan-apa/contoh.tsv" \
    "$dir_skrip/../data/contoh.tsv" "/usr/share/makan-apa/contoh.tsv"; do
    if [ -n "$kandidat" ] && [ -f "$kandidat" ]; then
      printf '%s\n' "$kandidat"
      return 0
    fi
  done
  return 1
}

# Kolom ke-n dari baris 5 kolom (1..5), tanpa Surround baris kosong.
kolom_ke() { # $1=baris $2=nomor
  local sisa=$1 n=$2 i=0 bagian
  while [ "$i" -lt "$((n - 1))" ]; do
    sisa=${sisa#*$'\t'}
    i=$((i + 1))
  done
  bagian=${sisa%%$'\t'*}
  if [ "$n" -lt 5 ]; then printf '%s' "$bagian"; else printf '%s' "$sisa"; fi
}

cmd_init() {
  local sumber="$FILE_TEMPAT" contoh jumlah
  if [ -e "$sumber" ] && [ "$OPT_PAKSA" != 1 ]; then
    printf 'makan-apa: data sudah ada di %s.\n' "$sumber"
    printf "Gunakan 'makan-apa init --paksa' untuk menimpa (data lama hilang).\n"
    return 1
  fi
  contoh=$(cari_contoh) || die "data contoh tidak ditemukan. Paket rusak; pasang ulang." 3
  ambil_kunci x
  tulis_atomik "$sumber" <"$contoh" || die "gagal menulis $sumber." 3
  jumlah=$(grep -cvE '^[[:space:]]*(#|$)' "$sumber") || jumlah=0
  printf 'Data contoh disalin ke %s (%s tempat).\n' "$sumber" "$jumlah"
  printf "Jalankan 'makan-apa pilih' untuk mencoba.\n"
}

cmd_tambah() {
  validasi_nama "${1-}"
  local nama=$NAMA_BERSIH min maks tag catatan baris i
  if [ -z "$OPT_HARGA" ]; then
    die_opsi "perintah \"tambah\" membutuhkan --harga."
  fi
  if [[ $OPT_HARGA == *-* ]]; then
    parse_harga "${OPT_HARGA%%-*}"
    min=$HARGA_NILAI
    parse_harga "${OPT_HARGA#*-}"
    maks=$HARGA_NILAI
  else
    parse_harga "$OPT_HARGA"
    min=$HARGA_NILAI
    maks=$min
  fi
  if [ "$min" -gt "$maks" ]; then
    die "harga_min ($(format_harga "$min" "$min")) lebih besar dari harga_max ($(format_harga "$maks" "$maks")). Periksa --harga." 1
  fi
  tag=$(gabung_tag "$OPT_TAG")
  if [ "${#OPT_CATATAN}" -gt 200 ]; then
    die "catatan maksimal 200 karakter." 1
  fi
  catatan=$OPT_CATATAN
  ambil_kunci x
  baca_tempat
  for (( i = 0; i < TEMPAT_TOTAL; i++ )); do
    if [ "$(kolom_ke "${TEMPAT[i]}" 1)" = "$nama" ]; then
      die "\"$nama\" sudah ada di daftar. Gunakan 'makan-apa ubah' untuk mengubahnya." 1
    fi
  done
  printf -v baris '%s\t%s\t%s\t%s\t%s' "$nama" "$min" "$maks" "$tag" "$catatan"
  {
    if [ "$TEMPAT_TOTAL" -gt 0 ]; then printf '%s\n' "${TEMPAT[@]}"; fi
    printf '%s\n' "$baris"
  } | tulis_tempat
  printf 'Ditambahkan: %s (%s) [%s]\n' "$nama" "$(format_harga "$min" "$maks")" "$tag"
}

# Daftar tag dari string dipisah koma -> stdout; kosong bila input kosong.
gabung_tag() {
  local sisa=${1-} hasil='' satu
  [ -n "$sisa" ] || return 0
  while [ -n "$sisa" ]; do
    satu=${sisa%%,*}
    if [ "$satu" = "$sisa" ]; then sisa=; else sisa=${sisa#*,}; fi
    normalisasi_tag "$satu"
    hasil="${hasil:+$hasil,}$TAG_BERSIH"
  done
  printf '%s' "$hasil"
}

# --tag OR (kontrak 4.2): 1 bila $1 (tag tempat, dipisah koma) punya salah satu tag
# dari $2 (tag yang diminta, dipisah koma).
punya_tag() { # $1=tag tempat $2=tag diminta
  local punya=$1 minta=$2 satu
  [ -n "$punya" ] || return 1
  while [ -n "$minta" ]; do
    satu=${minta%%,*}
    if [ "$satu" = "$minta" ]; then minta=; else minta=${minta#*,}; fi
    case ",$punya," in
      *",$satu,"*) return 0 ;;
    esac
  done
  return 1
}

cmd_daftar() {
  ambil_kunci s
  baca_tempat
  local -a tampil=()
  local i baris
  for (( i = 0; i < TEMPAT_TOTAL; i++ )); do
    baris=${TEMPAT[i]}
    if [ -n "$OPT_TAG" ] && ! punya_tag "$(kolom_ke "$baris" 4)" "$OPT_TAG"; then
      continue
    fi
    tampil+=("$baris")
  done
  if [ "$OPT_TSV" = 1 ]; then
    if [ "${#tampil[@]}" -gt 0 ]; then
      printf '%s\n' "${tampil[@]}" | sort
    fi
    return 0
  fi
  if [ "${#tampil[@]}" -eq 0 ]; then
    if [ "$TEMPAT_TOTAL" -eq 0 ]; then
      printf "Belum ada data. Jalankan 'makan-apa init' atau 'makan-apa tambah'.\n" >&2
    else
      printf '0 tempat (daftar kosong).\n' >&2
    fi
    return 0
  fi
  local -a urut=()
  mapfile -t urut < <(printf '%s\n' "${tampil[@]}" | sort)
  local lebar_nama=0 lebar_tag=0 lebar
  for baris in "${urut[@]}"; do
    lebar=$(kolom_ke "$baris" 1)
    [ "${#lebar}" -le "$lebar_nama" ] || lebar_nama=${#lebar}
    lebar=$(kolom_ke "$baris" 4)
    [ "${#lebar}" -le "$lebar_tag" ] || lebar_tag=${#lebar}
  done
  lebar_nama=$((lebar_nama + 2))
  [ "$lebar_nama" -le 30 ] || lebar_nama=30
  lebar_tag=$((lebar_tag + 2))
  [ "$lebar_tag" -le 18 ] || lebar_tag=18
  printf '%-*s%-17s%-*s%s\n' "$lebar_nama" NAMA HARGA "$lebar_tag" TAG CATATAN
  local harga catatan
  for baris in "${urut[@]}"; do
    nama=$(kolom_ke "$baris" 1)
    tag=$(kolom_ke "$baris" 4)
    catatan=$(kolom_ke "$baris" 5)
    harga=$(format_harga "$(kolom_ke "$baris" 2)" "$(kolom_ke "$baris" 3)")
    [ -n "$tag" ] || tag=-
    [ -n "$catatan" ] || catatan=-
    printf '%-*s%-17s%-*s%s\n' "$lebar_nama" "$nama" "$harga" "$lebar_tag" "$tag" "$catatan"
  done
  printf '%s tempat.\n' "${#urut[@]}" >&2
}

cmd_hapus() {
  validasi_nama "${1-}"
  local nama=$NAMA_BERSIH i ketemu=-1
  ambil_kunci x
  baca_tempat
  local -a sisa=()
  for (( i = 0; i < TEMPAT_TOTAL; i++ )); do
    if [ "$ketemu" = -1 ] && [ "$(kolom_ke "${TEMPAT[i]}" 1)" = "$nama" ]; then
      ketemu=$i
      continue
    fi
    sisa+=("${TEMPAT[i]}")
  done
  if [ "$ketemu" = -1 ]; then
    die "tidak ada tempat bernama \"$nama\". Lihat 'makan-apa daftar'." 5
  fi
  if [ "${#sisa[@]}" -gt 0 ]; then
    printf '%s\n' "${sisa[@]}" | tulis_tempat
  else
    printf '\n' | tulis_tempat
  fi
  printf 'Dihapus: %s (%s) [%s]\n' "$nama" \
    "$(format_harga "$(kolom_ke "${TEMPAT[ketemu]}" 2)" "$(kolom_ke "${TEMPAT[ketemu]}" 3)")" \
    "$(kolom_ke "${TEMPAT[ketemu]}" 4)"
}