#!/bin/sh
# 90-shell-zsh：不装 zsh 的"类 zsh"体验（仅交互式 bash 生效）
#   1) zoxide —— z 式目录跳转（二进制已内置 /sbin/zoxide，无需装包）
#   2) bash 原生 Tab —— 命令名 + 路径补全（readline 内建）
#   3) 上/下方向键改为"按已输入前缀搜历史"（最轻量的自动提示）

[ -n "$BASH_VERSION" ] || exit 0
case "$-" in *i*) ;; *) exit 0 ;; esac

# --- zoxide：z <关键字> 跳转、z 自动记录去过的目录、Tab 补全目录 ---
if [ -x /sbin/zoxide ]; then
	export _ZO_DATA_DIR=/root/.local/share/zoxide
	eval "$(/sbin/zoxide init bash 2>/dev/null)"
fi

# --- fzf（二进制内置 /usr/bin/fzf，官方 shell 集成脚本内置）---
#   Ctrl+R 模糊搜历史（含预览）；Ctrl+T 模糊选路径；Alt+C 跳目录；
#   `kill **` / `cd **` / `vim **` 这类 ** 触发模糊补全；z 裸执行也用它出菜单。
if [ -x /usr/bin/fzf ]; then
	[ -r /usr/share/fzf/key-bindings.bash ] && . /usr/share/fzf/key-bindings.bash
	[ -r /usr/share/fzf/completion.bash ] && . /usr/share/fzf/completion.bash
fi

# --- 前缀历史搜索：输入几个字符再按 ↑/↓，只翻匹配过的命令 ---
bind '"\e[A":history-search-backward' 2>/dev/null
bind '"\e[B":history-search-forward' 2>/dev/null

# --- 补全忽略大小写 ---
bind 'set completion-ignore-case on' 2>/dev/null

exit 0
