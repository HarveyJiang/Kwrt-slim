#!/bin/bash
#=================================================
shopt -s extglob

# 不再引入第三方 feed；openlist / luci-app-openlist / zip 等独有包已内置到 diy/package/
# 已内置在 devices/common/diy/package/ 下，随 diy 一起拷进源码树。
sed -i "/telephony/d" feeds.conf.default

sed -i "s?targets/%S/packages?targets/%S/\$(LINUX_VERSION)?" include/feeds.mk

sed -i '/	refresh_config();/d' scripts/feeds

sed -i "s?git.openwrt.org/\(project\|feed\)?github.com/openwrt?g" feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a

sed --follow-symlinks -i "s#%C\"#%C\"#" package/base-files/files/etc/os-release
sed -i -e '$a /etc/bench.log' \
        -e '/\/etc\/profile/d' \
        -e '/\/etc\/shinit/d' \
        package/base-files/files/lib/upgrade/keep.d/base-files-essential
sed -i -e '/^\/etc\/profile/d' \
        -e '/^\/etc\/shinit/d' \
        package/base-files/Makefile
sed -i "s/192.168.1/10.0.0/" package/base-files/files/bin/config_generate

sed -i "s#false; \\\#true; \\\#" include/download.mk

wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/package/kernel/linux/modules/video.mk -P package/kernel/linux/modules/
wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/package/network/utils/nftables/patches/002-nftables-add-fullcone-expression-support.patch -P package/network/utils/nftables/patches/
wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/package/libs/libnftnl/patches/001-libnftnl-add-fullcone-expression-support.patch -P package/libs/libnftnl/patches/
wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/package/firmware/wireless-regdb/patches/600-custom-change-txpower-and-dfs.patch -P package/firmware/wireless-regdb/patches/
wget -N  https://github.com/coolsnowwolf/lede/raw/refs/heads/master/package/system/fstools/patches/0200-ntfs3-with-utf8.patch -P package/system/fstools/patches/
wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/config/Config-kernel.in -P config/

rm -rf package/libs/openssl package/network/services/ppp
git_clone_path openwrt-25.12 https://github.com/immortalwrt/immortalwrt package/libs/openssl package/network/services/ppp

echo "$(date +"%s")" >version.date
sed -i "s/DEFAULT_PACKAGES:=/DEFAULT_PACKAGES:=luci-app-advancedplus luci-app-sysctl luci-app-firewall luci-app-package-manager luci-app-upnp luci-app-syscontrol \
luci-app-wizard luci-base luci-compat \
coremark wget-ssl curl autocore htop nano zram-swap kmod-lib-zstd kmod-tcp-bbr bash openssh-sftp-server block-mount resolveip ds-lite swconfig luci-app-fan luci-app-footstrap-files /" include/target.mk

sed -i "s/^.*vermagic$/\techo '1' > \$(LINUX_DIR)\/.vermagic/" include/kernel-defaults.mk

wget -N https://raw.githubusercontent.com/openwrt/packages/master/lang/golang/golang/Makefile -P feeds/packages/lang/golang/golang/

#sed -i "/call Build\/check-size,\$\$(KERNEL_SIZE)/d" include/image.mk

git_clone_path master https://github.com/coolsnowwolf/lede mv target/linux/generic/hack-6.12

rm -rf target/linux/generic/hack-6.12/767-net-phy-realtek-add-led*
wget -N https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/generic/pending-6.12/613-netfilter_optional_tcp_window_check.patch -P target/linux/generic/pending-6.12/

