#!/usr/bin/env bash
set -euo pipefail

VERSION="1.1.1"
BASE_URL="${CAMPUSBOOP_BASE_URL:-https://campusboop.creatorpromote.com}"
INSTALL_DIR="${HOME}/.local/share/campusboop"
BIN_DIR="${HOME}/.local/bin"
COMMAND_PATH="${BIN_DIR}/campusboop"
APP_DESKTOP="${HOME}/.local/share/applications/CampusBoop.desktop"
CONFIG_ROOT="${XDG_CONFIG_HOME:-${HOME}/.config}/campusboop"

case "$(uname -m)" in
  x86_64|amd64)
    PACKAGE="CampusBoop-v${VERSION}-Linux-x64.zip"
    EXPECTED_SHA="627bb8748f20d3e31a8d9559e4beae9d4b96e8b48b88298d58ed71ec8d838c56"
    ;;
  aarch64|arm64)
    PACKAGE="CampusBoop-v${VERSION}-Linux-ARM64.zip"
    EXPECTED_SHA="30c994f64815fea92dc2ce9e8f10c2be7b6cc48988ac29cbeab6d29ad1c688f8"
    ;;
  *)
    echo "CampusBoop: unsupported CPU architecture: $(uname -m)" >&2
    echo "Supported Linux builds: x64 (Intel/AMD) and ARM64." >&2
    exit 1
    ;;
esac

need() { command -v "$1" >/dev/null 2>&1 || { echo "CampusBoop installer needs '$1'." >&2; exit 1; }; }
need unzip
if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fL --retry 2 --connect-timeout 15 "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -q --https-only -O "$2" "$1"; }
else
  echo "CampusBoop installer needs curl or wget." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ZIP="${TMP}/${PACKAGE}"

echo "CampusBoop v${VERSION} // Linux installer"
echo "Detected CPU: $(uname -m)"
echo "Downloading ${PACKAGE}..."
fetch "${BASE_URL}/downloads/${PACKAGE}" "$ZIP"

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA="$(sha256sum "$ZIP" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
else
  echo "CampusBoop installer needs sha256sum or shasum to verify the download." >&2
  exit 1
fi
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "CampusBoop: SHA-256 verification failed. Nothing was installed." >&2
  exit 1
fi
echo "SHA-256 verified."

# Ask an already-running copy to exit before updating it.
if [ -f "${CONFIG_ROOT}/port" ] && command -v curl >/dev/null 2>&1; then
  PORT="$(cat "${CONFIG_ROOT}/port" 2>/dev/null || true)"
  if [ -n "$PORT" ]; then
    curl -fsS -X POST -H 'Content-Type: application/json' -d '{"action":"exit"}' "http://127.0.0.1:${PORT}/api/action" >/dev/null 2>&1 || true
    sleep 0.3
  fi
fi

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$(dirname "$APP_DESKTOP")"
unzip -q "$ZIP" -d "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/CampusBoop"

cat > "$COMMAND_PATH" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/.local/share/campusboop"
APP="$ROOT/CampusBoop"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/campusboop"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/CampusBoop.desktop"
APP_DESKTOP="$HOME/.local/share/applications/CampusBoop.desktop"
SELF="$HOME/.local/bin/campusboop"

stop_running() {
  if [ -f "$CONFIG_ROOT/port" ] && command -v curl >/dev/null 2>&1; then
    p="$(cat "$CONFIG_ROOT/port" 2>/dev/null || true)"
    if [ -n "$p" ]; then
      curl -fsS -X POST -H 'Content-Type: application/json' -d '{"action":"exit"}' "http://127.0.0.1:${p}/api/action" >/dev/null 2>&1 || true
      sleep 0.3
    fi
  fi
}

case "${1:-}" in
  --uninstall)
    stop_running
    rm -f "$AUTOSTART" "$APP_DESKTOP"
    rm -rf "$ROOT"
    rm -f "$SELF"
    echo "CampusBoop removed. Your settings were kept in: $CONFIG_ROOT"
    echo "For a complete reset/removal, use campusboop --purge before uninstalling next time or remove that settings folder manually."
    exit 0
    ;;
  --purge)
    stop_running
    rm -f "$AUTOSTART" "$APP_DESKTOP"
    rm -rf "$ROOT" "$CONFIG_ROOT"
    rm -f "$SELF"
    echo "CampusBoop and its local settings were removed."
    exit 0
    ;;
esac

if [ ! -x "$APP" ]; then
  echo "CampusBoop is not installed correctly. Reinstall from https://campusboop.creatorpromote.com" >&2
  exit 1
fi
exec "$APP" "$@"
WRAPPER
chmod +x "$COMMAND_PATH"

cat > "$APP_DESKTOP" <<EOF2
[Desktop Entry]
Type=Application
Name=CampusBoop
Comment=Student check-in, commit, break and checkout reminder
Exec=${COMMAND_PATH}
Terminal=false
Categories=Education;Utility;
Icon=${INSTALL_DIR}/campusboop.png
EOF2

if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
  touch "${HOME}/.profile"
  if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.profile"; then
    printf '\n# CampusBoop / user commands\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "${HOME}/.profile"
  fi
fi

printf '\nCampusBoop is installed.\n\n'
printf '  Start:       campusboop\n'
printf '  Background:  campusboop --background\n'
printf '  Auto-start:  campusboop --autostart-on\n'
printf '  Help:        campusboop --help\n'
printf '  Uninstall:   campusboop --uninstall\n'
printf '  Full remove: campusboop --purge\n\n'
printf 'Instructions: %s/#instructions\n' "$BASE_URL"
printf '\033]8;;%s/#instructions\033\\Open CampusBoop instructions\033]8;;\033\\\n' "$BASE_URL" 2>/dev/null || true
if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
  printf '\n~/.local/bin was added to ~/.profile. Open a new terminal before using the short command.\n'
  printf 'You can start it right now with: %s\n' "$COMMAND_PATH"
fi

# On normal graphical sessions, open first-run setup after installation/update.
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  nohup "$COMMAND_PATH" >/dev/null 2>&1 &
fi
