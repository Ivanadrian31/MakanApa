# shellcheck shell=bash # dimuat oleh bin/makan-apa (bukan skrip mandiri)
# lib/saring.sh - saring, pilih_indeks, cetak_diagnosa.

# MAKAN_APA_SEED harus bilangan bulat 0-2147483646 (kontrak 4.7).
validasi_seed() {
  [ -n "${MAKAN_APA_SEED:-}" ] || return 0
  case $MAKAN_APA_SEED in
    *[!0-9]*) die "MAKAN_APA_SEED harus bilangan bulat 0-2147483646." 1 ;;
  esac
  if [ "$((10#$MAKAN_APA_SEED))" -gt 2147483646 ]; then
    die "MAKAN_APA_SEED harus bilangan bulat 0-2147483646." 1
  fi
}

# $1 = jumlah kandidat -> stdout indeks 0..N-1.
# Sumber acak: 4 byte /dev/urandom, atau MAKAN_APA_SEED untuk tes (kontrak 4.7).
# LCG Park-Miller, aritmetika < 2^53 sehingga sama di mawk maupun gawk.
pilih_indeks() {
  local jumlah=$1 seed
  validasi_seed
  if [ -n "${MAKAN_APA_SEED:-}" ]; then
    seed=$MAKAN_APA_SEED
  else
    seed=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
  fi
  awk -v n="$jumlah" -v s="$seed" 'BEGIN {
    s = s % 2147483647
    if (s <= 0) s = 1
    s = (s * 16807) % 2147483647
    printf "%d", s % n
  }'
}

# Jendela riwayat aktif: OPT_HARI menimpa RIWAYAT_HARI, 0 berarti abaikan (kontrak 4.3).
nilai_jendela() {
  local n=$RIWAYAT_HARI
  if [ -n "$OPT_HARI" ]; then
    case $OPT_HARI in
      *[!0-9]*) die "--hari harus bilangan bulat 0-365." 1 ;;
    esac
    if [ "$((10#$OPT_HARI))" -gt 365 ]; then
      die "--hari harus bilangan bulat 0-365." 1
    fi
    n=$((10#$OPT_HARI))
  fi
  printf '%s' "$n"
}

# 1 bila baris punya salah satu tag yang diminta (OR).
punya_tag() { # $1=tag tempat $2=tag diminta
  local punya=$1 minta=$2 satu
  [ -n "$punya" ] || return 1
  while [ -n "$minta" ]; do
    satu=${minta%%,*}
    if [ "$satu" = "$minta" ]; then minta=; else minta=${minta#*,}; fi
    case ",$punya," in
      *",$satu,"*) return 0 ;;
    esac
  done
  return 1
}

# Budget sebagai angka (0 = tidak ada filter). Validasi --budget dan --ketat.
# $1 = perintah (untuk pesan galat).
siapkan_budget() {
  BUDGET_ANGKA=0
  if [ -z "$OPT_BUDGET" ]; then
    if [ "$OPT_KETAT" = 1 ]; then
      die "--ketat membutuhkan --budget." 1
    fi
    return 0
  fi
  case $OPT_BUDGET in
    *-*) die "--budget hanya menerima satu nilai." 1 ;;
  esac
  parse_harga "$OPT_BUDGET"
  BUDGET_ANGKA=$HARGA_NILAI
}

