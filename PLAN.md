# Makan Apa? — Rencana Proyek

Shell script pemilih tempat makan dengan **riwayat** dan **filter**, dikemas sebagai paket `.deb`.
Versi rencana: 0.1.0 · Target: Ubuntu 24.04 LTS (diuji juga di 22.04) · Lisensi: MIT.

## Cara memakai dokumen ini

Dokumen ini adalah spesifikasi yang bisa langsung dikerjakan. Setiap perintah, nama opsi,
kode keluar, nama berkas, dan teks pesan yang tertulis di sini **mengikat**: implementasi
harus memakai string yang sama agar tes dan dokumentasi konsisten. Jika ada bagian yang
tampak kurang, jangan mengarang; periksa bagian 10 (pertanyaan terbuka) lebih dulu.

## 1. Ringkasan dan nilai jual

**Masalah.** Di grup chat, pertanyaan "makan apa?" muncul hampir setiap hari. Jawabannya
biasanya berputar-putar: orang menawarkan tempat yang sama, atau yang harganya tidak cocok,
atau yang kemarin sudah dimakan. Tidak ada satu tempat yang mengingat keputusan bersama.

**Pengguna.** Mahasiswa dan pekerja kantor yang makan bersama 2–6 orang, memakai terminal,
dan ingin keputusan cepat tanpa membuka aplikasi.

**Nilai jual (bukan acak).** Acak itu bagian termurah dari alat ini. Yang membuatnya berguna:

1. **Riwayat** — tempat yang dipilih dalam 3 hari terakhir tidak muncul lagi, jadi tidak
   ada "ayam geprek lagi" tiga hari berturut-turut. Jendela riwayat bisa diubah (`--hari`)
   atau lewat berkas konfigurasi.
2. **Filter** — budget (termasuk mode ketat) dan tag/kategori menyaring kandidat sebelum
   diacak. Kalau semua kandidat habis, alat menjelaskan **mengapa** dan menawarkan cara
   melonggarkan, bukan diam atau gagal tanpa alasan.
3. **Keputusan yang bisa diulang** — `--ulang` mengganti pilihan hari ini tanpa mencatat dua
   kali; `--dry-run` mencoba tanpa mengotori riwayat.

Data berupa TSV yang bisa dibuka di editor teks, disimpan per pengguna di direktori XDG,
dan bisa dibagikan ke teman lewat `daftar --tsv` + `impor`.

### Skenario demo 2 menit

Semua perintah memakai data contoh 8 tempat dari `makan-apa init`. Tanggal dipalsukan dengan
`MAKAN_APA_TANGGAL` supaya demo tidak perlu menunggu tiga hari; perilakunya sama dengan
tanggal asli karena seluruh aturan riwayat bekerja pada string tanggal.

```bash
export MAKAN_APA_DATA_DIR=/tmp/makan-apa-demo   # data demo, bukan data asli
rm -rf "$MAKAN_APA_DATA_DIR"
makan-apa init
MAKAN_APA_TANGGAL=2026-10-18 makan-apa pilih
MAKAN_APA_TANGGAL=2026-10-19 makan-apa pilih
MAKAN_APA_TANGGAL=2026-10-20 makan-apa pilih
MAKAN_APA_TANGGAL=2026-10-20 makan-apa riwayat --hari 3
MAKAN_APA_TANGGAL=2026-10-20 makan-apa pilih --ulang --budget 20rb --ketat
MAKAN_APA_TANGGAL=2026-10-20 makan-apa riwayat --hari 1
```

Keluaran contoh (nama bisa berbeda tergantung sumber acak; yang tetap adalah jumlah kandidat
dan tidak adanya pengulangan):

```
$ MAKAN_APA_TANGGAL=2026-10-18 makan-apa pilih
Bakso Sapi Campur
  Rp14.000-24.000  [bakso,berkuah]
  Catatan: porsi jumbo
  Kandidat: 8 dari 8 (tersaring: budget 0, tag 0, riwayat 0)
  Tercatat di riwayat: 2026-10-18

$ MAKAN_APA_TANGGAL=2026-10-19 makan-apa pilih
Ayam Geprek Dada
  Rp13.000-22.000  [nasi,pedas]
  Catatan: sambal level 1-5
  Kandidat: 7 dari 8 (tersaring: budget 0, tag 0, riwayat 1)
  Tercatat di riwayat: 2026-10-19

$ MAKAN_APA_TANGGAL=2026-10-20 makan-apa pilih
Kopi Susu Gula Aren
  Rp10.000-18.000  [kopi,minuman]
  Catatan: bisa tanpa gula
  Kandidat: 6 dari 8 (tersaring: budget 0, tag 0, riwayat 2)
  Tercatat di riwayat: 2026-10-20

$ MAKAN_APA_TANGGAL=2026-10-20 makan-apa riwayat --hari 3
TANGGAL     NAMA
2026-10-20  Kopi Susu Gula Aren
2026-10-19  Ayam Geprek Dada
2026-10-18  Bakso Sapi Campur

$ MAKAN_APA_TANGGAL=2026-10-20 makan-apa pilih --ulang --budget 20rb --ketat
Nasi Uduk Komplit
  Rp12.000-20.000  [nasi]
  Catatan: telur balado
  Kandidat: 3 dari 8 (tersaring: budget 4, tag 0, riwayat 1)
  Mengganti pilihan 2026-10-20: Kopi Susu Gula Aren -> Nasi Uduk Komplit

$ MAKAN_APA_TANGGAL=2026-10-20 makan-apa riwayat --hari 1
TANGGAL     NAMA
2026-10-20  Nasi Uduk Komplit
```

Yang harus terlihat penonton dalam 2 menit: (a) tiga hari berturut-turut hasilnya tidak
pernah sama; (b) `riwayat` membuktikannya; (c) `--ketat` mempersempit kandidat dari 5 ke 3
pada hari yang sama; (d) `--ulang` mengganti baris hari ini, bukan menambah baris keempat.

## 2. Rancangan perintah (CLI)

### 2.1 Prinsip

- **stdout = data, stderr = meta.** `pilih` hanya menulis nama tempat ke stdout sehingga
  `$(makan-apa pilih)` bisa dipakai di skrip lain. Detail harga, tag, jumlah kandidat, dan
  status pencatatan masuk ke stderr. `daftar`/`riwayat` menulis tabel ke stdout, ringkasan
  jumlah ke stderr.
- **Opsi panjang, huruf kecil, dipisah tanda hubung.** Semua perintah memakai gaya yang
  sama: `--budget`, `--ketat`, `--tag`, `--hari`, `--harga`, `--catatan`, `--nama-baru`,
  `--paksa`, `--ganti`, `--tsv`, `--dry-run`, `--help`, `--version`. Singkatan hanya
  `-h` (= `--help`) dan `-V` (= `--version`).
- **Opsi global boleh di mana saja** (sebelum atau sesudah subperintah).
- **Nama tempat adalah satu argumen posisional**; pakai tanda kutip bila mengandung spasi:
  `makan-apa tambah "Nasi Goreng Spesial" ...`. Nama yang dimulai dengan `-` ditulis setelah
  `--`: `makan-apa tambah -- "-Nama Aneh"`.
- **Semua pesan berbahasa Indonesia**, diawali `makan-apa: ` bila itu galat, dan satu baris
  saran (`Coba 'makan-apa --help'.`) bila perlu.

### 2.2 Daftar perintah

|Perintah|Sintaks|Fungsi|
|---|---|---|
|`init`|`makan-apa init [--paksa]`|menyalin data contoh ke direktori data|
|`tambah`|`makan-apa tambah NAMA --harga MIN[-MAKS] [--tag T[,T]] [--catatan C]`|menambah tempat|
|`daftar`|`makan-apa daftar [--tag T] [--budget H] [--ketat] [--tsv]`|menampilkan daftar|
|`ubah`|`makan-apa ubah NAMA [--nama-baru X] [--harga ...] [--tag ...] [--catatan ...]`|mengubah tempat|
|`hapus`|`makan-apa hapus NAMA`|menghapus tempat|
|`pilih`|`makan-apa pilih [--budget H] [--ketat] [--tag T] [--hari N] [--dry-run] [--ulang]`|memilih satu tempat (utama)|
|`riwayat`|`makan-apa riwayat [--hari N] [--semua]`|menampilkan riwayat pilihan|
|`impor`|`makan-apa impor BERKAS [--ganti]`|mengimpor daftar dari berkas TSV|

### 2.3 `init`

Menyalin data contoh ke `$MAKAN_APA_DATA_DIR/tempat.tsv` (default
`~/.local/share/makan-apa/tempat.tsv`). Membuat direktori dengan mode 700 dan berkas 600.
Tidak menulis apa pun ke direktori home selain direktori data tersebut.

```bash
$ makan-apa init
Data contoh disalin ke /home/ani/.local/share/makan-apa/tempat.tsv (8 tempat).
Jalankan 'makan-apa pilih' untuk mencoba.
```

Bila data sudah ada:

```bash
$ makan-apa init
makan-apa: data sudah ada di /home/ani/.local/share/makan-apa/tempat.tsv.
Gunakan 'makan-apa init --paksa' untuk menimpa (data lama hilang).
$ echo $?
1
```

