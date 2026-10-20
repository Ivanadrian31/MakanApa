# PLAN-B — Orang B (`Ivanadrian31`)

Paket `.deb`, halaman manual, completion, dokumen, tiga subperintah (`riwayat`, `impor`,
`ubah`), tes jendela riwayat, rilis, **dan tugas admin repo** (B pemilik
`Ivanadrian31/MakanApa`: seed `main`, undang kolaborator, proteksi branch, tag).
Beban: **51 jam** (≈ 13 hari pada 4 jam/hari).

Baca `KONTRAK.md` lebih dulu; dokumen ini tidak mengulang string dan tanda tangan fungsi.

---

## 1. Peran dan berkas yang dimiliki

| Path | Isi |
|---|---|
|`PLAN-B.md`|dokumen ini|
|`lib/cmd-riwayat.sh`|`cmd_riwayat` (tabel, `--hari`, `--semua`, ringkasan stderr)|
|`lib/cmd-impor.sh`|`cmd_impor` (validasi menyeluruh, dedupe, `--ganti`, atomik)|
|`lib/cmd-ubah.sh`|`cmd_ubah` (ubah sebagian, `--nama-baru`, `--catatan ""`)|
|`debian/control`, `debian/changelog`, `debian/copyright`|metadata paket (DEP-5)|
|`man/makan-apa.1`|10 bagian (NAME…SEE ALSO)|
|`completions/makan-apa`|bash completion|
|`README.md`|8 bagian (kontrak `PLAN.md` §8.1)|
|`CHANGELOG.md`|Keep a Changelog|
|`LICENSE`|MIT|
|`tests/riwayat.bats`|15 kasus (5 di B2, 10 di B5)|
|`tests/impor.bats`|4 kasus|
|`tests/ubah.bats`|4 kasus|
|`tests/pasang-bersih.sh`|uji Docker pasang/remove/purge|

Tugas admin repo (B pemilik, tidak bisa didelegasikan ke A): seed `main` dengan 4 dokumen,
undang `bimadji` sebagai kolaborator `push`, aktifkan proteksi `main`, merge PR #1
(bootstrap), tag `v0.1.0` dan GitHub Release.

Berkas milik A yang **tidak** boleh disentuh: `Makefile`, `.github/workflows/ci.yml`,
`bin/makan-apa`, `lib/umum.sh`, `lib/harga.sh`, `lib/data.sh`, `lib/saring.sh`,
`lib/cmd-dasar.sh`, `lib/cmd-pilih.sh`, `tests/helper.bash`, `tests/cli.bats`,
`tests/tambah.bats`, `tests/daftar.bats`, `tests/pilih.bats`, `tests/data.bats`,
`data/contoh.tsv`, `KONTRAK.md`, `PLAN-A.md`.

Bila butuh target Makefile baru atau perubahan `ci.yml`: tulis issue `butuh: <target>`
dengan alasan, A yang mengubah (satu baris, PR kecil).

## 2. Bahan yang dibaca dari KONTRAK.md

| Bagian | Untuk apa |
|---|---|
|§2.1 P1–P9|pemecahan `lib/`, kepemilikan, koreksi angka demo, saran `--ketat` (P9)|
|§2.2 K1–K14|hint help, `--tsv` + filter (K12), `ubah` idempoten (K7), `MAKAN_APA_LIB`|
|§3|pohon berkas + aturan "lib hanya definisi fungsi"|
|§4|opsi dan arity `riwayat`/`impor`/`ubah`|
|§5.4, §5.5|string sukses `Diubah:`, `Diimpor …`, tabel `riwayat` (K5)|
|§6|format TSV yang dibaca/ditulis ketiga perintah|
|§7|tanda tangan `baca_tempat`, `tulis_tempat`, `parse_harga`, `validasi_nama`, `normalisasi_tag`|
|§9|helper beku, pemisahan stream, aturan tes merah|
|§10|isi paket (15 path) — dasar `tests/pasang-bersih.sh`|
|§11|alur Git/GitHub, CI, repo `Ivanadrian31/MakanApa`, rilis dari commit hijau|
|§12|jadwal, titik temu, ketergantungan|
|§14|keputusan pemilik rencana (repo publik, K1–K14 disetujui, P9)|

