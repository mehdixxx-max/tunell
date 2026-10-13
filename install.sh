#!/usr/bin/env bash
# Tunnel Forge GitHub bootstrap for mehdixxx-max/tunell.
set -Eeuo pipefail

RELEASE_URL='https://github.com/mehdixxx-max/tunell/releases/download/v0.2.0'
ARCHIVE='tunnel-forge-0.2.0-bundle.zip'
EXPECTED_SHA256='4ac9b7a2d42abf77726b93e372361f60c8d3eb4bff58422d223b71a9b4727116'

fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
[[ $(uname -s) == Linux ]] || fail 'Linux is required.'
[[ $(uname -m) == x86_64 ]] || fail 'This supplied bundle requires Linux x86_64.'

SUDO=()
if (( EUID != 0 )); then
    command -v sudo >/dev/null || fail 'Run as root or install sudo.'
    SUDO=(sudo)
    sudo -v
fi

missing=()
for tool in curl unzip python3; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if (( ${#missing[@]} )); then
    command -v apt-get >/dev/null || fail 'Install curl, unzip and Python 3.11+ first.'
    "${SUDO[@]}" apt-get update
    "${SUDO[@]}" apt-get install -y "${missing[@]}"
fi
python3 -c 'import sys; assert sys.version_info >= (3,11)' 2>/dev/null \
    || fail 'Python 3.11+ is required. Ubuntu 24.04 is recommended.'
python3 -c 'import curses,tomllib' 2>/dev/null \
    || fail 'This Python installation must include curses and tomllib.'

WORK_DIR=$(mktemp -d /tmp/tunnel-forge-install.XXXXXXXX)
cleanup() {
    case "${WORK_DIR:-}" in
        /tmp/tunnel-forge-install.*) rm -rf -- "$WORK_DIR" ;;
    esac
}
trap cleanup EXIT
trap 'printf "\nInstallation stopped at line %s.\n" "$LINENO" >&2' ERR

printf '\nTunnel Forge / download and install\n'
curl --fail --location --show-error --retry 3 --connect-timeout 15 --max-time 600 \
    "$RELEASE_URL/$ARCHIVE" -o "$WORK_DIR/$ARCHIVE"
printf '%s  %s\n' "$EXPECTED_SHA256" "$WORK_DIR/$ARCHIVE" | sha256sum --check --status \
    || fail 'Archive checksum mismatch. Nothing from the archive was executed.'
unzip -q "$WORK_DIR/$ARCHIVE" -d "$WORK_DIR"
[[ -f "$WORK_DIR/tunnel-forge/install.sh" ]] || fail 'Missing bundled installer.'
"${SUDO[@]}" bash "$WORK_DIR/tunnel-forge/install.sh"

printf '\nPanel installed. Engines are installed separately from its menu.\n'
if [[ -t 1 && -r /dev/tty ]]; then
    cleanup
    trap - EXIT
    "${SUDO[@]}" /usr/local/bin/tunnel-forge </dev/tty
else
    printf 'Open the panel with: sudo tunnel-forge\n'
fi