# KONTRAK — makan-apa 0.1.0

Dokumen ini adalah **satu-satunya** spesifikasi yang dibagi antara Orang A dan Orang B.
Isinya diturunkan dari `PLAN.md` (beku) dan mengikat: string, path, tanda tangan fungsi,
kode keluar, dan kepemilikan berkas di sini tidak boleh diubah tanpa PR kontrak.

Status: **beku sejak merge PR kontrak pertama.** Perubahan hanya lewat branch
`a-kontrak-<topik>` atau `b-kontrak-<topik>`, disetujui **kedua** orang, dan dicatat di
bagian 2 dokumen ini. `PLAN.md` tidak diubah; bila kontrak dan `PLAN.md` berbeda, yang
berlaku adalah bagian 2 (Perubahan) di bawah.

Cara pakai: A membaca bagian 2–12 + `PLAN-A.md`; B membaca bagian 2–12 + `PLAN-B.md`.
Tidak ada yang perlu membaca `PLAN.md` untuk bekerja — kecuali teks `--help` di bagian 5.1
yang dikutip dari `PLAN.md` §2.11.

---

## 1. Ringkasan pembagian

| | Orang A | Orang B |
|---|---|---|
| Akun GitHub | `bimadji` (kolaborator, akses `push`) | `Ivanadrian31` (pemilik repo, admin) |
| Peran | inti skrip: dispatch, penyimpanan, penyaringan, diagnosis | paket, dokumen, dan tiga subperintah |
| Berkas kode | `bin/makan-apa`, `lib/umum.sh`, `lib/harga.sh`, `lib/data.sh`, `lib/saring.sh`, `lib/cmd-dasar.sh`, `lib/cmd-pilih.sh` | `lib/cmd-ubah.sh`, `lib/cmd-impor.sh`, `lib/cmd-riwayat.sh` |
| Infrastruktur | `Makefile`, `.github/workflows/ci.yml`, `.gitignore`, `tests/helper.bash`, `data/contoh.tsv` | `debian/*`, `man/makan-apa.1`, `completions/makan-apa`, `tests/pasang-bersih.sh` |
| Tes | `tests/cli.bats`, `tests/tambah.bats`, `tests/daftar.bats`, `tests/pilih.bats`, `tests/data.bats` (38 kasus) | `tests/riwayat.bats`, `tests/impor.bats`, `tests/ubah.bats` (23 kasus) |
| Dokumen | `KONTRAK.md`, `PLAN-A.md` | `README.md`, `CHANGELOG.md`, `LICENSE`, `PLAN-B.md` |
| Tugas admin repo | verifikasi proteksi, review | seed `main`, undang kolaborator, proteksi branch, tag rilis |
| Beban | 54,5 jam | 51 jam |

**Invarian ketergantungan kode: B → A saja.** Tidak ada modul milik A yang memanggil fungsi
milik B. Dispatch di `bin/makan-apa` memanggil `cmd_*` milik B lewat nama (dijaga
`declare -F`), jadi A tidak pernah butuh berkas B untuk lulus `make check`. Arah ini yang
membuat B tidak pernah memblokir A.

---

## 2. Perubahan dari PLAN.md dan klarifikasi

### 2.1 Perubahan (wajib, beserta alasan)

**P1 — `bin/makan-apa` dipecah menjadi `bin/` + `lib/*.sh`.**
Alasan: dua orang menulis kode; satu berkas 550 baris berarti setiap PR menyentuh berkas
yang sama dan konflik terus-menerus (syarat "satu berkas = satu pemilik" tidak mungkin
dipenuhi). Pemecahan mengikuti tabel fungsi `PLAN.md` §5 apa adanya.
Dampak: (a) isi paket bertambah 9 berkas `lib/*.sh` (bagian 10); (b) `Installed-Size`
dihitung ulang otomatis oleh Makefile; (c) `shellcheck` memeriksa `bin/makan-apa lib/*.sh
tests/helper.bash`; (d) `bin/makan-apa` mencari `lib/` lewat `MAKAN_APA_LIB` →
`<dir-skrip>/../lib` (repo) → `<dir-skrip>/../share/makan-apa/lib` (terpasang) →
`/usr/share/makan-apa/lib`; (e) tes tidak berubah karena tes memanggil CLI, bukan fungsi.

**P2 — `parse_harga`, `format_harga`, `validasi_nama`, `normalisasi_tag` dimiliki A.**
Alasan: A memakainya di `cmd_tambah`, `cmd_daftar`, dan `cetak_diagnosa`; bila B yang
memilikinya, A harus menunggu berkas B masuk `main` sebelum `make check` hijau — melanggar
syarat "tidak ada tahap menunggu". Dampak: modul `lib/harga.sh` menjadi milik A; jam kerja
B dipindah ke `tests/riwayat.bats`, `man`, `README`, dan demo.

**P3 — Kepemilikan tes tidak lagi seluruhnya B.** `PLAN.md` §9 menaruh semua tes di B.
Sekarang setiap tahap membawa tes untuk perilaku yang ia tambahkan (aturan `PLAN.md` §6),
jadi `tests/helper.bash`, `cli`, `tambah`, `daftar`, `pilih`, `data` milik A; `riwayat`,
`impor` milik B. Cross-check tetap ada: B menulis 10 dari 11 kasus wajib `riwayat.bats`
yang menguji `saring`/`cmd_pilih` milik A, dan A menulis `pilih.bats` yang menguji
`parse_harga` miliknya sendiri.

**P4 — Pengecualian bootstrap di tahap A1.** A1 membuat kerangka `debian/control`,
`debian/changelog`, `debian/copyright`, `man/makan-apa.1` (minimal, valid groff),
`completions/makan-apa` (minimal) — semuanya disalin dari kontrak, bukan dirancang — supaya
`make deb` sudah bisa jalan di PR pertama. Setelah A1 merge, kepemilikan berkas itu pindah
ke B (bagian 3), dan B1 mengganti man page + completion dengan versi lengkap. Alasan: CI
wajib menjalankan `make check` **dan** `make deb` sejak PR pertama, dan sebuah `.deb` butuh
man page, completion, control, changelog, dan copyright.

**P5 — "Tidak ada stub perintah" (`PLAN.md` §9, T1) digeser.** Pada keadaan `main` antara
A1 dan B4, empat perintah milik B belum ada. `bin/makan-apa` tidak memuat stub: dispatch
memeriksa `declare -F "cmd_$perintah"` dan, bila tidak ada, keluar 3 dengan
`makan-apa: perintah "<nama>" belum tersedia di build ini.` Keadaan ini (perintah tidak
tersedia bagi pengguna) **wajib hilang paling lambat di Temu-4**; penjaga `declare -F`
dihapus A di A6. Tidak ada rilis dari keadaan ini.

**P6 — `tests/riwayat.bats` ditulis dalam dua tahap.** B2 menulis 5 kasus perintah
`riwayat`; B5 menulis 10 kasus wajib (jendela N, konfigurasi, `--ulang`, tengah malam,
pangkas 90 hari). Alasan: kasus-kasus B5 menguji perilaku A5 yang belum ada di `main` saat
B2 merge; menaruhnya di B2 akan membuat CI merah dan memblokir merge.

**P7 — `Makefile` dan `.github/workflows/ci.yml` dimiliki A, dibuat di A1.**
`PLAN.md` §9 menaruh Makefile di B. Alasan: PR bootstrap (A1) harus memuat gerbang CI-nya
sendiri; B tidak boleh menunggu Makefile. B tidak menyentuh kedua berkas itu; kebutuhan
target baru ditulis B sebagai issue dan A yang mengubah (satu baris, PR kecil).

