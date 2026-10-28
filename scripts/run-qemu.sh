#!/usr/bin/env bash
# BIOS/TCG test on an old PC-compatible machine, with VGA + serial capture.
# SPDX-License-Identifier: 0BSD
set -euo pipefail
if (( $# < 1 || $# > 2 )); then
  echo 'Usage: ./run-qemu.sh <pistachio.iso> [--gdb]' >&2
  exit 2
fi
command -v qemu-system-x86_64 >/dev/null || { echo 'Install qemu-system-x86' >&2; exit 1; }
[[ -s "$1" ]] || { echo "ISO not found: $1" >&2; exit 1; }
iso="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
extra=()
if [[ "${2:-}" == '--gdb' ]]; then
  extra=(-S -s)
elif [[ $# -eq 2 ]]; then
  echo 'Unknown option (only --gdb is accepted)' >&2
  exit 2
fi
qemu-system-x86_64 \
  -machine pc,accel=tcg \
  -cpu max -smp 1 -m 256M \
  -boot order=d -cdrom "$iso" \
  -serial stdio -monitor none \
  -debugcon file:qemu-early.log -global isa-debugcon.iobase=0xe9 \
  -no-reboot -no-shutdown \
  -d guest_errors,int,cpu_reset -D qemu-guest-errors.log \
  "${extra[@]}"
