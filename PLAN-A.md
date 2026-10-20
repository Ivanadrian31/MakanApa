# PLAN-A — Orang A (`bimadji`)

Inti skrip, penyimpanan, penyaringan, diagnosis, plus infrastruktur (Makefile, CI, helper
tes) dan audit kasus tepi. Beban: **54,5 jam** (≈ 13–14 hari pada 4 jam/hari; naik 1 jam dari
A2 yang sekarang membawa `muat_config`/`baca_riwayat`/`tulis_riwayat` — lihat A2). A adalah
**kolaborator** di repo B (`Ivanadrian31/MakanApa`), bukan pemilik: A tidak mengubah
pengaturan repo dan tidak push langsung ke `main`.

Baca `KONTRAK.md` lebih dulu; dokumen ini tidak mengulang string dan tanda tangan fungsi.

---

## 1. Peran dan berkas yang dimiliki

| Path | Isi |
|---|---|
|`KONTRAK.md`|kontrak beku (perubahan lewat PR kontrak, disetujui B)|
|`PLAN-A.md`|dokumen ini|
|`.gitignore`|`build/`, `dist/`, `*.deb`, `tests/vendor/`|
|`Makefile`|`check`, `man`, `deb`, `lint`, `uji-pasang`, `versi`, `bersih`|
|`.github/workflows/ci.yml`|job `check` (matriks 24.04/22.04) + `pasang`|
|`bin/makan-apa`|entry: `set -euo pipefail`, `umask 077`, `IFS`, `LC_ALL=C`, cek bash, source `lib/*.sh`, `main`, `parse_opsi`, `usage`, `usage_perintah`, `versi`|
|`lib/umum.sh`|`die`, `peringatan`, `hari_ini`, `tanggal_minus`, `tanggal_valid`, `siapkan_dir_data`, `ambil_kunci`, `tulis_atomik`, `bersihkan_tmp`, `validasi_nama`, `normalisasi_tag`|
|`lib/harga.sh`|`parse_harga`, `format_harga`|
|`lib/data.sh`|`muat_config`, `baca_tempat`, `tulis_tempat`, `baca_riwayat`, `tulis_riwayat`|
|`lib/saring.sh`|`saring`, `pilih_indeks`, `cetak_diagnosa`|
|`lib/cmd-dasar.sh`|`cmd_init`, `cmd_tambah`, `cmd_daftar`, `cmd_hapus`|
|`lib/cmd-pilih.sh`|`cmd_pilih`|
|`data/contoh.tsv`|2 komentar + 8 baris (kontrak §6.4)|
|`tests/helper.bash`|5 ekspor beku (kontrak §9)|
|`tests/cli.bats`, `tests/tambah.bats`, `tests/daftar.bats`, `tests/pilih.bats`, `tests/data.bats`|38 kasus|

Berkas milik B yang **tidak** boleh disentuh setelah A1: `debian/*`, `man/makan-apa.1`,
`completions/makan-apa`, `README.md`, `CHANGELOG.md`, `LICENSE`, `lib/cmd-ubah.sh`,
`lib/cmd-impor.sh`, `lib/cmd-riwayat.sh`, `tests/riwayat.bats`, `tests/impor.bats`.

## 2. Bahan yang dibaca dari KONTRAK.md

| Bagian | Untuk apa |
|---|---|
|§2.1 P1–P9|alasan pemecahan `lib/`, kepemilikan, koreksi angka, saran `--ketat` (P9)|
|§2.2 K1–K14|perilaku yang tidak ada di `PLAN.md` (hint help, status dry-run+ulang, `MAKAN_APA_LIB`)|
|§3|pohon berkas + aturan "lib hanya definisi fungsi"|
|§4|opsi per perintah, arity, kode keluar|
|§5|seluruh string keluaran (verbatim, termasuk format `printf '  %-18s: %d'`)|
|§6|path, env, format TSV|
|§7–8|tanda tangan fungsi dan variabel global yang dipakai lintas pemilik|
|§9|aturan tes (helper beku, pemisahan stream, shellcheck)|
|§10|isi paket (15 path)|
|§11|alur Git/GitHub, CI, repo `Ivanadrian31/MakanApa`, proteksi branch|
|§12|jadwal, titik temu, ketergantungan|
|§14|keputusan pemilik rencana (repo publik, K1–K14 disetujui, P9)|

