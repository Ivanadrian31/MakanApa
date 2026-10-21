#!/usr/bin/env bats

load helper

# Fixture tempat ditulis tes sendiri dengan printf TSV (TAB literal).
# "Hanya kolom yang opsinya diberikan yang berubah" (PLAN 2.6) adalah inti tes ini:
# setiap kasus memeriksa kolom yang TIDAK disebut tetap utuh.

@test "ubah mengganti harga dan tag saja" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t15000\t25000\tsoto\tdaging sapi\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa ubah "Soto Betawi" --harga 20rb-30rb --tag soto,daging 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "Diubah: Soto Betawi (Rp20.000-30.000) [soto,daging]" ]

  # Nama dan catatan tidak berubah; harga dan tag berubah.
  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Rawon"$'\t'"20000"$'\t'"28000"$'\t'"sup"$'\t'"kuah hitam" ]
  [ "${lines[1]}" = "Soto Betawi"$'\t'"20000"$'\t'"30000"$'\t'"soto,daging"$'\t'"daging sapi" ]
}

@test "ubah mengosongkan catatan dengan string kosong" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t15000\t25000\tsoto\tdaging sapi\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa ubah "Soto Betawi" --catatan "" 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "Diubah: Soto Betawi (Rp15.000-25.000) [soto]" ]

  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${lines[0]}" = "Soto Betawi"$'\t'"15000"$'\t'"25000"$'\t'"soto"$'\t'"" ]
}

@test "ubah mengosongkan tag dengan string kosong" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t15000\t25000\tsoto\tdaging sapi\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa ubah "Soto Betawi" --tag "" 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "Diubah: Soto Betawi (Rp15.000-25.000) []" ]

  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${lines[0]}" = "Soto Betawi"$'\t'"15000"$'\t'"25000"$'\t'""$'\t'"daging sapi" ]
}

@test "ubah mengganti nama tanpa menabrak nama lain" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t15000\t25000\tsoto\tdaging sapi\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa ubah "Soto Betawi" --nama-baru "Soto Tangkar" 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "Diubah: Soto Tangkar (Rp15.000-25.000) [soto]" ]

  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[1]}" = "Soto Tangkar"$'\t'"15000"$'\t'"25000"$'\t'"soto"$'\t'"daging sapi" ]

  # Nama lama sudah tidak ada: ubah lagi harus keluar 5.
  run bash -c 'makan-apa ubah "Soto Betawi" --harga 10rb 2>/dev/null'
  [ "$status" -eq 5 ]
}

@test "ubah nama yang tidak ada keluar 5" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Rawon\t20000\t28000\tsup\tkuah hitam\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa ubah "Soto Betawi" --harga 10rb 2>&1 >/dev/null'
  [ "$status" -eq 5 ]
  [ "$output" = 'makan-apa: tidak ada tempat bernama "Soto Betawi". Lihat '\''makan-apa daftar'\''.' ]
}

@test "ubah tanpa opsi tetap mencetak baris dan menulis ulang berkas" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# komentar pengguna\nSoto Betawi\t15000\t25000\tsoto\tdaging sapi\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  # K7: idempoten, tanpa perubahan kolom.
  run bash -c 'makan-apa ubah "Soto Betawi" 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "Diubah: Soto Betawi (Rp15.000-25.000) [soto]" ]

  # Komentar pengguna di tempat.tsv tetap ada setelah ditulis ulang.
  run grep -c '^# komentar pengguna$' "$MAKAN_APA_DATA_DIR/tempat.tsv"
  [ "$output" = "1" ]

  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${lines[0]}" = "Soto Betawi"$'\t'"15000"$'\t'"25000"$'\t'"soto"$'\t'"daging sapi" ]
}

@test "ubah nama baru yang sudah dipakai ditolak" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t15000\t25000\tsoto\tdaging sapi\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa ubah "Soto Betawi" --nama-baru Rawon 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = 'makan-apa: "Rawon" sudah ada di daftar. Gunakan '\''makan-apa ubah'\'' untuk mengubahnya.' ]
}
