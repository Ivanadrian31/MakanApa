# Makan Apa?

Pemilih tempat makan dengan riwayat dan filter, untuk terminal.

## Pasang

```bash
sudo apt install ./makan-apa_0.1.0_all.deb
makan-apa init
makan-apa pilih
```

## Pakai dalam 5 baris

```bash
makan-apa init
makan-apa tambah "Nasi Goreng Spesial" --harga 15rb-25rb --tag nasi
makan-apa pilih
makan-apa pilih --budget 20rb --tag nasi,mie
makan-apa riwayat --hari 7
```

## Contoh keluaran

Transkrip asli `PLAN.md` §1, direkam dari `main` dengan data contoh delapan tempat. Tanggal
dipalsukan lewat `MAKAN_APA_TANGGAL` dan sumber acak dikunci lewat `MAKAN_APA_SEED=11`, jadi
seluruh baris di bawah dapat diulang persis:

```console
$ export MAKAN_APA_DATA_DIR=/tmp/makan-apa-demo
$ makan-apa init
Data contoh disalin ke /tmp/makan-apa-demo/tempat.tsv (8 tempat).
Jalankan 'makan-apa pilih' untuk mencoba.

$ MAKAN_APA_TANGGAL=2026-10-18 makan-apa pilih
Bakso Sapi Campur
  Rp14.000-24.000  [bakso,berkuah]
  Catatan: porsi jumbo
  Kandidat: 8 dari 8 (tersaring: budget 0, tag 0, riwayat 0)
  Tercatat di riwayat: 2026-10-18

$ MAKAN_APA_TANGGAL=2026-10-19 makan-apa pilih
Nasi Goreng Spesial
  Rp15.000-25.000  [nasi,cepat]
  Catatan: porsi besar
  Kandidat: 7 dari 8 (tersaring: budget 0, tag 0, riwayat 1)
  Tercatat di riwayat: 2026-10-19

$ MAKAN_APA_TANGGAL=2026-10-20 makan-apa pilih
Es Teh Manis
  Rp4.000-8.000  [minuman]
  Catatan: gelas besar
  Kandidat: 6 dari 8 (tersaring: budget 0, tag 0, riwayat 2)
  Tercatat di riwayat: 2026-10-20

$ MAKAN_APA_TANGGAL=2026-10-20 makan-apa riwayat --hari 3
TANGGAL     NAMA
2026-10-20  Es Teh Manis
2026-10-19  Nasi Goreng Spesial
2026-10-18  Bakso Sapi Campur
3 catatan (3 hari terakhir).

$ MAKAN_APA_TANGGAL=2026-10-20 makan-apa pilih --ulang --budget 20rb --ketat
Nasi Uduk Komplit
  Rp12.000-20.000  [nasi]
  Catatan: telur balado
  Kandidat: 3 dari 8 (tersaring: budget 4, tag 0, riwayat 1)
  Mengganti pilihan 2026-10-20: Es Teh Manis -> Nasi Uduk Komplit

$ MAKAN_APA_TANGGAL=2026-10-20 makan-apa riwayat --hari 1
TANGGAL     NAMA
2026-10-20  Nasi Uduk Komplit
1 catatan (1 hari terakhir).
```

Yang tetap berapa pun sumber acaknya: jumlah kandidat turun satu per hari karena jendela
riwayat, dan `--ulang` mengganti baris hari ini alih-alih menambah baris kedua. Nama yang
terpilih bergantung pada sumber acak — tanpa `MAKAN_APA_SEED`, `pilih` memakai
`/dev/urandom`.

## Demo 2 menit

Jalankan `make demo` (atau `bash demo/demo-2-menit.sh`) untuk mencetak transkrip
demo. Skrip memakai direktori `/tmp/makan-apa-demo` (atau `MAKAN_APA_DEMO_DIR`) dan
tidak menyentuh data pengguna. Sumber acak dikunci (`MAKAN_APA_SEED=11`) dan
tanggal dipalsukan, sehingga keluarannya sama setiap kali dan sama dengan contoh di
atas. Simpan dengan `bash demo/demo-2-menit.sh > demo.txt`.

## Cara kerja riwayat dan filter

Tempat yang dipilih dalam **N hari terakhir** tidak muncul lagi. `N` diambil dari
`--hari N`, lalu `riwayat_hari` di berkas konfigurasi, lalu nilai bawaan **3**.
`--hari 0` mematikan penyaringan riwayat. Jendela N=3 berarti hari ini, kemarin, dan
kemarin lusa; catatan yang berumur tepat tiga hari sudah tidak memblokir.

`--ulang` mengganti pilihan hari ini, bukan menambah baris kedua. Bila hari ini belum ada
pilihan, `--ulang` mencatat pilihan baru dan memberitahukannya. `--dry-run` menampilkan
pilihan tanpa menyentuh riwayat, dan boleh digabung dengan `--ulang`.

Filter menyaring kandidat sebelum diacak:

- `--budget HARGA` membandingkan `harga_min` dengan batas; format `25000`, `25rb`, `25k`,
  atau `25.000`.
- `--ketat` membandingkan `harga_max`, sehingga hanya tempat yang seluruh rentangnya muat
  dalam budget yang lolos. Opsi ini membutuhkan `--budget`.
- `--tag T[,T...]` hanya menyisakan tempat yang memiliki salah satu tag tersebut.

Bila semua kandidat tersaring, perintah keluar dengan kode 2 dan menjelaskan berapa tempat
yang gugur karena budget, tag, dan riwayat, beserta saran melonggarkan filter.

## Berkas data, cadangan, dan berbagi

Data disimpan sebagai TSV di direktori XDG pengguna:

- `~/.local/share/makan-apa/tempat.tsv` — lima kolom: nama, harga_min, harga_max, tag,
  catatan. Baris yang diawali `#` adalah komentar.
- `~/.local/share/makan-apa/riwayat.tsv` — dua kolom: tanggal `YYYY-MM-DD` dan nama.
  Entri lebih tua dari 90 hari dipangkas saat menulis.
- `~/.config/makan-apa/config` — konfigurasi `kunci=nilai`; satu kunci dikenal:
  `riwayat_hari` (0–365).

Cadangan cukup menyalin kedua berkas TSV. Untuk berbagi daftar dengan teman:

```bash
makan-apa daftar --tsv > daftar-makan.tsv
makan-apa impor daftar-makan.tsv
```

`impor` memvalidasi seluruh berkas lebih dulu; satu baris tidak valid membatalkan seluruh
impor. Nama yang sudah ada dilewati; `--ganti` mengganti seluruh daftar. Menghapus data
pengguna:

```bash
rm -rf ~/.local/share/makan-apa ~/.config/makan-apa
```

Mencopot paket tidak menghapus data pengguna.

## Keterbatasan

- Tidak ada filter jarak atau area; alat bekerja offline tanpa sumber koordinat.
- Nama non-ASCII dapat menggeser kolom tabel karena program berjalan dengan `LC_ALL=C`.
- Versi 0.1.0 tidak menyediakan impor/ekspor format selain TSV.
- Baris komentar pada `tempat.tsv` dikumpulkan ulang di atas berkas setiap kali daftar
  ditulis ulang (oleh `tambah`, `ubah`, `hapus`, atau `impor`), jadi posisinya di tengah
  berkas tidak dipertahankan.

## Lisensi

MIT. Lihat [LICENSE](LICENSE).
