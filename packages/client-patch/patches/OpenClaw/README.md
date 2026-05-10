# OpenClaw bootstrap patch

This optional patch injects a minimal OpenClaw recovery bootstrap into the patched XiaoAI rootfs.

It is intended for Xiaomi Smart Speaker Pro / OH2P firmware `1.58.6`, based on the existing Open-XiaoAI patched firmware flow.

## What it adds

- `/usr/bin/openclaw-bootstrap.sh`
- optional `/usr/share/openclaw/client` backup binary, if `temp/openclaw-client` exists during build
- `/etc/rc.local` that starts `openclaw-bootstrap.sh` in the background after system init
- backup of the previous rc.local at `/etc/rc.local.before-openclaw`

## Runtime behavior

The bootstrap is conservative. It does **not** kill native Xiaomi services and does **not** change miio / mipns / mibrain configs.

On boot it:

1. waits for `wlan0` IPv4
2. syncs time via `ntp.aliyun.com` / `cn.pool.ntp.org`
3. creates `/tmp/mico_aivs_lab/usock -> /tmp/mipns/usock`
4. restores `/data/open-xiaoai/client` from `/usr/share/openclaw/client` if missing
5. writes `/data/open-xiaoai/server.txt` as `ws://192.168.3.27:4399` if missing
6. restores a minimal `/data/init.sh` if missing
7. starts `/data/init.sh`

## How to include client backup

Before `npm run patch`, place the ARM client binary at:

```text
packages/client-patch/temp/openclaw-client
```

The patch script will copy it to `/usr/share/openclaw/client` inside rootfs.

## Safety

SSH (`dropbear`) starts before `rc.local`, so bootstrap failure should not block SSH access.

## DID compatibility shim

`miio_did_fix.c` is a small LD_PRELOAD helper used during local debugging for Xiaomi DID overflow cases. It redirects `json_object_new_int()` to `json_object_new_int64()` when the value hits `2147483647`, so newer DID values do not get truncated by 32-bit integer handling.

This file is kept as source/reference only; it is not injected into firmware by default.