`--paksa` hanya menimpa `tempat.tsv`; `riwayat.tsv` dan konfigurasi tidak disentuh.

Sumber data contoh dicari berurutan: `$MAKAN_APA_CONTOH`, lalu
`<dir-skrip>/../share/makan-apa/contoh.tsv` (bentuk terpasang), lalu
`<dir-skrip>/../data/contoh.tsv` (bentuk repo), lalu `/usr/share/makan-apa/contoh.tsv`.
Tidak ditemukan → `makan-apa: data contoh tidak ditemukan. Paket rusak; pasang ulang.` keluar 3.

### 2.4 `tambah`

```bash
$ makan-apa tambah "Soto Betawi" --harga 18rb-28rb --tag soto,berkuah --catatan "porsi besar"
Ditambahkan: Soto Betawi (Rp18.000-28.000) [soto,berkuah]
```

Aturan:

- `--harga` wajib. Bentuk: `MIN`, `MIN-MAKS`, masing-masing menerima `25000`, `25rb`, `25k`,
  `25.000` (huruf besar/kecil sama). Bila hanya satu nilai, `harga_max = harga_min`.
- `harga_min > harga_max` → keluar 1:
  `makan-apa: harga_min (Rp30.000) lebih besar dari harga_max (Rp20.000). Periksa --harga.`
- `--tag` opsional, dipisah koma, tiap tag dihuruf-kecilkan, pola `[a-z0-9][a-z0-9_-]{0,19}`.
  Tag salah → `makan-apa: tag "Nasi Goreng" tidak valid. Gunakan huruf kecil, angka, '-' atau '_' (maks 20 karakter).`
- `--catatan` opsional, maks 200 karakter.
- Nama: 1–80 karakter, tidak boleh mengandung tab/baris baru, tidak boleh diawali `#`
  (akan terbaca sebagai komentar), spasi di awal/akhir dipangkas. Nama duplikat (persis,
  peka huruf besar-kecil) ditolak:
  `makan-apa: "Soto Betawi" sudah ada di daftar. Gunakan 'makan-apa ubah' untuk mengubahnya.`

### 2.5 `daftar`

```bash
$ makan-apa daftar
NAMA                 HARGA            TAG            CATATAN
Nasi Goreng Spesial  Rp15.000-25.000  nasi,cepat     porsi besar
Mie Ayam Pangsit     Rp12.000-20.000  mie            kuah kaldu ayam
Ayam Geprek Dada     Rp13.000-22.000  nasi,pedas     sambal level 1-5
Kopi Susu Gula Aren  Rp10.000-18.000  kopi,minuman   bisa tanpa gula
Sate Ayam 10 Tusuk   Rp20.000-30.000  sate,cepat     aroma bakar
Bakso Sapi Campur    Rp14.000-24.000  bakso,berkuah  porsi jumbo
Nasi Uduk Komplit    Rp12.000-20.000  nasi           telur balado
Es Teh Manis         Rp4.000-8.000    minuman        gelas besar
```

- Diurutkan menurut nama, `LC_ALL=C sort`.
- Lebar kolom: `nama = min(maks_len_nama + 2, 30)`, `harga = 17` (cukup untuk
  `Rp15.000-25.000`), `tag = min(maks_len_tag + 2, 18)`, sisanya `catatan`. Nilai yang
  lebih panjang dari lebarnya dipotong menjadi `lebar-3` karakter lalu ditambah `...`.
- Tag kosong ditampilkan `-`; catatan kosong ditampilkan `-`.
- Ringkasan ke stderr: `8 tempat.` atau `0 tempat (daftar kosong).`
- `--tag`, `--budget`, `--ketat` menyaring dengan aturan yang sama seperti `pilih` (bagian 4).
- `--tsv` mencetak TSV ternormalisasi tanpa header dan tanpa komentar, urut nama, untuk
  ekspor: `makan-apa daftar --tsv > daftar.tsv`.
- Daftar kosong: stdout kosong, stderr
  `Belum ada data. Jalankan 'makan-apa init' atau 'makan-apa tambah'.`, keluar 0.

### 2.6 `ubah`

```bash
$ makan-apa ubah "Soto Betawi" --harga 20rb-30rb --tag soto
Diubah: Soto Betawi (Rp20.000-30.000) [soto]
```

- Hanya kolom yang opsinya diberikan yang berubah. `--catatan ""` mengosongkan catatan,
  `--tag ""` mengosongkan tag.
- `--nama-baru` mengganti nama; nama baru tunduk pada aturan validasi dan tidak boleh
  bertabrakan dengan nama lain. `--nama-baru` yang sama dengan nama lama bukan galat
  (tidak ada yang berubah).
- Nama lama tidak ada → keluar 5:
  `makan-apa: tidak ada tempat bernama "Soto Betawi". Lihat 'makan-apa daftar'.`

### 2.7 `hapus`

```bash
$ makan-apa hapus "Soto Betawi"
Dihapus: Soto Betawi (Rp20.000-30.000) [soto]
```

Langsung menghapus tanpa konfirmasi (bisa dipakai di skrip); README memperingatkan hal ini.
Nama tidak ada → keluar 5 dengan pesan seperti `ubah`. Riwayat **tidak** diubah: nama yang
sudah dihapus tetap muncul di `riwayat`.

### 2.8 `pilih` (perintah utama)

```bash
$ makan-apa pilih --budget 20rb --tag nasi,mie
Nasi Uduk Komplit
  Rp12.000-20.000  [nasi]
  Catatan: telur balado
  Kandidat: 4 dari 8 (tersaring: budget 0, tag 4, riwayat 0)
  Tercatat di riwayat: 2026-10-20
```

Baris pertama adalah stdout (hanya nama). Empat baris berikutnya stderr.

Opsi:

|Opsi|Arti|
|---|---|
|`--budget H`|batas harga; format sama dengan `--harga` (satu nilai)|
|`--ketat`|bandingkan `harga_max <= budget`, bukan `harga_min <= budget`|
|`--tag T[,T]`|hanya tempat yang punya **salah satu** tag (OR); tag masukan dihuruf-kecilkan|
|`--hari N`|jendela riwayat dalam hari kalender, menimpa konfigurasi|
|`--dry-run`|tampilkan pilihan, jangan tulis riwayat|
|`--ulang`|ganti pilihan terakhir hari ini, jangan menambah baris|

`--dry-run`:

```bash
$ makan-apa pilih --budget 15rb --dry-run
Nasi Goreng Spesial
  Rp15.000-25.000  [nasi,cepat]
  Catatan: porsi besar
  Kandidat: 7 dari 8 (tersaring: budget 1, tag 0, riwayat 0)
  (dry-run: riwayat tidak diubah)
```

`--ulang` (rincian semantik di 4.6):

```bash
$ makan-apa pilih --ulang --budget 20rb
Nasi Uduk Komplit
  ...
  Mengganti pilihan 2026-10-20: Kopi Susu Gula Aren -> Nasi Uduk Komplit
```

Bila belum ada pilihan hari ini:

```bash
$ makan-apa pilih --ulang
Es Teh Manis
  ...
  Belum ada pilihan hari ini; --ulang mencatat pilihan baru.
```

`--dry-run` dan `--ulang` boleh digabung: hasilnya hanya ditampilkan, riwayat tidak diubah,
dan pesan menyebut bahwa baris hari ini **akan** diganti (`(dry-run: riwayat tidak diubah)`).

Semua kandidat tereliminasi → keluar 2 dengan diagnosis (bagian 4.4), tidak memilih apa pun.

### 2.9 `riwayat`

```bash
$ makan-apa riwayat --hari 7
TANGGAL     NAMA
2026-10-20  Nasi Uduk Komplit
2026-10-19  Ayam Geprek Dada
2026-10-18  Bakso Sapi Campur
```

- Urutan: tanggal menurun; untuk tanggal yang sama, urutan penulisan terbaru di atas.
- `--hari N` (default 14) menampilkan N hari kalender terakhir termasuk hari ini; `--hari 0`
  berarti hanya hari ini.
- `--semua` menampilkan seluruh riwayat. `--semua` dan `--hari` bersamaan → keluar 1:
  `makan-apa: opsi --semua dan --hari tidak bisa dipakai bersama.`
- Ringkasan ke stderr: `3 catatan (7 hari terakhir).`
- Riwayat kosong: stdout kosong, stderr `Belum ada riwayat.`, keluar 0.

### 2.10 `impor`

```bash
$ makan-apa impor daftar-teman.tsv
Diimpor 5 tempat, 2 dilewati karena namanya sudah ada.
```

- Berkas divalidasi **seluruhnya** lebih dulu; satu baris tidak valid → tidak ada yang
  ditulis, keluar 3, pesan menyebut sampai 5 nomor baris:
  `makan-apa: berkas impor tidak valid pada baris 3, 7. Tidak ada data yang diubah.`
- Duplikat terhadap daftar yang ada dilewati (bukan galat); duplikat di dalam berkas impor
  juga dilewati, yang pertama menang.
- `--ganti` mengganti seluruh daftar dengan isi berkas (tetap atomik: validasi dulu, baru tulis).
- Berkas tidak ada → keluar 3: `makan-apa: berkas "x.tsv" tidak ditemukan.`

