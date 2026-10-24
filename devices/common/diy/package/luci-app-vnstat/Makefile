#
# Copyright (C) 2008-2014 The LuCI Team <luci@lists.subsignal.org>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#
# 从官方 openwrt-23.05 luci feed 的 applications/luci-app-vnstat 原样移植：
# 25.12 的 luci feed 已删除该应用，这里本地内置以保留 LuCI 流量页面。
# 依赖 vnstati 生成 PNG 图表（自动拉 libgd-full）。

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for VnStat
LUCI_DEPENDS:=+luci-compat +vnstat +vnstati

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
