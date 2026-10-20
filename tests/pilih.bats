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

@test "budget batas inklusif" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t20000\t25000\tnasi\tx\nB\t20001\t25000\tnasi\ty\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  # harga_min == budget lolos; harga_min == budget+1 tidak.
  run bash -c 'makan-apa pilih --budget 20000 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 1 dari 2 (tersaring: budget 1, tag 0, riwayat 0)"* ]]
}

@test "--ketat membandingkan harga_max di batas" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t30000\tnasi\tx\nB\t10000\t30001\tnasi\ty\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa pilih --budget 30000 --ketat 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 1 dari 2 (tersaring: budget 1, tag 0, riwayat 0)"* ]]
}

@test "--ketat lebih sempit dari default" {
  run bash -c 'makan-apa init >/dev/null 2>&1 && makan-apa pilih --budget 20rb 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 8 dari 8 (tersaring: budget 0, tag 0, riwayat 0)"* ]]

  # `pilih` mencatat ke riwayat, jadi riwayat dihapus di antara dua pengukuran
  # supaya keduanya dibandingkan dari keadaan awal yang sama.
  run bash -c 'makan-apa init --paksa >/dev/null 2>&1 && rm -f "$MAKAN_APA_DATA_DIR/riwayat.tsv" && makan-apa pilih --budget 20rb --ketat 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 4 dari 8 (tersaring: budget 4, tag 0, riwayat 0)"* ]]
}

@test "filter tag hanya menampilkan tempat bertag itu" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tkopi\tx\nB\t10000\t20000\tnasi\ty\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa pilih --tag kopi 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 1 dari 2 (tersaring: budget 0, tag 1, riwayat 0)"* ]]
}

@test "--dry-run tidak mengubah riwayat" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\nB\t20000\t30000\tnasi\ty\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-19\tA\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"
  local sebelum
  sebelum=$(cat "$MAKAN_APA_DATA_DIR/riwayat.tsv")

  run bash -c 'makan-apa pilih --dry-run'
  [ "$status" -eq 0 ]
  # Berkas riwayat tidak berubah sedikit pun.
  [ "$(cat "$MAKAN_APA_DATA_DIR/riwayat.tsv")" = "$sebelum" ]

  run bash -c 'makan-apa pilih --dry-run 2>&1 >/dev/null'
  [[ $output == *"(dry-run: riwayat tidak diubah)"* ]]
}

@test "semua tereliminasi memberi diagnosis dan saran" {
  run bash -c 'makan-apa init >/dev/null 2>&1 && makan-apa pilih --budget 3rb 2>&1 >/dev/null'
  [ "$status" -eq 2 ]
  [[ $output == *"Tidak ada tempat yang lolos filter."* ]]
  [[ $output == *"total tempat      : 8"* ]]
  [[ $output == *"gagal budget      : 8  (harga_min > Rp3.000)"* ]]
  [[ $output == *"gagal tag         : 0"* ]]
  [[ $output == *"diblokir riwayat  : 0  (dipilih dalam 3 hari terakhir)"* ]]
  [[ $output == *"Saran: naikkan --budget (mis. --budget 4rb)."* ]]
  # stdout kosong: tidak ada nama yang dipilih.
  run bash -c 'makan-apa init --paksa >/dev/null 2>&1 && makan-apa pilih --budget 3rb 2>/dev/null'
  [ "$output" = "" ]
}

@test "saran ketat memakai harga_max" {
  run bash -c 'makan-apa init >/dev/null 2>&1 && makan-apa pilih --ketat --budget 5rb 2>&1 >/dev/null'
  [ "$status" -eq 2 ]
  # Semua tempat gagal: yang paling murah berdasarkan harga_max adalah Es Teh (8000).
  [[ $output == *"Saran: naikkan --budget (mis. --budget 8rb)."* ]]
  [[ $output == *"(harga_max > Rp5.000)"* ]]
}

@test "tag dan riwayat habis memberi dua saran" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\nB\t10000\t20000\tmie\ty\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-20\tA\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa pilih --tag nasi 2>&1 >/dev/null'
  [ "$status" -eq 2 ]
  [[ $output == *"gagal tag         : 1  (tidak punya tag: nasi)"* ]]
  [[ $output == *"diblokir riwayat  : 1"* ]]
  [[ $output == *"Saran: longgarkan --tag, --hari 0 untuk mengabaikan riwayat."* ]]
}