## 3. Tahap

### B0 — Bootstrap repo sebagai pemilik (kecil, 2 jam) · bukan tahap PR

- **Cakupan:** clone repo kosong, commit 4 dokumen ke `main`, push, undang `bimadji`
  (permission `push`), pastikan A menerima; aktifkan proteksi `main` setelah #1 merge
  (nama status check baru ada setelah CI berjalan sekali).
- **Berkas:** `PLAN.md`, `KONTRAK.md`, `PLAN-A.md`, `PLAN-B.md` (sudah ada di folder kerja;
  hanya di-commit, bukan ditulis ulang).
- **Tes wajib:** `gh api .../collaborators --jq '.[].login'` memuat `bimadji`;
  `git ls-remote --heads origin` menampilkan `refs/heads/main`.
- **Kriteria selesai:** `main` berisi 4 dokumen; A bisa `git push` ke branch uji; proteksi
  terpasang (dicek ulang di T1).
- **Branch/PR/reviewer:** tidak ada PR (seed awal `main` oleh pemilik, dicatat di kontrak
  §11.1/§11.2). Reviewer: — .
- **Bisa dimulai sekarang karena:** B pemilik repo; tidak butuh apa pun dari A. B0 selesai
  dalam hitungan menit, lalu B langsung lanjut B1 di jam yang sama.

### B1 — Paket, man, completion, dokumen, uji pasang (besar, 12 jam)

- **Cakupan:** finalkan `debian/control` (field + `Installed-Size` diserahkan ke Makefile),
  `debian/changelog` (RFC 2822 `+0700`), `debian/copyright` (DEP-5, MIT); tulis
  `man/makan-apa.1` lengkap 10 bagian; completion yang memuat 8 perintah dan opsi per
  perintah; `README.md` 8 bagian; `CHANGELOG.md`; `LICENSE` MIT; `tests/pasang-bersih.sh`
  (pasang → demo → `remove` → cek data → `purge` → cek paket hilang).
- **Berkas:** `debian/control`, `debian/changelog`, `debian/copyright`,
  `man/makan-apa.1`, `completions/makan-apa`, `tests/pasang-bersih.sh`, `README.md`,
  `CHANGELOG.md`, `LICENSE`.
- **Tes wajib:** `make man` (groff tanpa peringatan), `make lint` (output dibaca; setiap tag
  dijelaskan di deskripsi PR), `bash -n completions/makan-apa` + `source` tanpa galat,
  `make deb` lalu `dpkg-deb -c` = 15 path kontrak §10, `make uji-pasang` di `ubuntu:24.04`.
- **Kriteria selesai:** `make man` dan `make lint` bersih; README 5 baris pertama bisa
  diikuti tanpa bertanya; `tests/pasang-bersih.sh` keluar 0.
- **Branch:** `b-1-paket` · **PR:** #2 · **Reviewer:** A.
- **Bisa dimulai sekarang karena:** man page, README, CHANGELOG, LICENSE, dan control
  ditulis dari `PLAN.md` §7–8 tanpa kode apa pun. PR dibuka sebagai draft di H1; CI baru
  berjalan setelah #1 (A1) merge. Selama menunggu, B lanjut menulis `lib/cmd-riwayat.sh`.

### B2 — `cmd_riwayat` + 5 tes perintah (sedang, 7 jam)

- **Cakupan:** baca riwayat, urutkan tanggal menurun (tanggal sama: baris terbaru di atas),
  `--hari N` (default 14, `0` = hari ini saja), `--semua`, tolak `--semua` + `--hari`,
  ringkasan `3 catatan (7 hari terakhir).`, kosong → `Belum ada riwayat.` keluar 0.
