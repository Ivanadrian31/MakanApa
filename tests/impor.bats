#!/usr/bin/env bats

load helper

# Berkas impor dibuat tes sendiri dengan printf TSV (TAB literal), bukan lewat
# perintah lain. Setiap tes memakai direktori data sendiri dari helper.

# Lima baris valid (TAB literal), ditulis ulang di tiap tes.
@test "impor menambah lima tempat baru" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi	18000	25000	sup,daging	kuah santan
Rawon	20000	28000	sup	kuah hitam
Gado-Gado	10000	15000	sayur,kacang	bumbu kacang
Sate Padang	15000	22000	sate,pedas	kuah kental
Es Kelapa	5000	9000	minuman	dingin
' >"$MAKAN_APA_DATA_DIR/impor.tsv"

  run bash -c 'makan-apa impor "$1" 2>/dev/null' _ "$MAKAN_APA_DATA_DIR/impor.tsv"
  [ "$status" -eq 0 ]
  [ "$output" = "Diimpor 5 tempat, 0 dilewati karena namanya sudah ada." ]

  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 5 ]
  [ "${lines[0]}" = "Es Kelapa"$'\t'"5000"$'\t'"9000"$'\t'"minuman"$'\t'"dingin" ]
}

@test "impor kedua melewati duplikat" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi	18000	25000	sup,daging	kuah santan
Rawon	20000	28000	sup	kuah hitam
Gado-Gado	10000	15000	sayur,kacang	bumbu kacang
Sate Padang	15000	22000	sate,pedas	kuah kental
Es Kelapa	5000	9000	minuman	dingin
' >"$MAKAN_APA_DATA_DIR/impor.tsv"

  run bash -c 'makan-apa impor "$1" 2>/dev/null' _ "$MAKAN_APA_DATA_DIR/impor.tsv"
  [ "$status" -eq 0 ]

  # Berkas yang sama diimpor lagi: nol yang baru, lima dilewati.
  run bash -c 'makan-apa impor "$1" 2>/dev/null' _ "$MAKAN_APA_DATA_DIR/impor.tsv"
  [ "$status" -eq 0 ]
  [ "$output" = "Diimpor 0 tempat, 5 dilewati karena namanya sudah ada." ]

  # Daftar tidak bertambah.
  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${#lines[@]}" -eq 5 ]
}

@test "--ganti mengganti seluruh daftar" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  run bash -c 'makan-apa init 2>/dev/null'
  [ "$status" -eq 0 ]
  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${#lines[@]}" -eq 8 ]

  printf 'Soto Betawi	18000	25000	sup,daging	kuah santan
Rawon	20000	28000	sup	kuah hitam
Gado-Gado	10000	15000	sayur,kacang	bumbu kacang
Sate Padang	15000	22000	sate,pedas	kuah kental
Es Kelapa	5000	9000	minuman	dingin
' >"$MAKAN_APA_DATA_DIR/impor.tsv"
  run bash -c 'makan-apa impor --ganti "$1" 2>/dev/null' _ "$MAKAN_APA_DATA_DIR/impor.tsv"
  [ "$status" -eq 0 ]
  [ "$output" = "Diimpor 5 tempat, 0 dilewati karena namanya sudah ada." ]

  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 5 ]
  # Nama lama benar-benar hilang.
  run bash -c 'makan-apa daftar --tsv 2>/dev/null | grep -c "Nasi Goreng Spesial"'
  [ "$output" = "0" ]
}

@test "baris tidak valid membatalkan seluruh impor" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Bakso Sapi Campur\t14000\t24000\tbakso\tporsi jumbo\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  cp "$MAKAN_APA_DATA_DIR/tempat.tsv" "$MAKAN_APA_DATA_DIR/sebelum.tsv"

  # Lima baris valid (1-5); baris 6 hanya 4 kolom, baris 7 valid, baris 8 harga rusak.
  printf 'Soto Betawi	18000	25000	sup,daging	kuah santan
Rawon	20000	28000	sup	kuah hitam
Gado-Gado	10000	15000	sayur,kacang	bumbu kacang
Sate Padang	15000	22000	sate,pedas	kuah kental
Es Kelapa	5000	9000	minuman	dingin
' >"$MAKAN_APA_DATA_DIR/impor.tsv"
  {
    printf 'Rusak Tanpa Kolom\t9000\t12000\tsalah\n'
    printf 'Baris Ketujuh\t7000\t9000\tminuman\tvalid\n'
    printf 'Harga Rusak\txx\t9000\tminuman\tsalah\n'
  } >>"$MAKAN_APA_DATA_DIR/impor.tsv"

  run bash -c 'makan-apa impor "$1" 2>&1 >/dev/null' _ "$MAKAN_APA_DATA_DIR/impor.tsv"
  [ "$status" -eq 3 ]
  [ "$output" = 'makan-apa: berkas impor tidak valid pada baris 6, 8. Tidak ada data yang diubah.' ]

  # Tidak ada satu baris pun yang ditulis.
  run cmp "$MAKAN_APA_DATA_DIR/sebelum.tsv" "$MAKAN_APA_DATA_DIR/tempat.tsv"
  [ "$status" -eq 0 ]

  # Daftar tetap satu tempat.
  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${#lines[@]}" -eq 1 ]
}

@test "berkas impor tidak ada keluar 3" {
  mkdir -p "$MAKAN_APA_DATA_DIR"

  run bash -c 'makan-apa impor "$1" 2>&1 >/dev/null' _ "$MAKAN_APA_DATA_DIR/tidak-ada.tsv"
  [ "$status" -eq 3 ]
  [ "$output" = 'makan-apa: berkas "'"$MAKAN_APA_DATA_DIR"'/tidak-ada.tsv" tidak ditemukan.' ]
}
