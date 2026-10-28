#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
# Early structural checks; passing does not prove the images can boot.
set -euo pipefail
if (( $# != 1 )); then echo "Usage: $0 <build/boot/profile>" >&2; exit 2; fi
for tool in readelf grep; do
  command -v "$tool" >/dev/null || { echo "Missing: $tool" >&2; exit 1; }
done
folder="$1"
require() {
  local image="$folder/$1" expected="$2"
  [[ -s "$image" ]] || { echo "Missing ELF: $image" >&2; exit 1; }
  readelf -h "$image" | grep -q 'Type:.*EXEC' || { echo "Not an executable ELF: $image" >&2; exit 1; }
  readelf -h "$image" | grep -q "Class:.*$expected" || { echo "Unexpected ELF class: $image" >&2; exit 1; }
  echo "OK ($expected): $image"
}
require kickstart ELF32
require x86-kernel ELF64
require sigma0 ELF64
require roottask ELF64
# GRUB validates the checksum/header independently when installed.
if command -v grub-file >/dev/null; then
  grub-file --is-x86-multiboot "$folder/kickstart" || { echo 'Invalid Multiboot 1 header' >&2; exit 1; }
  echo 'OK: Kickstart Multiboot v1 header'
else
  echo 'NOTE: grub-file unavailable; Multiboot 1 header not checked here'
fi
