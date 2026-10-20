#!/usr/bin/env bats

load helper

# Fixture ditulis tes sendiri (kontrak 9). Tidak lewat init/pilih.

@test "baris rusak dilewati dengan peringatan" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\nLama\t10000\t20000\tnasi\tx\nRusak\t1\t2\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa daftar 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"peringatan: baris 3 rusak (3 kolom, seharusnya 5)"* ]]

  # Baris valid tetap terbaca.
  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = $'Lama\t10000\t20000\tnasi\tx' ]
}

@test "semua baris rusak keluar 3" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\nRusak\t1\t2\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa daftar 2>&1 >/dev/null'
  [ "$status" -eq 3 ]
  [[ $output == *"data tempat rusak: tidak ada baris valid"* ]]
}

@test "CRLF dibuang dari nama" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\r\nLama\t10000\t20000\tnasi\tx\r\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = $'Lama\t10000\t20000\tnasi\tx' ]
  # Tidak ada \r yang bocor ke kolom mana pun.
  run bash -c 'makan-apa daftar --tsv 2>/dev/null | grep -c $'"'"'\r'"'"''
  [ "$output" = "0" ]
}

@test "komentar dan baris kosong diabaikan" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# komentar satu\n\n   \n# komentar dua\nLama\t10000\t20000\tnasi\tx\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa daftar --tsv 2>/dev/null'
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = $'Lama\t10000\t20000\tnasi\tx' ]
}

@test "berkas tidak ada menghasilkan daftar kosong" {
  # Tidak ada tempat.tsv sama sekali.
  run bash -c 'makan-apa daftar 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "" ]

  run bash -c 'makan-apa daftar 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [ "$output" = "Belum ada data. Jalankan 'makan-apa init' atau 'makan-apa tambah'." ]
}

@test "kunci sibuk keluar 4" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\nLama\t10000\t20000\tnasi\tx\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  # Kunci eksklusif ditahan 5 detik; perintah hanya menunggu 2 detik lalu keluar 4.
  # Pemegang kunci harus jauh lebih lama daripada batas tunggu, kalau tidak ada balapan
  # antara "kunci dilepas" dan "batas tunggu habis" (terbukti: dengan sleep 3 dua-duanya
  # jatuh di detik yang sama dan perintahnya bisa tetap menang).
  flock -x "$MAKAN_APA_DATA_DIR/.kunci" -c 'sleep 5' &
  local penjaga=$!
  # Beri waktu penyimpan untuk sampai ke flock.
  sleep 1

  run bash -c 'makan-apa tambah "Baru" --harga 30rb 2>&1 >/dev/null'
  [ "$status" -eq 4 ]
  [ "$output" = "makan-apa: data sedang dipakai proses lain. Coba lagi sebentar." ]

  kill "$penjaga" 2>/dev/null || true
  wait "$penjaga" 2>/dev/null || true
}

@test "tidak ada berkas sementara tersisa" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf '# data\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa tambah "Baru" --harga 30rb-40rb --tag nasi'
  [ "$status" -eq 0 ]

  # .tmp.$$ dibersihkan oleh trap EXIT.
  run bash -c 'ls -a "$MAKAN_APA_DATA_DIR" | grep -c "\.tmp\."'
  [ "$output" = "0" ]

  # Jalur galat juga tidak meninggalkan berkas sementara.
  run bash -c 'makan-apa tambah "Baru" --harga 30rb 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  run bash -c 'ls -a "$MAKAN_APA_DATA_DIR" | grep -c "\.tmp\."'
  [ "$output" = "0" ]
}