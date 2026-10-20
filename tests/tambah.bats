#!/usr/bin/env bats

load helper

# Fixture ditulis tes sendiri (kontrak 9): printf TSV dengan TAB literal.
# init dipakai hanya bila tes memang soal init.

@test "tambah valid menyimpan lima kolom" {
  run bash -c 'makan-apa init >/dev/null && makan-apa tambah "Soto Betawi" --harga 15rb-25rb --tag soto,berkuah'
  [ "$status" -eq 0 ]

  # 8 baris data contoh + 1 baris baru = 9 baris.
  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${#lines[@]}" -eq 9 ]
  # Baris baru tepat 5 kolom dan tag tersimpan apa adanya.
  run bash -c 'makan-apa daftar --tsv 2>/dev/null | grep "Soto Betawi"'
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = $'Soto Betawi\t15000\t25000\tsoto,berkuah\t' ]
}

@test "tiga format harga setara" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "A" --harga 25000'
  [ "$status" -eq 0 ]
  run bash -c 'makan-apa tambah "B" --harga 25rb'
  [ "$status" -eq 0 ]
  run bash -c 'makan-apa tambah "C" --harga 25k'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa daftar --tsv | grep -E "^[ABC]	"'
  [ "${lines[0]}" = $'A\t25000\t25000\t\t' ]
  [ "${lines[1]}" = $'B\t25000\t25000\t\t' ]
  [ "${lines[2]}" = $'C\t25000\t25000\t\t' ]
}

@test "harga bertitik diterima" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "A" --harga 25.000'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa daftar --tsv | grep "^A	"'
  [ "${lines[0]}" = $'A\t25000\t25000\t\t' ]
}

@test "harga_min lebih besar dari harga_max ditolak" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "A" --harga 30rb-20rb 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = "makan-apa: harga_min (Rp30.000) lebih besar dari harga_max (Rp20.000). Periksa --harga." ]

  run bash -c 'makan-apa daftar --tsv'
  [ "$output" = "" ]
}

@test "nama duplikat ditolak" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "Soto Betawi" --harga 20rb'
  [ "$status" -eq 0 ]
  run bash -c 'makan-apa tambah "Soto Betawi" --harga 25rb 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = "makan-apa: \"Soto Betawi\" sudah ada di daftar. Gunakan 'makan-apa ubah' untuk mengubahnya." ]
}

@test "nama dengan spasi tersimpan utuh dan bisa dihapus" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "Nasi Goreng Spesial" --harga 15rb-25rb'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa daftar --tsv | grep -c "Nasi Goreng Spesial"'
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]

  run bash -c 'makan-apa hapus "Nasi Goreng Spesial"'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa daftar --tsv'
  [ "$output" = "" ]
}

@test "nama bertab ditolak" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "$(printf "A\tB")" --harga 20rb 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [[ $output == *"tab atau baris baru"* ]]
}

@test "nama berawalan pagar ditolak" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "#1" --harga 20rb 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = "makan-apa: nama tempat tidak boleh diawali '#'." ]
}

@test "tambah mempertahankan komentar di tempat.tsv" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# catatan satu\n# catatan dua\nLama\t10000\t20000\tnasi\tlama\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "Baru" --harga 30rb-40rb'
  [ "$status" -eq 0 ]

  # Dua komentar tetap ada, di atas, dan dua baris data utuh.
  run bash -c 'grep -c "^#" "$MAKAN_APA_DATA_DIR/tempat.tsv"'
  [ "$output" = "2" ]
  run bash -c 'makan-apa daftar --tsv'
  [ "${lines[0]}" = $'Baru\t30000\t40000\t\t' ]
  [ "${lines[1]}" = $'Lama\t10000\t20000\tnasi\tlama' ]
  run bash -c 'head -2 "$MAKAN_APA_DATA_DIR/tempat.tsv"'
  [ "${lines[0]}" = "# catatan satu" ]
  [ "${lines[1]}" = "# catatan dua" ]
}

@test "tambah memperingatkan baris rusak dan tetap menyimpan baris valid" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\nLama\t10000\t20000\tnasi\tx\nRusak\t1\t2\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "Baru" --harga 30rb 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"peringatan: baris 3 rusak"* ]]

  # Baris rusak dibuang, baris valid lama dan yang baru tetap ada.
  run bash -c 'makan-apa daftar --tsv'
  [ "${#lines[@]}" -eq 2 ]
  [[ $output != *"Rusak"* ]]
}

@test "tambah menangani CRLF di tempat.tsv" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\r\nLama\t10000\t20000\tnasi\tx\r\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "Baru" --harga 30rb'
  [ "$status" -eq 0 ]

  # Nama lama tidak lagi membawa \r.
  run bash -c 'makan-apa daftar --tsv'
  [ "${lines[0]}" = $'Baru\t30000\t30000\t\t' ]
  [ "${lines[1]}" = $'Lama\t10000\t20000\tnasi\tx' ]
  run bash -c 'grep -c $'"'"'\r'"'"' "$MAKAN_APA_DATA_DIR/tempat.tsv"'
  [ "$output" = "0" ]
}