### 2.11 `--help` dan `--version`

```bash
$ makan-apa --version
makan-apa 0.1.0
```

`makan-apa --help` mencetak teks berikut ke stdout, keluar 0:

```
makan-apa 0.1.0 - pemilih tempat makan dengan riwayat dan filter

Pemakaian:
  makan-apa <perintah> [opsi]

Perintah:
  init                 salin data contoh ke direktori data
  tambah NAMA          tambah tempat baru
  daftar               tampilkan daftar tempat
  ubah NAMA            ubah data tempat
  hapus NAMA           hapus tempat
  pilih                pilih satu tempat secara acak (utama)
  riwayat              tampilkan riwayat pilihan
  impor BERKAS         impor daftar dari berkas TSV

Opsi umum:
  -h, --help           tampilkan bantuan ini
  -V, --version        tampilkan versi

Opsi pilih:
  --budget HARGA       batas harga: 25000, 25rb, 25k, 25.000
  --ketat              bandingkan harga_max dengan budget
  --tag T[,T...]       hanya tempat dengan salah satu tag ini
  --hari N             jendela riwayat dalam hari (0 = abaikan riwayat)
  --dry-run            tampilkan pilihan tanpa mencatat ke riwayat
  --ulang              ganti pilihan terakhir hari ini

Opsi daftar:
  --budget HARGA, --ketat, --tag T[,T...], --tsv

Kode keluar: 0 sukses, 1 pemakaian, 2 tidak ada kandidat,
             3 data/IO, 4 data terkunci, 5 nama tidak ditemukan.

Contoh:
  makan-apa init
  makan-apa tambah "Nasi Goreng Spesial" --harga 15rb-25rb --tag nasi
  makan-apa pilih --budget 20rb --tag nasi,mie
  makan-apa riwayat --hari 7
```

`makan-apa <perintah> --help` mencetak sintaks dan opsi perintah itu, keluar 0.
`makan-apa --version` dan `-V` mencetak `makan-apa <versi>` (satu baris) dan keluar 0.
Tanpa argumen sama sekali (`makan-apa`) → teks bantuan yang sama dicetak ke **stderr**,
keluar 1.

### 2.12 Galat dan kode keluar

Format seragam: `makan-apa: <pesan>` ke stderr, lalu (bila relevan) satu baris
`Coba 'makan-apa --help'.`

|Kode|Arti|Contoh pemicu|
|---|---|---|
|0|sukses|perintah selesai|
|1|pemakaian/validasi|opsi tidak dikenal, harga tidak valid, nama duplikat, `init` tanpa `--paksa`|
|2|tidak ada kandidat|daftar kosong, semua tersaring|
|3|data/IO|berkas tidak terbaca, semua baris rusak, gagal tulis, impor tidak valid, data contoh hilang|
|4|data terkunci|`flock` gagal dalam 2 detik|
|5|nama tidak ditemukan|`hapus`/`ubah` dengan nama yang tidak ada|

Contoh pesan:

```
makan-apa: perintah "pili" tidak dikenal.
Coba 'makan-apa --help'.
```
```
makan-apa: opsi "--budget" membutuhkan nilai.
Coba 'makan-apa --help'.
```
```
makan-apa: harga "25ribu" tidak dikenali. Gunakan 25000, 25rb, atau 25k.
```

### 2.13 Filter jarak/area: tidak dipakai

Filter jarak/area **tidak** dimasukkan ke versi 0.1.0. Alasannya: (a) alat ini bekerja
offline dan tidak punya sumber koordinat atau peta, jadi "jarak" hanya bisa diisi manual
sebagai tebakan; (b) menambah kolom area mengubah format data yang sudah ditetapkan lima
kolom, menaikkan beban pengisian, dan membuat impor/berbagi lebih rapuh; (c) kebutuhan
nyatanya tertutup oleh tag (mis. `--tag kampus` atau `--tag dekat`) tanpa janji akurasi.
Kalau nanti dibutuhkan, jalur termurah adalah tag, bukan kolom baru.

## 3. Format data dan penyimpanan

### 3.1 Lokasi (XDG)

|Berkas|Lokasi default|Isi|
|---|---|---|
|daftar tempat|`${XDG_DATA_HOME:-$HOME/.local/share}/makan-apa/tempat.tsv`|5 kolom TSV|
|riwayat|`${XDG_DATA_HOME:-$HOME/.local/share}/makan-apa/riwayat.tsv`|tanggal + nama|
|kunci|`${XDG_DATA_HOME:-$HOME/.local/share}/makan-apa/.kunci`|berkas kosong untuk `flock`|
|konfigurasi|`${XDG_CONFIG_HOME:-$HOME/.config}/makan-apa/config`|`kunci=nilai`|

Tidak ada yang ditulis ke `/usr` saat runtime, dan tidak ada yang ditulis ke home saat
pemasangan paket (tidak ada `postinst` yang menyentuh home).

Direktori data dibuat saat perintah tulis pertama (`init`, `tambah`, `impor`) dengan mode
700; berkas 600. `umask 077` dipasang di awal skrip.

### 3.2 `tempat.tsv`

```
# komentar, diawali '#'
# nama<TAB>harga_min<TAB>harga_max<TAB>tag<TAB>catatan
Nasi Goreng Spesial	15000	25000	nasi,cepat	porsi besar
Mie Ayam Pangsit	12000	20000	mie	kuah kaldu ayam
```

Aturan baca:

- Baris kosong dan baris yang diawali `#` (setelah spasi awal dipangkas) dilewati.
- Tepat 5 kolom dipisah TAB. Jumlah kolom lain → baris rusak.
- Akhiran `\r` (berkas yang pernah diedit di Windows) dibuang sebelum parsing.
- Spasi di awal/akhir tiap kolom dipangkas.
- `harga_min`/`harga_max` harus bilangan bulat 0–100000000 dan `min <= max`; selain itu rusak.
- Baris rusak **dilewati** dengan peringatan ke stderr:
  `makan-apa: peringatan: baris 7 rusak (4 kolom, seharusnya 5) - dilewati.`
- Bila tidak ada satu pun baris valid tetapi ada baris rusak → keluar 3:
  `makan-apa: data tempat rusak: tidak ada baris valid di <path>.`
- Nama dan tag dinormalisasi (pangkas spasi); isi lain dipakai apa adanya.
- Nama tidak harus unik saat dibaca (berkas diedit manual); `tambah` mencegah duplikat baru.

Isi `data/contoh.tsv` yang dikirim paket (nilai mentah; kolom dipisah satu TAB, tanpa
pemangkasan):

|nama|harga_min|harga_max|tag|catatan|
|---|---|---|---|---|
|Nasi Goreng Spesial|15000|25000|nasi,cepat|porsi besar|
|Mie Ayam Pangsit|12000|20000|mie|kuah kaldu ayam|
|Ayam Geprek Dada|13000|22000|nasi,pedas|sambal level 1-5|
|Kopi Susu Gula Aren|10000|18000|kopi,minuman|bisa tanpa gula|
|Sate Ayam 10 Tusuk|20000|30000|sate,cepat|aroma bakar|
|Bakso Sapi Campur|14000|24000|bakso,berkuah|porsi jumbo|
|Nasi Uduk Komplit|12000|20000|nasi|telur balado|
|Es Teh Manis|4000|8000|minuman|gelas besar|

Dua baris komentar di awal berkas:

```
# data contoh makan-apa - silakan diedit
# nama<TAB>harga_min<TAB>harga_max<TAB>tag<TAB>catatan
```

### 3.3 `riwayat.tsv`

```
# tanggal<TAB>nama
2026-10-20	Nasi Uduk Komplit
2026-10-19	Ayam Geprek Dada
```

- `tanggal` = `YYYY-MM-DD` pada zona `Asia/Jakarta`.
- `nama` boleh merujuk tempat yang sudah dihapus dari daftar; riwayat tidak ikut dihapus.
- Baris rusak/tanggal tidak valid: dilewati dengan peringatan, **tidak** dihapus otomatis.
- Tanggal di masa depan: dilewati dengan peringatan
  `makan-apa: peringatan: 1 baris riwayat bertanggal masa depan diabaikan.`
- Saat menulis riwayat, entri valid yang lebih tua dari 90 hari dipangkas (riwayat tetap
  kecil; tidak ada opsi untuk mengubah ini di 0.1.0).

### 3.4 Konfigurasi

```
# ~/.config/makan-apa/config
riwayat_hari=3
```

- Format `kunci=nilai`, `#` untuk komentar, spasi di sekitar `=` dipangkas.
- Kunci yang dikenal: `riwayat_hari` (bilangan bulat 0–365). Kunci lain →
  `makan-apa: peringatan: kunci konfigurasi "x" tidak dikenal.`
- Nilai tidak valid → keluar 3:
  `makan-apa: nilai "abc" untuk riwayat_hari tidak valid (0-365).`
- Berkas tidak ada = nilai default (`riwayat_hari=3`), bukan galat.

### 3.5 Kunci dan tulis atomik

- Semua perintah memakai `flock` pada `$DIR/.kunci`: tulis memakai kunci eksklusif, baca
  memakai kunci bersama; batas tunggu 2 detik (`flock -w 2`).