## 3. Tahap

Ukuran: kecil ≈ 2–3 jam, sedang ≈ 5–7 jam, besar ≈ 9–12 jam.

### A0 — Klon dan verifikasi akses (kecil, 0,5 jam) · bukan tahap PR

- **Cakupan:** `git clone https://github.com/Ivanadrian31/MakanApa.git`, set `user.name`
  dan `user.email`, verifikasi akses `push` dengan branch uji sekali pakai, konfirmasi
  `make`/`bats`/`shellcheck` terpasang di mesin.
- **Berkas:** tidak ada (hanya konfigurasi git lokal).
- **Tes wajib:** tidak ada.
- **Kriteria selesai:** `git push -u origin uji-akses` berhasil lalu branch itu dihapus
  (`uji-akses` satu-satunya pengecualian penghapusan branch, P10);
  `bats --version`, `shellcheck --version`, `make --version` keluar 0.
- **Branch/PR/reviewer:** tidak ada PR (branch uji dihapus). Reviewer: — .
- **Bisa dimulai sekarang karena:** A tidak butuh repo untuk menulis kode. Bila `main` atau
  undangan belum siap, A mengerjakan A1 langsung di folder kerja lokal (berkas yang sama),
  lalu menyambungkannya: `git init -b main`, `git remote add origin ...`, dan
  `git rebase --onto origin/main` setelah B0 mendarat. Jalur cadangan tanpa akses tulis:
  fork (`gh repo fork Ivanadrian31/MakanApa --clone`) lalu PR dari fork.

### A1 — Kerangka, CI, `bin`, `umum`, `data`, paket minimal (besar, 12 jam)

- **Cakupan:** entry point + parser opsi + dispatch; `umum.sh` lengkap; `data.sh` versi
  dasar (baca/tulis 5 kolom, komentar, trim, lock, atomik); `Makefile` 7 target; CI;
  `helper.bash`; `data/contoh.tsv`; kerangka paket (P4); `tests/cli.bats`.
- **Berkas:** `.gitignore`, `Makefile`, `.github/workflows/ci.yml`, `tests/helper.bash`,
  `bin/makan-apa`, `lib/umum.sh`, `lib/data.sh`, `lib/harga.sh` (header), `lib/saring.sh`
  (header), `lib/cmd-dasar.sh` (header), `lib/cmd-pilih.sh` (header), `lib/cmd-ubah.sh`
  (header), `lib/cmd-impor.sh` (header), `lib/cmd-riwayat.sh` (header), `data/contoh.tsv`,
  `debian/control`, `debian/changelog`, `debian/copyright`, `man/makan-apa.1` (minimal),
  `completions/makan-apa` (minimal), `tests/cli.bats`.
- **Tes wajib (`tests/cli.bats`):**
  - `--help keluar 0 dan memuat semua perintah`
  - `--version mencetak versi kontrak`
  - `perintah tidak dikenal keluar 1 dengan saran help`
  - `opsi tanpa nilai keluar 1`
- **Kriteria selesai:** `make check` hijau; `make deb` menghasilkan
  `dist/makan-apa_0.1.0_all.deb`; `dpkg-deb -c` memuat 15 path kontrak §10;
  `./bin/makan-apa --help` identik dengan `PLAN.md` §2.11; `make versi` lulus.
- **Branch:** `a-1-kerangka` · **PR:** #1 · **Reviewer:** B.
- **Bisa dimulai sekarang karena:** tidak ada kode B yang dipakai; kerangka `debian/`,
  man, dan completion disalin dari kontrak (P4), bukan menunggu B. Perintah milik B
  dilayani `declare -F` (pesan "belum tersedia", P5).

### A2 — `harga` + `init`/`tambah`/`daftar`/`hapus` + fungsi riwayat (besar, 11 jam)

