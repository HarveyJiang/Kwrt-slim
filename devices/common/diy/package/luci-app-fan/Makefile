# Copyright (C) 2016 Openwrt.org
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI fan control
LUCI_DEPENDS:=+coreutils-stat +kmod-hwmon-pwmfan +kmod-thermal
LUCI_PKGARCH:=all
# apk 的版本语法（Alpine apk-tools src/version.c）里 '-r' 只能出现一次：
#   case '-': if (t->token >= TOKEN_REVISION_NO) goto invalid;
#             if (!apk_blob_pull_blob_match(b, "-r")) goto invalid;
# 而 openwrt 打包时会把版本拼成 "$(PKG_VERSION)-r$(PKG_RELEASE)"。
# 原来的 PKG_VERSION=1.0.0-r3 于是拼出 1.0.0-r3-r1，第二个 -r 让 apk mkpkg
# 报 "package version is invalid" 而编译失败（旧 opkg 时代无所谓）。
# 故这里把 -rN 从 PKG_VERSION 移除，N 挪进 PKG_RELEASE。
PKG_VERSION:=1.0.0
PKG_RELEASE:=3
PKG_MAINTAINER:=jjm2473 <jjm2473@gmail.com>

define Package/luci-app-fan/conffiles
/etc/config/luci-fan
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

