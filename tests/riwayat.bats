#!/usr/bin/env bats

load helper

# Fixture riwayat ditulis tes sendiri dengan printf TSV (TAB literal), bukan lewat
# init/pilih (kontrak 9). Tanggal "hari ini" = MAKAN_APA_TANGGAL di helper.

@test "riwayat menampilkan tanggal menurun" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '2026-10-18\tBakso Sapi Campur\n2026-10-19\tAyam Geprek Dada\n2026-10-20\tKopi Susu Gula Aren\n2026-10-20\tNasi Uduk Komplit\n' \
    >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa riwayat 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "TANGGAL     NAMA" ]
  [ "${lines[1]}" = "2026-10-20  Nasi Uduk Komplit" ]
  [ "${lines[2]}" = "2026-10-20  Kopi Susu Gula Aren" ]
  [ "${lines[3]}" = "2026-10-19  Ayam Geprek Dada" ]
  [ "${lines[4]}" = "2026-10-18  Bakso Sapi Campur" ]
  [ "${#lines[@]}" -eq 5 ]

  run bash -c 'makan-apa riwayat 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "4 catatan (14 hari terakhir)." ]
}

@test "--hari 0 hanya menampilkan hari ini" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '2026-10-18\tBakso Sapi Campur\n2026-10-19\tAyam Geprek Dada\n2026-10-20\tKopi Susu Gula Aren\n' \
    >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa riwayat --hari 0 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "TANGGAL     NAMA" ]
  [ "${lines[1]}" = "2026-10-20  Kopi Susu Gula Aren" ]
  [ "${#lines[@]}" -eq 2 ]

  run bash -c 'makan-apa riwayat --hari 0 2>&1 >/dev/null'
  [ "$output" = "1 catatan (0 hari terakhir)." ]

  # Jendela 1 hanya hari ini juga; jendela 3 mencakup tiga hari terakhir.
  run bash -c 'makan-apa riwayat --hari 3 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 4 ]
  run bash -c 'makan-apa riwayat --hari 1 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "--semua dan --hari bersama ditolak" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '2026-10-18\tBakso Sapi Campur\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa riwayat --semua --hari 7 2>/dev/null'
  [ "$status" -eq 1 ]
  [ -z "$output" ]

  run bash -c 'makan-apa riwayat --semua --hari 7 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = 'makan-apa: opsi --semua dan --hari tidak bisa dipakai bersama.' ]

  # --hari di luar 0-365 juga galat pemakaian, tanpa hint help (bukan K1).
  run bash -c 'makan-apa riwayat --hari 366 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = 'makan-apa: --hari harus bilangan bulat 0-365.' ]

  run bash -c 'makan-apa riwayat --hari tujuh 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = 'makan-apa: --hari harus bilangan bulat 0-365.' ]

  # --semua sendiri boleh dan menampilkan seluruh riwayat.
  run bash -c 'makan-apa riwayat --semua 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "2026-10-18  Bakso Sapi Campur" ]
  run bash -c 'makan-apa riwayat --semua 2>&1 >/dev/null'
  [ "$output" = "1 catatan (semua riwayat)." ]

  # Arity 0 (kontrak 4.2): argumen posisional adalah galat pemakaian (K1).
  run bash -c 'makan-apa riwayat foo 2>/dev/null'
  [ "$status" -eq 1 ]
  [ -z "$output" ]

  run bash -c 'makan-apa riwayat foo 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = "makan-apa: perintah \"riwayat\" tidak menerima argumen posisional.
Coba 'makan-apa --help'." ]
}

@test "riwayat kosong keluar 0 dengan pesan Belum ada riwayat" {
  mkdir -p "$MAKAN_APA_DATA_DIR"

  run bash -c 'makan-apa riwayat 2>/dev/null'
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run bash -c 'makan-apa riwayat 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "Belum ada riwayat." ]

  # Berkas ada tapi kosong: pesan sama.
  : >"$MAKAN_APA_DATA_DIR/riwayat.tsv"
  run bash -c 'makan-apa riwayat --semua 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "Belum ada riwayat." ]
}

@test "riwayat tetap menampilkan nama yang sudah dihapus" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Sate Ayam 10 Tusuk\t20000\t30000\tsate,cepat\taroma bakar\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-20\tEs Teh Manis\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  # "Es Teh Manis" tidak ada di tempat.tsv (sudah dihapus) tapi tetap ditampilkan.
  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "$status" -eq 0 ]
  [[ $output != *"Es Teh Manis"* ]]

  run bash -c 'makan-apa riwayat 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "TANGGAL     NAMA" ]
  [ "${lines[1]}" = "2026-10-20  Es Teh Manis" ]
  [ "${#lines[@]}" -eq 2 ]
}