- **Cakupan:** `parse_harga` (25000/25rb/25k/25.000/25RB), `format_harga`; validasi nama
  dan tag dipakai `tambah`/`daftar`; `cmd_init` (cari `contoh.tsv` 4 lokasi, `--paksa`),
  `cmd_tambah`, `cmd_daftar` (lebar kolom, potong `...`, `--tsv`, ringkasan stderr),
  `cmd_hapus`; **`muat_config`, `baca_riwayat`, `tulis_riwayat` di `lib/data.sh`** — yang
  tiga terakhir bukan pilihan, tapi prasyarat PR B2 yang sudah terbuka dan merah karena
  `baca_riwayat` belum ada. KONTRAK §7 sudah mengikat tanda tangannya: `muat_config`
  mengisi `RIWAYAT_HARI` (default 3, kunci asing → peringatan, nilai salah → keluar 3),
  `baca_riwayat` mengisi `RIWAYAT[]`/`RIWAYAT_TOTAL` (2 kolom, lewati tanggal tidak valid
  dan masa depan + peringatan), `tulis_riwayat` menulis atomik dan memangkas entri > 90 hari.
- **Berkas:** `lib/harga.sh`, `lib/cmd-dasar.sh`, `lib/data.sh`, `tests/tambah.bats`,
  `tests/daftar.bats`.
- **Tes wajib (`tests/tambah.bats`, 8):** `tambah valid menyimpan lima kolom`,
  `tiga format harga setara`, `harga bertitik diterima`,
  `harga_min lebih besar dari harga_max ditolak`, `nama duplikat ditolak`,
  `nama dengan spasi tersimpan utuh dan bisa dihapus`, `nama bertab ditolak`,
  `nama berawalan pagar ditolak`.
  **(`tests/daftar.bats`, 3):** `tabel terurut dan berisi delapan baris`,
  `--tsv mencetak lima kolom tanpa header`, `daftar kosong keluar 0 dengan pesan Belum ada data`.
  **(`tests/tambah.bats`, 3 tambahan wajib — `tulis_tempat` sempat lolos tanpa tes di A1):**
  `tambah mempertahankan komentar di tempat.tsv`, `tambah memperingatkan baris rusak dan
  tetap menyimpan baris valid`, `tambah menangani CRLF di tempat.tsv`.
- **Kriteria selesai:** `init` + `tambah` + `daftar` + `hapus` jalan di `MAKAN_APA_DATA_DIR`
  tmp; lebar kolom sama dengan contoh `PLAN.md` §2.5; `daftar --tsv | wc -l` = 8 setelah
  `init`; **`make check` hijau tanpa tes yang di-skip; `makan-apa riwayat` jalan tanpa galat
  `baca_riwayat: command not found`** (prasyarat PR B2); tidak ada driver sementara yang
  ikut ter-commit.
- **Branch:** `a-2-perintah-dasar` · **PR:** #6 · **Reviewer:** B.
- **Bisa dimulai sekarang karena:** `parse_harga` milik sendiri (P2); hanya butuh `bin` dan
  `data` dari A1. Melepas blokir PR B2 adalah tambahan gratis — tidak menambah ketergantungan
  ke tahap lain.

### A3 — `saring` dasar + `cmd_pilih` (sedang, 6 jam)

- **Cakupan:** `saring` tanpa filter (semua baris jadi kandidat); `pilih_indeks` (LCG
  Park–Miller, 4 byte `/dev/urandom`, `MAKAN_APA_SEED`); `cmd_pilih`: baca, pilih, tulis
  riwayat (tambah baris), cetak nama ke stdout + detail ke stderr.
- **Berkas:** `lib/saring.sh`, `lib/cmd-pilih.sh`, `tests/pilih.bats`.
- **Tes wajib (`tests/pilih.bats`, 3):** `stdout hanya berisi nama`,
  `seed sama menghasilkan nama sama`, `satu kandidat dipilih dan dicatat`.
