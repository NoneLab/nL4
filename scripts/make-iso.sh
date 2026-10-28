#!/usr/bin/env bash
# L4Ka::Pistachio QEMU BIOS/Multiboot-v1 ISO generator.
# SPDX-License-Identifier: 0BSD
set -euo pipefail

usage() {
  cat <<'END'
Usage: ./make-iso.sh <kickstart> <x86-kernel> <sigma0> <root-task> [output.iso]

Example:
  ./make-iso.sh \
    ../user-build/util/kickstart/kickstart \
    ../build/x86-x64-p4-nokdb/x86-kernel \
    ../user-build/serv/sigma0/sigma0 \
    ../user-build/apps/bench/pingpong/pingpong \
    pistachio.iso

All four inputs must be real, compatible L4Ka::Pistachio ELF binaries.
Do not supply a Linux kernel, nor use grub's multiboot2 command.
END
}
if [[ "${1:-}" == '-h' || "${1:-}" == '--help' ]]; then usage; exit 0; fi
if (( $# < 4 || $# > 5 )); then usage >&2; exit 2; fi
for tool in grub-mkrescue grub-file mktemp cp; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing command: $tool" >&2; exit 1; }
done
for path in "$1" "$2" "$3" "$4"; do
  [[ -s "$path" ]] || { echo "Missing/empty boot image: $path" >&2; exit 1; }
done
if ! grub-file --is-x86-multiboot "$1"; then
  echo "Kickstart lacks a GRUB-recognized Multiboot v1 header: $1" >&2
  exit 1
fi
output="${5:-pistachio.iso}"
# Save input paths before cd into the staging directory.
inputs=()
for path in "$1" "$2" "$3" "$4"; do
  inputs+=("$(cd "$(dirname "$path")" && pwd)/$(basename "$path")")
done
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
staging="$(mktemp -d)"
trap 'rm -rf -- "$staging"' EXIT
mkdir -p "$staging/iso/boot/grub"
cp -- "${inputs[0]}" "$staging/iso/boot/kickstart"
cp -- "${inputs[1]}" "$staging/iso/boot/x86-kernel"
cp -- "${inputs[2]}" "$staging/iso/boot/sigma0"
cp -- "${inputs[3]}" "$staging/iso/boot/roottask"
cat > "$staging/iso/boot/grub/grub.cfg" <<'END'
set default=0
set timeout=2
menuentry 'L4Ka::Pistachio (Multiboot v1)' {
    multiboot /boot/kickstart
    module /boot/x86-kernel
    module /boot/sigma0
    module /boot/roottask
    boot
}
END
grub-mkrescue -o "$output" "$staging/iso"
echo "Created $output"
