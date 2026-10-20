# lib/cmd-riwayat.sh - cmd_riwayat (milik B, tahap B2).
# shellcheck shell=bash # dimuat oleh bin/makan-apa (bukan skrip mandiri)
# Hanya definisi fungsi; dimuat oleh bin/makan-apa.

# Jendela bawaan perintah riwayat (PLAN.md 2.9); tidak memakai config
# riwayat_hari karena config itu untuk penyaringan pada perintah pilih.
RIWAYAT_JENDELA_BAWAAN=14

# Lebar kolom TANGGAL pada tabel riwayat (kontrak K5).
RIWAYAT_LEBAR_TANGGAL=12

cmd_riwayat() { # tanpa argumen; OPT_HARI/OPT_SEMUA sudah di-parse
  local semua=0 jendela=$RIWAYAT_JENDELA_BAWAAN nilai batas
  local i jumlah nama tanggal label urut
  local -a kunci=()

  # Arity 0 (kontrak 4.2); lebih dari satu argumen adalah galat pemakaian (K1).
  if [ "$#" -gt 0 ]; then
    die_opsi "perintah \"riwayat\" tidak menerima argumen posisional."
  fi

  if [ "$OPT_SEMUA" = 1 ] && [ -n "$OPT_HARI" ]; then
    die "opsi --semua dan --hari tidak bisa dipakai bersama." 1
  fi
  if [ -n "$OPT_HARI" ]; then
    nilai=$OPT_HARI
    case $nilai in
      *[!0-9]*) die "--hari harus bilangan bulat 0-365." 1 ;;
    esac
    while [ ${#nilai} -gt 1 ] && [ "${nilai#0}" != "$nilai" ]; do
      nilai=${nilai#0}
    done
    if [ ${#nilai} -gt 3 ] || [ "$nilai" -gt 365 ]; then
      die "--hari harus bilangan bulat 0-365." 1
    fi
    jendela=$nilai
  elif [ "$OPT_SEMUA" = 1 ]; then
    semua=1
  fi

  hari_ini

  # Batas bawah jendela: N hari kalender terakhir termasuk hari ini (N-1 hari).
  # N=0 berarti hanya hari ini, jadi batasnya tetap HARI_INI.
  batas=$HARI_INI
  if [ "$semua" = 0 ] && [ "$jendela" -gt 0 ]; then
    batas=$(tanggal_minus $((jendela - 1)))
  fi

  baca_riwayat

  # Urut: tanggal menurun; tanggal sama, baris yang ditulis belakangan (indeks lebih
  # besar) di atas. Indeks dipadatkan supaya urut stabil pada perbandingan string.
  for (( i = 0; i < RIWAYAT_TOTAL; i++ )); do
    tanggal=${RIWAYAT[i]%%$'\t'*}
    nama=${RIWAYAT[i]#*$'\t'}
    if [ "$semua" = 0 ] && { [[ $tanggal < $batas ]] || [[ $tanggal > $HARI_INI ]]; }; then
      continue
    fi
    printf -v urut '%010d' "$i"
    kunci+=("$tanggal"$'\t'"$urut"$'\t'"$nama")
  done

  if [ "${#kunci[@]}" -eq 0 ]; then
    printf 'Belum ada riwayat.\n' >&2
    return 0
  fi

  printf '%-*s%s\n' "$RIWAYAT_LEBAR_TANGGAL" TANGGAL NAMA
  printf '%s\n' "${kunci[@]}" |
    sort -t $'\t' -k1,1r -k2,2r |
    cut -f1,3- |
    while IFS=$'\t' read -r tanggal nama; do
      printf '%-*s%s\n' "$RIWAYAT_LEBAR_TANGGAL" "$tanggal" "$nama"
    done

  jumlah=${#kunci[@]}
  label="$jendela hari terakhir"
  if [ "$semua" = 1 ]; then
    label="semua riwayat"
  fi
  printf '%d catatan (%s).\n' "$jumlah" "$label" >&2
}