- **Berkas:** `lib/cmd-riwayat.sh`, `tests/riwayat.bats`.
- **Tes wajib (5):** `riwayat menampilkan tanggal menurun`,
  `--hari 0 hanya menampilkan hari ini`, `--semua dan --hari bersama ditolak`,
  `riwayat kosong keluar 0 dengan pesan Belum ada riwayat`,
  `riwayat tetap menampilkan nama yang sudah dihapus`.
- **Kriteria selesai:** 3 baris riwayat tersusun benar; `--semua --hari 7` keluar 1.
- **Branch:** `b-2-riwayat` · **PR:** #4 · **Reviewer:** A.
- **Bisa dimulai sekarang karena:** hanya butuh `baca_riwayat`, `hari_ini`, `die`, dan
  dispatch dari A1 — semuanya sudah di `main` saat B1 merge. Tes menulis fixture sendiri
  (`printf` ke `$MAKAN_APA_DATA_DIR/riwayat.tsv`), tidak menunggu `cmd_pilih`.

### B3 — `cmd_impor` + 4 tes (sedang, 8 jam)

- **Cakupan:** baca berkas impor; validasi **seluruh** baris dulu (kolom, harga via
  `parse_harga`, tag via `normalisasi_tag`, nama via `validasi_nama`); satu baris salah →
  keluar 3, tidak ada yang ditulis, pesan memuat maks 5 nomor baris; duplikat terhadap
  daftar dan di dalam berkas dilewati (yang pertama menang); `--ganti` mengganti seluruh
  daftar (tetap atomik); berkas tidak ada → keluar 3.
- **Berkas:** `lib/cmd-impor.sh`, `tests/impor.bats`.
- **Tes wajib (4):** `impor menambah lima tempat baru`,
  `impor kedua melewati duplikat` (`Diimpor 0, 5 dilewati`),
  `--ganti mengganti seluruh daftar` (8 → 5),
  `baris tidak valid membatalkan seluruh impor` (`cmp` berkas identik, keluar 3).
