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

- **U-Boot 刷入**：用 `*-factory.bin`（或 `*-initramfs` 先引导再 sysupgrade），注意 U-Boot 对固件体积有限制，固件需控制在 60MB 以内。
- **后台升级**：用 `*-sysupgrade.bin`。
- 默认 LAN IP `10.0.0.1`，root 无密码。

## 固件体积

AX1800 Pro 是 128MB NAND，U-Boot 刷入上限是 **60MB**。`factory.bin` = kernel(6MB) + `rootfs.squashfs`，
所以 rootfs 要 < 54MB。CI 在 `Verify build output` 步骤会打印 `factory.bin` 的实际体积，
超过 60MB 只给警告、不判失败（`sysupgrade` 直写 MTD，不走 U-Boot 的体积限制）。

当前默认包集合实测（2026-10-21，run 39584003439）：apk 166MB → squashfs 120MB → **factory.bin 126MB**，
超过 60MB 上限，**U-Boot 直刷会失败**。体积大头：

| 功能 | apk 体积 | 默认 |
| --- | --- | --- |
| Docker（dockerd / docker / compose / containerd / runc） | 约 85MB | 开 |
| OpenList（含内嵌前端） | 约 44MB | 开 |
| xray-core | 约 10MB | 开 |

要压到 60MB 以内，Docker 与 OpenList 必须**同时**去掉，去掉一个都不够：
只去 Docker → factory.bin 约 65MB，只去 OpenList → 约 95MB，两个都去 → 约 33MB。
做法是把 `devices/common/.config` 里这两段的 `=y` 改成 `=n`（包本体都还在，随时改回 `=y` 恢复）。
换算：squashfs 体积 ≈ apk 体积 × 0.73。

## 说明

- target：`qualcommax/ipq60xx`，device：`jdcloud_re-ss-01`（ipq6000，DEVICE_DTS_CONFIG `config@cp03-c2`）。
- 校准数据 `board-jdcloud_re-ss-01.ipq6018` 由上游 `firmware_qca-wireless` 源码自带。
- 无线走 NSS 方案（LiBwrt/openwrt-6.x `25.12-nss`）。