# find target/linux/x86 -name "config*" -exec bash -c 'cat kernel.conf >> "{}"' \;
sed -i 's/max_requests 3/max_requests 20/g' package/network/services/uhttpd/files/uhttpd.config
#rm -rf ./feeds/packages/lang/{golang,node}
sed -i "s/tty\(0\|1\)::askfirst/tty\1::respawn/g" target/linux/*/base-files/etc/inittab

# 版本号：apk 的版本语法（Alpine apk-tools src/version.c）规定 '~' 之后只能
# 跟十六进制字符 [0-9a-fA-F] 且不能为空，遇到 '.' 会直接判 INVALID，
# 于是 '1719~10.20.2026' 会让 apk mkpkg 报 "package version is invalid" 而编译失败。
# 所以这里只生成纯数字日期段（如 1719~20261020）。要显示完整日期请用
# VERSION_NUMBER（仅展示，不参与 apk 版本解析），不要往 REVISION 里塞点号。
date=`date +%Y%m%d`
case "$date" in
	*[!0-9]*) echo "ERROR: 生成的版本日期 '$date' 含非数字字符，apk 会拒绝该版本号" >&2; exit 1 ;;
esac
sed -i -e "/\(# \)\?REVISION:=/c\REVISION:=$date" -e '/VERSION_CODE:=/c\VERSION_CODE:=$(REVISION)' include/version.mk

# ---------------------------------------------------------------------------
# apk 版本号合法性预检
#
# opkg 把版本号当普通字符串，apk 则会用严格的词法分析（Alpine apk-tools
# src/version.c 的 token_next()），非法版本号会在打包阶段才炸，白等几小时。
# 规则（见 version.c）：
#   1. '~' 后只能跟十六进制字符 [0-9a-fA-F] 且非空（TOKEN_COMMIT_HASH）
#   2. '-rN' 只能出现一次，且必须是版本串的最后一段（TOKEN_REVISION_NO）
#   3. '.' 只能跟在数字段后面（不能开头、不能连续、不能结尾）
#
# 打包时 openwrt 用的是 "$(PKG_VERSION)-r$(PKG_RELEASE)"，因此
# PKG_VERSION 里若自带 '-rN' 就会拼出 '1.0.0-r3-r1' 这种双 -r 非法串。
# 另外没有显式 PKG_VERSION 的包（luci-app-syscontrol/wizard/luci-nginx 等）
# 版本号由 feeds/luci/luci.mk 的 findrev 生成，这里也一并演算校验。
# 在编译开始前扫一遍，命中就直接退出，避免跑完三小时才在某个包上失败。
# ---------------------------------------------------------------------------

# 与 feeds/luci/luci.mk 的 findrev 保持一致：
#   有 .git -> <yday>.<secs%86400 五位>~<7位短hash>
#   无 .git -> 0.<YYmmdd>.<mtime%86400 五位>
luci_findrev() {
	if git -C "$1" log -1 >/dev/null 2>&1; then
		set -- $(git -C "$1" log -1 --format="%ct %h" --abbrev=7 -- . ':(exclude)po' 2>/dev/null)
		if [ -n "$1" ]; then
			secs=$(( $1 % 86400 ))
			yday=$(date --utc --date="@$1" "+%y.%j")
			printf '%s.%05d~%s' "$yday" "$secs" "$2"
			return
		fi
		echo 0
		return
	fi
	local ts
	ts=$(find "$1" -type f -not -path "*/po/*" -printf '%T@\n' 2>/dev/null | sort -rn | head -n1 | cut -d. -f1)
	if [ -n "$ts" ]; then
		secs=$(( ts % 86400 ))
		d=$(date --utc --date="@$ts" "+%y%m%d")
		printf '0.%s.%05d' "$d" "$secs"
		return
	fi
	echo 0
}

# 校验一个版本串是否会被 apk 接受；不合法则 echo 原因并 return 1
apk_version_why() {
	local v="$1" why=
	case "$v" in
		*' '*|*'/'*|*':'*|*'"'*) echo "含非法字符（空格/斜杠/冒号/引号）"; return 1 ;;
		*'..'*|.*|*.) echo "'.' 位置非法（开头/连续/结尾）"; return 1 ;;
		*'~') echo "'~' 后为空"; return 1 ;;
	esac
	case "$v" in
		*'~'*)
			local tail=${v##*~}
			case "$tail" in *[!0-9a-fA-F]*) echo "'~' 后含非十六进制字符（如日期里的点号）"; return 1 ;; esac ;;
	esac
	case "$v" in
		*-r[0-9]*)
			local rest=${v#*-r}
			case "$rest" in
				*-r[0-9]*) echo "'-rN' 出现多次（打包会拼成 X-rN-rM）"; return 1 ;;
				[0-9]*) echo "PKG_VERSION 自带 '-rN'，打包会再拼一次成 '-rN-rM'；请把 N 挪到 PKG_RELEASE"; return 1 ;;
			esac ;;
	esac
	# 必须以数字开头（apk 要求 TOKEN_INITIAL_DIGIT）
	case "$v" in
		[0-9]*) : ;;
		*) echo "版本号必须以数字开头"; return 1 ;;
	esac
	return 0
}

apk_version_check() {
	local bad=0 v why fn
	# 1) 显式写了 PKG_VERSION 的包
	for mk in $(find package feeds -name Makefile 2>/dev/null); do
		v=$(sed -n 's/^[[:space:]]*PKG_VERSION:[[:space:]]*=[[:space:]]*\(.\+\)$/\1/p' "$mk" | head -n1)
		[ -z "$v" ] && continue
		# 引用变量的（如 $(FOOTSTRAP_VERSION)）无法静态求值，先跳过
		case "$v" in *'$'*)
			echo "SKIP: $mk 的 PKG_VERSION='$v' 由变量拼出，无法静态校验" >&2
			continue ;;
		esac
		if why=$(apk_version_why "$v"); then :; else
			echo "ERROR: $mk 的 PKG_VERSION='$v' 会被 apk 拒绝：$why" >&2
			bad=1
		fi
	done
	# 2) 没有 PKG_VERSION 但用了 luci.mk 的包，版本由 findrev 生成
	for mk in $(find package feeds -name Makefile 2>/dev/null); do
		grep -q 'PKG_VERSION[[:space:]]*:=' "$mk" && continue
		grep -q 'feeds/luci/luci.mk\|luci.mk' "$mk" || continue
		dir=$(dirname "$mk")
		v=$(luci_findrev "$dir")
		if why=$(apk_version_why "$v"); then
			echo "OK(findrev): $mk -> $v"
		else
			echo "ERROR: $mk 无 PKG_VERSION，findrev 生成的版本 '$v' 会被 apk 拒绝：$why" >&2
			bad=1
		fi
	done
	if [ "$bad" = 1 ]; then
		echo "ERROR: 存在 apk 无法解析的包版本号，编译必失败。请修正上面的包后重试。" >&2
		exit 1
	fi
	echo "apk 版本号预检通过"
}
apk_version_check

sed -i 's/option timeout 30/option timeout 120/g' package/system/rpcd/files/rpcd.config

sed -i "s/OpenWrt/OpenWrt/g" package/base-files/files/bin/config_generate 2>/dev/null || true

sed -i -e "s/set \${s}.country='\${country || ''}'/set \${s}.country='\${country || \"CN\"}'/g" -e "s/set \${s}.disabled=.*/set \${s}.disabled='0'/" package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc

rm -rf package/feeds/packages/jool