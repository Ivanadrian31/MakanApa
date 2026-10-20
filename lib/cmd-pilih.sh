# shellcheck shell=bash # dimuat oleh bin/makan-apa (bukan skrip mandiri)
# lib/cmd-pilih.sh - cmd_pilih.

cmd_pilih() {
  # Urutan mengikuti kontrak 4.8: validasi, config, kunci, baca, hari_ini, saring.
  validasi_seed
  siapkan_budget
  muat_config
  ambil_kunci x
  baca_tempat
  hari_ini
  baca_riwayat
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

  # Catat ke riwayat (atomik, pangkas > 90 hari).
  {
    if [ "$RIWAYAT_TOTAL" -gt 0 ]; then printf '%s\n' "${RIWAYAT[@]}"; fi
    printf '%s\t%s\n' "$HARI_INI" "$nama"
  } | tulis_riwayat || die "gagal menulis riwayat." 3

  printf '%s\n' "$nama"
  printf '  %s  [%s]\n' "$(format_harga "$hmin" "$hmax")" "$tag" >&2
  if [ -n "$catatan" ]; then
    printf '  Catatan: %s\n' "$catatan" >&2
  fi
  printf '  Kandidat: %d dari %d (tersaring: budget %d, tag %d, riwayat %d)\n' \
    "$KANDIDAT_TOTAL" "$TEMPAT_TOTAL" "$GAGAL_BUDGET" "$GAGAL_TAG" "$GAGAL_RIWAYAT" >&2
  printf '  Tercatat di riwayat: %s\n' "$HARI_INI" >&2
}
