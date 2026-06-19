# Тесты ядра Shamir (pack 2): split/combine над GF(256).
# Спека корректности: round-trip для всех подмножеств порога, отказ при <T долей,
# детект порчи/чужого набора, бинарные секреты, граничные N/T.
setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../seedsplit"
  STUBS="${BATS_TEST_DIRNAME}/stubs"
  export PATH="$STUBS:$PATH"
  export ST_ASSUME_YES=1
}

# --- помощник: разбить секрет, вернуть доли (по строке на долю) ---
_split() { # $1=secret $2=N $3=T
  printf '%s' "$1" | bash "$SCRIPT" split -n "$2" -t "$3"
}

@test "split outputs exactly N share lines" {
  run _split "topsecret" 5 3
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^SSS1-')" -eq 5 ]
}

@test "share lines carry the SSS1 format" {
  run _split "topsecret" 3 2
  [[ "$output" == SSS1-* ]]
}

@test "round-trip 2-of-3: every pair reconstructs the secret" {
  secret="correct horse battery staple"
  shares="$(_split "$secret" 3 2)"
  for pair in "1p;2p" "1p;3p" "2p;3p"; do
    sel="$(printf '%s\n' "$shares" | sed -n "$pair")"
    out="$(printf '%s\n' "$sel" | bash "$SCRIPT" combine)"
    [ "$out" = "$secret" ]
  done
}

@test "round-trip 3-of-5: a threshold subset reconstructs" {
  secret="my-wallet-seed-phrase-words-here"
  shares="$(_split "$secret" 5 3)"
  sel="$(printf '%s\n' "$shares" | sed -n '2p;4p;5p')"
  out="$(printf '%s\n' "$sel" | bash "$SCRIPT" combine)"
  [ "$out" = "$secret" ]
}

@test "more than T shares also reconstruct (extra shares are fine)" {
  secret="abc123"
  shares="$(_split "$secret" 5 2)"
  out="$(printf '%s\n' "$shares" | bash "$SCRIPT" combine)"   # all 5
  [ "$out" = "$secret" ]
}

@test "default params (no -n/-t) round-trip" {
  secret="default-params-secret"
  shares="$(printf '%s' "$secret" | bash "$SCRIPT" split)"
  n="$(printf '%s\n' "$shares" | grep -c '^SSS1-')"
  [ "$n" -ge 2 ]
  out="$(printf '%s\n' "$shares" | bash "$SCRIPT" combine)"
  [ "$out" = "$secret" ]
}

@test "fewer than T shares fails (no secret leak)" {
  secret="needs-three"
  shares="$(_split "$secret" 5 3)"
  sel="$(printf '%s\n' "$shares" | sed -n '1p;2p')"   # only 2 of 3
  run bash -c "printf '%s\n' \"$sel\" | bash '$SCRIPT' combine"
  [ "$status" -ne 0 ]
  [[ "$output" != *"needs-three"* ]]
}

@test "corrupted share is detected via per-share checksum" {
  secret="integrity-matters"
  shares="$(_split "$secret" 3 2)"
  first="$(printf '%s\n' "$shares" | sed -n '1p')"
  second="$(printf '%s\n' "$shares" | sed -n '2p')"
  # Детерминированная порча: флипаем первый hex-символ Y-блока (0↔1), chk оставляем старый.
  T="$(cut -d- -f2 <<<"$first")"; x="$(cut -d- -f3 <<<"$first")"
  Y="$(cut -d- -f4 <<<"$first")"; chk="$(cut -d- -f5 <<<"$first")"
  c="${Y:0:1}"; if [ "$c" = "0" ]; then nc="1"; else nc="0"; fi
  corrupt="SSS1-${T}-${x}-${nc}${Y:1}-${chk}"
  run bash -c "printf '%s\n%s\n' '$corrupt' '$second' | bash '$SCRIPT' combine"
  [ "$status" -ne 0 ]
  [[ "$output" != *"$secret"* ]]
}

@test "shares from two different splits do not combine to a valid secret" {
  a="$(_split "secret-A" 3 2)"
  b="$(_split "secret-B" 3 2)"
  mix="$(printf '%s\n%s\n' "$(printf '%s\n' "$a" | sed -n '1p')" "$(printf '%s\n' "$b" | sed -n '2p')")"
  run bash -c "printf '%s\n' \"$mix\" | bash '$SCRIPT' combine"
  [ "$status" -ne 0 ]
}

@test "duplicate share (same x) is rejected" {
  shares="$(_split "dup-check" 3 2)"
  one="$(printf '%s\n' "$shares" | sed -n '1p')"
  run bash -c "printf '%s\n%s\n' \"$one\" \"$one\" | bash '$SCRIPT' combine"
  [ "$status" -ne 0 ]
}

@test "binary secret with high bytes round-trips" {
  shares="$(printf '\x00\x01\xfe\xff\x80\x7f' | bash "$SCRIPT" split -n 3 -t 2)"
  sel="$(printf '%s\n' "$shares" | sed -n '1p;3p')"
  out_hex="$(printf '%s\n' "$sel" | bash "$SCRIPT" combine | od -An -v -tx1 | tr -d ' \n')"
  [ "$out_hex" = "0001feff807f" ]
}

@test "secret from --file round-trips" {
  f="$(mktemp)"; printf 'file-fed-secret' > "$f"
  shares="$(bash "$SCRIPT" split -n 3 -t 2 --file "$f")"
  sel="$(printf '%s\n' "$shares" | sed -n '1p;2p')"
  out="$(printf '%s\n' "$sel" | bash "$SCRIPT" combine)"
  [ "$out" = "file-fed-secret" ]
  rm -f "$f"
}

@test "threshold below 2 is rejected" {
  run bash -c "printf 'x' | bash '$SCRIPT' split -n 3 -t 1"
  [ "$status" -ne 0 ]
}

@test "threshold above shares is rejected" {
  run bash -c "printf 'x' | bash '$SCRIPT' split -n 3 -t 4"
  [ "$status" -ne 0 ]
}

@test "shares above 255 is rejected" {
  run bash -c "printf 'x' | bash '$SCRIPT' split -n 256 -t 2"
  [ "$status" -ne 0 ]
}

@test "empty secret is rejected" {
  run bash -c "printf '' | bash '$SCRIPT' split -n 3 -t 2"
  [ "$status" -ne 0 ]
}

@test "split is randomized: two runs give different shares but both reconstruct" {
  secret="randomness-check"
  s1="$(_split "$secret" 3 2)"
  s2="$(_split "$secret" 3 2)"
  [ "$s1" != "$s2" ]
  o1="$(printf '%s\n' "$s1" | sed -n '1p;2p' | bash "$SCRIPT" combine)"
  o2="$(printf '%s\n' "$s2" | sed -n '1p;2p' | bash "$SCRIPT" combine)"
  [ "$o1" = "$secret" ]
  [ "$o2" = "$secret" ]
}

@test "T=N boundary (all shares required) round-trips" {
  secret="all-needed"
  shares="$(_split "$secret" 4 4)"
  out="$(printf '%s\n' "$shares" | bash "$SCRIPT" combine)"
  [ "$out" = "$secret" ]
}