- Gagal mendapat kunci → keluar 4:
  `makan-apa: data sedang dipakai proses lain. Coba lagi sebentar.`
- Penulisan: tulis ke `$DIR/.tmp.$$` di direktori yang sama, `fsync` tidak diperlukan,
  lalu `mv -f` menimpa berkas asli (atomik pada filesystem yang sama). `trap` menghapus
  berkas sementara saat keluar.
- Tidak ada penulisan di tempat (in-place) pada `tempat.tsv` atau `riwayat.tsv`.

### 3.6 Mencadangkan dan membagikan

```bash
# cadangan
cp ~/.local/share/makan-apa/tempat.tsv ~/cadangan-makan-apa-2026-10-20.tsv

# berbagi: ekspor lalu kirim berkasnya
makan-apa daftar --tsv > daftar-makan.tsv

# di komputer teman
makan-apa impor daftar-makan.tsv          # menambah, duplikat dilewati
makan-apa impor daftar-makan.tsv --ganti  # mengganti seluruh daftar
```

Riwayat tidak ikut diekspor (sengaja: riwayat adalah keputusan pribadi). Berkas cadangan
bisa dikembalikan dengan `makan-apa impor --ganti`.

## 4. Aturan pemilihan (inti)

### 4.1 Urutan penyaringan

Kandidat dihitung dengan urutan tetap: **budget → tag → riwayat**. Statistik yang
ditampilkan mengikuti urutan ini, sehingga `budget + tag + riwayat + kandidat = total`.
Urutan ini dipilih agar diagnosis mudah dibaca (budget adalah filter yang paling sering
dilonggarkan). Hitungan `riwayat` adalah jumlah **tempat unik** yang diblokir, bukan jumlah
baris riwayat, sehingga menjumlah tetap konsisten meskipun satu tempat tercatat dua kali.

### 4.2 Budget

- Default: lolos bila `harga_min <= budget`.
- `--ketat`: lolos bila `harga_max <= budget`.
- Perbandingan inklusif di batas: `harga_min == budget` lolos; `harga_min == budget + 1`
  tidak lolos.
- Format harga yang diterima: `25000`, `25rb`, `25k`, `25.000`, juga `25RB`/`25K`.
  Nilai = angka tanpa titik, dikali 1000 bila berakhiran `rb`/`k`. Batas 0–100000000.
- `--budget` tanpa nilai → keluar 1 (`opsi "--budget" membutuhkan nilai`).
- `--budget` hanya menerima **satu** nilai; `--budget 25rb-30rb` → keluar 1:
  `makan-apa: --budget hanya menerima satu nilai.`
- `--ketat` tanpa `--budget` → keluar 1: `makan-apa: --ketat membutuhkan --budget.`
  (berlaku untuk `pilih` dan `daftar`).

### 4.3 Riwayat: jendela N hari

`N` = `--hari` bila diberikan, selain itu `riwayat_hari` dari konfigurasi, selain itu 3.

Tempat diblokir bila ada catatan riwayat dengan tanggal `D` yang memenuhi
`hari_ini - (N-1) hari <= D <= hari_ini`. Dengan kata lain, N=3 berarti **hari ini,
kemarin, dan kemarin lusa**; catatan yang berumur tepat 3 hari sudah tidak memblokir.

|Tanggal catatan|N=3 (hari ini 2026-10-20)|Diblokir?|
|---|---|---|
|2026-10-20|hari ini|ya|
|2026-10-19|1 hari lalu|ya|
|2026-10-18|2 hari lalu|ya|
|2026-10-17|3 hari lalu|tidak|
|2026-10-21|masa depan|diabaikan + peringatan|

- `N=0` menonaktifkan penyaringan riwayat.
- Perbandingan memakai string `YYYY-MM-DD` (leksikografis = kronologis), sehingga tidak ada
  aritmetika jam. "Hari ini" dihitung sekali di awal perintah dengan
  `TZ=Asia/Jakarta date +%F`, jadi pergantian hari di tengah eksekusi tidak mungkin terjadi.
- `N` di luar 0–365 → keluar 1:
  `makan-apa: --hari harus bilangan bulat 0-365.`

### 4.4 Semua kandidat tereliminasi

Jangan diam, jangan galat samar, jangan otomatis melonggarkan. Cetak diagnosis ke stderr
dan keluar 2.

Contoh A — budget terlalu rendah (data contoh yang baru di-`init`):

```
$ makan-apa pilih --budget 3rb
Tidak ada tempat yang lolos filter.
  total tempat      : 8
  gagal budget      : 8  (harga_min > Rp3.000)
  gagal tag         : 0
  diblokir riwayat  : 0  (dipilih dalam 3 hari terakhir)
Saran: naikkan --budget (mis. --budget 4rb).
```

Contoh B — tag + riwayat menghabiskan kandidat (keempat tempat bertag nasi sudah dipilih
dalam 3 hari terakhir):

```
$ makan-apa pilih --tag nasi
Tidak ada tempat yang lolos filter.
  total tempat      : 8
  gagal budget      : 0
  gagal tag         : 4  (tidak punya tag: nasi)
  diblokir riwayat  : 4  (dipilih dalam 3 hari terakhir)
Saran: longgarkan --tag, --hari 0 untuk mengabaikan riwayat.
```

Aturan:

- Angka pada baris `total` dan tiga baris penyaring harus berjumlah konsisten
  (`total = gagal budget + gagal tag + diblokir riwayat + kandidat`), karena penyaringan
  berurutan (4.1).
- Teks dalam tanda kurung menyesuaikan: `harga_max > RpX` bila `--ketat`, selain itu
  `harga_min > RpX`; `(tidak punya tag: nasi,mie)` untuk tag yang diminta; `N hari terakhir`
  sesuai N; `(riwayat diabaikan)` bila N=0.
- Baris `Saran:` disusun berurutan, maksimal tiga butir, hanya untuk penyaring yang
  benar-benar menggugurkan tempat:
  1. budget: `naikkan --budget (mis. --budget <X>)`, dengan `X` = `harga_min` terkecil
     di antara tempat yang gagal budget **dan** lolos filter tag; bila himpunan itu kosong,
     tulis `naikkan --budget` tanpa contoh angka. `X` ditulis `4rb` bila habis dibagi 1000,
     selain itu angka polos (`12500`).
  2. tag: `longgarkan --tag`.
  3. riwayat: `--hari 0` untuk mengabaikan riwayat.
  Butir digabung dengan `, ` dan diakhiri titik. Contoh A hanya memuat butir 1; contoh B
  memuat butir 2 dan 3 karena tag dan riwayat sama-sama menggugurkan tempat, sedangkan
  menaikkan budget tidak akan menolong.
- Bila daftar kosong (tidak ada baris valid sama sekali): pesan berbeda, keluar 2:
  ```
  Daftar tempat masih kosong.
  Jalankan 'makan-apa init' untuk data contoh atau 'makan-apa tambah NAMA --harga ...'.
  ```
- Bila hanya satu tempat yang lolos, tempat itu tetap dipilih; larangan riwayat tidak
  dilanggar diam-diam. Daftar satu tempat yang sudah dipilih hari ini menghasilkan diagnosis
  `diblokir riwayat  : 1` dan saran `--hari 0`, bukan pilihan diam-diam.

### 4.5 Kasus tepi yang wajib benar

|Kasus|Perilaku|
|---|---|
|daftar kosong / berkas belum ada|keluar 2, pesan "Daftar tempat masih kosong", tanpa diagnosis angka|
|satu tempat, belum pernah dipilih|dipilih, dicatat|
|satu tempat, sudah dipilih hari ini|keluar 2, diagnosis `diblokir riwayat: 1`, saran `--hari 0`|
|semua diblokir riwayat|keluar 2, saran `--hari 0`|
|semua gagal budget|keluar 2, saran `--budget` dengan `harga_min` terkecil yang gagal|
|tanggal berubah tengah malam|pilihan 23:59 tercatat di tanggal itu; `--ulang` setelah 00:00 menambah baris baru (lihat 4.6)|
|`--ulang` tanpa pilihan hari ini|mencatat seperti `pilih` biasa + info di stderr|
|`--ulang` saat tidak ada kandidat tersisa (mis. hanya satu tempat dan sudah dipilih hari ini)|keluar 2, diagnosis seperti biasa + saran `--hari 0`|

### 4.6 `--ulang`: mengganti, bukan menambah

Definisi: `--ulang` memakai filter yang sama seperti `pilih` (termasuk jendela riwayat,
sehingga pilihan hari ini otomatis tidak muncul lagi), lalu:

- Bila baris **terakhir** `riwayat.tsv` bertanggal hari ini: ganti nama pada baris itu.
  Jumlah baris tidak bertambah.
- Bila tidak: tambah baris baru, dan beri tahu pengguna bahwa ini pilihan baru.

Contoh pergantian hari:

```
23:59  pilih                -> menulis "2026-10-20  Kopi Susu Gula Aren"
00:01  pilih --ulang        -> baris terakhir bukan hari ini (2026-10-21),
                               jadi menambah "2026-10-21  <nama lain>"
```

