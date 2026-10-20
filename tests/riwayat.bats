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

# --- B5: jendela riwayat (cross-check saring/cmd_pilih milik A) ---
# Hari ini = 2026-10-20 (helper). Jendela N hari memblokir catatan bertanggal
# >= hari ini-(N-1), jadi N=3 memblokir 10-18..10-20 dan tidak memblokir 10-17.
# Dua tempat: "Soto Betawi" (diblokir di sebagian tes) dan "Rawon".

@test "jendela N=3 memblokir catatan dua hari lalu" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t18000\t25000\tsup\tkuah santan\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-18\tSoto Betawi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  # 2026-10-18 = hari ini-2, masih di dalam jendela 3 hari (10-18..10-20).
  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 1 dari 2 (tersaring: budget 0, tag 0, riwayat 1)"* ]]
}

@test "jendela N=3 tidak memblokir catatan tiga hari lalu" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t18000\t25000\tsup\tkuah santan\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-17\tSoto Betawi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  # 2026-10-17 = hari ini-3, sudah di luar jendela 3 hari.
  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 2 dari 2 (tersaring: budget 0, tag 0, riwayat 0)"* ]]
}

@test "hari 0 mengabaikan riwayat" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t18000\t25000\tsup\tkuah santan\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-20\tSoto Betawi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  # Tanpa --hari: pilihan hari ini memblokir.
  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 1 dari 2 (tersaring: budget 0, tag 0, riwayat 1)"* ]]

  # --hari 0: jendela mati, riwayat diabaikan sepenuhnya.
  run bash -c 'makan-apa pilih --hari 0 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 2 dari 2 (tersaring: budget 0, tag 0, riwayat 0)"* ]]
}

@test "hari menimpa konfigurasi riwayat_hari" {
  mkdir -p "$MAKAN_APA_DATA_DIR" "$MAKAN_APA_CONFIG_DIR"
  printf 'Soto Betawi\t18000\t25000\tsup\tkuah santan\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-18\tSoto Betawi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"
  printf 'riwayat_hari=1\n' >"$MAKAN_APA_CONFIG_DIR/config"

  # Konfigurasi 1 hari: catatan 10-18 tidak memblokir.
  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 2 dari 2 (tersaring: budget 0, tag 0, riwayat 0)"* ]]

  # --hari 3 menimpa konfigurasi: catatan 10-18 memblokir lagi.
  run bash -c 'makan-apa pilih --hari 3 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 1 dari 2 (tersaring: budget 0, tag 0, riwayat 1)"* ]]
}

@test "konfigurasi riwayat_hari dipakai bila --hari tidak ada" {
  mkdir -p "$MAKAN_APA_DATA_DIR" "$MAKAN_APA_CONFIG_DIR"
  printf 'Soto Betawi\t18000\t25000\tsup\tkuah santan\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-18\tSoto Betawi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"
  printf '# konfigurasi uji\nriwayat_hari = 3\n' >"$MAKAN_APA_CONFIG_DIR/config"

  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 1 dari 2 (tersaring: budget 0, tag 0, riwayat 1)"* ]]
  # Tanpa peringatan kunci tidak dikenal (spasi di sekitar '=' sah, kontrak 6.3).
  [[ $output != *"tidak dikenal"* ]]
}

@test "konfigurasi riwayat_hari=1 hanya memblokir hari ini" {
  mkdir -p "$MAKAN_APA_DATA_DIR" "$MAKAN_APA_CONFIG_DIR"
  printf 'Soto Betawi\t18000\t25000\tsup\tkuah santan\nRawon\t20000\t28000\tsup\tkuah hitam\nGado-Gado\t10000\t15000\tsayur\tbumbu kacang\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-19\tRawon\n2026-10-20\tSoto Betawi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"
  printf 'riwayat_hari=1\n' >"$MAKAN_APA_CONFIG_DIR/config"

  # Hanya 10-20 yang memblokir; 10-19 (kemarin) lolos karena jendela 1 hari.
  run bash -c 'makan-apa pilih 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Kandidat: 2 dari 3 (tersaring: budget 0, tag 0, riwayat 1)"* ]]
}

