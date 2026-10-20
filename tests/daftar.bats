#!/usr/bin/env bats

load helper

@test "tabel terurut dan berisi delapan baris" {
  run bash -c 'makan-apa init >/dev/null 2>&1 && makan-apa daftar 2>/dev/null'
  [ "$status" -eq 0 ]
  # 1 header + 8 baris data.
  [ "${#lines[@]}" -eq 9 ]
  [[ "${lines[0]}" == NAMA*HARGA*TAG*CATATAN ]]
  # Urut LC_ALL=C pada kolom nama (nama mengandung spasi, jadi cocokkan prefiks).
  [[ ${lines[1]} == "Ayam Geprek Dada"* ]]
  [[ ${lines[2]} == "Bakso Sapi Campur"* ]]
  [[ ${lines[3]} == "Es Teh Manis"* ]]
  [[ ${lines[4]} == "Kopi Susu Gula Aren"* ]]
  [[ ${lines[5]} == "Mie Ayam Pangsit"* ]]
  [[ ${lines[6]} == "Nasi Goreng Spesial"* ]]
  [[ ${lines[7]} == "Nasi Uduk Komplit"* ]]
  [[ ${lines[8]} == "Sate Ayam 10 Tusuk"* ]]
  # Harga terformat; tag dipisah koma; catatan di akhir.
  [[ ${lines[1]} == *"Rp13.000-22.000"* ]]
  [[ ${lines[1]} == *"nasi,pedas"* ]]
  [[ ${lines[1]} == *"sambal level 1-5" ]]
}

@test "--tsv mencetak lima kolom tanpa header" {
  run bash -c 'makan-apa init >/dev/null 2>&1 && makan-apa daftar --tsv 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 8 ]

  local kolom
  for kolom in "${lines[@]}"; do
    [[ $kolom == *"$(printf '\t')"* ]]
  done
  # Tanpa header dan tanpa komentar.
  [[ "${lines[0]}" != NAMA* ]]
  [[ $output != *"#"* ]]
}

@test "daftar kosong keluar 0 dengan pesan Belum ada data" {
  # Tidak ada tempat.tsv sama sekali.
  run bash -c 'makan-apa daftar 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "" ]

  run bash -c 'makan-apa daftar 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "Belum ada data. Jalankan 'makan-apa init' atau 'makan-apa tambah'." ]
}

@test "filter tag OR hanya menampilkan nasi atau mie" {
  run bash -c 'makan-apa init >/dev/null 2>&1 && makan-apa daftar --tsv --tag nasi,mie'
  [ "$status" -eq 0 ]
  # Nasi Goreng Spesial, Mie Ayam Pangsit, Ayam Geprek Dada, Nasi Uduk Komplit.
  [ "${#lines[@]}" -eq 4 ]
  [[ ${lines[0]} == "Ayam Geprek Dada	"* ]]
  [[ ${lines[1]} == "Mie Ayam Pangsit	"* ]]
  [[ ${lines[2]} == "Nasi Goreng Spesial	"* ]]
  [[ ${lines[3]} == "Nasi Uduk Komplit	"* ]]
}

@test "daftar juga memfilter budget" {
  run bash -c 'makan-apa init >/dev/null 2>&1 && makan-apa daftar --tsv --budget 12rb'
  [ "$status" -eq 0 ]
  # harga_min <= 12000: Es Teh Manis, Kopi Susu Gula Aren, Mie Ayam Pangsit, Nasi Uduk Komplit.
  [ "${#lines[@]}" -eq 4 ]
  [[ ${lines[0]} == "Es Teh Manis	"* ]]
  [[ ${lines[1]} == "Kopi Susu Gula Aren	"* ]]
  [[ ${lines[2]} == "Mie Ayam Pangsit	"* ]]
  [[ ${lines[3]} == "Nasi Uduk Komplit	"* ]]
}

@test "daftar --ketat tanpa --budget ditolak" {
  run bash -c 'makan-apa daftar --ketat 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = "makan-apa: --ketat membutuhkan --budget." ]
}