# Penyaringan: budget -> tag -> riwayat (kontrak 4.1).
# A4: budget dan tag masuk. STATISTIK: GAGAL_BUDGET, GAGAL_TAG, GAGAL_RIWAYAT,
# KANDIDAT[], KANDIDAT_TOTAL, SARAN_BUDGET.
saring() {
  KANDIDAT=()
  KANDIDAT_TOTAL=0
  GAGAL_BUDGET=0
  GAGAL_TAG=0
  GAGAL_RIWAYAT=0
  SARAN_BUDGET=
  local n batas i nama sisa hmin hmax tag harga
  n=$(nilai_jendela)
  local -a diblokir=()
  if [ "$n" -gt 0 ]; then
    batas=$(tanggal_minus $((n - 1)))
    for (( i = 0; i < RIWAYAT_TOTAL; i++ )); do
      local tanggal=${RIWAYAT[i]%%$'\t'*}
      if [[ $tanggal < $batas || $tanggal > $HARI_INI ]]; then continue; fi
      diblokir+=("${RIWAYAT[i]#*$'\t'}")
    done
  fi
  for (( i = 0; i < TEMPAT_TOTAL; i++ )); do
    nama=${TEMPAT[i]%%$'\t'*}
    sisa=${TEMPAT[i]#*$'\t'}
    hmin=${sisa%%$'\t'*}
    sisa=${sisa#*$'\t'}
    hmax=${sisa%%$'\t'*}
    sisa=${sisa#*$'\t'}
    tag=${sisa%%$'\t'*}
    # Budget: default harga_min <= budget; --ketat harga_max <= budget (kontrak 4.2).
    if [ -n "$OPT_BUDGET" ]; then
      harga=$hmin
      [ "$OPT_KETAT" = 1 ] && harga=$hmax
      if [ "$harga" -gt "$BUDGET_ANGKA" ]; then
        GAGAL_BUDGET=$((GAGAL_BUDGET + 1))
        # Saran budget: nilai terkecil di antara yang gagal budget DAN lolos tag.
        if [ -z "$OPT_TAG" ] || punya_tag "$tag" "$OPT_TAG"; then
          if [ -z "$SARAN_BUDGET" ] || [ "$harga" -lt "$SARAN_BUDGET" ]; then
            SARAN_BUDGET=$harga
          fi
        fi
        continue
      fi
    fi
    # Tag: OR (kontrak 4.2).
    if [ -n "$OPT_TAG" ] && ! punya_tag "$tag" "$OPT_TAG"; then
      GAGAL_TAG=$((GAGAL_TAG + 1))
      continue
    fi
    # Riwayat: diblokir bila dipilih dalam jendela N hari.
    if [ "${#diblokir[@]}" -gt 0 ] && printf '%s\n' "${diblokir[@]}" | grep -qxF "$nama"; then
      GAGAL_RIWAYAT=$((GAGAL_RIWAYAT + 1))
      continue
    fi
    KANDIDAT+=("${TEMPAT[i]}")
  done
  # shellcheck disable=SC2034 # dibaca pemanggil (kontrak 8)
  KANDIDAT_TOTAL=${#KANDIDAT[@]}
}

# Diagnosis saat semua kandidat habis (kontrak 5.7); selalu keluar 2.
cetak_diagnosa() {
  local mode_budget=$'harga_min'
  [ "${OPT_KETAT:-0}" = 1 ] && mode_budget=$'harga_max'
  printf 'Tidak ada tempat yang lolos filter.\n' >&2
  printf '  %-18s: %d\n' 'total tempat' "$TEMPAT_TOTAL" >&2
  if [ "$GAGAL_BUDGET" -gt 0 ]; then
    printf '  %-18s: %d  (%s > %s)\n' 'gagal budget' "$GAGAL_BUDGET" "$mode_budget" \
      "$(format_harga "$OPT_BUDGET" "$OPT_BUDGET")" >&2
  else
    printf '  %-18s: %d\n' 'gagal budget' "$GAGAL_BUDGET" >&2
  fi
  if [ "$GAGAL_TAG" -gt 0 ]; then
    printf '  %-18s: %d  (tidak punya tag: %s)\n' 'gagal tag' "$GAGAL_TAG" "$OPT_TAG" >&2
  else
    printf '  %-18s: %d\n' 'gagal tag' "$GAGAL_TAG" >&2
  fi
  if [ "$(nilai_jendela)" = 0 ]; then
    printf '  %-18s: %d  (riwayat diabaikan)\n' 'diblokir riwayat' "$GAGAL_RIWAYAT" >&2
  else
    printf '  %-18s: %d  (dipilih dalam %s hari terakhir)\n' 'diblokir riwayat' \
      "$GAGAL_RIWAYAT" "$(nilai_jendela)" >&2
  fi
  local -a saran=()
  if [ "$GAGAL_BUDGET" -gt 0 ]; then
    if [ -n "$SARAN_BUDGET" ]; then
      saran+=("naikkan --budget (mis. --budget $(format_angka "$SARAN_BUDGET"))")
    else
      saran+=("naikkan --budget")
    fi
  fi
  if [ "$GAGAL_TAG" -gt 0 ]; then
    saran+=("longgarkan --tag")
  fi
  if [ "$GAGAL_RIWAYAT" -gt 0 ]; then
    saran+=("--hari 0 untuk mengabaikan riwayat")
  fi
  if [ "${#saran[@]}" -gt 0 ]; then
    printf 'Saran: %s.\n' "$(printf '%s, ' "${saran[@]}" | sed 's/, $//')" >&2
  fi
  exit 2
}
