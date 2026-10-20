# lib/cmd-ubah.sh - cmd_ubah (milik B, tahap B4).
# shellcheck shell=bash # dimuat oleh bin/makan-apa (bukan skrip mandiri)
# Hanya definisi fungsi; dimuat oleh bin/makan-apa.

# Ubah satu baris tempat.tsv (kontrak 2.6, K7).
# Hanya kolom yang opsinya DIBERIKAN yang berubah; `--catatan ""` dan `--tag ""`
# mengosongkan kolom. "Diberikan" dibedakan dari "tidak diberikan" lewat
# OPT_<NAMA>_DIBERI (issue #14): nilai kosong tidak bisa membedakan keduanya.
# Opsi yang tidak kosong selalu dianggap diberikan, jadi tanpa penanda itu
# pun semua kasus selain `--catatan ""`/`--tag ""` sudah benar.
cmd_ubah() {
  # Arity 1 (kontrak 4.2); kurang/lebih adalah galat pemakaian (K1).
  if [ "$#" -eq 0 ]; then
    die_opsi "perintah \"ubah\" membutuhkan NAMA."
  fi
  if [ "$#" -gt 1 ]; then
    die_opsi "perintah \"ubah\" tidak menerima argumen posisional tambahan."
  fi
  validasi_nama "$1"
  local lama=$NAMA_BERSIH baru
  local ada_nama=${OPT_NAMA_BARU_DIBERI:-0}
  local ada_harga=${OPT_HARGA_DIBERI:-0}
  local ada_tag=${OPT_TAG_DIBERI:-0}
  local ada_catatan=${OPT_CATATAN_DIBERI:-0}
  [ -n "$OPT_NAMA_BARU" ] && ada_nama=1
  [ -n "$OPT_HARGA" ] && ada_harga=1
  [ -n "$OPT_TAG" ] && ada_tag=1
  [ -n "$OPT_CATATAN" ] && ada_catatan=1
  baru=$lama

  # Validasi semua opsi sebelum menyentuh data (urutan sama dengan cmd_tambah).
  if [ "$ada_nama" = 1 ]; then
    validasi_nama "$OPT_NAMA_BARU"
    baru=$NAMA_BERSIH
  fi
  local hmin hmax tag catatan
  if [ "$ada_harga" = 1 ]; then
    if [[ $OPT_HARGA == *-* ]]; then
      parse_harga "${OPT_HARGA%%-*}"
      hmin=$HARGA_NILAI
      parse_harga "${OPT_HARGA#*-}"
      hmax=$HARGA_NILAI
    else
      parse_harga "$OPT_HARGA"
      hmin=$HARGA_NILAI
      hmax=$hmin
    fi
    if [ "$hmin" -gt "$hmax" ]; then
      die "harga_min ($(format_harga "$hmin" "$hmin")) lebih besar dari harga_max ($(format_harga "$hmax" "$hmax")). Periksa --harga." 1
    fi
  fi
  if [ "$ada_tag" = 1 ]; then
    tag=$(gabung_tag "$OPT_TAG")
  fi
  if [ "$ada_catatan" = 1 ]; then
    if [ "${#OPT_CATATAN}" -gt 200 ]; then
      die "catatan maksimal 200 karakter." 1
    fi
    catatan=$OPT_CATATAN
  fi

  ambil_kunci x
  baca_tempat

  # 1. Cari baris lama (nama pertama yang cocok).
  local i ketemu=-1
  for (( i = 0; i < TEMPAT_TOTAL; i++ )); do
    if [ "$(kolom_ke "${TEMPAT[i]}" 1)" = "$lama" ]; then
      ketemu=$i
      break
    fi
  done
  if [ "$ketemu" -eq -1 ]; then
    die "tidak ada tempat bernama \"$lama\". Lihat 'makan-apa daftar'." 5
  fi

  # 2. Nama baru tidak boleh menabrak baris lain; sama dengan nama lama bukan galat.
  if [ "$ada_nama" = 1 ] && [ "$baru" != "$lama" ]; then
    for (( i = 0; i < TEMPAT_TOTAL; i++ )); do
      if [ "$(kolom_ke "${TEMPAT[i]}" 1)" = "$baru" ]; then
        die "\"$baru\" sudah ada di daftar. Gunakan 'makan-apa ubah' untuk mengubahnya." 1
      fi
    done
  fi

  # 3. Nilai akhir = nilai lama, ditimpa hanya oleh opsi yang diberikan.
  local baris=${TEMPAT[ketemu]}
  local f_nama f_hmin f_hmax f_tag f_catatan
  f_nama=$(kolom_ke "$baris" 1)
  f_hmin=$(kolom_ke "$baris" 2)
  f_hmax=$(kolom_ke "$baris" 3)
  f_tag=$(kolom_ke "$baris" 4)
  f_catatan=$(kolom_ke "$baris" 5)
  [ "$ada_nama" = 1 ] && f_nama=$baru
  if [ "$ada_harga" = 1 ]; then
    f_hmin=$hmin
    f_hmax=$hmax
  fi
  [ "$ada_tag" = 1 ] && f_tag=$tag
  [ "$ada_catatan" = 1 ] && f_catatan=$catatan

  # 4. Tulis ulang di posisi yang sama; komentar dipertahankan tulis_tempat.
  printf -v baris '%s\t%s\t%s\t%s\t%s' "$f_nama" "$f_hmin" "$f_hmax" "$f_tag" "$f_catatan"
  local -a urut=()
  for (( i = 0; i < TEMPAT_TOTAL; i++ )); do
    if [ "$i" -eq "$ketemu" ]; then
      urut+=("$baris")
    else
      urut+=("${TEMPAT[i]}")
    fi
  done
  printf '%s\n' "${urut[@]}" | tulis_tempat

  printf 'Diubah: %s (%s) [%s]\n' "$f_nama" "$(format_harga "$f_hmin" "$f_hmax")" "$f_tag"
}
