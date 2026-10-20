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
  [ "$output" = "makan-apa 0.1.0" ]
}

@test "perintah tidak dikenal keluar 1 dengan saran help" {
  run bash -c 'makan-apa pili 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [[ $output == *tidak dikenal* ]]
  [[ $output == *"Coba 'makan-apa --help'."* ]]
}

@test "opsi tanpa nilai keluar 1" {
  run bash -c 'makan-apa pilih --budget 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [[ $output == *membutuhkan\ nilai* ]]
}
