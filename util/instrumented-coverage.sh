#!/bin/sh

this_repo="$(realpath $(dirname $(dirname -- "$(readlink -- "${0}")")))"
features="$1"

rm -rf "$this_repo/profiles/*"

echo "building objects"
objects=$(RUSTFLAGS="-C instrument-coverage" \
                   cargo test --no-run --features "$features" --message-format=json \
              | jq -r "select(.profile.test == true) | .filenames[]" \
              | grep -v dSYM -)

echo "running tests"
RUSTFLAGS="-C instrument-coverage" \
         LLVM_PROFILE_FILE="$this_repo/profiles/profile-%m.profraw" \
         cargo test --features "$features" --message-format=json >tests.log

echo "merging profiles"
llvm-profdata merge \
              -sparse \
              "$this_repo/profiles/"*.profraw \
              -o "$this_repo/profiles/combined.profdata"

echo "exporting lcov"
llvm-cov export \
         --ignore-filename-regex='/.cargo/registry' \
         --format=lcov \
         --instr-profile="$this_repo/profiles/combined.profdata" \
         $(for file in $objects; do echo "-object $file"; done) \
         >"$this_repo/profiles/lcov.info"
