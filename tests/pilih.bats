#!/usr/bin/env bats

load helper

# Fixture ditulis tes sendiri (kontrak 9): printf TSV dengan TAB literal.

@test "stdout hanya berisi nama" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Nasi Goreng Spesial\t15000\t25000\tnasi,cepat\tporsi besar\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa pilih 2>/dev/null'
  [ "$status" -eq 0 ]
  # Tepat satu baris: hanya nama, tanpa harga/tag/catatan.
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "Nasi Goreng Spesial" ]
}

@test "seed sama menghasilkan nama sama" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\nB\t20000\t30000\tmie\ty\nC\t30000\t40000\tnasi\tz\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa pilih 2>/dev/null'
  [ "$status" -eq 0 ]
  local pertama=${lines[0]}

  # Riwayat dikosongkan agar kandidat sama; seed sama -> nama sama.
  rm -f "$MAKAN_APA_DATA_DIR/riwayat.tsv"
  run bash -c 'makan-apa pilih 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$pertama" ]
}

@test "satu kandidat dipilih dan dicatat" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Es Teh Manis\t4000\t8000\tminuman\tgelas besar\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa pilih 2>/dev/null'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Es Teh Manis" ]

  # Tercatat di riwayat pada tanggal hari ini (helper: 2026-10-20).
  run bash -c 'cat "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$status" -eq 0 ]
  [[ $output == *"2026-10-20	Es Teh Manis"* ]]
}

@test "riwayat ditulis dengan tanggal hari ini dan nama yang dipilih" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa pilih >/dev/null 2>&1'
  [ "$status" -eq 0 ]

  # Satu entri saja, tanpa duplikat.
  run bash -c 'grep -cv "^#" "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$output" = "1" ]
}

@test "detail ke stderr berisi kandidat dan pencatatan" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Bakso Sapi Campur\t14000\t24000\tbakso,berkuah\tporsi jumbo\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Rp14.000-24.000"* ]]
  [[ $output == *"[bakso,berkuah]"* ]]
  [[ $output == *"Catatan: porsi jumbo"* ]]
  [[ $output == *"Kandidat: 1 dari 1 (tersaring: budget 0, tag 0, riwayat 0)"* ]]
  [[ $output == *"Tercatat di riwayat: 2026-10-20"* ]]
}

@test "tempat yang sudah dipilih dalam jendela riwayat diblokir" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\nB\t20000\t30000\tmie\ty\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-19\tA\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  # A diblokir (kemarin, dalam jendela 3 hari), jadi B yang terpilih.
  # Detail diambil dari pemanggilan yang sama: pick mencatatkan, jadi memanggil
  # lagi akan mengubah keadaan (B ikut terblokir).
  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 1 dari 2 (tersaring: budget 0, tag 0, riwayat 1)"* ]]
}

@test "--hari 0 mengabaikan riwayat" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\nB\t20000\t30000\tmie\ty\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-20\tA\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  # Tanpa --hari 0, A diblokir (hari ini) -> hanya B.
  run bash -c 'makan-apa pilih 2>/dev/null'
  [ "${lines[0]}" = "B" ]

  # Dengan --hari 0, riwayat diabaikan -> keduanya boleh.
  run bash -c 'makan-apa pilih --hari 0 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 2 dari 2 (tersaring: budget 0, tag 0, riwayat 0)"* ]]
}

@test "daftar kosong keluar 2 dengan pesan Daftar tempat masih kosong" {
  # Tidak ada tempat.tsv.
  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 2 ]
  [ "$output" = "Daftar tempat masih kosong.
Jalankan 'makan-apa init' untuk data contoh atau 'makan-apa tambah NAMA --harga ...'." ]
}

@test "seed tidak valid ditolak" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'MAKAN_APA_SEED=abc makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = "makan-apa: MAKAN_APA_SEED harus bilangan bulat 0-2147483646." ]

  run bash -c 'MAKAN_APA_SEED=2147483647 makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = "makan-apa: MAKAN_APA_SEED harus bilangan bulat 0-2147483646." ]
}

@test "tanggal tidak valid ditolak" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'MAKAN_APA_TANGGAL=2026-02-30 makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 1 ]
  [ "$output" = "makan-apa: MAKAN_APA_TANGGAL harus berformat YYYY-MM-DD dan tanggalnya valid." ]
}