- **Kriteria selesai:** berkas 5 baris + 1 baris rusak → daftar tidak berubah sama sekali.
- **Branch:** `b-3-impor` · **PR:** #6 · **Reviewer:** A.
- **Bisa dimulai sekarang karena:** tanda tangan `parse_harga`/`validasi_nama`/
  `normalisasi_tag` ada di kontrak §7 (milik A, mendarat di #3); kode ditulis terhadap
  kontrak, `shellcheck` jalan tanpa A2, `bats` merah sampai #3 merge. Merge setelah #3.

### B4 — `cmd_ubah` + 4 tes (sedang, 6 jam)

- **Cakupan:** ubah kolom yang opsinya diberikan saja; `--catatan ""` dan `--tag ""`
  mengosongkan; `--nama-baru` tunduk validasi nama dan tidak boleh menabrak nama lain
  (`--nama-baru` sama dengan nama lama bukan galat); nama tidak ada → keluar 5;
  K7 (tanpa opsi tetap mencetak `Diubah:`).
- **Berkas:** `lib/cmd-ubah.sh`, `tests/ubah.bats`.
- **Tes wajib (4):** `ubah mengganti harga dan tag saja`,
  `ubah mengosongkan catatan dengan string kosong`,
  `ubah mengganti nama tanpa menabrak nama lain`,
  `ubah nama yang tidak ada keluar 5`.
- **Kriteria selesai:** `ubah` tidak pernah mengubah kolom yang tidak disebut; riwayat tidak
  tersentuh.
- **Branch:** `b-4-ubah` · **PR:** #8 · **Reviewer:** A.
- **Bisa dimulai sekarang karena:** sama seperti B3; hanya butuh A2 yang sudah merge di #3.

### B5 — 10 kasus wajib jendela riwayat (besar, 9 jam)

- **Cakupan:** menambah 10 kasus ke `tests/riwayat.bats` yang menguji `saring`/`cmd_pilih`
  milik A (cross-check), memakai `MAKAN_APA_TANGGAL` untuk memalsukan hari dan fixture
  riwayat langsung.
- **Berkas:** `tests/riwayat.bats`.
- **Tes wajib (10):** `jendela N=3 memblokir catatan dua hari lalu`,
  `jendela N=3 tidak memblokir catatan tiga hari lalu`, `hari 0 mengabaikan riwayat`,
  `hari menimpa konfigurasi riwayat_hari`,
  `konfigurasi riwayat_hari dipakai bila --hari tidak ada`,
  `konfigurasi riwayat_hari=1 hanya memblokir hari ini`,
  `ulang setelah tengah malam menambah baris baru`,
  `ulang mengganti baris hari ini tanpa menambah`,
  `ulang tanpa pilihan hari ini mencatat pilihan baru`,
  `entri lebih tua dari 90 hari dipangkas saat menulis`.
- **Kriteria selesai:** `Kandidat: 1 dari 2` vs `2 dari 2` terbukti pada batas N=3; jumlah
  baris `riwayat.tsv` tetap 1 setelah `--ulang`.
- **Branch:** `b-5-gerbang-riwayat` · **PR:** #10 · **Reviewer:** A.
- **Bisa dimulai sekarang karena:** kesepuluh kasus ditulis dari kontrak §5.6/§6.3 dan
  `PLAN.md` §4.3/§4.6 (boleh merah dulu). Merge setelah #9 (A5). Waktu tunggu dipakai
  merekam demo di `main` yang sudah punya A5.

### B6 — Rilis (sedang, 7 jam)

- **Cakupan:** finalkan README (transkrip demo asli dari `main`), CHANGELOG `[0.1.0]`,
  rekam demo 2 menit (6 perintah `PLAN.md` §1), tag `v0.1.0` dari `main` hijau, unggah
  `.deb` hasil CI ke GitHub Releases, pastikan `make lint` bersih atau setiap tag dijelaskan.
- **Berkas:** `README.md`, `CHANGELOG.md`.
- **Tes wajib:** `make check`, `make deb`, `make lint`, `make uji-pasang` di `main` commit
  tag; unduh artefak CI dan `dpkg-deb -I` memeriksa versi 0.1.0.
- **Kriteria selesai:** `gh release view v0.1.0` menampilkan satu aset `.deb`; aset itu
  berasal dari `gh run download` run yang hijau pada commit tag.
- **Branch:** `b-6-rilis` · **PR:** #12 · **Reviewer:** A.
- **Bisa dimulai sekarang karena:** langkah rilis dan teks CHANGELOG sudah ditentukan;
  eksekusi tag menunggu #11 (A6) hijau — pekerjaan sebelumnya (README, rekaman) tidak.

## 4. Urutan kerja dan pekerjaan saat menunggu

1. H1 jam pertama: **B0** (seed `main` 4 dokumen, undang `bimadji`, pastikan akses) — ± 15
   menit, lalu langsung lanjut.
2. H1: tulis B1 (man, README, CHANGELOG, LICENSE, completion, control, changelog, copyright,
   `pasang-bersih.sh`), buka PR draft #2.
3. H1–H2 juga: tulis `lib/cmd-riwayat.sh` + 5 tes (B2) — tidak butuh berkas A untuk ditulis.
4. Setelah #1 merge: pasang proteksi `main` (nama status check sudah terdaftar), ubah #2 jadi
   ready, jalankan `make man && make deb && make lint`, minta review A.
5. Pola tetap: satu PR menunggu, satu tahap sedang ditulis. Saat menunggu: `gh pr diff`
   PR A untuk review, baca ulang kontrak §5 untuk string, siapkan fixture tes.
6. Bila `bats` merah karena modul A belum ada: jangan mengubah implementasi atau tes menjadi
   longgar; tunggu merge A yang relevan, lanjut tahap berikutnya.
7. Saat titik temu: jalankan `make check && make deb && make lint` di `main`.

## 5. Stub dan data palsu

| Dibuat di | Isi | Diganti/dibuang |
|---|---|---|
|B1|`man/makan-apa.1` dan `completions/makan-apa` versi lengkap menggantikan kerangka A1|permanen|
|B2–B4|fixture tes: `printf` baris TSV ke `$MAKAN_APA_DATA_DIR/{tempat,riwayat}.tsv` dan `$MAKAN_APA_CONFIG_DIR/config`|permanen di tes|
|B2–B5|tidak ada stub produksi: ketiga `cmd_*` langsung implementasi penuh|—|

B tidak membuat stub untuk modul A. Bila tes merah karena A belum merge, itu keadaan yang
diharapkan (kontrak §12.1) dan bukan alasan menambah stub.

## 6. Titik temu dengan A

| Temu | Peran B | Yang diperiksa bersama |
|---|---|---|
|T1 (akhir S2)|review + verifikasi lokal PR #1 lalu merge sebagai pemilik; pasang proteksi `main`; serahkan #2 siap merge|deb 15 path, `make check`/`make deb` di `main`, proteksi aktif (`pr=1`, `force=false`)|
|T2 (akhir S3)|jalankan `riwayat` dan `impor` di data tmp|`Diimpor 5 tempat` dan tabel `riwayat` sesuai kontrak|
|T3 (akhir S4)|jalankan `ubah`; periksa angka `Kandidat:` pada 4 kombinasi filter|`Diubah:` sesuai kontrak; `b+t+r+k = n`|
|T4 (akhir S5)|jalankan demo §1 dan bandingkan dengan transkrip|angka demo persis, termasuk `3 dari 8 (budget 4, tag 0, riwayat 1)`|
|T5 (akhir S7)|jalankan rilis: tag + release dari artefak CI|`gh release view` satu aset; `dpkg-deb -I` versi 0.1.0|

## 7. Langkah Git praktis

B0 (sekali, B pemilik): seed `main`, undang A, siapkan proteksi.

```bash
git clone https://github.com/Ivanadrian31/MakanApa.git
cd MakanApa
# salin PLAN.md, KONTRAK.md, PLAN-A.md, PLAN-B.md ke folder ini
git add PLAN.md KONTRAK.md PLAN-A.md PLAN-B.md
git commit -m "dok: rencana proyek dan kontrak kerja dua orang"
git push -u origin main

gh api -X PUT "repos/Ivanadrian31/MakanApa/collaborators/bimadji" -f permission=push
gh api "repos/Ivanadrian31/MakanApa/collaborators" --jq '.[].login'
```

Setelah #1 merge (CI sudah berjalan sekali sehingga nama check terdaftar):

```bash
gh api -X PUT "repos/Ivanadrian31/MakanApa/branches/main/protection" --input - <<'JSON'
{"required_status_checks":{"strict":true,"contexts":["check (ubuntu-24.04)","check (ubuntu-22.04)"]},
 "enforce_admins":true,
 "required_pull_request_reviews":{"required_approving_review_count":1,"dismiss_stale_reviews":true},
 "restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
JSON
```

Pola setiap tahap (contoh B3):

```bash
git switch main && git pull --ff-only
git switch -c b-3-impor
# ... kerja ...
git add lib/cmd-impor.sh tests/impor.bats
git commit -m "b3: cmd_impor dengan validasi menyeluruh dan --ganti"
git push -u origin b-3-impor
gh pr create --base main --title "B3: impor TSV (validasi menyeluruh, --ganti)" \
  --body "Cakupan: ... | Tes: tests/impor.bats (4) | make check: hijau lokal setelah #3"
gh pr checks --watch
gh pr merge --squash --delete-branch
git switch main && git pull --ff-only
```

Catatan peran: B pemilik repo, jadi B boleh menekan merge — tetapi tetap **tidak** untuk PR
tulisannya sendiri; PR B di-approve dan di-merge oleh A (`gh pr review <n> --approve` dari
akun `bimadji`, lalu A yang menjalankan `gh pr merge`). Aturan `enforce_admins: true`
membuat B juga terhalang merge tanpa persetujuan.

PR draft B1 di hari pertama:

```bash
git switch -c b-1-paket
git add debian man completions README.md CHANGELOG.md LICENSE tests/pasang-bersih.sh
git commit -m "b1: paket debian, man page, completion, README, CHANGELOG, LICENSE"
git push -u origin b-1-paket
gh pr create --draft --base main --title "B1: paket, man, completion, dokumen" \
  --body "Draft sampai #1 merge (CI belum ada di main)."
gh pr ready 2        # setelah #1 merge
```

Review PR A (silang):

```bash
gh pr checkout 3
make check && make deb
gh pr review 3 --approve --body "Diperiksa: string kontrak §5, tes 8+3 kasus, lebar kolom"
gh pr merge 3 --squash --delete-branch
```

Rilis (setelah #11 hijau):

```bash
git switch main && git pull --ff-only
git log -1 --format=%H
gh run list --repo Ivanadrian31/MakanApa --branch main --limit 1   # pastikan run hijau
gh run download <run-id> --repo Ivanadrian31/MakanApa -n deb-ubuntu-24.04 -D dist-ci
dpkg-deb -I dist-ci/makan-apa_0.1.0_all.deb | grep Version
git tag -a v0.1.0 -m "makan-apa 0.1.0"
git push origin v0.1.0
gh release create v0.1.0 dist-ci/makan-apa_0.1.0_all.deb \
  --title "makan-apa 0.1.0" --notes-file CHANGELOG.md
```

## 8. Risiko khusus B

| Risiko | Mitigasi |
|---|---|
|groff memperingatkan (mis. `can't break line`, escape salah) sehingga `make man` gagal|`make man` dijalankan setiap commit; perbaiki `.nf/.fi`, `\-`, dan baris > 80 kolom|
|lintian memunculkan tag tak terduga|jalankan `make lint` lokal; tag yang tersisa dijelaskan satu per satu di deskripsi PR (kontrak §11)|
|`bats` merah sampai modul A merge|diharapkan; jangan melonggarkan tes; merge hanya setelah PR A yang relevan (jadwal §12)|
|Salah menafsirkan `--ulang` (mengganti vs menambah)|ikuti `PLAN.md` §4.6 dan K3; tes `ulang setelah tengah malam` membuktikan batas hari|
|`riwayat` menguji modul A (cross-check) dan bisa salah terhadap kontrak|kontrak menang; perbaiki tes di branch yang sama, jangan mengubah `lib/saring.sh`|
|Docker tidak ada di Windows|`tests/pasang-bersih.sh` dijalankan di WSL Ubuntu; CI job `pasang` menjadi bukti utama|
|Unggah `.deb` build lokal, bukan CI|hanya `gh run download` dari run hijau pada commit tag (kontrak §11)|
|Repo privat → tidak ada proteksi branch|Tidak berlaku: repo `Ivanadrian31/MakanApa` publik (kontrak §11.2)|
|Nama non-ASCII menggeser kolom `riwayat`/`daftar`|`LC_ALL=C`; keterbatasan didokumentasikan di README (bagian 7)|
|Sebagai pemilik, B tergoda merge PR sendiri atau bypass proteksi|`enforce_admins: true` + aturan: PR B di-approve dan di-merge A; tidak ada `--admin` merge|
|A belum menerima undangan sehingga #1 tidak bisa di-push|B0 mengundang `bimadji` di hari pertama dan memverifikasi lewat `gh api .../collaborators`; A punya jalur fork|
|Proteksi dipasang sebelum nama status check terdaftar (tidak bisa dipilih)|pasang proteksi setelah #1 merge (CI sudah jalan sekali), bukan di B0|
|B0 menahan A1 karena `main` belum ada|B0 selesai ± 15 menit di H1; A menulis kode di clone lokal lebih dulu, jadi tidak menganggur|
