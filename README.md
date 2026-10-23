# Kwrt-slim

精简版 [Kwrt](https://github.com/kiddin9/Kwrt)，只编译 **京东云亚瑟 AX1800 Pro（JDCloud RE-SS-01）** 一个机型。

## 结构

```
devices/
├── common/                    # 公共层（feeds、补丁、通用 .config）
│   ├── settings.ini           # openwrt 源码地址与分支策略
│   ├── .config                # 通用配置
│   ├── diy.sh                 # 公共定制脚本
│   ├── patches/               # 公共补丁
│   └── diy/                   # 公共覆盖文件
└── qualcommax_ipq60xx/        # 目标平台层
    ├── .config                # 平台 + 单设备选择
    ├── diy.sh                 # NSS 化脚本
    └── patches/               # 平台补丁
```

## 编译

Actions → Build OpenWrt → Run workflow（手动触发，无参数）。

## 刷机

- **U-Boot 刷入**：用 `*-factory.bin`（或 `*-initramfs` 先引导再 sysupgrade）。
  进 U-Boot：电脑 IP 设 `192.168.1.2/24` → 断电按住 reset 上电，LED 红闪 5 次变蓝 → 浏览器开 `192.168.1.1` → 上传 factory.bin 点更新 → 绿灯亮 3 秒即成功。
- **后台升级**：用 `*-sysupgrade.bin`。
- 默认 LAN IP `10.0.0.1`，root 无密码。

## 固件体积

实机是 **eMMC**（64G/128G/256G 批次不同，不是 NAND）。**60MB 上限不是 U-Boot 的限制**，而是原厂 GPT 里
rootfs 分区 `p18` 只有 60MiB：`factory.bin` = kernel(6MB 写 `0:HLOS` p16) + `rootfs.squashfs`（写 p18，
p18 剩余空间挂 `/dev/loop0` 当 overlay，故 p18 = 固件 + overlay 总容量）。`sysupgrade` 同样写 p18，
一样受分区大小约束。要刷更大的固件需先刷 GPT 扩容模板 `gpt-JDC_AX1800_Pro_dual-boot_rootfs2048M_no-last-partition.bin`
（亚瑟专用，别用雅典娜的）。CI 在 `Verify build output` 步骤打印 factory.bin 实际体积，超过只警告、不判失败。

当前精简配置实测预算（2026-10-23）：rootfs ≈ **37MB**、factory.bin ≈ **40MB**，余量 ~22MB（p18=60MiB）。
主要取舍：

| 功能 | apk 体积 | 当前 |
| --- | --- | --- |
| Docker（dockerd/docker/compose/containerd/runc） | 约 85MB | **不进镜像**（需要时 `apk add` 装 overlay） |
| OpenList（含内嵌前端） | 约 44MB | **不进镜像**（需要时 `apk add` 装 overlay） |
| xray-core | 约 10MB | 开 |
| aria2 + ariang + luci-app-aria2 | 约 1.7MB | 开 |
| Tailscale | 约 10.6MB（官方 feed 精简版） | **开（编入镜像，含 kmod-tun + ca-bundle）** |
| 实用工具（mtr-json/drill/iperf3/tmux/lsof/jq/gdisk/vnstat/zstd/rsync/ifstat/fio + htop/nano/btop/ncdu/duf） | 约 4MB | 开 |

换算：squashfs 体积 ≈ apk 体积 × 0.73。Docker/OpenList 的包本体都还在
`devices/common/.config` 里，随时改回 `=y` 恢复。

## 说明

- target：`qualcommax/ipq60xx`，device：`jdcloud_re-ss-01`（ipq6000，DEVICE_DTS_CONFIG `config@cp03-c2`）。
- 校准数据 `board-jdcloud_re-ss-01.ipq6018` 由上游 `firmware_qca-wireless` 源码自带。
- 无线走 NSS 方案（LiBwrt/openwrt-6.x `25.12-nss`）。
