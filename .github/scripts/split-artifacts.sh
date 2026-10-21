#!/usr/bin/env bash
# 把 OpenWrt 构建产物按用途分组，让 Actions 页面能「需要哪个下哪个」。
#
# 背景：以前把整个 bin/targets/ 打成 1 个 artifact（1.2GB+：imagebuilder 445MB
# + 三个各 126MB 的镜像 + 400MB 的 apk 包），下载一次太重，而实际用的人只想
# 拿其中一两个文件。改成每组一个 artifact 后，单个最大只有 imagebuilder 445MB，
# 刷机党只要下 sysupgrade.bin（126MB）那一组。
#
# 用法: split-artifacts.sh <产物根目录> <输出目录>
# 输出目录下每个子目录 = 一个 artifact：
#   firmware-sysupgrade/  刷机主力：sysupgrade.bin + sha256sums + manifest + config
#   firmware-factory/    U-Boot 直刷用 factory.bin
#   firmware-initramfs/  initramfs 应急启动
#   imagebuilder/        imagebuilder（自己加包重编译用）
#   packages/            全部 apk 包（连 index.json / packages.adb 一起，作为本地 apk 源）
#   metadata/            索引/元信息小文件
set -u

root="${1:-}"
out="${2:-}"
if [ -z "$root" ] || [ -z "$out" ]; then
  echo "用法: $0 <产物根目录> <输出目录>" >&2
  exit 2
fi

# 找到真正放产物的目录（含 *-squashfs-sysupgrade.bin）
src=""
while IFS= read -r d; do
  if compgen -G "$d/*-squashfs-sysupgrade.bin" >/dev/null 2>&1; then
    src="$d"
    break
  fi
done < <(find "$root" -maxdepth 4 -type d 2>/dev/null)
if [ -z "$src" ]; then
  echo "错误：在 $root 下没找到 *-squashfs-sysupgrade.bin" >&2
  exit 1
fi
echo "产物目录: $src"

rm -rf "$out"
mkdir -p "$out"/{firmware-sysupgrade,firmware-factory,firmware-initramfs,imagebuilder,packages,metadata}

cd "$src" || exit 1

# 1) 三个镜像各一组：刷机党通常只需要其中一个
cp -f -- *-squashfs-sysupgrade.bin "$out/firmware-sysupgrade/" 2>/dev/null || true
cp -f -- *-squashfs-factory.bin   "$out/firmware-factory/"   2>/dev/null || true
cp -f -- *-initramfs-uImage.itb   "$out/firmware-initramfs/" 2>/dev/null || true

# 2) 校验和 / 清单 / 配置跟着 sysupgrade 走（刷机前要看校验和）
cp -f -- sha256sums *.manifest *.buildinfo *config "$out/firmware-sysupgrade/" 2>/dev/null || true
cp -f -- sha256sums "$out/firmware-factory/" 2>/dev/null || true

# 3) imagebuilder：自己加包重编译用
cp -f -- openwrt-imagebuilder-*.tar.zst "$out/imagebuilder/" 2>/dev/null || true

# 4) apk 包：apk 仓库目录一般在 <kernel_version>/ 下（里面带 index.json、packages.adb），
#    少数布局直接叫 packages/。两种都兼容，整个目录搬过去当本地 apk 源用。
for d in */; do
  v="${d%/}"
  [ "$v" = "packages" ] && continue
  if compgen -G "$v/*.apk" >/dev/null 2>&1; then
    mkdir -p "$out/packages/$v"
    cp -f -- "$v"/*.apk "$out/packages/$v/" 2>/dev/null || true
    cp -f -- "$v"/index.json "$v"/packages.adb "$out/packages/$v/" 2>/dev/null || true
  elif [ -d "$v/packages" ]; then
    mkdir -p "$out/packages/$v"
    cp -rf -- "$v/packages" "$out/packages/$v/" 2>/dev/null || true
  fi
done
if [ -d packages ] && [ -z "$(compgen -G "$out/packages/*/*.apk" 2>/dev/null)" ]; then
  cp -rf -- packages "$out/packages/" 2>/dev/null || true
fi

# 5) 元信息小文件
cp -f -- packages.adb profiles.json* *.buildinfo "$out/metadata/" 2>/dev/null || true

echo "=== 分组结果 ==="
du -sh "$out"/* 2>/dev/null || true
echo "=== 文件数 ==="
for d in "$out"/*/; do
  printf '%s: %s 个文件\n' "$(basename "$d")" "$(find "$d" -type f | wc -l)"
done
