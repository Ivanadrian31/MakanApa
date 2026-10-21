#!/usr/bin/env bats

load helper

@test "--help keluar 0 dan memuat semua perintah" {
  run makan-apa --help
  [ "$status" -eq 0 ]
  [[ $output == *pilih* ]]
  [[ $output == *impor* ]]
}

@test "--version mencetak versi kontrak" {
  run makan-apa --version
  [ "$status" -eq 0 ]
  [ "$output" = "makan-apa 0.1.1" ]
}

@test "perintah tidak dikenal keluar 1 dengan saran help" {
  run bash -c 'makan-apa pili 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [[ $output == *"tidak dikenal"* ]]
  [[ $output == *"Coba 'makan-apa --help'."* ]]
}

@test "opsi tanpa nilai keluar 1" {
  run bash -c 'makan-apa pilih --budget 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [[ $output == *membutuhkan\ nilai* ]]
}

# A6: penjaga declare-F dihapus, jadi kedelapan perintah harus benar-benar
# terpasang. Tanpa tes ini, hilangnya satu lib/*.sh baru ketahuan saat
# pengguna memanggil perintahnya (keluar 127 "command not found"), bukan
# saat make check. Yang diperiksa adalah jawaban kontrak tiap perintah,
# sehingga tes ini gagal kalau modulnya hilang.
@test "kedua delapan perintah menjawab sesuai kontrak" {
  mkdir -p "$MAKAN_APA_DATA_DIR"

  run bash -c 'makan-apa init 2>&1 >/dev/null'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa tambah "Uji Enam" 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [[ $output == *'membutuhkan --harga'* ]]

  run bash -c 'makan-apa tambah "Uji Enam" --harga 10rb 2>&1 >/dev/null'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa daftar 2>&1 >/dev/null'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa ubah 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [[ $output == *'membutuhkan NAMA'* ]]

  run bash -c 'makan-apa ubah "Uji Enam" --harga 12rb 2>&1 >/dev/null'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa hapus "Tidak Ada" 2>&1 >/dev/null'
  [ "$status" -eq 5 ]

  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa riwayat 2>&1 >/dev/null'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa impor 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [[ $output == *'membutuhkan BERKAS'* ]]
}

# Contoh di README harus bisa dijalankan apa adanya. Perintah diambil dari
# README, bukan disalin, supaya contoh dan implementasi tidak bisa berbeda
# diam-diam. A9: contoh "tambah" yang memakai nama yang sudah ada di data
# contoh membuat baris kedua README gagal setelah init.
@test "lima perintah README berjalan tanpa galat" {
  readme="$BATS_TEST_DIRNAME/../README.md"
  perintah=$(awk '
    /^## Pakai dalam 5 baris$/ { bagian = 1; next }
    bagian && /^```bash$/ { blok = 1; next }
    blok && /^```$/ { exit }
    blok { print }
  ' "$readme")

  [ "$(printf '%s\n' "$perintah" | grep -c .)" -eq 5 ]

  # init gagal bila tempat.tsv sudah ada, jadi tes ini memakai direktori data
  # sendiri, bukan MAKAN_APA_DATA_DIR milik helper.
  data_baru=$(mktemp -d "${BATS_TMPDIR:-/tmp}/makan-apa-readme-XXXXXX")
  export MAKAN_APA_DATA_DIR="$data_baru"
  export MAKAN_APA_CONFIG_DIR="$data_baru/config"

  while IFS= read -r baris; do
    [ -n "$baris" ] || continue
    run bash -c "$baris"
    if [ "$status" -ne 0 ]; then
      echo "perintah README gagal (exit $status): $baris" >&2
      echo "$output" >&2
      return 1
    fi
  done <<< "$perintah"
}