- **Kriteria selesai:** dua kali `pilih` dengan `MAKAN_APA_SEED=42` memberi nama sama;
  `riwayat.tsv` bertambah satu baris per pemanggilan; stdout tepat satu baris.
- **Branch:** `a-3-pilih` · **PR:** #5 · **Reviewer:** B.
- **Bisa dimulai sekarang karena:** `baca_riwayat`/`tulis_riwayat` sudah ada dari A1.

### A4 — Filter budget/tag/ketat + statistik (sedang, 6 jam)

- **Cakupan:** `saring` menerapkan budget → tag secara berurutan, mengisi `GAGAL_BUDGET`,
  `GAGAL_TAG`, `KANDIDAT_TOTAL`, `SARAN_BUDGET`; `cmd_pilih` mencetak baris
  `Kandidat: ...`; `cmd_daftar` menerima `--tag`/`--budget`/`--ketat` (filter sama) dan
  `--tsv` dengan filter tetap berlaku (K12); validasi `--ketat` tanpa `--budget` dan
  `--budget` dua nilai.
- **Berkas:** `lib/saring.sh`, `lib/cmd-pilih.sh`, `lib/cmd-dasar.sh`, `tests/pilih.bats`,
  `tests/daftar.bats`.
- **Tes wajib:** `budget inklusif di batas`, `ketat membandingkan harga_max di batas`,
  `ketat lebih sempit dari default` (8 → 4), `filter tag hanya menampilkan tempat bertag itu`
  (pilih.bats, 4); `filter tag OR hanya menampilkan nasi atau mie` (daftar.bats, 1).
- **Kriteria selesai:** `budget + tag + riwayat + kandidat = total` pada setiap kombinasi
  yang diuji; `pilih --budget 20rb --ketat` memberi `Kandidat: 4 dari 8`.
- **Branch:** `a-4-filter` · **PR:** #7 · **Reviewer:** B.
- **Bisa dimulai sekarang karena:** hanya menambah cabang di `saring` milik sendiri.

### A5 — Jendela riwayat, `--dry-run`, `--ulang`, diagnosis (besar, 9 jam)

- **Cakupan:** `saring` memblokir tempat yang tercatat dalam `N` hari
  (`HARI_INI - (N-1) .. HARI_INI`), `N=0` mematikan; `cmd_pilih` menentukan `N`
  (`--hari` > `riwayat_hari` > 3), `--dry-run` (kunci bersama, tanpa tulis), `--ulang`
  (ganti baris terakhir bila bertanggal hari ini, selain itu tambah + info), K3;
  `cetak_diagnosa` lengkap (blok 5.7 + `Saran:`), termasuk P9: saran `--budget` memakai
  `harga_max` terkecil saat `--ketat`, `harga_min` saat mode default; `tulis_riwayat`
  memangkas entri > 90 hari.
- **Berkas:** `lib/saring.sh`, `lib/cmd-pilih.sh`, `lib/data.sh`, `tests/pilih.bats`.
- **Tes wajib (`tests/pilih.bats`, 5):** `--dry-run tidak mengubah riwayat`,
  `semua tereliminasi memberi diagnosis dan saran` (memuat `gagal budget      : 7` dan
  `Saran:`), `saran ketat memakai harga_max` (`--ketat --budget 5rb` → 0 kandidat, saran
  `naikkan --budget (mis. --budget 8rb)`; aturan lama berbasis `harga_min` akan menulis
  `4rb`, jadi tes ini membedakan P9), `daftar kosong keluar 2`,
  `satu tempat sudah dipilih hari ini diblokir riwayat` (`diblokir riwayat  : 1`).
- **Kriteria selesai:** demo `PLAN.md` §1 langkah 1–6 lulus dengan angka persis
  (`8/8`, `7/8`, `6/8`, lalu `3 dari 8 (budget 4, tag 0, riwayat 1)`); `--hari 0` memberi
  `Kandidat: n dari n`.
- **Branch:** `a-5-pengalaman` · **PR:** #9 · **Reviewer:** B.
- **Bisa dimulai sekarang karena:** semua bagiannya milik sendiri; tidak butuh PR B.