**P8 — Koreksi dua angka contoh yang tidak konsisten di `PLAN.md`.**
(a) `PLAN.md` §4.4 contoh B menyebut "keempat tempat bertag nasi" dan menulis
`gagal tag : 4`, padahal `data/contoh.tsv` hanya memuat **3** tempat bertag `nasi`
(Nasi Goreng Spesial, Ayam Geprek Dada, Nasi Uduk Komplit). Angka yang benar:
`gagal tag : 5`, `diblokir riwayat : 3` (total tetap 8, kandidat 0), dan kata "keempat"
menjadi "ketiga".
(b) `PLAN.md` §1 butir (c) menulis "`--ketat` mempersempit kandidat dari 5 ke 3", padahal
transkrip demo hari ketiga menunjukkan `Kandidat: 6 dari 8` lalu 3 setelah `--ketat`.
Angka yang benar: **6 ke 3**. Keduanya koreksi terhadap contoh yang melanggar aturan
konsistensi `PLAN.md` §4.1/§4.4 sendiri, bukan perubahan perilaku.

**P9 — Saran `--budget` mengikuti mode ketat (disetujui pemilik rencana).**
`PLAN.md` §4.4 menetapkan `X` = `harga_min` terkecil pada semua mode. Pada `--ketat` yang
menggugurkan adalah `harga_max`, sehingga saran berbasis `harga_min` bisa menyarankan angka
yang tetap membuat tempat gagal. Keputusan: `X` = `harga_max` terkecil bila `--ketat`, dan
tetap `harga_min` terkecil pada mode default. Teks dan format `4rb` tidak berubah.
Dampak: `cetak_diagnosa` (A) memilih field sesuai `OPT_KETAT`; variabel hasil `saring`
bernama `SARAN_BUDGET` (menggantikan `SARAN_BUDGET_MIN`, kontrak §7); satu tes tambahan
di A5.

**P10 — Branch tahap tidak dihapus setelah merge (disetujui pemilik rencana).**
Dulu langkah 7 alur Git menghapus branch setelah merge. Alasan perubahan: riwayat kerja
per tahap tetap terlihat di remote sehingga mudah ditelusuri saat review atau bila perlu
menelusuri ulang; menghapus branch menghilangkan bukti yang tidak selalu ada di commit squash.
Dampak: (a) `gh pr merge <nomor> --squash` dipakai tanpa opsi hapus branch; (b)
`git push origin --delete <branch>` dan `git branch -d/-D` dilarang untuk branch tahap,
satu-satunya pengecualian branch uji `uji-akses` di A0; (c) branch lama tidak dipakai ulang,
perbaikan susulan memakai branch baru (mis. `a-1-kerangka-perbaikan`); (d) sekitar 14 branch
menumpuk di remote — tidak mengganggu CI karena CI hanya berjalan untuk PR dan push ke
`main`; (e) reviewer harus memeriksa bahwa branch PR tidak ikut terhapus.