Ini disengaja: keputusan tanggal 20 tetap tercatat sebagai keputusan tanggal 20, dan
tempat itu masih diblokir karena masuk jendela 3 hari. Bila pengguna benar-benar memilih
dua kali dalam satu hari (makan siang dan malam), panggil `pilih` biasa untuk yang kedua;
hanya `--ulang` yang mengganti.

### 4.7 Keacakan

Sumber: **4 byte dari `/dev/urandom`**, diubah menjadi indeks oleh LCG Park–Miller di awk.

```bash
if [ -n "${MAKAN_APA_SEED:-}" ]; then
  seed=$MAKAN_APA_SEED
else
  seed=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
fi
idx=$(awk -v n="$jumlah" -v s="$seed" 'BEGIN {
  s = s % 2147483647
  if (s <= 0) s = 1
  s = (s * 16807) % 2147483647
  printf "%d", s % n
}')
```

Alasan:

- `$RANDOM` hanya 15 bit (0–32767) dan di-reseed per subshell; cukup untuk dadu, tetapi
  tidak perlu dipaksakan ketika `/dev/urandom` tersedia di semua sistem Linux.
- `shuf` benar secara statistik, tetapi `--random-source` mengharuskan berkas entropi dan
  perilakunya berbeda antarversi coreutils; membuat seed deterministik jadi tidak jelas.
- LCG di atas memakai aritmetika bilangan bulat < 2^53, jadi hasilnya **sama** di mawk
  (default Ubuntu) dan gawk. Modulo dari ruang 2^31 terhadap n kecil (n ≤ ratusan)
  biasnya tidak terasa.
- `MAKAN_APA_SEED` (bilangan bulat 0–2147483646) membuat pemilihan deterministik untuk tes:
  seed sama + daftar kandidat sama + urutan sama → indeks sama. Tes tidak boleh
  mengandalkan nama tertentu; tes memakai daftar satu baris bila butuh kandidat pasti.
- Nilai lingkungan yang tidak valid ditolak dengan keluar 1:
  `makan-apa: MAKAN_APA_SEED harus bilangan bulat 0-2147483646.` dan
  `makan-apa: MAKAN_APA_TANGGAL harus berformat YYYY-MM-DD dan tanggalnya valid.`
  `MAKAN_APA_TANGGAL` divalidasi dengan `date -d "$nilai" +%F` dan hasilnya harus sama
  dengan nilai yang diberikan (menolak `2026-02-30`).

### 4.8 Algoritma `pilih` (urutan operasi)

```
1. parse opsi; validasi --budget, --hari, --tag, MAKAN_APA_TANGGAL, MAKAN_APA_SEED
2. muat konfigurasi (riwayat_hari)
3. ambil kunci (bersama untuk --dry-run, eksklusif untuk yang menulis)
4. baca tempat.tsv -> baris valid + peringatan baris rusak
5. hitung hari_ini; hitung batas = hari_ini - (N-1) hari
6. saring: budget -> tag -> riwayat; catat statistik
7. bila 0 kandidat: cetak diagnosis, keluar 2
8. pilih indeks dengan seed
9. bila --dry-run: cetak hasil + "(dry-run: riwayat tidak diubah)", keluar 0
10. tulis riwayat (ganti baris terakhir bila --ulang dan tanggalnya hari ini, selain itu tambah;
    pangkas entri > 90 hari) secara atomik
11. cetak nama ke stdout; detail + statistik + status ke stderr; keluar 0
```

Bila langkah 10 gagal (disk penuh, izin), jangan mencetak nama ke stdout; keluar 3 dengan
pesan `makan-apa: gagal menulis riwayat: <alasan>.`

## 5. Rancangan skrip

- **Bahasa:** Bash, minimum 4.2 (`mapfile`, array, `[[ ]]`). Ubuntu 22.04 (bash 5.1) dan
  24.04 (bash 5.2) memenuhi. Versi dicek di awal; bila kurang:
  `makan-apa: butuh bash >= 4.2.` keluar 3.
- **Ketergantungan:** hanya alat standar Ubuntu — `bash`, `coreutils` (`date`, `sort`,
  `mv`, `od`, `tr`, `wc`), `grep`, `sed`, `awk` (mawk), `flock` (util-linux), `tzdata`.
  Tidak ada Python, jq, curl, atau pustaka pihak ketiga.
- **Satu berkas:** seluruh logika di `bin/makan-apa` (± 550 baris), dipasang sebagai
  `/usr/bin/makan-apa`. Tidak dipecah ke `/usr/lib/makan-apa` karena tidak ada kode yang
  dipakai bersama dan berkas tunggal lebih mudah diuji serta dipasang. Berkas pendukung
  (man, completion, data contoh) tetap terpisah di `/usr/share`.
- **Mode ketat:** `set -euo pipefail`; `IFS=$'\n\t'`; `LC_ALL=C` diekspor agar `sort` dan
  `awk` deterministik (konsekuensi: nama non-ASCII bisa membuat kolom bergeser; dicatat di
  README).
- **Penanganan galat:** fungsi `die PESAN KODE` mencetak `makan-apa: PESAN` ke stderr lalu
  `exit KODE`; `trap 'rm -f "$TMP"' EXIT` membersihkan berkas sementara; setiap perintah
  luar yang boleh gagal dibungkus `|| die ...` agar `set -e` tidak mematikan skrip dengan
  pesan Bash mentah.

Struktur fungsi (nama dan tanggung jawab mengikat):

|Fungsi|Tanggung jawab|
|---|---|
|`main`|dispatch subperintah, parse opsi global|
|`usage` / `usage_perintah`|teks `--help` (2.11)|
|`die PESAN KODE`|cetak galat + keluar|
|`muat_config`|baca `config`, set `RIWAYAT_HARI`|
|`hari_ini`|`TZ=Asia/Jakarta date +%F`, atau `MAKAN_APA_TANGGAL`|
|`tanggal_minus N`|`date -d "$hari - N days" +%F`|
|`parse_harga STR`|validasi + normalisasi harga → integer|
|`format_harga MIN MAKS`|`Rp15.000-25.000` / `Rp20.000`|
|`ambil_kunci MODE`|`flock` eksklusif/bersama, keluar 4 bila gagal|
|`baca_tempat`|validasi TSV → stdout, peringatan → stderr|
|`baca_riwayat`|validasi riwayat → stdout, peringatan → stderr|
|`saring`|terapkan budget/tag/riwayat, isi variabel statistik|
|`pilih_indeks N`|LCG (4.7) → 0..N-1|
|`tulis_tempat` / `tulis_riwayat`|tulis atomik + pangkas riwayat|
|`cetak_diagnosa`|diagnosis 4.4|
|`cmd_init`, `cmd_tambah`, `cmd_daftar`, `cmd_ubah`, `cmd_hapus`, `cmd_pilih`, `cmd_riwayat`, `cmd_impor`|satu per subperintah|

Variabel lingkungan:

|Variabel|Default|Kegunaan|
|---|---|---|
|`MAKAN_APA_DATA_DIR`|`${XDG_DATA_HOME:-$HOME/.local/share}/makan-apa`|direktori data (tes memakai tmpdir)|
|`MAKAN_APA_CONFIG_DIR`|`${XDG_CONFIG_HOME:-$HOME/.config}/makan-apa`|direktori konfigurasi|
|`MAKAN_APA_TANGGAL`|tidak diset (pakai tanggal sistem)|memalsukan "hari ini" (tes/demo); divalidasi `YYYY-MM-DD`|
|`MAKAN_APA_SEED`|`/dev/urandom`|seed acak deterministik (tes)|
|`MAKAN_APA_CONTOH`|dicari otomatis|lokasi `contoh.tsv`|

Pengujian tidak menyentuh data asli: setiap tes mengekspor `MAKAN_APA_DATA_DIR` dan
`MAKAN_APA_CONFIG_DIR` ke direktori sementara milik tes.

## 6. Strategi tes

Kerangka: **bats-core** (`bats`), dijalankan dengan `bats tests/*.bats`. Pemasangan:
`sudo apt install bats shellcheck`. Bila paket `bats` tidak tersedia di image yang dipakai,
fallback yang sudah diputuskan: `git submodule add https://github.com/bats-core/bats-core
tests/vendor/bats` dan jalankan `tests/vendor/bats/bin/bats`. Jangan memakai fitur bats
yang hanya ada di versi baru (`bats_require_minimum_version`, `run -N`); cukup `run`,
`$status`, `$output`, `$lines`.

`tests/helper.bash` (dimiliki Orang B) menyiapkan:

```bash
export MAKAN_APA_DATA_DIR="$BATS_TEST_TMPDIR/data"
export MAKAN_APA_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
export MAKAN_APA_TANGGAL=2026-10-20
export MAKAN_APA_SEED=42
export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
```

`run` pada bats 1.x menggabungkan stdout dan stderr ke `$output`, dan `--separate-stderr`
tidak ada di bats 1.2 (Ubuntu 22.04). Karena itu pisahkan sendiri:

```bash
# menguji stdout saja
run bash -c 'makan-apa pilih --budget 20rb 2>/dev/null'
# menguji stderr saja
run bash -c 'makan-apa pilih --budget 20rb 2>&1 >/dev/null'
```

Jangan memakai `$stderr`; jangan mengandalkan urutan baris gabungan.