@test "ulang setelah tengah malam menambah baris baru" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t18000\t25000\tsup\tkuah santan\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-20\tSoto Betawi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  # Hari berganti ke 10-21: baris 10-20 bukan "hari ini" lagi, jadi --ulang menambah.
  run bash -c 'MAKAN_APA_TANGGAL=2026-10-21 makan-apa pilih --ulang 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Belum ada pilihan hari ini; --ulang mencatat pilihan baru."* ]]
  [[ $output != *"Mengganti pilihan"* ]]

  run bash -c 'wc -l <"$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$(printf '%s' "$output" | tr -d ' ')" = 3 ] # 1 komentar + 2 baris
  run bash -c 'tail -1 "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [[ $output == "2026-10-21"$'\t'* ]]
  run bash -c 'head -2 "$MAKAN_APA_DATA_DIR/riwayat.tsv" | tail -1'
  [ "$output" = "2026-10-20"$'\t'"Soto Betawi" ]
}

@test "ulang mengganti baris hari ini tanpa menambah" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t18000\t25000\tsup\tkuah santan\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  printf '2026-10-19\tGado-Gado\n2026-10-20\tSoto Betawi\n' >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa pilih --ulang 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Mengganti pilihan 2026-10-20: Soto Betawi -> "* ]]

  # Jumlah baris tetap 3 (komentar + 2), dan baris hari ini tetap di posisi terakhir.
  run bash -c 'wc -l <"$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$(printf '%s' "$output" | tr -d ' ')" = 3 ]
  run bash -c 'tail -1 "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [[ $output == "2026-10-20"$'\t'* ]]
  [[ $output != *"Soto Betawi"* ]]
  run bash -c 'head -2 "$MAKAN_APA_DATA_DIR/riwayat.tsv" | tail -1'
  [ "$output" = "2026-10-19"$'\t'"Gado-Gado" ]
}

@test "ulang tanpa pilihan hari ini mencatat pilihan baru" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t18000\t25000\tsup\tkuah santan\n' >"$MAKAN_APA_DATA_DIR/tempat.tsv"

  run bash -c 'makan-apa pilih --ulang 2>&1 >/dev/null'
  [ "$status" -eq 0 ]
  [[ $output == *"Belum ada pilihan hari ini; --ulang mencatat pilihan baru."* ]]

  run bash -c 'wc -l <"$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$(printf '%s' "$output" | tr -d ' ')" = 2 ] # 1 komentar + 1 baris
  run bash -c 'tail -1 "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$output" = "2026-10-20"$'\t'"Soto Betawi" ]
}

@test "entri lebih tua dari 90 hari dipangkas saat menulis" {
  mkdir -p "$MAKAN_APA_DATA_DIR"
  printf 'Soto Betawi\t18000\t25000\tsup\tkuah santan\nRawon\t20000\t28000\tsup\tkuah hitam\n' \
    >"$MAKAN_APA_DATA_DIR/tempat.tsv"
  # Batas = hari ini-90 = 2026-07-22; 2026-07-21 lebih tua, 2026-07-22 tepat batas.
  printf '2026-07-01\tGado-Gado\n2026-07-22\tRawon\n2026-10-19\tSoto Betawi\n' \
    >"$MAKAN_APA_DATA_DIR/riwayat.tsv"

  run bash -c 'makan-apa pilih --hari 0 2>&1 >/dev/null'
  [ "$status" -eq 0 ]

  run bash -c 'cat "$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [[ $output != *"Gado-Gado"* ]]
  [[ $output == *"2026-07-22"$'\t'"Rawon"* ]]
  [[ $output == *"2026-10-19"$'\t'"Soto Betawi"* ]]
  [[ $output == *"2026-10-20"$'\t'* ]]
  run bash -c 'wc -l <"$MAKAN_APA_DATA_DIR/riwayat.tsv"'
  [ "$(printf '%s' "$output" | tr -d ' ')" = 4 ] # 1 komentar + 3 baris
}