**P11 — Fungsi riwayat (`muat_config`, `baca_riwayat`, `tulis_riwayat`) naik ke A2, dan
tesnya wajib (disetujui pemilik rencana).**
A1 hanya mengirim `baca_tempat`/`tulis_tempat`; akibatnya PR B2 (#3) terbuka dan merah karena
`cmd_riwayat` memanggil `baca_riwayat` yang belum ada — satu tahap B tersendat oleh
kelewatan A. Alasan pemindahan ke A2: `lib/data.sh` milik A, tanda tangannya sudah
mengikat di KONTRAK §7, dan menambahkannya di A2 tidak menambah ketergantungan baru (punya
sendiri, bukan menunggu B). Dampak: (a) A2 naik 1 jam (10 → 11); (b) PR B2 cukup rebase
setelah A2 merge; (c) `tulis_tempat` yang sejak A1 tidak pernah punya tes kini wajib diuji —
`tambah mempertahankan komentar di tempat.tsv`,
`tambah memperingatkan baris rusak dan tetap menyimpan baris valid`, dan
`tambah menangani CRLF di tempat.tsv` — karena `cmd_tambah` membuat parser terjangkau lewat
CLI; (d) berkas sementara untuk driver tes tidak boleh ikut ter-commit.

### 2.2 Klarifikasi aditif (menutup celah; wajib disetujui di PR kontrak pertama)

`PLAN.md` tidak menentukan hal-hal berikut. Tanpa keputusan, dua implementasi akan berbeda
dan tes silang gagal. Semua ditandai **K** dan berlaku sampai dicabut lewat PR kontrak.

| Kode | Keputusan |
|---|---|
|K1|Baris `Coba 'makan-apa --help'.` dicetak **hanya** untuk galat pemakaian: perintah tidak dikenal, opsi tidak dikenal, opsi tanpa nilai, argumen posisional kurang/lebih, `--harga` wajib tidak diberikan, opsi tidak berlaku untuk perintah itu. Tidak dicetak untuk galat harga/tag/nama/data.|
|K2|`pilih`: baris tag kosong dicetak `  Rp12.000-20.000  []`; baris `Catatan:` **dilewati** bila catatan kosong.|
|K3|`pilih --dry-run --ulang` dengan baris hari ini: cetak `  Akan mengganti pilihan <tanggal>: <lama> -> <baru>` lalu `  (dry-run: riwayat tidak diubah)`. Tanpa baris hari ini: `  Belum ada pilihan hari ini; --ulang akan mencatat pilihan baru.` lalu baris dry-run.|
|K4|`daftar`: baris header dicetak walau daftar kosong? **Tidak** — daftar kosong mencetak stdout kosong (sesuai `PLAN.md` §2.5).|
|K5|`riwayat`: kolom `TANGGAL` selebar 12 (`printf '%-12s%s\n'`), header `TANGGAL` + `NAMA`.|
|K6|Pesan sukses `init`, `tambah`, `ubah`, `hapus`, `impor` masuk **stdout**; ringkasan `daftar`/`riwayat` dan seluruh detail `pilih` masuk **stderr** (sesuai `PLAN.md` §2.1).|
|K7|`ubah` tanpa opsi perubahan tetap mencetak `Diubah: <nama> (<harga>) [<tag>]` dan menulis ulang berkas (idempoten).|
|K8|`tambah` tanpa `--harga` → keluar 1: `makan-apa: perintah "tambah" membutuhkan --harga.` + baris K1.|
|K9|Opsi yang tidak berlaku untuk sebuah perintah (mis. `pilih --harga 5rb`) → keluar 1: `makan-apa: opsi "--harga" tidak berlaku untuk perintah "pilih".` + baris K1.|
|K10|`makan-apa <perintah> --help` mencetak `Pemakaian:` + satu baris sintaks + blok `Opsi:` perintah itu + baris `Kode keluar:` (bagian 5.2), keluar 0, tanpa membaca data dan tanpa memvalidasi `MAKAN_APA_TANGGAL`/`MAKAN_APA_SEED`.|
|K11|`MAKAN_APA_LIB` (baru): direktori berisi `lib/*.sh`. Urutan: `$MAKAN_APA_LIB` → `<dir-skrip>/../lib` → `<dir-skrip>/../share/makan-apa/lib` → `/usr/share/makan-apa/lib`. Tidak ditemukan → keluar 3: `makan-apa: pustaka tidak ditemukan. Paket rusak; pasang ulang.`|
|K12|`--tsv` mengabaikan `--budget`/`--tag`? **Tidak** — filter tetap berlaku; yang dihilangkan hanya header dan ringkasan.|
|K13|`init` menghitung jumlah tempat dari isi `contoh.tsv` (baris valid), bukan konstanta 8.|
|K14|Semua perintah memanggil `hari_ini` sendiri (tidak di `main`), supaya `--help`/`--version` tetap jalan dengan `MAKAN_APA_TANGGAL` yang tidak valid.|

---

## 3. Arsitektur berkas dan kepemilikan

### 3.1 Pohon repo (satu berkas = satu pemilik)

```
KONTRAK.md                    A   (perubahan: PR kontrak, disetujui B)
PLAN-A.md                     A
PLAN-B.md                     B
PLAN.md                       beku — tidak diubah siapa pun
README.md                     B
CHANGELOG.md                  B
LICENSE                       B
Makefile                      A
.gitignore                    A
.github/workflows/ci.yml      A
bin/makan-apa                 A
lib/umum.sh                   A
lib/harga.sh                  A
lib/data.sh                   A
lib/saring.sh                 A
lib/cmd-dasar.sh              A
lib/cmd-pilih.sh              A
lib/cmd-ubah.sh               B
lib/cmd-impor.sh              B
lib/cmd-riwayat.sh            B
man/makan-apa.1               B
completions/makan-apa         B
data/contoh.tsv               A
debian/control                B
debian/changelog              B
debian/copyright              B
tests/helper.bash             A
tests/cli.bats                A
tests/tambah.bats             A
tests/daftar.bats             A
tests/pilih.bats              A
tests/data.bats               A
tests/riwayat.bats            B
tests/impor.bats              B
tests/ubah.bats               B
tests/pasang-bersih.sh        B
build/  dist/                 tidak di-commit (.gitignore); keduanya boleh menghasilkannya
```

### 3.2 Aturan pemecahan `lib/`

- `bin/makan-apa` melakukan `set -euo pipefail`, `umask 077`, `IFS=$'\n\t'`,
  `export LC_ALL=C`, cek versi bash ≥ 4.2, lalu source **semua** `lib/*.sh` yang ada
  (urutan abjad, tidak ada yang bergantung pada urutan karena semua isi hanya definisi
  fungsi). Baris source diberi
  `# shellcheck disable=SC1090 # path lib ditentukan saat runtime` agar `shellcheck
  --severity=style` bersih.
- Setiap `lib/*.sh` **hanya** berisi definisi fungsi dan variabel konstanta; tidak ada
  kode yang dieksekusi saat di-source (tidak ada `echo`, `exit`, atau panggilan fungsi di
  level atas). Ini yang membuat `shellcheck -x` dan tes bisa memuatnya dengan aman.
- Tidak ada `lib/*.sh` yang men-source berkas lain.

---

## 4. Antarmuka CLI (mengikat)

### 4.1 Prinsip

`stdout` = data, `stderr` = meta. `pilih` hanya menulis nama ke stdout. Semua pesan galat
diawali `makan-apa: `. Opsi global (`--help`, `-h`, `--version`, `-V`) boleh di mana saja.
Nama tempat adalah satu argumen posisional; nama yang diawali `-` ditulis setelah `--`.

### 4.2 Perintah dan arity

| Perintah | Argumen posisional | Opsi yang berlaku |
|---|---|---|
|`init`|0|`--paksa`|
|`tambah`|1 (NAMA)|`--harga` (wajib), `--tag`, `--catatan`|
|`daftar`|0|`--tag`, `--budget`, `--ketat`, `--tsv`|
|`ubah`|1 (NAMA)|`--nama-baru`, `--harga`, `--tag`, `--catatan`|
|`hapus`|1 (NAMA)|—|
|`pilih`|0|`--budget`, `--ketat`, `--tag`, `--hari`, `--dry-run`, `--ulang`|
|`riwayat`|0|`--hari`, `--semua`|
|`impor`|1 (BERKAS)|`--ganti`|

Arity salah → keluar 1 (K1). `--harga` menerima `MIN` atau `MIN-MAKS`.

### 4.3 Kode keluar (dari `PLAN.md` §2.12, tidak berubah)

|Kode|Arti|
|---|---|
|0|sukses|
|1|pemakaian/validasi|
|2|tidak ada kandidat|
|3|data/IO|
|4|data terkunci (`flock` gagal dalam 2 detik)|
|5|nama tidak ditemukan (`ubah`/`hapus`)|

---

## 5. Teks keluaran (verbatim)

### 5.1 `--help` global

Teks **persis** `PLAN.md` §2.11 (blok di dalam pagar kode), dicetak ke stdout, keluar 0.
Tanpa argumen sama sekali: teks yang sama ke **stderr**, keluar 1.
`--version`/`-V`: `makan-apa 0.1.0` (satu baris, stdout, keluar 0).

### 5.2 `--help` per perintah (K10)

```
Pemakaian:
  makan-apa <perintah> <sintaks-posisional> [opsi]

Opsi:
  <satu baris per opsi yang berlaku, format "  --nama NILAI<spasi>keterangan">

Kode keluar: 0 sukses, 1 pemakaian, 2 tidak ada kandidat,
             3 data/IO, 4 data terkunci, 5 nama tidak ditemukan.
```

### 5.3 Galat (stderr)

|Kapan|Teks|Keluar|
|---|---|---|
|perintah tidak dikenal|`makan-apa: perintah "pili" tidak dikenal.` + K1|1|
|opsi tanpa nilai|`makan-apa: opsi "--budget" membutuhkan nilai.` + K1|1|
|opsi tidak berlaku|`makan-apa: opsi "--harga" tidak berlaku untuk perintah "pilih".` + K1|1|
|harga tidak dikenali|`makan-apa: harga "25ribu" tidak dikenali. Gunakan 25000, 25rb, atau 25k.`|1|
|min > maks|`makan-apa: harga_min (Rp30.000) lebih besar dari harga_max (Rp20.000). Periksa --harga.`|1|
|tag tidak valid|`makan-apa: tag "Nasi Goreng" tidak valid. Gunakan huruf kecil, angka, '-' atau '_' (maks 20 karakter).`|1|
|nama duplikat|`makan-apa: "Soto Betawi" sudah ada di daftar. Gunakan 'makan-apa ubah' untuk mengubahnya.`|1|
|nama tidak ada|`makan-apa: tidak ada tempat bernama "Soto Betawi". Lihat 'makan-apa daftar'.`|5|
|init tanpa --paksa|`makan-apa: data sudah ada di <path>.` lalu `Gunakan 'makan-apa init --paksa' untuk menimpa (data lama hilang).`|1|
|contoh hilang|`makan-apa: data contoh tidak ditemukan. Paket rusak; pasang ulang.`|3|
|budget dua nilai|`makan-apa: --budget hanya menerima satu nilai.`|1|
|ketat tanpa budget|`makan-apa: --ketat membutuhkan --budget.`|1|
|hari di luar 0–365|`makan-apa: --hari harus bilangan bulat 0-365.`|1|
|semua + hari|`makan-apa: opsi --semua dan --hari tidak bisa dipakai bersama.`|1|
|kunci sibuk|`makan-apa: data sedang dipakai proses lain. Coba lagi sebentar.`|4|
|gagal tulis riwayat|`makan-apa: gagal menulis riwayat: <alasan>.`|3|
|seed tidak valid|`makan-apa: MAKAN_APA_SEED harus bilangan bulat 0-2147483646.`|1|
|tanggal tidak valid|`makan-apa: MAKAN_APA_TANGGAL harus berformat YYYY-MM-DD dan tanggalnya valid.`|1|
|bash terlalu tua|`makan-apa: butuh bash >= 4.2.`|3|
|berkas impor tidak ada|`makan-apa: berkas "x.tsv" tidak ditemukan.`|3|
|impor tidak valid|`makan-apa: berkas impor tidak valid pada baris 3, 7. Tidak ada data yang diubah.` (maks 5 nomor)|3|
|semua baris tempat rusak|`makan-apa: data tempat rusak: tidak ada baris valid di <path>.`|3|
|pustaka hilang (K11)|`makan-apa: pustaka tidak ditemukan. Paket rusak; pasang ulang.`|3|
|perintah belum ada (P5, sementara)|`makan-apa: perintah "<nama>" belum tersedia di build ini.`|3|

Peringatan (stderr, tidak mengubah kode keluar):

|Kapan|Teks|
|---|---|
|baris tempat rusak|`makan-apa: peringatan: baris 7 rusak (4 kolom, seharusnya 5) - dilewati.`|
|riwayat masa depan|`makan-apa: peringatan: 1 baris riwayat bertanggal masa depan diabaikan.`|
|kunci konfigurasi asing|`makan-apa: peringatan: kunci konfigurasi "x" tidak dikenal.`|
|nilai konfigurasi salah|`makan-apa: nilai "abc" untuk riwayat_hari tidak valid (0-365).` → keluar 3 (ini galat, bukan peringatan)|

### 5.4 Keluaran sukses

|Perintah|Stream|Teks|
|---|---|---|
|`init`|stdout|`Data contoh disalin ke <path> (8 tempat).` lalu `Jalankan 'makan-apa pilih' untuk mencoba.`|
|`tambah`|stdout|`Ditambahkan: <nama> (<harga>) [<tag>]`|
|`ubah`|stdout|`Diubah: <nama> (<harga>) [<tag>]`|
|`hapus`|stdout|`Dihapus: <nama> (<harga>) [<tag>]`|
|`daftar`|stdout|tabel (bagian 5.5)|
|`daftar`|stderr|`8 tempat.` / `0 tempat (daftar kosong).`|
|`daftar` kosong|stderr|`Belum ada data. Jalankan 'makan-apa init' atau 'makan-apa tambah'.` (keluar 0)|
|`pilih`|stdout|`<nama>` (satu baris)|
|`pilih`|stderr|blok detail (bagian 5.6)|
|`riwayat`|stdout|tabel (K5)|
|`riwayat`|stderr|`3 catatan (7 hari terakhir).`|
|`riwayat` kosong|stderr|`Belum ada riwayat.` (keluar 0)|
|`impor`|stdout|`Diimpor 5 tempat, 2 dilewati karena namanya sudah ada.`|

### 5.5 Tabel `daftar`

Header `NAMA`, `HARGA`, `TAG`, `CATATAN`. Lebar: nama `min(maks_nama+2,30)`, harga 17,
tag `min(maks_tag+2,18)`, catatan sisanya. Nilai lebih panjang dipotong ke `lebar-3` +
`...`. Tag kosong → `-`; catatan kosong → `-`. Urut `LC_ALL=C sort` pada nama.

### 5.6 Blok detail `pilih` (stderr)

```
  <harga>  [<tag1>,<tag2>]
  Catatan: <catatan>            (dilewati bila catatan kosong — K2)
  Kandidat: <k> dari <n> (tersaring: budget <b>, tag <t>, riwayat <r>)
  <status>
```

`<status>` salah satu:

|Kondisi|Teks|
|---|---|
|dicatat|`Tercatat di riwayat: <tanggal>`|
|`--dry-run`|`(dry-run: riwayat tidak diubah)`|
|`--ulang`, baris hari ini ada|`Mengganti pilihan <tanggal>: <lama> -> <baru>`|
|`--ulang`, tidak ada baris hari ini|`Belum ada pilihan hari ini; --ulang mencatat pilihan baru.`|
|`--dry-run --ulang` (K3)|`Akan mengganti pilihan ...` / `... akan mencatat pilihan baru.` lalu `(dry-run: riwayat tidak diubah)`|

### 5.7 Diagnosis (stderr, keluar 2)

```
Tidak ada tempat yang lolos filter.
  total tempat      : <n>
  gagal budget      : <n>  (<harga_min|harga_max> > <harga>)
  gagal tag         : <n>  (tidak punya tag: <t1,t2>)
  diblokir riwayat  : <n>  (dipilih dalam <N> hari terakhir)
Saran: <butir1>, <butir2>, <butir3>.
```

- Label diformat `printf '  %-18s: %d'`.
- Tanda kurung: budget **hanya bila > 0**; tag **hanya bila > 0**; riwayat **selalu**
  (atau `(riwayat diabaikan)` bila N=0).
- `Saran:` hanya butir yang benar-benar menggugurkan tempat; urutan budget → tag → riwayat;
  digabung `, ` dan diakhiri titik. Butir tag: `longgarkan --tag`. Butir riwayat:
  `--hari 0 untuk mengabaikan riwayat`.
- Butir budget memakai nilai batas yang benar-benar menggugurkan (P9):
  - mode default: `X` = `harga_min` terkecil di antara baris yang gagal budget **dan** lolos
    filter tag;
  - `--ketat`: `X` = `harga_max` terkecil di antara himpunan yang sama;
  - teks: `naikkan --budget (mis. --budget <X>)` dengan `X` ditulis `4rb` bila habis dibagi
    1000, selain itu angka polos (`12500`); bila himpunan kosong, tulis `naikkan --budget`
    tanpa contoh angka (sesuai `PLAN.md` §4.4).
- Daftar kosong: `Daftar tempat masih kosong.` lalu
  `Jalankan 'makan-apa init' untuk data contoh atau 'makan-apa tambah NAMA --harga ...'.`

---

## 6. Data, path, variabel lingkungan

### 6.1 Path (default)

|Berkas|Path|
|---|---|
|direktori data|`${MAKAN_APA_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/makan-apa}`|
|tempat|`$DIR_DATA/tempat.tsv`|
|riwayat|`$DIR_DATA/riwayat.tsv`|
|kunci|`$DIR_DATA/.kunci`|
|konfigurasi|`${MAKAN_APA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/makan-apa}/config`|

Direktori data 700, berkas 600, `umask 077`. Tulis atomik: `$DIR_DATA/.tmp.$$` lalu
`mv -f`; `trap` menghapus sisa.

### 6.2 Variabel lingkungan

|Variabel|Default|Validasi|
|---|---|---|
|`MAKAN_APA_DATA_DIR`|XDG|—|
|`MAKAN_APA_CONFIG_DIR`|XDG|—|
|`MAKAN_APA_TANGGAL`|tanggal sistem (`TZ=Asia/Jakarta`)|harus `date -d "$v" +%F` == `$v`|
|`MAKAN_APA_SEED`|`/dev/urandom`|integer 0–2147483646|
|`MAKAN_APA_CONTOH`|dicari otomatis|—|
|`MAKAN_APA_LIB` (K11)|dicari otomatis|—|

### 6.3 Format TSV (tidak berubah dari `PLAN.md` §3.2–3.4)

- `tempat.tsv`: 5 kolom TAB (`nama`, `harga_min`, `harga_max`, `tag`, `catatan`);
  `#` komentar; `\r` dibuang; kolom dipangkas; harga integer 0–100000000 dan `min <= max`;
  baris rusak dilewati + peringatan; 0 baris valid + ada baris rusak → keluar 3.
- `riwayat.tsv`: 2 kolom (`tanggal` `YYYY-MM-DD`, `nama`); tanggal masa depan dilewati +
  peringatan; entri > 90 hari dipangkas saat menulis.
- `config`: `kunci=nilai`; hanya `riwayat_hari` (0–365); kunci asing → peringatan; nilai
  salah → keluar 3; berkas tidak ada → 3.
- Tag: dipisah koma, dihuruf-kecilkan, pola `^[a-z0-9][a-z0-9_-]{0,19}$`.
- Nama: 1–80 karakter, tanpa TAB/baris baru, tidak diawali `#`, dipangkas.

### 6.4 Data contoh

`data/contoh.tsv` = 2 baris komentar + 8 baris, persis tabel `PLAN.md` §3.2 (TAB literal,
tanpa pemangkasan). Nilai harga: 15000-25000, 12000-20000, 13000-22000, 10000-18000,
20000-30000, 14000-24000, 12000-20000, 4000-8000.

---

## 7. Kontrak fungsi

Semua fungsi dipanggil di shell utama (bukan subshell), kecuali dinyatakan lain. Fungsi
yang "keluar" memanggil `exit`; pemanggil tidak menangkap nilainya.

| Fungsi | Berkas | Argumen | Dibaca | Ditulis | stderr | Keluar |
|---|---|---|---|---|---|---|
|`die`|umum|`PESAN KODE`|—|—|`makan-apa: PESAN`|`KODE`|
|`peringatan`|umum|`PESAN`|—|—|`makan-apa: peringatan: PESAN`|0|
|`hari_ini`|umum|—|`MAKAN_APA_TANGGAL`|`HARI_INI`|pesan (K14)|0/1|
|`tanggal_minus`|umum|`N`|`HARI_INI`|stdout tanggal|—|0|
|`tanggal_valid`|umum|`STR`|—|status|—|0/1|
|`siapkan_dir_data`|umum|—|`DIR_DATA`|mkdir 700, `.kunci`|—|0/3|
|`ambil_kunci`|umum|`MODE` (`x`\|`s`)|`FILE_KUNCI`|fd 9|pesan kunci|0/4|
|`tulis_atomik`|umum|`FILE`|stdin|`FILE`|—|0/nonzero|
|`bersihkan_tmp`|umum|—|`TMP`|hapus|—|0|
|`validasi_nama`|umum|`NAMA`|—|`NAMA_BERSIH`|pesan nama|0/1|
|`normalisasi_tag`|umum|`STR`|—|`TAG_BERSIH`|pesan tag|0/1|
|`parse_harga`|harga|`STR`|—|`HARGA_NILAI`|pesan harga|0/1|
|`format_harga`|harga|`MIN MAKS`|—|stdout `Rp15.000-25.000`|—|0|
|`muat_config`|data|—|`FILE_CONFIG`|`RIWAYAT_HARI`|peringatan/pesan|0/3|
|`baca_tempat`|data|—|`FILE_TEMPAT`|`TEMPAT[]`, `TEMPAT_TOTAL`|peringatan|0/3|
|`tulis_tempat`|data|—|stdin|`FILE_TEMPAT`|—|0/3|
|`baca_riwayat`|data|—|`FILE_RIWAYAT`, `HARI_INI`|`RIWAYAT[]`, `RIWAYAT_TOTAL`|peringatan|0|
|`tulis_riwayat`|data|—|stdin, `HARI_INI`|`FILE_RIWAYAT` (pangkas 90 hari)|—|0/3|
|`saring`|saring|—|`TEMPAT[]`, `OPT_*`, `RIWAYAT[]`, `RIWAYAT_HARI`, `HARI_INI`|`KANDIDAT[]`, `KANDIDAT_TOTAL`, `GAGAL_BUDGET`, `GAGAL_TAG`, `GAGAL_RIWAYAT`, `SARAN_BUDGET`|—|0|
|`pilih_indeks`|saring|`N`|`MAKAN_APA_SEED`|stdout `0..N-1`|pesan seed|0/1|
|`cetak_diagnosa`|saring|—|statistik + `OPT_*` + `RIWAYAT_HARI`|—|blok 5.7|2|
|`cmd_init`|cmd-dasar|—|`OPT_PAKSA`|stdout 5.4|pesan|0/1/3|
|`cmd_tambah`|cmd-dasar|`NAMA`|`OPT_HARGA`, `OPT_TAG`, `OPT_CATATAN`|stdout|pesan|0/1/3|
|`cmd_daftar`|cmd-dasar|—|`OPT_*`|stdout tabel|ringkasan|0/1|
|`cmd_hapus`|cmd-dasar|`NAMA`|—|stdout|pesan|0/1/5|
|`cmd_pilih`|cmd-pilih|—|`OPT_*`, `RIWAYAT_HARI`|stdout nama|detail|0/1/2/3/4|
|`cmd_ubah`|cmd-ubah|`NAMA`|`OPT_NAMA_BARU`, `OPT_HARGA`, `OPT_TAG`, `OPT_CATATAN`|stdout|pesan|0/1/3/5|
|`cmd_riwayat`|cmd-riwayat|—|`OPT_HARI`, `OPT_SEMUA`|stdout tabel|ringkasan|0/1|
|`cmd_impor`|cmd-impor|`BERKAS`|`OPT_GANTI`|stdout|pesan|0/1/3|

Catatan wajib:

- `TEMPAT[]` dan `RIWAYAT[]` berisi baris **ternormalisasi** (5 dan 2 kolom TAB, tanpa `\r`,
  tanpa spasi tepi). `KANDIDAT[]` berisi elemen `TEMPAT[]` yang lolos, urutan asli.
- `saring` menghitung berurutan budget → tag → riwayat, sehingga
  `TEMPAT_TOTAL == GAGAL_BUDGET + GAGAL_TAG + GAGAL_RIWAYAT + KANDIDAT_TOTAL` selalu benar.
- `SARAN_BUDGET` = nilai batas terkecil di antara baris yang gagal budget **dan** lolos
  filter tag: `harga_min` pada mode default, `harga_max` pada `--ketat` (P9); kosong bila
  himpunan kosong.
- `baca_tempat`/`baca_riwayat` tidak pernah mengubah berkas.
- `normalisasi_tag` menerima **satu** tag; daftar `nasi,mie` dipecah pemanggil
  (`bin/makan-apa` untuk `--tag`, `cmd_tambah`/`cmd_ubah`/`cmd_impor` untuk kolom tag) dan
  hasil tiap tag digabung kembali dengan koma.
- `cmd_*` dipanggil dari `bin/makan-apa` setelah opsi di-parse; sisa argumen posisional
  diteruskan sebagai `"$@"`.

---

## 8. Kontrak variabel global

| Variabel | Pengisi | Isi |
|---|---|---|
|`VERSI`|bin|`0.1.0`|
|`ZONA`|bin|`Asia/Jakarta`|
|`DIR_DATA`, `DIR_CONFIG`, `FILE_TEMPAT`, `FILE_RIWAYAT`, `FILE_KUNCI`, `FILE_CONFIG`|bin|path absolut|
|`HARI_INI`|`hari_ini`|`YYYY-MM-DD`|
|`RIWAYAT_HARI`|`muat_config`|0–365|
|`OPT_BUDGET`|bin|integer atau kosong|
|`OPT_KETAT`, `OPT_DRY_RUN`, `OPT_ULANG`, `OPT_TSV`, `OPT_SEMUA`, `OPT_PAKSA`, `OPT_GANTI`|bin|`0`/`1`|
|`OPT_TAG`|bin|`''` atau `nasi,mie` (sudah divalidasi, urutan dipertahankan)|
|`OPT_HARI`|bin|integer atau kosong|
|`OPT_HARGA`, `OPT_CATATAN`, `OPT_NAMA_BARU`|bin|string atau kosong|
|`NAMA_BERSIH`, `TAG_BERSIH`, `HARGA_NILAI`|fungsi validasi|hasil normalisasi|
|`TEMPAT[]`, `TEMPAT_TOTAL`, `RIWAYAT[]`, `RIWAYAT_TOTAL`|data|baris ternormalisasi|
|`KANDIDAT[]`, `KANDIDAT_TOTAL`, `GAGAL_BUDGET`, `GAGAL_TAG`, `GAGAL_RIWAYAT`, `SARAN_BUDGET`|saring|statistik|
|`TMP`|bin|path berkas sementara untuk `trap`|

Opsi yang tidak diberikan bernilai kosong/`0`, bukan `unset` — supaya `set -u` aman.

---

## 9. Kontrak tes

- Kerangka: bats-core. `make check` = `shellcheck --severity=style -x bin/makan-apa lib/*.sh tests/helper.bash` lalu `bats tests/*.bats`. Shellcheck **nol temuan**; bila mustahil, `# shellcheck disable=SCxxxx` **dengan alasan** di baris yang sama.
- Tidak memakai `bats_require_minimum_version`, `run -N`, atau `$stderr` (bats 1.2 di 22.04).
- `tests/helper.bash` (A1, beku):

```bash
export MAKAN_APA_DATA_DIR="$BATS_TEST_TMPDIR/data"
export MAKAN_APA_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
export MAKAN_APA_TANGGAL=2026-10-20
export MAKAN_APA_SEED=42
export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
```

- Memisahkan stream: `run bash -c 'makan-apa pilih 2>/dev/null'` (stdout) dan
  `run bash -c 'makan-apa pilih 2>&1 >/dev/null'` (stderr).
- Fixture dibuat tes sendiri dengan `mkdir -p "$MAKAN_APA_DATA_DIR"` + `printf` (TAB
  literal), bukan lewat `init`, kecuali tes yang memang menguji `init`.
- Tes yang bertentangan dengan kontrak ini adalah **bug tes**; penulis tes memperbaikinya
  di branch yang sama. Implementasi tidak diubah untuk memenuhi tes yang salah.
- Aturan: setiap tahap menambah tes untuk perilakunya sendiri; PR tidak merge bila tes baru
  belum ada atau `make check` merah. Tidak ada tes yang di-skip.

---

## 10. Kontrak paket `.deb`

Isi paket (`Architecture: all`):

```
/usr/bin/makan-apa                                    0755
/usr/share/makan-apa/lib/umum.sh                      0644
/usr/share/makan-apa/lib/harga.sh                     0644
/usr/share/makan-apa/lib/data.sh                      0644
/usr/share/makan-apa/lib/saring.sh                    0644
/usr/share/makan-apa/lib/cmd-dasar.sh                 0644
/usr/share/makan-apa/lib/cmd-pilih.sh                 0644
/usr/share/makan-apa/lib/cmd-ubah.sh                  0644
/usr/share/makan-apa/lib/cmd-impor.sh                 0644
/usr/share/makan-apa/lib/cmd-riwayat.sh               0644
/usr/share/makan-apa/contoh.tsv                       0644
/usr/share/man/man1/makan-apa.1.gz                    0644
/usr/share/bash-completion/completions/makan-apa      0644
/usr/share/doc/makan-apa/copyright                    0644
/usr/share/doc/makan-apa/changelog.gz                 0644
```

Tidak ada maintainer script. `Depends: tzdata` saja. `Installed-Size` diisi
`du -sk build/makan-apa_$(VERSION)_all | cut -f1`. Versi harus sama di empat tempat
(`VERSI` di bin, `VERSION` di Makefile, `debian/control`, `debian/changelog`) dan
`make versi` gagal bila tidak.

---

## 11. Alur Git/GitHub wajib (setiap perubahan, tanpa pengecualian)

Berlaku untuk kode, tes, dokumen, salah ketik, dan perubahan kontrak.

1. `git switch main && git pull --ff-only` lalu `git switch -c <a|b>-<tahap>-<topik>`.
   Satu tahap = satu branch = satu PR kecil.
2. Commit kecil dengan pesan jelas; `git push -u origin <branch>` segera, minimal di akhir
   setiap sesi kerja.
3. Buka PR ke `main`; judul berawalan nomor tahap (`A2: perintah dasar`), isi: cakupan,
   tes yang ditambah, hasil `make check` lokal.
4. CI otomatis: `make check`, `make man`, `make deb`, `make lint` (selalu); `make uji-pasang`
   (job `pasang`, wajib dari Temu-5).
5. Merge **hanya** bila semua pemeriksaan hijau, tanpa tes di-skip, dan PR disetujui
   reviewer (orang yang tidak menulisnya). A mereview PR B; B mereview PR A.
6. Merah → perbaiki di branch yang sama, push ulang. Dilarang merge dengan CI merah,
   `--no-verify`, push langsung ke `main`, atau force-push ke `main`.
7. Setelah merge: **branch tahap TIDAK dihapus** (P10) — `gh pr merge <nomor> --squash`
   tanpa opsi hapus branch. Lalu `git switch main && git pull --ff-only` dan buat branch
   baru dari `main`; branch lama tidak dipakai ulang, dan perbaikan susulan memakai branch
   baru (mis. `a-1-kerangka-perbaikan`). Dilarang `git push origin --delete <branch>` dan
   `git branch -d/-D` untuk branch tahap; satu-satunya pengecualian adalah branch uji
   `uji-akses` di A0.

Tambahan mengikat:

- **Konflik:** PR yang kedua melakukan `git rebase origin/main` dan menjalankan ulang
  `make check` sebelum merge. Yang menulis berkas pemilik menang; perubahan pada berkas
  milik orang lain dipindah ke PR pemiliknya.
- **Rilis:** tag `v<versi>` hanya dari `main` yang CI-nya hijau; `.deb` yang diunggah hanya
  hasil build CI commit yang sama (`gh run download`), bukan build lokal yang tidak terverifikasi.

### 11.1 `.github/workflows/ci.yml` (milik A, dibuat di A1)

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
jobs:
  check:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-24.04, ubuntu-22.04]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update -qq && sudo apt-get install -y -qq bats shellcheck lintian man-db groff-base
      - run: make versi
      - run: make check
      - run: make man
      - run: make deb
      - run: make lint
      - uses: actions/upload-artifact@v4
        with:
          name: deb-${{ matrix.os }}
          path: dist/*.deb
  pasang:
    runs-on: ubuntu-24.04
    continue-on-error: true   # dihapus A di A6 setelah B1 mendarat
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update -qq && sudo apt-get install -y -qq bats shellcheck man-db groff-base
      - run: make deb
      - run: make uji-pasang
```

Nama status check yang diminta proteksi: `check (ubuntu-24.04)`, `check (ubuntu-22.04)`,
`pasang`.

**Verifikasi PR pertama (A1):** repo belum punya CI di `main`, jadi PR A1 tidak bisa
menunggu CI. Urutannya: (1) B mereview isi PR dan menjalankan `make check && make deb` di
mesinnya; (2) **B** merge (pemilik repo, sekaligus reviewer PR itu) dengan catatan
"bootstrap: diverifikasi lokal oleh B, commit <sha>"; (3) B langsung mengaktifkan proteksi
branch `main`; (4) semua PR setelah A1 wajib hijau. Pengecualian ini hanya untuk A1 dan
dicatat di deskripsi PR.

### 11.2 Repo dan pengaturan (B, karena B pemilik repo)

Repo: `https://github.com/Ivanadrian31/MakanApa.git`. Pemilik/admin: **B (`Ivanadrian31`)**.
**A (`bimadji`) adalah kolaborator** dengan akses `push`; A tidak bisa mengubah pengaturan
repo, tidak bisa push langsung ke `main`, dan tidak bisa mengaktifkan proteksi. Karena itu
tiga tindakan admin ada di B (tahap B0), bukan di A.

Repo publik (`"private": false`, `"size": 0`, `"Git Repository is empty."` per API pada
2026-10-20), default branch `main`. Proteksi branch tersedia; tidak ada rencana
memprivatkan.

Langkah B0 (B, hari pertama, ± 15 menit):

```bash
git clone https://github.com/Ivanadrian31/MakanApa.git
cd MakanApa
# salin PLAN.md, KONTRAK.md, PLAN-A.md, PLAN-B.md ke folder ini
git add PLAN.md KONTRAK.md PLAN-A.md PLAN-B.md
git commit -m "dok: rencana proyek dan kontrak kerja dua orang"
git push -u origin main

gh api -X PUT "repos/Ivanadrian31/MakanApa/collaborators/bimadji" -f permission=push
gh api "repos/Ivanadrian31/MakanApa/collaborators" --jq '.[].login'   # harus memuat bimadji
```

A menerima undangan (email/`gh api -X PATCH /user/repository_invitations/<id>`), lalu
memverifikasi aksesnya:

```bash
git clone https://github.com/Ivanadrian31/MakanApa.git
git switch -c uji-akses && git commit --allow-empty -m "uji akses" && git push -u origin uji-akses
git push origin --delete uji-akses   # satu-satunya branch yang boleh dihapus (P10)
```

Bila undangan belum diterima, A **tidak menunggu**: A mengerjakan A1 di clone lokal (kode
dan tes), lalu push begitu akses aktif. Alternatif tanpa akses tulis: A memakai fork
(`gh repo fork Ivanadrian31/MakanApa --clone`) dan membuka PR dari fork; semua aturan lain
tetap sama.

Lewat UI (B): Settings → Branches → Add rule untuk `main`: *Require a pull request before
merging* (1 approval, dismiss stale approvals), *Require status checks to pass* (`check
(ubuntu-24.04)`, `check (ubuntu-22.04)`; `pasang` ditambahkan di Temu-5), *Require branches
to be up to date*, *Do not allow bypassing*, *Block force pushes*, *Restrict deletions*.
Setara CLI (jalankan setelah nama check muncul minimal sekali):

```bash
gh api -X PUT "repos/Ivanadrian31/MakanApa/branches/main/protection" \
  --input - <<'JSON'
{"required_status_checks":{"strict":true,
   "contexts":["check (ubuntu-24.04)","check (ubuntu-22.04)"]},
 "enforce_admins":true,
 "required_pull_request_reviews":{"required_approving_review_count":1,
   "dismiss_stale_reviews":true},
 "restrictions":null,
 "allow_force_pushes":false,
 "allow_deletions":false}
JSON
```

A memverifikasi (bukan mengubah):

```bash
gh api "repos/Ivanadrian31/MakanApa/branches/main/protection" \
  --jq '{pr: .required_pull_request_reviews.required_approving_review_count,
         force: .allow_force_pushes.enabled,
         checks: .required_status_checks.contexts}'
```

Karena repo publik, aturan manual untuk repo privat tidak dipakai.

---

## 12. Jadwal dua lajur

Jam kerja: 1 hari ≈ 4 jam efektif. Slot = 2 hari (≈ 8 jam). Tahap "besar" (9–12 jam)
melintasi dua slot; yang penting kedua lajur tidak pernah menganggur — saat satu tahap
besar masih berjalan, tahap berikutnya sudah ditulis di branch terpisah.

| Slot | Lajur A | Lajur B | Branch | PR | Status CI wajib | Reviewer | Syarat merge |
|---|---|---|---|---|---|---|---|
|S1 (H1–2)|**A1** kerangka, CI, `bin`, `umum`, `data`, paket minimal (mulai di clone lokal; push begitu akses `push` aktif)|**B0** seed `main` + undang `bimadji` + **B1** tulis `man`, completion, README, CHANGELOG, LICENSE, `tests/pasang-bersih.sh`|`a-1-kerangka`, `b-1-paket`|#1, #2|#1: lokal (bootstrap), #2: belum ada CI sampai #1 merge|#1 B, #2 A|#1 diverifikasi lokal oleh B dan di-merge B; proteksi `main` langsung aktif; #2 hijau di S2 |
|S2 (H3–4)|**A2** `harga` + `init`/`tambah`/`daftar`/`hapus`|**B1** merge, lalu **B2** `cmd_riwayat` + tes perintah `riwayat`|`a-2-perintah-dasar`, `b-2-riwayat`|#3, #4|`check (24.04+22.04)`, `pasang`|#3 B, #4 A|#3 hijau; #4 hijau (butuh #1) |
|S3 (H5–6)|**A3** `saring` dasar + `cmd_pilih` + tulis riwayat|**B3** `cmd_impor` + `impor.bats`|`a-3-pilih`, `b-3-impor`|#5, #6|idem|#5 B, #6 A|#5 hijau; #6 hijau (butuh #3) |
|S4 (H7–8)|**A4** filter budget/tag/ketat + statistik|**B4** `cmd_ubah` + tes `ubah`|`a-4-filter`, `b-4-ubah`|#7, #8|idem|#7 B, #8 A|#7 hijau; #8 hijau (butuh #3) |
|S5 (H9–10)|**A5** jendela riwayat, `--dry-run`, `--ulang`, diagnosis, pangkas 90 hari|**B5** 10 kasus wajib `riwayat.bats` (jendela, config, `--ulang`, tengah malam, pangkas)|`a-5-pengalaman`, `b-5-gerbang-riwayat`|#9, #10|idem + `make lint` dibaca|#9 B, #10 A|#9 hijau; #10 hijau (butuh #9) |
|S6 (H11–12)|**A6** pengerasan `data` (CRLF, baris rusak, `flock`, atomik) + `data.bats`; hapus `continue-on-error` di `pasang`|**B6** README final, CHANGELOG final, rekaman demo 2 menit|`a-6-pengerasan`, `b-6-rilis`|#11, #12|idem + `pasang` wajib|#11 B, #12 A|#11 hijau; #12 hijau |
|S7 (H13–14)|**A7** 3 tes kasus tepi `PLAN.md` §4.5 di `tests/pilih.bats` + audit kontrak vs implementasi|**B6** lanjut: tag `v0.1.0`, GitHub Release, unggah `.deb` hasil CI|`a-7-kasustepi`, `b-6-rilis`|#13, #12|idem|#13 B, #12 A|#13 hijau; #12 hijau di commit yang sama dengan tag |

Titik temu (masing-masing ≤ 30 menit, tidak ada yang berhenti). Bootstrap (#1) diverifikasi
sendiri menurut §11.1 tepat setelah merge, sebelum temu pertama.

| Temu | Kapan | Yang digabung | Yang diperiksa |
|---|---|---|---|
|T1|akhir S2|#1 + #2|`make check` + `make deb` di `main`; isi deb = 15 path bagian 10; proteksi `main` aktif; `make man`/`make lint` bersih|
|T2|akhir S3|#5 + #6|7 perintah (`init`, `tambah`, `daftar`, `hapus`, `pilih`, `riwayat`, `impor`) jalan di `MAKAN_APA_DATA_DIR=/tmp/...`|
|T3|akhir S4|#7 + #8|`ubah` jalan; filter budget/tag/ketat: angka `Kandidat:` konsisten (`b+t+r+k = n`)|
|T4|akhir S5|#9 + #10|demo `PLAN.md` §1 langkah 1–6 lulus; kedelapan perintah berfungsi (tidak ada pesan "belum tersedia")|
|T5|akhir S7|#13 (+ #12 yang sudah merge di S6)|kontainer bersih: pasang, demo, remove, data pengguna utuh; lintian bersih/terjelaskan|

### 12.1 Tabel ketergantungan

| Tahap | Butuh dari rekan | Bagaimana dihindari |
|---|---|---|
|B0|—|B pemilik repo: seed `main` 4 dokumen, undang `bimadji`, aktifkan proteksi setelah #1. Tidak menunggu A|
|A1|akses `push` dari B0|A mulai menulis kode dan tes di clone lokal sebelum undangan diterima; push PR setelah akses aktif. Fallback: fork + PR dari fork|
|A2|—|`parse_harga` milik sendiri (P2)|
|A3|—|`cmd_ubah`/`cmd_impor`/`cmd_riwayat` dipanggil lewat nama, dijaga `declare -F`|
|A4|—|—|
|A5|—|—|
|A6|—|`data.bats` hanya menguji modul sendiri|
|A7|—|Kasus tepi §4.5 hanya menguji `cmd_pilih` milik sendiri; audit membandingkan kode dengan kontrak|
|B1|A1 (Makefile, CI, `bin`, `lib`, `data`)|Man page, README, CHANGELOG, LICENSE, control, copyright, completion, dan `pasang-bersih.sh` ditulis H1–2 tanpa kode; PR draft; `make man`/`make lint`/`make deb` dijalankan setelah #1 merge. Pekerjaan tidak berhenti: B lanjut menulis `cmd_riwayat`|
|B2|A1 (`bin` dispatch, `data`, `umum`)|Kode ditulis dari tanda tangan bagian 7; `shellcheck` jalan tanpa A1; `bats` merah sampai A1 merge|
|B3|A2 (`parse_harga`, `validasi_nama`, `normalisasi_tag`)|Signature dari kontrak; merge setelah #3; B lanjut B4 sambil menunggu review|
|B4|A2|idem|
|B5|A5 (jendela riwayat, `--ulang`, pangkas)|10 tes ditulis dari kontrak (boleh merah); merge setelah #9; B memakai waktu tunggu untuk rekaman demo di `main` yang sudah punya A5|
|B6|A6 (agar `pasang` wajib dan stabil)|Langkah rilis sudah ditulis; tag baru dibuat setelah #11 hijau|

---

## 13. Peta cakupan `PLAN.md`

| Bagian `PLAN.md` | Dikerjakan di | Diverifikasi oleh |
|---|---|---|
|§1 ringkasan + demo|A1–A5, B6 (rekaman)|T4, T5 |
|§2.1–2.7 (prinsip, init, tambah, daftar, ubah, hapus)|A1, A2, B4|`cli.bats`, `tambah.bats`, `daftar.bats`, `ubah.bats` |
|§2.8 `pilih`|A3, A4, A5|`pilih.bats` |
|§2.9 `riwayat`|B2|`riwayat.bats` (5 kasus perintah) |
|§2.10 `impor`|B3|`impor.bats` |
|§2.11 `--help`/`--version`|A1|`cli.bats` |
|§2.12 kode keluar|A1–A5, B2–B4|tes per kasus + T4 |
|§2.13 tanpa filter jarak|— (keputusan: tidak ada kode)|review kontrak |
|§3.1–3.5 path, TSV, config, kunci, atomik|A1 (path/kunci/atomik), A5 (pangkas), A6 (pengerasan)|`data.bats`, `riwayat.bats` |
|§3.6 cadangan/berbagi|B1 (README)|review B1 |
|§4.1–4.8 penyaringan, budget, jendela, diagnosis, `--ulang`, LCG|A3, A4, A5; kasus tepi §4.5 di A7|`pilih.bats`, `riwayat.bats` |
|§5 rancangan skrip (fungsi, env)|A1 + bagian 7–8 kontrak|review kontrak |
|§6 strategi tes|A1 (`helper`), semua tahap|`make check` |
|§7 pengemasan|A1 (kerangka), B1 (final + `tests/pasang-bersih.sh`), B6 (rilis)|T1, T5 |
|§8 dokumentasi|B1, B6|review B6 |
|§9 tahapan kerja|diganti bagian 12 (P7, P5, P6)|— |
|§10 risiko|`PLAN-A.md` §8, `PLAN-B.md` §8|review |

### 13.1 Setiap kasus uji wajib → tepat satu tahap

49 kasus dari `PLAN.md` §6. Tidak ada kasus yang muncul di dua tahap.

| # | Kasus (`PLAN.md` §6) | Tahap | Berkas |
|---|---|---|---|
|1|`--help` keluar 0 dan memuat semua perintah|A1|cli.bats|
|2|`--version` format benar|A1|cli.bats|
|3|perintah tidak dikenal|A1|cli.bats|
|4|opsi tanpa nilai|A1|cli.bats|
|5|tambah valid|A2|tambah.bats|
|6|tiga format harga setara|A2|tambah.bats|
|7|`25.000` diterima|A2|tambah.bats|
|8|min > maks ditolak|A2|tambah.bats|
|9|nama duplikat ditolak|A2|tambah.bats|
|10|nama dengan spasi|A2|tambah.bats|
|11|tab/baris baru ditolak|A2|tambah.bats|
|12|nama diawali `#` ditolak|A2|tambah.bats|
|13|tabel terurut dan berisi 8 baris|A2|daftar.bats|
|14|`--tsv` tanpa header|A2|daftar.bats|
|15|filter tag OR|A4|daftar.bats|
|16|daftar kosong|A2|daftar.bats|
|17|budget batas inklusif|A4|pilih.bats|
|18|`--ketat` batas inklusif|A4|pilih.bats|
|19|`--ketat` lebih sempit dari default|A4|pilih.bats|
|20|filter tag|A4|pilih.bats|
|21|stdout hanya nama|A3|pilih.bats|
|22|`--dry-run` tidak menulis riwayat|A5|pilih.bats|
|23|seed deterministik|A3|pilih.bats|
|24|semua tereliminasi|A5|pilih.bats|
|25|daftar kosong|A5|pilih.bats|
|26|satu tempat sudah dipilih hari ini|A5|pilih.bats|
|27|hanya satu kandidat|A3|pilih.bats|
|28|batas jendela N=3 (diblokir)|B5|riwayat.bats|
|29|batas jendela N=3 (lewat batas)|B5|riwayat.bats|
|30|N=0 mengabaikan riwayat|B5|riwayat.bats|
|31|`--hari` menimpa konfigurasi|B5|riwayat.bats|
|32|konfigurasi dipakai|B5|riwayat.bats|
|33|konfigurasi pendek|B5|riwayat.bats|
|34|tengah malam|B5|riwayat.bats|
|35|`--ulang` mengganti|B5|riwayat.bats|
|36|`--ulang` tanpa pilihan hari ini|B5|riwayat.bats|
|37|riwayat berisi nama yang sudah dihapus|B2|riwayat.bats|
|38|pangkas 90 hari|B5|riwayat.bats|
|39|baris rusak dilewati|A6|data.bats|
|40|semua baris rusak|A6|data.bats|
|41|CRLF|A6|data.bats|
|42|komentar dan baris kosong|A6|data.bats|
|43|berkas tidak ada untuk `daftar`|A6|data.bats|
|44|kunci sibuk|A6|data.bats|
|45|tulis atomik|A6|data.bats|
|46|impor menambah|B3|impor.bats|
|47|duplikat dilewati|B3|impor.bats|
|48|`--ganti` mengganti|B3|impor.bats|
|49|baris tidak valid membatalkan seluruh impor|B3|impor.bats|

Kasus tambahan di luar daftar wajib (wajib ditulis, bukan opsional): B2 menambah 4 kasus
perintah `riwayat` (`PLAN.md` §2.9), B4 menambah 4 kasus `ubah` (§2.6), A7 menambah 3 kasus
tepi §4.5, A5 menambah 1 kasus saran ketat. Total 61 kasus.

---

## 14. Keputusan pemilik rencana (2026-10-20)

Semua pertanyaan terbuka sebelumnya sudah dijawab. Tidak ada pertanyaan terbuka yang
menghambat mulai kerja.

| # | Pertanyaan | Keputusan | Akibat di dokumen |
|---|---|---|---|
|1|Repo publik atau privat?|**Publik**, repo sudah ada: `https://github.com/Ivanadrian31/MakanApa.git`, pemilik **B** (`Ivanadrian31`), **A** = `bimadji` sebagai kolaborator `push`|§11.2 ditulis ulang: B seed `main`, B undang `bimadji`, B aktifkan proteksi, A verifikasi; tahap B0 baru|
|2|Klarifikasi K1–K14|**Disetujui** semuanya|§2.2 tetap; `PLAN.md` tidak diubah|
|3|Saran `--budget` pada `--ketat`|**Disesuaikan**: `X` = `harga_max` terkecil pada `--ketat`, `harga_min` pada mode default|P9 baru; §5.7 dan §7 diperbarui; `SARAN_BUDGET_MIN` → `SARAN_BUDGET`; tes tambahan di A5|
|4|`make deb` menjalankan `make check` dua kali di CI|**Diterima**|tidak ada perubahan|
|5|Beban kerja|**Diterima**: A 54,5 jam vs B 51 jam (6,8%)|A0 mengecil jadi 0,5 jam (clone + verifikasi akses); B0 baru 2 jam (seed, undang, proteksi); A2 naik 1 jam karena membawa `muat_config`/`baca_riwayat`/`tulis_riwayat` + 3 tes parser (P11)|
|6|`MAKAN_APA_LIB` (K11)|**Disesuaikan/disetujui**: variabel resmi, dipakai `bin/makan-apa` untuk menemukan `lib/`|K11 tetap; §6.2 memuatnya|
|7|Siapa A, siapa B?|**A = `bimadji`** (inti skrip), **B = `Ivanadrian31`** (paket, dokumen, pemilik repo)|§1 tabel akun; B0 memuat tugas admin; A7 tidak lagi memuat tugas admin|
|8|Branch tahap dihapus setelah merge?|**Tidak** (P10): branch dipertahankan sebagai riwayat kerja; hanya `uji-akses` (A0) boleh dihapus|§11 langkah 7 ditulis ulang; contoh `gh pr merge` di `PLAN-A.md` §7 memakai opsi hapus branch|
|9|Job `pasang` kapan jadi wajib?|Tetap `continue-on-error: true` sampai B1 (PR #2) merge; **A** menghapus flag itu di A6, lalu **B** menambahkan `pasang` ke status check wajib di proteksi branch (A tidak mengubah proteksi, cukup meminta lewat komentar PR A6)|`ci.yml` A6; permintaan ke B di deskripsi PR A6|
|10|Komentar di `tempat.tsv`?|Cukup dikumpulkan di atas untuk 0.1.0; posisi asli tidak dipertahankan. B diminta menambahkannya ke bagian "Keterbatasan" README di PR B1|`tulis_tempat` tidak berubah; keterbatasan didokumentasikan|
|11|Tes `tulis_tempat` kapan ditulis?|**WAJIB di A2**, bukan menunggu A6. `tulis_tempat` sudah ada sejak A1 dan sempat lolos tanpa tes karena tidak terjangkau dari CLI; sekarang `cmd_tambah` dibuat, jadi parser bisa diuji lewat CLI: `tambah mempertahankan komentar di tempat.tsv`, `tambah memperingatkan baris rusak dan tetap menyimpan baris valid`, `tambah menangani CRLF di tempat.tsv`|P11 baru; `PLAN-A.md` A2 berkembang (+1 jam); driver sementara tidak boleh ikut ter-commit|

Keputusan ini adalah bagian dari kontrak: mengubahnya butuh PR kontrak baru yang disetujui
kedua orang, sama seperti bagian lain dokumen ini.