`make check` menjalankan, berurutan:

```bash
shellcheck --severity=style -x bin/makan-apa tests/helper.bash
bats tests/*.bats
```

`shellcheck` harus **nol temuan** (semua level sampai `style`). Bila sebuah peringatan
tidak bisa dihindari, tambahkan komentar `# shellcheck disable=SCxxxx` **dengan alasan**
di baris yang sama; tanpa alasan tidak diterima saat review.

Kasus uji wajib (nama tes = kalimat yang menyebut perilaku):

|Berkas|Kasus|Masukan → hasil yang diharapkan|
|---|---|---|
|`tests/cli.bats`|`--help` keluar 0 dan memuat semua perintah|`makan-apa --help` → status 0, `output` memuat `pilih` dan `impor`|
||`--version` format benar|`makan-apa --version` → `makan-apa 0.1.0`, status 0|
||perintah tidak dikenal|`makan-apa pili` → status 1, stderr memuat `tidak dikenal`|
||opsi tanpa nilai|`makan-apa pilih --budget` → status 1, `membutuhkan nilai`|
|`tests/tambah.bats`|tambah valid|`tambah "Nasi Goreng Spesial" --harga 15rb-25rb --tag nasi` → status 0, `daftar --tsv` memuat 5 kolom|
||tiga format harga setara|`25000`, `25rb`, `25k` → `harga_min` sama (`25000`)|
||`25.000` diterima|→ `25000`|
||min > maks ditolak|`--harga 30rb-20rb` → status 1|
||nama duplikat ditolak|tambah dua kali nama sama → status 1|
||nama dengan spasi|nama `Nasi Goreng Spesial` tersimpan utuh dan bisa dihapus dengan nama yang sama|
||tab/baris baru ditolak|`tambah $'A\tB'` → status 1|
||nama diawali `#` ditolak|`tambah "#1"` → status 1|
|`tests/daftar.bats`|tabel terurut dan berisi 8 baris|`init` lalu `daftar` → 8 baris data, header `NAMA`|
||`--tsv` tanpa header|→ 8 baris, tiap baris 5 kolom|
||filter tag OR|`--tag nasi,mie` → hanya baris bertag nasi atau mie|
||daftar kosong|tanpa data → status 0, stderr `Belum ada data`|
|`tests/pilih.bats`|budget batas inklusif|daftar {A min=20000, B min=20001}; `--budget 20000` → hanya A|
||`--ketat` batas inklusif|daftar {A maks=30000, B maks=30001}; `--ketat --budget 30000` → hanya A|
||`--ketat` lebih sempit dari default|data contoh; `--budget 20rb` → 8 kandidat, `--ketat` → 4|
||filter tag|`--tag kopi` → hanya Kopi Susu Gula Aren|
||stdout hanya nama|`run bash -c 'makan-apa pilih 2>/dev/null'` → `$output` satu baris nama, tanpa harga|
||`--dry-run` tidak menulis riwayat|`cmp` riwayat sebelum/sesudah → identik, status 0|
||seed deterministik|`MAKAN_APA_SEED=42` dua kali → nama sama|
||semua tereliminasi|`--budget 5rb --tag nasi` → status 2, stderr memuat `gagal budget      : 7` dan `Saran:`|
||daftar kosong|tanpa data → status 2, `Daftar tempat masih kosong`|
||satu tempat sudah dipilih hari ini|status 2, `diblokir riwayat  : 1`|
||hanya satu kandidat|daftar 1 baris → terpilih, status 0|
|`tests/riwayat.bats`|batas jendela N=3 (diblokir)|daftar {A,B}, riwayat A=2026-10-18, `--dry-run` → stderr `Kandidat: 1 dari 2`|
||batas jendela N=3 (lewat batas)|riwayat A=2026-10-17, `--dry-run` → stderr `Kandidat: 2 dari 2`|
||N=0 mengabaikan riwayat|daftar {A,B}, A dipilih hari ini, `--hari 0 --dry-run` → `Kandidat: 2 dari 2`|
||`--hari` menimpa konfigurasi|config `riwayat_hari=10`, A=2026-10-18, `--hari 0` → `Kandidat: 2 dari 2`|
||konfigurasi dipakai|config `riwayat_hari=10`, A=2026-10-11, tanpa `--hari` → `Kandidat: 1 dari 2`|
||konfigurasi pendek|config `riwayat_hari=1`, A=kemarin → `Kandidat: 2 dari 2`|
||tengah malam|`MAKAN_APA_TANGGAL=2026-10-20 pilih` lalu `=2026-10-21 pilih --ulang` → 2 baris, tanggal berbeda|
||`--ulang` mengganti|pilih lalu `--ulang` → jumlah baris tetap 1, nama berubah|
||`--ulang` tanpa pilihan hari ini|→ menambah 1 baris + stderr `Belum ada pilihan hari ini`|
||riwayat berisi nama yang sudah dihapus|`hapus` tempat → `riwayat` tetap menampilkan nama itu|
||pangkas 90 hari|catatan 91 hari lalu hilang setelah `pilih` berikutnya|
|`tests/data.bats`|baris rusak dilewati|baris 4 kolom → status 0, stderr `baris 4 rusak`, baris valid tetap ada|
||semua baris rusak|status 3, `tidak ada baris valid`|
||CRLF|berkas dengan `\r\n` → nama tanpa `\r`|
||komentar dan baris kosong|diabaikan|
||berkas tidak ada untuk `daftar`|status 0, pesan `Belum ada data`|
||kunci sibuk|`flock -x .kunci -c 'sleep 3'` di latar → `pilih` status 4|
||tulis atomik|tidak ada berkas `.tmp.*` tersisa setelah perintah sukses/gagal|
|`tests/impor.bats`|impor menambah|5 baris baru → `Diimpor 5`|
||duplikat dilewati|impor berkas yang sama dua kali → `Diimpor 0, 5 dilewati`|
||`--ganti` mengganti|daftar lama 8 → menjadi 5|
||baris tidak valid membatalkan seluruh impor|`cmp` berkas sebelum/sesudah identik, status 3|

Aturan proses: **setiap tahap yang menambah perilaku menambah tesnya di branch tahap itu**.
PR tahap tidak boleh merge bila tes baru belum ada atau `make check` belum hijau.

## 7. Pengemasan `.deb`

### 7.1 Tata letak repo dan paket

```
repo/
├── PLAN.md
├── README.md
├── CHANGELOG.md
├── LICENSE
├── Makefile
├── .gitignore
├── bin/makan-apa
├── man/makan-apa.1
├── completions/makan-apa
├── data/contoh.tsv
├── debian/control
├── debian/changelog
├── debian/copyright
├── tests/helper.bash
├── tests/*.bats
├── tests/pasang-bersih.sh
├── build/            (dibuat saat build, tidak di-commit)
└── dist/             (hasil .deb, tidak di-commit)
```

Isi paket (`Architecture: all`):

```
/usr/bin/makan-apa                                   0755
/usr/share/man/man1/makan-apa.1.gz                   0644
/usr/share/bash-completion/completions/makan-apa     0644
/usr/share/makan-apa/contoh.tsv                      0644
/usr/share/doc/makan-apa/copyright                   0644
/usr/share/doc/makan-apa/changelog.gz                0644
```

Tidak ada `DEBIAN/postinst`, `preinst`, `postrm`, atau `prerm`: paket tidak menulis apa pun
ke direktori home, tidak membuat pengguna, dan tidak menjalankan layanan. Data pengguna
dibuat hanya oleh `makan-apa init`. Setelah terpasang, pemakaian **tidak butuh root**;
hanya pemasangan/penghapusan paket yang memakai `sudo`.

### 7.2 `DEBIAN/control`

```
Package: makan-apa
Version: 0.1.0
Architecture: all
Maintainer: Tim MakanApa <tim.makanapa@example.com>
Installed-Size: 84
Depends: tzdata
Section: utils
Priority: optional
Description: pemilih tempat makan acak dengan riwayat dan filter
 Mengingat tempat makan, memilih satu secara acak dengan filter
 budget dan tag, serta menghindari tempat yang sudah dipilih dalam
 beberapa hari terakhir.
 .
 Data disimpan sebagai berkas TSV di direktori XDG pengguna. Tidak
 ada yang ditulis ke direktori home saat pemasangan.
```

- `Installed-Size` diisi otomatis oleh Makefile: `du -sk "$PKGDIR" | cut -f1`. Nilai `84`
  di atas hanya contoh; Makefile menimpanya sebelum `dpkg-deb`.
- `Depends: tzdata` adalah satu-satunya dependensi eksplisit; `bash`, `coreutils`, `grep`,
  `sed`, `awk`, dan `flock` sudah ada di instalasi Ubuntu dasar. Jangan menambah
  `Depends` untuk paket yang tidak benar-benar dipakai.
- Deskripsi mengikuti format Debian: baris pertama sinopsis tanpa huruf kapital di awal,
  baris lanjutan menjorok satu spasi, baris kosong diganti ` .`.

### 7.3 Membangun dengan satu perintah

`make deb` melakukan, berurutan:

1. `make check` (shellcheck + bats).
2. Membuat `build/makan-apa_$(VERSION)_all/DEBIAN/` dan menyalin `control`.
3. `install -Dm755 bin/makan-apa build/.../usr/bin/makan-apa`
4. `install -Dm644 man/makan-apa.1 build/.../usr/share/man/man1/makan-apa.1` lalu
   `gzip -9n` di tempat.
5. `install -Dm644 completions/makan-apa build/.../usr/share/bash-completion/completions/makan-apa`
6. `install -Dm644 data/contoh.tsv build/.../usr/share/makan-apa/contoh.tsv`
7. `install -Dm644 debian/copyright build/.../usr/share/doc/makan-apa/copyright`;
   `debian/changelog` → `changelog.gz` dengan `gzip -9n`.
8. Mengisi `Installed-Size`.
9. `dpkg-deb --build --root-owner-group "build/makan-apa_$(VERSION)_all" "dist/makan-apa_$(VERSION)_all.deb"`
10. `lintian "dist/makan-apa_$(VERSION)_all.deb"` dan mencetak hasilnya (target `make lint`
    terpisah; `make deb` tidak gagal karena lintian, tapi PR wajib menyertakan hasilnya).

Target Makefile:

|Target|Fungsi|
|---|---|
|`make check`|shellcheck + bats|
|`make man`|`@! groff -man -Tutf8 -ww -z man/makan-apa.1 2>&1 >/dev/null \|grep -q .` (gagal bila groff mengeluarkan peringatan apa pun)|
|`make deb`|paket `.deb` (bergantung pada `check`)|
|`make lint`|`lintian dist/*.deb`|
|`make uji-pasang`|`tests/pasang-bersih.sh` (Docker)|
|`make versi`|memastikan versi di skrip, Makefile, `debian/control`, dan `debian/changelog` sama|
|`make bersih`|`rm -rf build dist`|

Prasyarat di mesin pengembang: `sudo apt install lintian bats shellcheck man-db groff-base`.
`dpkg-deb --root-owner-group` butuh dpkg ≥ 1.19 (tersedia di Ubuntu 18.04+).

### 7.4 Skema versi

`MAJOR.MINOR.PATCH` (SemVer), mulai `0.1.0`. Naikkan `MINOR` untuk perintah atau opsi baru,
`PATCH` untuk perbaikan. Satu kenaikan versi = empat tempat diubah bersamaan:

1. `VERSI="0.1.0"` di `bin/makan-apa`
2. `VERSION := 0.1.0` di `Makefile`
3. `Version: 0.1.0` di `debian/control`
4. entri baru di `debian/changelog` (format Debian, tanggal RFC 2822 dengan `+0700`)

`make versi` gagal bila ada yang tidak cocok. Rilis ditandai tag git `v0.1.0` yang sama
dengan versi paket.

### 7.5 Membagikan dan mencoba

```bash
# unggah ke GitHub Releases (manual lewat UI, atau gh)
gh release create v0.1.0 dist/makan-apa_0.1.0_all.deb \
  --title "makan-apa 0.1.0" --notes-file CHANGELOG.md

# unduh lalu pasang
sudo apt install ./makan-apa_0.1.0_all.deb

# coba tanpa memasang
dpkg-deb -x dist/makan-apa_0.1.0_all.deb build/coba
MAKAN_APA_DATA_DIR=/tmp/makan-apa-coba build/coba/usr/bin/makan-apa init
MAKAN_APA_DATA_DIR=/tmp/makan-apa-coba build/coba/usr/bin/makan-apa pilih

# mencopot
sudo apt remove makan-apa    # biner + dokumen hilang; data di ~/.local/share tetap
sudo apt purge makan-apa     # sama; paket tidak punya conffile, jadi tidak ada yang lain
```

Data pengguna sengaja **tidak** dihapus saat remove/purge; README menyebut cara
menghapusnya manual (`rm -rf ~/.local/share/makan-apa`).

### 7.6 Uji pasang bersih (Docker)

Target: **Ubuntu 24.04 LTS** (`ubuntu:24.04`), diulang di **22.04** (`ubuntu:22.04`) bila
waktu memungkinkan. `tests/pasang-bersih.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
IMG=${IMG:-ubuntu:24.04}
DEB=$(basename "$(ls dist/makan-apa_*_all.deb | head -n1)")
docker run --rm -v "$PWD/dist:/deb:ro" "$IMG" bash -euo pipefail -c '
  apt-get update -qq
  apt-get install -y -qq /deb/'"$DEB"'
  makan-apa --version
  export MAKAN_APA_DATA_DIR=/tmp/data MAKAN_APA_TANGGAL=2026-10-20
  makan-apa init
  makan-apa pilih --budget 20rb
  makan-apa riwayat --hari 3
  test "$(makan-apa daftar --tsv | wc -l)" -eq 8
  apt-get remove -y makan-apa
  test ! -e /usr/bin/makan-apa
  test -f /tmp/data/tempat.tsv
'
```

Lulus bila: paket terpasang tanpa galat, `--version` benar, `init` + `pilih` + `riwayat`
bekerja, 8 baris data, penghapusan menghilangkan biner, dan data pengguna tetap ada.
Ulangi dengan `apt-get purge -y makan-apa` lalu pastikan `test ! -e /usr/bin/makan-apa`,
`! dpkg -s makan-apa` (paket tidak terpasang), dan `/tmp/data/tempat.tsv` masih ada.

## 8. Dokumentasi

### 8.1 README.md

Urutan bagian:

1. Nama + satu kalimat: "Pemilih tempat makan dengan riwayat dan filter, untuk terminal."
2. **Pasang** (3 baris):

   ```bash
   sudo apt install ./makan-apa_0.1.0_all.deb
   makan-apa init
   makan-apa pilih
   ```
3. **Pakai dalam 5 baris** (wajib persis lima perintah):

   ```bash
   makan-apa init
   makan-apa tambah "Nasi Goreng Spesial" --harga 15rb-25rb --tag nasi
   makan-apa pilih
   makan-apa pilih --budget 20rb --tag nasi,mie
   makan-apa riwayat --hari 7
   ```
4. Contoh keluaran (transkrip demo bagian 1).
5. Cara kerja riwayat (N=3, `--hari`, `--ulang`, `--dry-run`) dan filter (`--budget`,
   `--ketat`, `--tag`).
6. Berkas data, cadangan, berbagi (`daftar --tsv` + `impor`), dan cara menghapus data.
7. Keterbatasan: tanpa filter jarak; nama non-ASCII bisa menggeser kolom tabel;
   `LC_ALL=C`.
8. Lisensi MIT + tautan `LICENSE`.

### 8.2 Halaman manual `man makan-apa`

groff (`man/makan-apa.1`), bagian: NAME, SYNOPSIS, DESCRIPTION, COMMANDS, OPTIONS,
FILES, ENVIRONMENT, EXIT STATUS, EXAMPLES, BUGS, SEE ALSO. Isinya harus konsisten dengan
`--help` dan bagian 2–4 dokumen ini; `make man` wajib tanpa peringatan groff.

### 8.3 CHANGELOG.md

Format Keep a Changelog:

```markdown
# Changelog

## [0.1.0] - 2026-10-20

### Ditambahkan
- Perintah `init`, `tambah`, `daftar`, `ubah`, `hapus`, `pilih`, `riwayat`, `impor`.
- Filter budget (termasuk `--ketat`) dan tag.
- Riwayat dengan jendela 3 hari, `--ulang`, dan `--dry-run`.
- Paket `.deb` dengan halaman manual dan bash completion.
```

### 8.4 Lisensi: MIT

