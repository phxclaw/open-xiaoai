#!/bin/sh
# OpenClaw bootstrap for OH2P.
# Lives in read-only patched rootfs so factory reset / unbind wiping /data can recover.
# Conservative: do not kill or modify native Xiaomi services.
LOG=/tmp/openclaw-bootstrap.log
SERVER_DEFAULT="ws://192.168.3.27:4399"
CLIENT_BAK="/usr/share/openclaw/client"
{
  echo "=== bootstrap $(date) ==="
  i=0
  while [ $i -lt 90 ]; do
    if ifconfig wlan0 2>/dev/null | grep -q "inet addr:"; then
      echo "wlan0 has IPv4"
      break
    fi
    i=$((i + 1))
    sleep 1
  done
  echo "before ntp: $(date)"
  /usr/sbin/ntpd -n -q -p ntp.aliyun.com >/tmp/openclaw-ntpd.log 2>&1 || \
  /usr/sbin/ntpd -n -q -p cn.pool.ntp.org >>/tmp/openclaw-ntpd.log 2>&1 || true
  echo "after ntp: $(date)"
  mkdir -p /tmp/mico_aivs_lab
  ln -sfn /tmp/mipns/usock /tmp/mico_aivs_lab/usock 2>/dev/null || true
  mkdir -p /data/open-xiaoai
  if [ ! -f /data/open-xiaoai/server.txt ]; then
    echo "$SERVER_DEFAULT" > /data/open-xiaoai/server.txt
  fi
  if [ ! -x /data/open-xiaoai/client ] && [ -x "$CLIENT_BAK" ]; then
    cp "$CLIENT_BAK" /data/open-xiaoai/client
    chmod +x /data/open-xiaoai/client
    echo "restored client from rootfs backup"
  fi
  if [ ! -x /data/init.sh ]; then
    cat > /data/init.sh <<'INIT_EOF'
#!/bin/sh
LOG=/tmp/open-xiaoai-init.log
{
  echo "=== init $(date) ==="
  for i in $(seq 1 60); do
    if ifconfig wlan0 2>/dev/null | grep -q "inet addr:"; then break; fi
    sleep 1
  done
  echo "before ntp: $(date)"
  /usr/sbin/ntpd -n -q -p ntp.aliyun.com >/tmp/open-xiaoai-ntpd.log 2>&1 || true
  echo "after ntp: $(date)"
  mkdir -p /tmp/mico_aivs_lab
  ln -sfn /tmp/mipns/usock /tmp/mico_aivs_lab/usock 2>/dev/null || true
  if [ -x /data/open-xiaoai/client ]; then
    killall client 2>/dev/null || true
    SERVER=$(cat /data/open-xiaoai/server.txt 2>/dev/null)
    [ -n "$SERVER" ] || SERVER="ws://192.168.3.27:4399"
    cd /data/open-xiaoai
    ./client "$SERVER" >/tmp/open-xiaoai-client.log 2>&1 &
    echo "client started: $SERVER"
  else
    echo "client missing"
  fi
} >> "$LOG" 2>&1
exit 0
INIT_EOF
    chmod +x /data/init.sh
    echo "restored /data/init.sh"
  fi
  if [ -x /data/init.sh ]; then
    sh /data/init.sh >/dev/null 2>&1 &
  fi
} >> "$LOG" 2>&1
exit 0
