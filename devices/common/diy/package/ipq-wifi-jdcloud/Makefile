#
# JDCloud RE-SS-01 (京东云亚瑟 AX1800 Pro) 板级校准数据 board-2.bin
#
# 为什么不用官方的 ipq-wifi-jdcloud_re-ss-01 包：
#   1) 官方包用 install-overlay 机制下发文件，apk 安装时带 --no-scripts，
#      postinst（functions.sh 里的 default_postinst）不会执行，
#      overlay 里的文件不会落到 / 根目录；
#   2) 打开 CONFIG_TARGET_PER_DEVICE_ROOTFS 后设备包会被降级成模块( =m )，
#      镜像阶段 include/image.mk 用 apk 从本地索引安装它时报：
#        ERROR: unable to select packages:
#          ipq-wifi-jdcloud_re-ss-01 (no such package):
#            required by: world[ipq-wifi-jdcloud_re-ss-01]
#        make[5]: *** [.../include/image.mk:397: target-dir-3458f57f] Error 1
#        → ERROR: target/linux failed to build.
#   所以改成自建的普通包（直接 install 到 ath11k 期望的路径），=y 即可。
#
# 文件来源（官方固件仓库，固定 commit）：
#   https://github.com/openwrt/firmware_qca-wireless
#   e20f4c6ff197823762319e4b7e31af01816503cf/board-jdcloud_re-ss-01.ipq6018
#   md5: 893b945c4ac94dddc1c48047243bcc65  size: 65640
#
# 安装路径与上游 ipq-wifi 一致：
#   ath11k 通过 ath11k_core_create_firmware_path() 请求
#   "ath11k/<fw.dir>/board-2.bin"，IPQ6018 的 fw.dir 是 IPQ6018/hw1.0，
#   即 /lib/firmware/ath11k/IPQ6018/hw1.0/board-2.bin
#
include $(TOPDIR)/rules.mk

PKG_NAME:=ipq-wifi-jdcloud
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=HarveyJiang

include $(INCLUDE_DIR)/package.mk

define Package/ipq-wifi-jdcloud
  SECTION:=firmware
  CATEGORY:=Firmware
  SUBMENU:=ath11k Board-Specific Overrides
  TITLE:=board-2.bin Overrides for JDCloud RE-SS-01 (AX1800 Pro)
  PKGARCH:=all
  DEPENDS:=+ath11k-firmware-ipq6018
endef

define Package/ipq-wifi-jdcloud/description
Board specific calibration data (board-2.bin) for the JDCloud RE-SS-01.
Only needed for this device.
endef

define Build/Compile
endef

define Package/ipq-wifi-jdcloud/install
	$(INSTALL_DIR) $(1)/lib/firmware/ath11k/IPQ6018/hw1.0
	$(INSTALL_DATA) ./files/board-2.bin $(1)/lib/firmware/ath11k/IPQ6018/hw1.0/board-2.bin
	$(INSTALL_DIR) $(1)/lib/firmware/IPQ6018/hw1.0
	$(INSTALL_DATA) ./files/board-2.bin $(1)/lib/firmware/IPQ6018/hw1.0/board-2.bin
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