### A6 — Pengerasan data + gerbang A (sedang, 7 jam)

- **Cakupan:** `baca_tempat` membuang `\r`, memberi peringatan baris rusak, keluar 3 bila
  semua baris rusak; `baca_riwayat` melewati tanggal tidak valid/masa depan + peringatan;
  `tulis_atomik` tidak meninggalkan `.tmp.*`; uji `flock` (kunci bersama vs eksklusif);
  hapus `continue-on-error` pada job `pasang` di `ci.yml`; hapus penjaga `declare -F`
  di `bin/makan-apa` (P5 selesai).
- **Berkas:** `lib/data.sh`, `lib/umum.sh`, `bin/makan-apa`, `.github/workflows/ci.yml`,
  `tests/data.bats`.
- **Tes wajib (`tests/data.bats`, 7):** `baris rusak dilewati dengan peringatan`,
  `semua baris rusak keluar 3`, `CRLF dibuang dari nama`,
  `komentar dan baris kosong diabaikan`, `berkas tidak ada menghasilkan daftar kosong`,
  `kunci sibuk keluar 4`, `tidak ada berkas sementara tersisa`.
- **Kriteria selesai:** `make check` hijau dengan `pasang` wajib; `grep -r "belum tersedia"`
  di `bin/` dan `lib/` kosong.
- **Branch:** `a-6-pengerasan` · **PR:** #11 · **Reviewer:** B.
- **Bisa dimulai sekarang karena:** hanya berkas sendiri; `tests/data.bats` tidak menyentuh
  modul B.

### A7 — Kasus tepi `PLAN.md` §4.5 + audit kontrak (kecil, 3 jam)

- **Cakupan:** tiga kasus wajib `PLAN.md` §4.5 yang belum punya tes: satu tempat belum
  pernah dipilih, semua diblokir riwayat, `--ulang` tanpa kandidat; audit: setiap string
  kontrak §5 muncul di kode, setiap kasus wajib ada di tepat satu berkas tes, isi deb =
  15 path, `grep -r "belum tersedia"` kosong.
- **Berkas:** `tests/pilih.bats` (3 kasus tambahan).
- **Tes wajib (3):** `satu tempat belum pernah dipilih langsung dipilih`,
  `semua tempat diblokir riwayat memberi saran hari 0`,
  `ulang tanpa kandidat keluar 2 dengan saran hari 0`.