@test "--ulang mengganti baris hari ini" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\nB\t20000\t30000\tmie\ty\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-20\tA\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  # Detail diambil dari pemanggilan yang sama: --ulang mengganti baris hari ini,
  # jadi pemanggilan kedua akan punya keadaan berbeda.
  run bash -c 'makan-apa pilih --ulang 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 1 dari 2 (tersaring: budget 0, tag 0, riwayat 1)"* ]]
  [[ $output == *"Mengganti pilihan 2026-10-20: A -> B"* ]]

  # Jumlah entri tetap 1 (diganti, bukan ditambah) dan namanya sudah B.
  run bash -c 'grep -cv "^#" "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$output" = "1" ]
  run bash -c 'tail -1 "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$output" = "2026-10-20	B" ]
}

@test "--ulang tanpa pilihan hari ini menambah baris" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\nB\t20000\t30000\tmie\ty\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-18\tA\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa pilih --ulang 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Belum ada pilihan hari ini; --ulang mencatat pilihan baru."* ]]
  run bash -c 'grep -cv "^#" "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$output" = "2" ]
}

@test "entri lebih tua dari 90 hari dipangkas saat menulis" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  # 2026-07-22 = 90 hari sebelum 2026-10-20; 2026-07-21 = 91 hari (dipangkas).
  printf '2026-07-21\tJauh\n2026-07-22\tTepi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa pilih'
  [ "$status" -eq 0 ]

  run bash -c 'makan-apa riwayat --semua'
  [ "$status" -eq 0 ]
  [[ $output != *"Jauh"* ]]
  [[ $output == *"Tepi"* ]]
}

@test "satu tempat belum pernah dipilih langsung dipilih" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t18000\t28000\tsoto\tporsi besar\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  # Detail dari pemanggilan yang sama: pilih mencatat, jadi pemanggilan kedua
  # sudah melihat tempat itu diblokir riwayat.
  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 1 dari 1 (tersaring: budget 0, tag 0, riwayat 0)"* ]]
  [[ $output == *"Tercatat di riwayat: 2026-10-20"* ]]

  run bash -c 'tail -1 "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$output" = "2026-10-20	Soto Betawi" ]
}

@test "satu tempat sudah dipilih hari ini diblokir riwayat" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t18000\t28000\tsoto\tporsi besar\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-20\tSoto Betawi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 2 ]
  [[ $output == *"diblokir riwayat  : 1  (dipilih dalam 3 hari terakhir)"* ]]
  [[ $output == *"Saran: --hari 0 untuk mengabaikan riwayat."* ]]

  # stdout kosong: larangan riwayat tidak dilanggar diam-diam.
  run bash -c 'makan-apa pilih 2>/dev/null'
  [ "$output" = "" ]
}

@test "semua tempat diblokir riwayat memberi saran hari 0" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'A\t10000\t20000\tnasi\tx\nB\t20000\t30000\tmie\ty\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-20\tA\n2026-10-19\tB\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 2 ]
  [[ $output == *"gagal budget      : 0"* ]]
  [[ $output == *"gagal tag         : 0"* ]]
  [[ $output == *"diblokir riwayat  : 2"* ]]
  [[ $output == *"Saran: --hari 0 untuk mengabaikan riwayat."* ]]

  # Dengan --hari 0 keduanya kembali menjadi kandidat.
  run bash -c 'makan-apa pilih --hari 0 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 2 dari 2 (tersaring: budget 0, tag 0, riwayat 0)"* ]]
}

@test "ulang saat tidak ada kandidat tersisa keluar 2 dengan saran hari 0" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t18000\t28000\tsoto\tporsi besar\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-20\tSoto Betawi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa pilih --ulang 2>&1 >/dev/null'
  [ "$status" -eq 2 ]
  [[ $output == *"diblokir riwayat  : 1"* ]]
  [[ $output == *"Saran: --hari 0 untuk mengabaikan riwayat."* ]]

  # Riwayat tidak berubah oleh percobaan yang gagal.
  run bash -c 'tail -1 "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$output" = "2026-10-20	Soto Betawi" ]
}