Alasan: proyek kecil, satu skrip, tidak ada kepentingan komersial atau paten; MIT paling
pendek dan paling mudah dipahami, cocok untuk tugas kuliah, dan tetap kompatibel bila nanti
kode disalin ke proyek lain. GPL-3.0 akan menambah kewajiban distribusi sumber yang tidak
diperlukan di sini. `debian/copyright` memakai format DEP-5 dengan pemegang hak "Tim
MakanApa" dan field: `Format`, `Upstream-Name: makan-apa`, `Files: *`, `Copyright: 2026
Tim MakanApa`, `License: MIT`, diikuti teks lisensi MIT lengkap.

## 9. Tahapan kerja untuk 2 orang

Aturan umum:

- **Satu tahap = satu branch = satu PR kecil.** Nama branch: `t1-kerangka`, `t2-pilih`, ….
- Branch tahap dipakai bersama: Orang A menaruh kode, Orang B menaruh tes untuk tahap itu.
  PR dibuka setelah keduanya selesai, direview oleh orang yang tidak menulis bagian itu.
- **Gerbang merge:** `make check` hijau (shellcheck + seluruh bats) dan `make deb` sukses;
  dari T7 juga `make lint` tanpa temuan yang tidak dijelaskan. Tidak ada merge langsung ke
  `main`.
- `PLAN.md` dibekukan setelah disetujui; perubahan rencana lewat PR terpisah.
- Komunikasi antartahap memakai spesifikasi di dokumen ini, bukan kesepakatan lisan.

|Tahap|Branch|Pemilik|Cakupan|Tes wajib|Selesai bila|
|---|---|---|---|---|---|
|**T1** Kerangka repo, CLI, penyimpanan|`t1-kerangka`|A (kode), B (tes)|Skeleton repo, `main`+dispatch, `--help`, `--version`, `die`, XDG path, `init`, `tambah`, `daftar`, `hapus`, `ubah`, `impor` + `--ganti`, TSV baca/tulis, `flock`, tulis atomik, Makefile `check`|`cli.bats`, `tambah.bats`, `daftar.bats`, `data.bats` (kecuali kunci), `impor.bats`|6 perintah (`init`, `tambah`, `daftar`, `ubah`, `hapus`, `impor`) jalan di data tmp; `make check` hijau; tidak ada stub perintah|
|**T2** Pilih acak|`t2-pilih`|A, B|`pilih` tanpa filter, LCG + `MAKAN_APA_SEED`, stdout nama/stderr detail, `MAKAN_APA_TANGGAL`|`pilih.bats` (seed, stdout, satu kandidat)|`pilih` dua kali dengan seed sama → nama sama; stdout tepat satu baris|
|**T3** Filter budget dan tag|`t3-filter`|A, B|`--budget`, `--ketat`, `--tag` untuk `pilih` dan `daftar`, statistik kandidat|`pilih.bats` (batas budget, ketat, tag), `daftar.bats` (filter)|Batas inklusif terbukti; statistik konsisten|
|**T4** Riwayat dan konfigurasi|`t4-riwayat`|A, B|`riwayat.tsv`, jendela N, config `riwayat_hari`, `riwayat` perintah, pangkas 90 hari, tengah malam|`riwayat.bats`, `pilih.bats` (blokir riwayat)|Batas N=3 terbukti; tanggal palsu lintas hari bekerja|
|**T5** Pengalaman pilih|`t5-pengalaman`|A, B|`--dry-run`, `--ulang`, diagnosis semua-tereliminasi, pesan galat final, uji kunci/atomik|`pilih.bats` (dry-run, ulang, diagnosis), `data.bats` (kunci)|Demo bagian 1 berjalan persis; kode keluar 2/4/5 terbukti|
|**T6** Gerbang tes menyeluruh|`t6-gerbang`|B (A review)|Melengkapi semua kasus wajib bagian 6, shellcheck `--severity=style` nol temuan, `tests/helper.bash` final|seluruh `tests/*.bats`|`make check` hijau dari repo bersih; tidak ada tes yang di-skip|
|**T7** Paket `.deb`|`t7-paket`|B (A review)|Makefile target `deb`/`lint`/`man`/`versi`, `debian/*`, man page, completion, `tests/pasang-bersih.sh`|`make man`, `make lint`, `make uji-pasang` di 24.04|`.deb` terpasang dan skenario demo lulus di kontainer bersih; lintian bersih/terjelaskan|
|**T8** Dokumentasi dan rilis|`t8-rilis`|B (A review)|README, CHANGELOG, LICENSE, `debian/copyright`, tag `v0.1.0`, GitHub Release, rekaman demo|pemeriksaan manual README (5 baris pertama bisa diikuti tanpa bertanya)|Rilis berisi `.deb`, README akurat, demo 2 menit direkam|

Urutan dan paralelisme:

- T1 adalah satu-satunya titik tunggu: B butuh path berkas dan string keluaran dari T1
  untuk mulai menulis tes. Karena itu T1 dikerjakan paling awal dan kecil.
- Setelah T1: A mengerjakan T2→T5 berurutan (satu branch per tahap), B mengerjakan tes
  tahap yang sedang berjalan **dan** mulai T7 (kerangka `debian/`, Makefile target, man page)
  serta T8 (README/CHANGELOG dari spesifikasi) tanpa menunggu T5.
- T6 dan T7 baru bisa selesai setelah T5, tetapi persiapannya jalan sejak T1.
- **Titik temu:** (1) akhir T1 — string keluaran dan path dibekukan; (2) akhir T3 — opsi
  filter dibekukan untuk man page; (3) akhir T5 — skrip beku, hanya perbaikan bug sampai
  rilis; (4) T7 — B meminta A memeriksa bahwa skrip tidak menulis ke home saat dipasang.
- **Berkas rawan konflik** dan pemiliknya: `bin/makan-apa` (A saja), `tests/helper.bash`
  (B saja), `Makefile` (B setelah T1), `debian/*` (B), `README.md`/`CHANGELOG.md`/`LICENSE`
  (B), `data/contoh.tsv` (A; B tidak mengubah), `man/makan-apa.1` (B).
  Bila A butuh target Makefile baru, A menulis permintaan di PR/issue, B yang mengubah.

## 10. Risiko dan pertanyaan terbuka

### 10.1 Risiko teknis

|Risiko|Dampak|Mitigasi|
|---|---|---|
|`TZ=Asia/Jakarta` tidak dikenal (tzdata hilang)|tanggal jatuh ke UTC, jendela riwayat meleset 7 jam|`Depends: tzdata`; uji di kontainer bersih; pesan galat bila `date` gagal|
|`date -d` adalah GNU date|skrip tidak portabel ke BSD/macOS|target resmi hanya Ubuntu; dicatat di README|
|Perbedaan mawk/gawk|hasil acak atau `length()` berbeda|hindari fitur gawk; aritmetika < 2^53; tes memakai mawk default Ubuntu|
|`LC_ALL=C` dan nama non-ASCII|kolom tabel bergeser, `sort` byte-wise|diterima dan didokumentasikan; data tetap benar karena TSV|
|`flock` di filesystem jaringan|kunci tidak andal|data dimaksudkan di home lokal; didokumentasikan|
|Riwayat diedit manual (duplikat/tanggal aneh)|hasil membingungkan|parser melewati baris rusak dengan peringatan; `riwayat` menampilkan apa adanya|
|`--ulang` setelah tengah malam|menambah baris, bukan mengganti|disengaja dan didokumentasikan (4.6)|
|Disk penuh saat menulis riwayat|pilihan tidak tercatat|tulis atomik + keluar 3 tanpa mencetak nama ke stdout|
|Tes bergantung pada tanggal asli|flaky menjelang tengah malam|semua tes mengekspor `MAKAN_APA_TANGGAL`|

### 10.2 Risiko pengemasan

|Risiko|Mitigasi|
|---|---|
|lintian memunculkan tag tak terduga (`no-changelog`, `no-copyright-file`, `manpage-has-errors-from-man`)|semua sudah disiapkan (changelog, copyright, `make man`); tag yang tersisa dijelaskan di PR|
|`Installed-Size` salah|dihitung otomatis dari `du -sk`|
|Paket menulis ke home|tidak ada maintainer script; diuji dengan `test ! -e $HOME/.local/share/makan-apa` di kontainer sebelum `init`|
|`apt install ./x.deb` gagal di image minimal|uji di `ubuntu:24.04` polos, bukan image yang sudah dimodifikasi|
|Docker tidak tersedia di mesin Windows|butuh Docker Desktop/WSL2; fallback: jalankan `tests/pasang-bersih.sh` di WSL Ubuntu atau minta rekan di Linux|
|Versi tidak sinkron|`make versi`|
|`dpkg-deb --root-owner-group` tidak ada|cek `dpkg --version`; Ubuntu LTS yang ditarget sudah memenuhi|

### 10.3 Yang bisa terlewat

- Bash completion tidak diuji otomatis (hanya dicek ada dan bisa di-`source`); risiko rendah.
- Perilaku `--ulang` saat pengguna memang ingin dua pilihan berbeda dalam satu hari.
- Penghapusan tempat tidak membersihkan riwayat (disengaja, tetapi bisa mengejutkan).
- Tidak ada `makan-apa ekspor` khusus; ekspor memakai `daftar --tsv`.
- Tidak ada dukungan bahasa selain Indonesia.
- Nama tempat dengan karakter kontrol selain tab/baris baru (mis. `\x1b`) belum ditolak;
  bisa ditambahkan bila muncul.

### 10.4 Pertanyaan terbuka dan usulan jawaban

1. **Apakah filter jarak/area perlu?** Usulan: tidak untuk 0.1.0; gunakan tag (`--tag dekat`,
   `--tag kampus`). Alasan di 2.13.
2. **Beberapa tag: OR atau AND?** Usulan: OR (`--tag nasi,mie` = nasi atau mie), karena
   pengguna biasanya ingin memperluas pilihan, bukan mempersempit.
3. **`--ulang` mengganti baris terakhir hari ini — bagaimana bila pengguna butuh dua
   keputusan dalam sehari?** Usulan: pakai `pilih` biasa untuk keputusan kedua; `--ulang`
   khusus untuk menolak hasil. Bila keluhan muncul, tambah `--baru` di versi berikutnya.
4. **Dukungan Ubuntu 22.04?** Usulan: ya, sebagai target sekunder; 24.04 adalah target uji
   utama.
5. **bats dari apt atau submodule?** Usulan: apt (`bats`), fallback submodule bila paket
   tidak tersedia.
6. **Retensi riwayat 90 hari tetap?** Usulan: ya, cukup untuk jendela 3 hari dan menjaga
   berkas kecil; bisa dijadikan kunci konfigurasi nanti.
7. **Zona waktu selain Asia/Jakarta?** Usulan: tidak di 0.1.0; konstanta `ZONA` di skrip
   memudahkan penambahan nanti.
