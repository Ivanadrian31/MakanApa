# shellcheck shell=bash # dimuat oleh bin/makan-apa (bukan skrip mandiri)
# lib/cmd-pilih.sh - cmd_pilih.

# Entri riwayat untuk hari ini, kalau ada (baris terakhir bertanggal HARI_INI).
# Mengisi RIWAYAT_HARI_INI (nama) dan RIWAYAT_TERAKHIR (ada/tidak).
entri_hari_ini() {
  RIWAYAT_HARI_INI=
  RIWAYAT_TERAKHIR=0
  local i tanggal
  for (( i = RIWAYAT_TOTAL - 1; i >= 0; i-- )); do
    tanggal=${RIWAYAT[i]%%$'\t'*}
    if [ "$tanggal" = "$HARI_INI" ]; then
      RIWAYAT_HARI_INI=${RIWAYAT[i]#*$'\t'}
      RIWAYAT_TERAKHIR=1
      return 0
    fi
  done
}

# Tulis riwayat dengan pilihan hari ini. --ulang mengganti baris terakhir yang
# bertanggal hari ini (jumlah baris tetap), selain itu menambah baris baru.
# Mengisi PILIHAN_DIGANTI (nama lama) dan PILIHAN_BARU (0/1).
catat_pilihan() { # $1=nama terpilih $2=--dry-run? 1/0
  local nama=$1 kering=$2 i
  PILIHAN_DIGANTI=
  PILIHAN_BARU=0
  if [ "$kering" = 1 ]; then return 0; fi
  if [ "$OPT_ULANG" = 1 ] && [ "$RIWAYAT_TERAKHIR" = 1 ]; then
    PILIHAN_DIGANTI=$RIWAYAT_HARI_INI
    PILIHAN_BARU=0
    local -a lainnya=()
    for (( i = 0; i < RIWAYAT_TOTAL - 1; i++ )); do
      lainnya+=("${RIWAYAT[i]}")
    done
    lainnya+=("$HARI_INI"$'\t'"$nama")
    printf '%s\n' "${lainnya[@]}" | tulis_riwayat || die "gagal menulis riwayat." 3
    return 0
  fi
  PILIHAN_BARU=1
  {
    if [ "$RIWAYAT_TOTAL" -gt 0 ]; then printf '%s\n' "${RIWAYAT[@]}"; fi
    printf '%s\t%s\n' "$HARI_INI" "$nama"
  } | tulis_riwayat || die "gagal menulis riwayat." 3
}

cmd_pilih() {
  # Urutan mengikuti kontrak 4.8: validasi, config, kunci, baca, hari_ini, saring.
  validasi_seed
  siapkan_budget
  muat_config
  if [ "$OPT_DRY_RUN" = 1 ]; then
    ambil_kunci s
  else
    ambil_kunci x
  fi
  baca_tempat
  hari_ini
  baca_riwayat
  entri_hari_ini
  saring

  if [ "$KANDIDAT_TOTAL" -eq 0 ]; then
    if [ "$TEMPAT_TOTAL" -eq 0 ]; then
      printf 'Daftar tempat masih kosong.\n' >&2
      printf "Jalankan 'makan-apa init' untuk data contoh atau 'makan-apa tambah NAMA --harga ...'.\n" >&2
      exit 2
    fi
    cetak_diagnosa
  fi

  local indeks=${KANDIDAT[$(pilih_indeks "$KANDIDAT_TOTAL")]}
  local nama=${indeks%%$'\t'*}
  local sisa=${indeks#*$'\t'}
  local hmin=${sisa%%$'\t'*}
  sisa=${sisa#*$'\t'}
  local hmax=${sisa%%$'\t'*}
  sisa=${sisa#*$'\t'}
  local tag=${sisa%%$'\t'*}
  local catatan=${sisa#*$'\t'}

  catat_pilihan "$nama" "$OPT_DRY_RUN"

  printf '%s\n' "$nama"
  printf '  %s  [%s]\n' "$(format_harga "$hmin" "$hmax")" "$tag" >&2
  if [ -n "$catatan" ]; then
    printf '  Catatan: %s\n' "$catatan" >&2
  fi
  printf '  Kandidat: %d dari %d (tersaring: budget %d, tag %d, riwayat %d)\n' \
    "$KANDIDAT_TOTAL" "$TEMPAT_TOTAL" "$GAGAL_BUDGET" "$GAGAL_TAG" "$GAGAL_RIWAYAT" >&2

  # Status pencatatan (kontrak 5.6).
  if [ "$OPT_DRY_RUN" = 1 ]; then
    if [ "$OPT_ULANG" = 1 ]; then
      if [ "$RIWAYAT_TERAKHIR" = 1 ]; then
        printf '  Akan mengganti pilihan %s: %s -> %s\n' "$HARI_INI" "$RIWAYAT_HARI_INI" "$nama" >&2
      else
        printf '  Belum ada pilihan hari ini; --ulang akan mencatat pilihan baru.\n' >&2
      fi
    fi
    printf '  (dry-run: riwayat tidak diubah)\n' >&2
  elif [ "$PILIHAN_DIGANTI" ]; then
    printf '  Mengganti pilihan %s: %s -> %s\n' "$HARI_INI" "$PILIHAN_DIGANTI" "$nama" >&2
  elif [ "$OPT_ULANG" = 1 ] && [ "$PILIHAN_BARU" = 1 ]; then
    printf '  Belum ada pilihan hari ini; --ulang mencatat pilihan baru.\n' >&2
  else
    printf '  Tercatat di riwayat: %s\n' "$HARI_INI" >&2
  fi
}
