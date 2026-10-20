# tests/helper.bash - lingkungan tes terisolasi (kontrak 9).
export MAKAN_APA_DATA_DIR="$BATS_TEST_TMPDIR/data"
export MAKAN_APA_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
export MAKAN_APA_TANGGAL=2026-10-20
export MAKAN_APA_SEED=42
export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
