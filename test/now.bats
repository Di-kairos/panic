# Тесты ядра panic (pack 2: now — detach образов, clipboard, lock screen).
# Системные команды подменяются стабами через PATH (+ PANIC_CGSESSION), поэтому
# тесты детерминированно гоняются и на Linux-CI.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../panic"
  STUBS="${BATS_TEST_DIRNAME}/stubs"
  TMP="$(mktemp -d)"
  export VW_STUB_LOG="$TMP/calls.log"
  export PANIC_CGSESSION="$STUBS/cgsession"
  export PATH="$STUBS:$PATH"
  export ST_ASSUME_YES=1
  unset ST_LANG
}

teardown() { rm -rf "$TMP"; }

run_now() { run env PATH="$STUBS:$PATH" PANIC_CGSESSION="$STUBS/cgsession" bash "$SCRIPT" now "$@"; }

@test "now detaches each mounted /Volumes disk image" {
  STUB_MOUNTS="/Volumes/SecretVault|/Volumes/Other" run_now
  [ "$status" -eq 0 ]
  grep -qF -- "detach -force /Volumes/SecretVault" "$VW_STUB_LOG"
  grep -qF -- "detach -force /Volumes/Other" "$VW_STUB_LOG"
}

@test "now does NOT detach a system image mounted outside /Volumes" {
  STUB_MOUNTS="/|/Volumes/SecretVault" run_now
  [ "$status" -eq 0 ]
  grep -qF -- "detach -force /Volumes/SecretVault" "$VW_STUB_LOG"
  ! grep -qE "detach -force /$" "$VW_STUB_LOG"
}

@test "now preserves a mountpoint with spaces" {
  STUB_MOUNTS="/Volumes/Secret Vault" run_now
  [ "$status" -eq 0 ]
  grep -qF -- "detach -force /Volumes/Secret Vault" "$VW_STUB_LOG"
}

@test "now clears the clipboard" {
  STUB_MOUNTS="/Volumes/SecretVault" run_now
  [ "$status" -eq 0 ]
  grep -q "pbcopy" "$VW_STUB_LOG"
}

@test "now locks the screen" {
  STUB_MOUNTS="/Volumes/SecretVault" run_now
  [ "$status" -eq 0 ]
  grep -qF -- "cgsession -suspend" "$VW_STUB_LOG"
}

@test "now with no mounted images still clears clipboard and locks" {
  STUB_MOUNTS="" run_now
  [ "$status" -eq 0 ]
  ! grep -q "detach" "$VW_STUB_LOG"
  grep -q "pbcopy" "$VW_STUB_LOG"
  grep -qF -- "cgsession -suspend" "$VW_STUB_LOG"
}

@test "now reports what it did" {
  STUB_MOUNTS="/Volumes/SecretVault" run_now
  [ "$status" -eq 0 ]
  [[ "$output" == *"clipboard"* ]] || [[ "$output" == *"буфер"* ]]
  [[ "$output" == *"lock"* ]] || [[ "$output" == *"заперт"* ]] || [[ "$output" == *"экран"* ]]
}