- **Kriteria selesai:** `make check` hijau; hasil audit ditulis sebagai komentar PR;
  `make uji-pasang` (skrip milik B, sudah ada sejak #2) lulus di `ubuntu:24.04` dan
  `ubuntu:22.04`.
- **Branch:** `a-7-kasustepi` · **PR:** #13 · **Reviewer:** B.
- **Bisa dimulai sekarang karena:** hanya menambah kasus ke `tests/pilih.bats` milik
  sendiri; `cmd_pilih` sudah lengkap sejak A5.

## 4. Urutan kerja dan pekerjaan saat menunggu

1. A0 → A1 (push + PR hari pertama; jangan menumpuk commit lokal). B0 (B) selesai lebih
   dulu di H1; bila belum, A tetap menulis A1 di clone lokal dan menunggu hanya untuk push.
2. Selagi PR #1 menunggu review B: mulai A2 di branch baru dari `main` (bukan dari branch
   #1). Bila #1 belum merge, A2 tetap dikerjakan; merge A2 setelah #1.
3. Pola tetap: satu branch aktif + satu tahap berikutnya sudah ditulis. Saat PR menunggu
   review/CI: (a) jalankan `make check` + `make deb` lokal, (b) review PR B yang terbuka
   (`gh pr diff`), (c) tulis tes tahap berikutnya.
4. Saat CI merah: perbaiki di branch yang sama, push ulang; jangan membuat branch baru.
5. Setelah PR merge: `git switch main && git pull --ff-only`, lalu branch baru untuk tahap
   berikutnya. **Branch lama tidak dihapus dan tidak dipakai ulang** (P10); perbaikan susulan
   memakai branch baru, mis. `a-1-kerangka-perbaikan`.
6. Saat titik temu: jalankan `make check && make deb && make lint` di `main` hasil merge,
   catat hasilnya di komentar PR.

## 5. Stub dan data palsu

| Dibuat di | Isi | Diganti/dibuang |
|---|---|---|
|A1|`lib/harga.sh`, `lib/saring.sh`, `lib/cmd-dasar.sh`, `lib/cmd-pilih.sh` hanya komentar header|A2/A3 (isi fungsi)|
|A1|`lib/cmd-ubah.sh`, `lib/cmd-impor.sh`, `lib/cmd-riwayat.sh` hanya komentar header|B4/B3/B2|
|A1|`man/makan-apa.1` minimal (NAME/SYNOPSIS/DESCRIPTION, tanpa peringatan groff)|B1 (versi lengkap)|
|A1|`completions/makan-apa` minimal (bisa di-`source`)|B1|
|A1|penjaga `declare -F` + pesan "belum tersedia"|A6 (dihapus)|
|A2|fixture tes: `printf` TSV langsung ke `$MAKAN_APA_DATA_DIR/tempat.tsv`|permanen di tes (bukan stub produksi)|

Tidak ada stub yang boleh bertahan setelah tahap pemiliknya merge; A6 memverifikasi dengan
`grep -r "belum tersedia"`.

## 6. Titik temu dengan B

| Temu | Peran A | Yang diperiksa bersama |
|---|---|---|
|T1 (akhir S2, setelah #2)|B merge #1 dan memasang proteksi; A memverifikasi proteksi, lalu B merge #2|`make check` + `make deb` di `main`; `dpkg-deb -c` = 15 path; status check muncul di PR #2|
|T2 (akhir S3)|jalankan 7 perintah (tanpa `ubah`) di `MAKAN_APA_DATA_DIR=/tmp/temu2`|`init`→`tambah`→`daftar`→`pilih`→`riwayat`→`impor`→`hapus` tanpa galat|
|T3 (akhir S4)|hitung manual `budget+tag+riwayat+kandidat` untuk 4 kombinasi filter; jalankan `ubah`|angka konsisten, `--ketat` 8 → 4, `Diubah:` sesuai kontrak|
|T4 (akhir S5)|jalankan demo `PLAN.md` §1 baris per baris|angka demo persis; kedelapan perintah berfungsi|
|T5 (akhir S7)|jalankan `IMG=ubuntu:24.04 tests/pasang-bersih.sh` (skrip B) lalu `IMG=ubuntu:22.04`|pasang, demo, remove, purge, data pengguna utuh|

## 7. Langkah Git praktis

A0 (sekali). Repo milik B, A kolaborator: `https://github.com/Ivanadrian31/MakanApa.git`.

```bash
git clone https://github.com/Ivanadrian31/MakanApa.git
cd MakanApa
git config user.name "bimadji" && git config user.email "<email-A>"
git switch -c uji-akses
git commit --allow-empty -m "uji akses"
git push -u origin uji-akses            # harus berhasil; bila 403, minta B mengundang
git push origin --delete uji-akses       # satu-satunya branch yang boleh dihapus (P10)
git switch main
```

Bila `main` belum di-seed B0 atau undangan belum diterima, A **tidak menunggu** — kerjakan
A1 langsung di folder kerja, lalu sambungkan begitu repo siap:

```bash
git init -b main
git remote add origin https://github.com/Ivanadrian31/MakanApa.git
git fetch origin && git rebase --onto origin/main --root   # setelah B0 mendarat
```

Jalur cadangan tanpa akses tulis: `gh repo fork Ivanadrian31/MakanApa --clone`, kerjakan A1
di fork, dan buka PR dari fork ke `Ivanadrian31:main`.

Pola setiap tahap (contoh A2):

```bash
git switch main && git pull --ff-only
git switch -c a-2-perintah-dasar
# ... kerja ...
git add lib/harga.sh lib/cmd-dasar.sh tests/tambah.bats tests/daftar.bats
git commit -m "a2: parse_harga/format_harga dan perintah init/tambah/daftar/hapus"
git push -u origin a-2-perintah-dasar
gh pr create --base main --title "A2: perintah dasar (init/tambah/daftar/hapus)" \
  --body "Cakupan: ... | Tes: tests/tambah.bats (8), tests/daftar.bats (3) | make check: hijau lokal"
gh pr checks --watch
gh pr merge --squash                       # tanpa --delete-branch (P10)
git switch main && git pull --ff-only      # branch lama dibiarkan di remote
```

Review PR B (silang):

```bash
gh pr checkout 4
make check && make deb
gh pr review 4 --approve --body "Diperiksa: string kontrak §5.4, tes 5 kasus, make check hijau"
gh pr merge 4 --squash                     # tanpa --delete-branch (P10)
```

Verifikasi proteksi (B yang memasang, A hanya memeriksa; B adalah pemilik repo):

```bash
gh api "repos/Ivanadrian31/MakanApa/branches/main/protection" \
  --jq '{pr: .required_pull_request_reviews.required_approving_review_count,
         force: .allow_force_pushes.enabled,
         checks: .required_status_checks.contexts}'
# harapan: pr=1, force=false, checks memuat "check (ubuntu-24.04)" dan "check (ubuntu-22.04)"
```

Bila proteksi belum ada di Temu-1, A menulis komentar di PR #1 dan menagih B; A **tidak**
mencoba mengubahnya (akan 403 dan bukan wewenang A).

Bila PR sendiri konflik: `git rebase origin/main`, selesaikan, `git push --force-with-lease`
(hanya branch sendiri, tidak pernah `main`), lalu `make check` ulang.

## 8. Risiko khusus A

| Risiko | Mitigasi |
|---|---|
|Arithmetic statistik diagnosis tidak konsisten (`b+t+r+k ≠ n`)|`saring` satu lintasan berurutan; tes T3 menghitung manual 4 kombinasi |
|Fungsi yang memanggil `die` di dalam `$(...)` mematikan subshell, bukan skrip|semua fungsi validasi memakai variabel global (`NAMA_BERSIH`, `HARGA_NILAI`), tidak dipanggil dalam command substitution (kontrak §7)|
|`set -e` + `pipefail` membuat `grep`/`sort` gagal mematikan skrip tanpa pesan|setiap perintah luar dibungkus `|| die ...` atau `if`|
|`LC_ALL=C` menggeser kolom untuk nama non-ASCII|diterima (PLAN.md §10.1); lebar dihitung `awk length()` pada byte |
|`flock` fd 9 hilang karena subshell|`ambil_kunci` dipanggil di shell utama; tes `kunci sibuk` membuktikan |
|shellcheck `--severity=style` (SC2086, SC2181, SC2015)|disiplin kutip; `# shellcheck disable=` hanya dengan alasan di baris yang sama|
|bats 1.2 di 22.04 tidak punya `run -N`/`$stderr`|pakai `run bash -c '... 2>/dev/null'` (kontrak §9)|
|PR #1 tidak bisa menunggu CI|verifikasi lokal oleh B + catatan di PR; B merge; proteksi dipasang B tepat setelah merge (kontrak §11.1)|
|Docker tidak ada di mesin Windows|A7 memakai skrip B di WSL Ubuntu; bila tidak ada, minta B menjalankan (CI job `pasang` jadi bukti utama)|
|A bukan pemilik repo: tidak bisa set proteksi, ubah setting, atau push `main`|A hanya memverifikasi proteksi lewat `gh api .../protection`; perubahan setting ditagih ke B di PR/issue|
|Undangan kolaborator belum diterima sehingga `git push` 403|A lanjut menulis A1 di clone lokal, lalu fork (`gh repo fork`) sebagai jalur PR; tidak ada tahap yang tertunda|
|Force-push tidak boleh ke `main` (dan A memang tidak bisa)|`git push --force-with-lease` hanya untuk branch sendiri, setelah `git rebase origin/main`|
