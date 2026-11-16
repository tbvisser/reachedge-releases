#!/usr/bin/env bash
# Reachedge: one-command install for macOS and Linux.
#   curl -fsSL https://raw.githubusercontent.com/tbvisser/reachedge-releases/main/install.sh | bash
#
# Installs everything in ~/.reachedge (no admin rights, nothing system-wide):
#   ~/.reachedge/runtime/node        private Node.js runtime
#   ~/.reachedge/app                 the Reachedge app
#   ~/.reachedge/data                your chats, connections and encrypted keys (kept on update)
#   ~/.reachedge/bin/reachedge       the `reachedge` command
# Options (env vars): REACHEDGE_HOME, REACHEDGE_PORT, REACHEDGE_TARBALL (local file or URL),
#   REACHEDGE_RELEASES_REPO (public GitHub repo with the release, default tbvisser/reachedge-releases),
#   REACHEDGE_NO_OPEN=1, REACHEDGE_NO_PATH=1 (don't touch shell rc files),
#   REACHEDGE_NO_SHORTCUT=1 (no ~/Applications/Reachedge.app)
set -euo pipefail

RELEASES_REPO="${REACHEDGE_RELEASES_REPO:-tbvisser/reachedge-releases}"
REACHEDGE_HOME="${REACHEDGE_HOME:-$HOME/.reachedge}"
NODE_MAJOR=24

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
say() { printf '  %s\n' "$*"; }
fail() { printf '\n  \033[31mError:\033[0m %s\n\n' "$*" >&2; exit 1; }

printf '\n'
bold "  Installing Reachedge"
printf '\n'

command -v curl >/dev/null 2>&1 || fail "curl is missing."
command -v tar >/dev/null 2>&1 || fail "tar is missing."

case "$(uname -s)" in
  Darwin) OS=darwin ;;
  Linux) OS=linux ;;
  *) fail "This operating system is not supported. On Windows, use install.ps1." ;;
esac
case "$(uname -m)" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64) ARCH=x64 ;;
  *) fail "Processor $(uname -m) is not supported." ;;
esac

mkdir -p "$REACHEDGE_HOME"/{runtime,bin,logs,data}
chmod 700 "$REACHEDGE_HOME" "$REACHEDGE_HOME/data"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

sha256() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }

# ── 1. Node.js runtime (private copy, verified checksum) ─────────────────────
NODE_BIN="$REACHEDGE_HOME/runtime/node/bin/node"
WANT_NODE="$(curl -fsSL "https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/SHASUMS256.txt" | grep -E "node-v[0-9.]+-${OS}-${ARCH}\.tar\.gz$" | head -1)" \
  || fail "Could not find Node.js. Are you connected to the internet?"
NODE_SUM="$(echo "$WANT_NODE" | awk '{print $1}')"
NODE_FILE="$(echo "$WANT_NODE" | awk '{print $2}')"
NODE_VERSION="$(echo "$NODE_FILE" | sed -E 's/node-(v[0-9.]+)-.*/\1/')"

if [[ -x "$NODE_BIN" && "$("$NODE_BIN" --version)" == "$NODE_VERSION" ]]; then
  say "Node.js $NODE_VERSION is already installed"
else
  say "Downloading Node.js $NODE_VERSION..."
  curl -fsSL "https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/$NODE_FILE" -o "$TMP/node.tgz" || fail "Downloading Node.js failed."
  [[ "$(sha256 "$TMP/node.tgz")" == "$NODE_SUM" ]] || fail "The Node.js checksum does not match."
  rm -rf "$REACHEDGE_HOME/runtime/node"
  mkdir -p "$TMP/node"
  tar -xzf "$TMP/node.tgz" -C "$TMP/node" --strip-components 1
  mv "$TMP/node" "$REACHEDGE_HOME/runtime/node"
fi

# ── 2. The app ───────────────────────────────────────────────────────────────
SRC="${REACHEDGE_TARBALL:-https://github.com/$RELEASES_REPO/releases/latest/download/reachedge.tar.gz}"
say "Downloading Reachedge..."
if [[ "$SRC" == http* ]]; then
  curl -fsSL "$SRC" -o "$TMP/reachedge.tgz" || fail "Downloading Reachedge failed ($SRC)."
else
  cp "$SRC" "$TMP/reachedge.tgz" || fail "File not found: $SRC"
fi
mkdir -p "$TMP/app"
tar -xzf "$TMP/reachedge.tgz" -C "$TMP/app" || fail "Unpacking failed."
[[ -f "$TMP/app/server.js" ]] || fail "The package is incomplete (server.js is missing)."

# Stop a running copy before swapping files.
if [[ -x "$REACHEDGE_HOME/bin/reachedge" ]]; then "$REACHEDGE_HOME/bin/reachedge" stop >/dev/null 2>&1 || true; fi
rm -rf "$REACHEDGE_HOME/app.old"
[[ -d "$REACHEDGE_HOME/app" ]] && mv "$REACHEDGE_HOME/app" "$REACHEDGE_HOME/app.old"
mv "$TMP/app" "$REACHEDGE_HOME/app"
rm -rf "$REACHEDGE_HOME/app.old"

# ── 3. The `reachedge` command ───────────────────────────────────────────────
cp "$REACHEDGE_HOME/app/launcher/reachedge" "$REACHEDGE_HOME/bin/reachedge"
chmod +x "$REACHEDGE_HOME/bin/reachedge"

LINE='export PATH="$HOME/.reachedge/bin:$PATH"'
[[ "$REACHEDGE_HOME" != "$HOME/.reachedge" ]] && LINE="export PATH=\"$REACHEDGE_HOME/bin:\$PATH\""
[[ "${REACHEDGE_NO_PATH:-}" == 1 ]] || for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [[ -f "$rc" || "$rc" == "$HOME/.zshrc" && "$OS" == darwin ]]; then
    grep -qF "$LINE" "$rc" 2>/dev/null || printf '\n# Reachedge\n%s\n' "$LINE" >>"$rc"
  fi
done

# macOS: a Reachedge app in ~/Applications (Launchpad / Spotlight).
if [[ "$OS" == darwin && "${REACHEDGE_NO_SHORTCUT:-}" != 1 ]] && command -v osacompile >/dev/null 2>&1; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Reachedge.app"
  osacompile -o "$HOME/Applications/Reachedge.app" -e "do shell script \"'$REACHEDGE_HOME/bin/reachedge' open >/dev/null 2>&1 &\"" >/dev/null 2>&1 || true
  if [[ -f "$REACHEDGE_HOME/app/public/reachedge.icns" && -d "$HOME/Applications/Reachedge.app" ]]; then
    cp "$REACHEDGE_HOME/app/public/reachedge.icns" "$HOME/Applications/Reachedge.app/Contents/Resources/applet.icns" 2>/dev/null || true
    touch "$HOME/Applications/Reachedge.app"
  fi
fi

# ── 4. Start ─────────────────────────────────────────────────────────────────
printf '\n'
if [[ "${REACHEDGE_NO_OPEN:-}" == 1 ]]; then
  "$REACHEDGE_HOME/bin/reachedge" start
else
  "$REACHEDGE_HOME/bin/reachedge" open
fi
printf '\n'
bold "  Done. Reachedge is running at http://127.0.0.1:${REACHEDGE_PORT:-3737}"
say "To start it later: type 'reachedge' in a new terminal window$([[ $OS == darwin ]] && echo ", or open Reachedge from Spotlight")."
say "Stop: reachedge stop · Update: reachedge update · Remove: reachedge uninstall"
printf '\n'
