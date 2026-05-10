# OH2P 1.58.6 OpenClaw Bootstrap v2 固件

## 产物

- 固件：`OH2P_1.58.6_openclaw-bootstrap-v2.squashfs`
- 基底：官方 Open-XiaoAI `OH2P_1.58.6_patched.squashfs`
- SHA256：`afb4c9a3bdf3c47e9c5350d156db3384667733012e93efc8c43ea46ff6c23efc`
- 大小：30,543,872 bytes
- system 分区上限：41,943,040 bytes
- 剩余空间：11,399,168 bytes

## v2 变化

v1 的 `/etc/rc.local` 同时包含官方 `/data/init.sh` 调用和 bootstrap 调用。v2 改为只调用 bootstrap：

```sh
[ -x "/usr/bin/openclaw-bootstrap.sh" ] && /usr/bin/openclaw-bootstrap.sh >/dev/null 2>&1 &
```

这样启动链路更干净：bootstrap 先校时、恢复 `/data/init.sh`、恢复 client，然后由 bootstrap 启动 `/data/init.sh`。

## SSH 安全性确认

SSH (`dropbear`) 是 `S50dropbear` 阶段启动；`rc.local` 在 `S95done` 阶段执行。因此 bootstrap 无论成功或失败，都不会阻塞 SSH 启动。

## 注入内容

只读 rootfs 内新增：

- `/usr/bin/openclaw-bootstrap.sh`
- `/usr/share/openclaw/client`
- `/etc/rc.local` 只保留 bootstrap 后台调用

bootstrap 行为：

1. 等待 `wlan0` 获得 IPv4
2. 使用 `ntp.aliyun.com` / `cn.pool.ntp.org` 校时
3. 创建兼容路径 `/tmp/mico_aivs_lab/usock -> /tmp/mipns/usock`
4. 如果 `/data/open-xiaoai/client` 丢失，从 `/usr/share/openclaw/client` 恢复
5. 如果 `/data/open-xiaoai/server.txt` 丢失，写入 `ws://192.168.3.27:4399`
6. 如果 `/data/init.sh` 丢失，写入最小启动脚本
7. 启动 `/data/init.sh`

原则：不 kill 原生小米服务，不修改 miio/mipns/mibrain 配置。

## 校验记录

已用 `unsquashfs` 反解包确认：

- `verify-v2/usr/bin/openclaw-bootstrap.sh` 存在且可执行
- `verify-v2/usr/share/openclaw/client` 存在且为 ARM 32-bit ELF
- `verify-v2/etc/rc.local` 只包含 bootstrap 调用，不包含 `/data/init.sh` 直调

## 刷写流程（macOS）

```bash
cd /tmp/open-xiaoai-research/packages/flash-tool
chmod +x ./flash

# 1. 连接设备：执行后给音箱断电再上电
./flash connect

# 2. 设置启动延时
./flash delay 15

# 3. 切到 boot0
./flash switch boot0

# 4. 刷写 system0
./flash system system0 /Users/openclaw/.openclaw/workspace/xiaoai-firmware/OH2P_1.58.6_openclaw-bootstrap-v2.squashfs
```

刷写完成后断电重启。

## 回滚

SSH 可用时：

```bash
fw_env -s boot_part boot1
reboot
```

或刷机工具：

```bash
./flash switch boot1
```

## 风险

- 刷错型号/版本或刷写中断可能变砖。
- 本固件基于 OH2P 1.58.6，不能用于其他型号或版本。
- 已保留官方 patched 固件的 SSH/禁 OTA 行为，并额外加入 OpenClaw bootstrap。
