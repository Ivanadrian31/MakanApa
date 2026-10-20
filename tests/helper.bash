# tests/helper.bash - lingkungan tes terisolasi (kontrak 9).
#
# BATS_TEST_TMPDIR baru tersedia sejak bats 1.4; di bats 1.2 (Ubuntu 22.04) variabel ini
# masih kosong saat helper dimuat, sehingga $BATS_TEST_TMPDIR/data menjadi /data dan tes
# gagal dengan kode keluar 3. Fallback: direktori unik per tes (P12).
if [ -n "${BATS_TEST_TMPDIR:-}" ]; then
  _bats_tmp=$BATS_TEST_TMPDIR
elif [ -n "${BATS_TMPDIR:-}" ]; then
  _bats_tmp=$(mktemp -d "${BATS_TMPDIR:-/tmp}/makan-apa-XXXXXX")
else
  _bats_tmp=$(mktemp -d)
fi

export MAKAN_APA_DATA_DIR="$_bats_tmp/data"
export MAKAN_APA_CONFIG_DIR="$_bats_tmp/config"
export MAKAN_APA_TANGGAL=2026-10-20
export MAKAN_APA_SEED=42
export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"