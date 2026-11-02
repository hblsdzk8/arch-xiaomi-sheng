#!/usr/bin/env bash
# Regenerate files.tar.gz for all packages and repair stale sha256sums entries
# in PKGBUILDs. Generation is deterministic (package-files.sh), so the freshly
# computed hash is authoritative for the current files/ tree.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

./scripts/package-files.sh

fixed=0
checked=0
for pb in pkgs/*/PKGBUILD; do
  dir=$(dirname "$pb")
  [[ -f "$dir/files.tar.gz" ]] || continue
  checked=$((checked + 1))
  actual=$(sha256sum "$dir/files.tar.gz" | cut -d' ' -f1)

  idx=$(bash -c '
    source "$1" >/dev/null 2>&1 || exit 1
    for i in "${!source[@]}"; do
      [[ ${source[$i]} == files.tar.gz ]] && { echo "$i"; exit 0; }
    done
    exit 1
  ' _ "$pb") || { echo "SKIP $pb (no files.tar.gz source)"; continue; }

  old=$(bash -c '
    source "$1" >/dev/null 2>&1 || exit 1
    echo "${sha256sums[$2]:-}"
  ' _ "$pb" "$idx")

  if [[ -z $old || $old == SKIP ]]; then
    echo "OK   $pb (idx=$idx old=${old:-empty})"
    continue
  fi
  if [[ $old == "$actual" ]]; then
    echo "OK   $pb"
    continue
  fi
  sed -i "s/$old/$actual/g" "$pb"
  echo "FIX  $pb idx=$idx: $old -> $actual"
  fixed=$((fixed + 1))
done
echo "checked=$checked fixed=$fixed"