#!/usr/bin/env bash
set -euo pipefail

# Inject OpenClaw bootstrap into patched XiaoAI rootfs.
# Executed by packages/client-patch/src/patch.sh while cwd is temp/squashfs-root.

ROOT="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_SRC="$SCRIPT_DIR/OpenClaw/openclaw-bootstrap.sh"
CLIENT_SRC="$SCRIPT_DIR/OpenClaw/client"
DID_SHIM_SRC="$SCRIPT_DIR/OpenClaw/libmiio_did_fix.so"

if [ ! -f "$BOOTSTRAP_SRC" ]; then
  echo "❌ missing OpenClaw bootstrap template: $BOOTSTRAP_SRC"
  exit 1
fi

mkdir -p "$ROOT/usr/bin" "$ROOT/usr/share/openclaw"
install -m 0755 "$BOOTSTRAP_SRC" "$ROOT/usr/bin/openclaw-bootstrap.sh"

if [ -f "$CLIENT_SRC" ]; then
  install -m 0755 "$CLIENT_SRC" "$ROOT/usr/share/openclaw/client"
else
  echo "⚠️ OpenClaw client binary not found at $CLIENT_SRC"
  echo "   The firmware will still include bootstrap, but cannot restore /data/open-xiaoai/client after factory reset."
fi

if [ -f "$DID_SHIM_SRC" ]; then
  install -m 0755 "$DID_SHIM_SRC" "$ROOT/usr/share/openclaw/libmiio_did_fix.so"
  if [ -f "$ROOT/etc/init.d/miio" ]; then
    if ! grep -q "libmiio_did_fix.so" "$ROOT/etc/init.d/miio"; then
      cp "$ROOT/etc/init.d/miio" "$ROOT/etc/init.d/miio.before-openclaw-did"
      python3 - <<'PY_PATCH_MIIO'
from pathlib import Path
p = Path('etc/init.d/miio')
s = p.read_text()
old = "    procd_open_instance\n    procd_set_param command /usr/bin/miio_helper\n"
new = """    procd_open_instance
    # OpenClaw DID compatibility shim: avoid 32-bit DID truncation in miio_helper.
    procd_set_param env LD_PRELOAD=/usr/share/openclaw/libmiio_did_fix.so
    procd_set_param command /usr/bin/miio_helper
"""
if old not in s:
    raise SystemExit('miio helper command block not found')
p.write_text(s.replace(old, new, 1))
PY_PATCH_MIIO
      chmod 0755 "$ROOT/etc/init.d/miio"
    fi
  else
    echo "⚠️ /etc/init.d/miio not found; DID shim copied but not wired"
  fi
else
  echo "⚠️ DID shim not found at $DID_SHIM_SRC; skipping miio LD_PRELOAD patch"
fi

if [ -f "$ROOT/etc/rc.local" ] && [ ! -f "$ROOT/etc/rc.local.before-openclaw" ]; then
  cp "$ROOT/etc/rc.local" "$ROOT/etc/rc.local.before-openclaw"
fi

cat > "$ROOT/etc/rc.local" <<'RCLOCAL'
# Put your custom commands here that should be executed once
# the system init finished.

[ -x "/usr/bin/openclaw-bootstrap.sh" ] && /usr/bin/openclaw-bootstrap.sh >/dev/null 2>&1 &

exit 0
RCLOCAL
chmod 0755 "$ROOT/etc/rc.local"

echo "✅ OpenClaw bootstrap injected"
