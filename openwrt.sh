#!/bin/sh

# ====== 可配置区域 ======
GITHUB_PROXY="https://ghproxy.feiyang.gq/"
OPENCLASH_REPO="vernesong/OpenClash"
ISTORE_URL="https://istore.linkease.com/repo/all/store/"
TMP_DIR="/tmp/openwrt_install_tmp"

# ====== 颜色定义 ======
GREEN='\033[0;32m'   # 成功
RED='\033[0;31m'     # 失败
YELLOW='\033[0;33m'  # 警告/进行中
NC='\033[0m'         # 默认颜色

# ====== 公共函数 ======
update_feeds() {
    echo -e "${YELLOW}正在更新软件源...${NC}"
    opkg update && echo -e "${GREEN}软件源更新完成。${NC}" || echo -e "${RED}更新失败！${NC}"
}

create_tmp_dir() {
    mkdir -p "$TMP_DIR"
    echo -e "${YELLOW}使用临时文件夹：$TMP_DIR${NC}"
}

cleanup_tmp_dir() {
    if [ -d "$TMP_DIR" ]; then
        echo -e "${YELLOW}清理临时文件夹：$TMP_DIR${NC}"
        rm -rf "$TMP_DIR"
    fi
}

# 捕获 Ctrl+C 和退出，同时清理临时目录
trap 'cleanup_tmp_dir; echo -e "${RED}脚本已退出${NC}"; exit 1' INT TERM EXIT

# ====== 获取 GitHub 最新版本号（使用 API，兼容 BusyBox） ======
get_latest_github_version() {
    repo="$1"
    latest_version=$(curl -Ls "https://targetproxy.feiyang.gq/?target=https://api.github.com/repos/feiyang1128/xuiApi/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "$latest_version"
}

# ====== 安装 OpenClash ======
install_openclash() {
    create_tmp_dir
    echo -e "${YELLOW}正在获取 OpenClash 最新版本号...${NC}"
    latest_version=$(get_latest_github_version "$OPENCLASH_REPO")

    if [ -z "$latest_version" ]; then
        echo -e "${RED}获取 OpenClash 最新版本失败！${NC}"
        return 1
    fi
    echo -e "${GREEN}最新版本为：$latest_version${NC}"

    ipk_url="https://github.com/vernesong/OpenClash/releases/download/${latest_version}/luci-app-openclash_${latest_version}_all.ipk"
    wget_url="$ipk_url"
    [ -n "$GITHUB_PROXY" ] && wget_url="${GITHUB_PROXY}${ipk_url#https://}"

    echo -e "${YELLOW}开始下载 OpenClash...${NC}"
    wget -O "$TMP_DIR/luci-app-openclash.ipk" "$wget_url" || { echo -e "${RED}下载失败！${NC}"; return 1; }

    echo -e "${YELLOW}安装 OpenClash...${NC}"
    opkg install "$TMP_DIR/luci-app-openclash.ipk" || opkg install --force-depends "$TMP_DIR/luci-app-openclash.ipk"
    echo -e "${GREEN}OpenClash 安装完成。${NC}"
}

uninstall_openclash() {
    echo -e "${YELLOW}正在卸载 OpenClash...${NC}"
    opkg remove luci-app-openclash
    echo -e "${GREEN}OpenClash 卸载完成。${NC}"
}

# ====== 安装 iStore ======
install_istore() {
    create_tmp_dir
    echo -e "${YELLOW}正在获取 iStore 最新版本信息...${NC}"
    files=$(curl -s "${ISTORE_URL}" | grep -o 'href="[^"]*\.ipk"' | cut -d '"' -f2)

    taskd=$(echo "$files" | grep 'taskd' | sort -V | tail -n1)
    xterm=$(echo "$files" | grep 'luci-lib-xterm' | sort -V | tail -n1)
    libtaskd=$(echo "$files" | grep 'luci-lib-taskd' | sort -V | tail -n1)
    appstore=$(echo "$files" | grep 'luci-app-store' | sort -V | tail -n1)

    echo -e "${YELLOW}下载并安装 iStore 所需的 4 个组件...${NC}"
    for pkg in $taskd $xterm $libtaskd $appstore; do
        url="${ISTORE_URL}${pkg}"
        filename="$TMP_DIR/$(basename $pkg)"
        echo -e "${YELLOW}下载：$url${NC}"
        wget -O "$filename" "$url" || { echo -e "${RED}下载 $pkg 失败！${NC}"; continue; }
        echo -e "${YELLOW}安装 $pkg...${NC}"
        opkg install "$filename" || opkg install --force-depends "$filename"
    done

    echo -e "${GREEN}iStore 安装完成。${NC}"
}

uninstall_istore() {
    echo -e "${YELLOW}正在卸载 iStore...${NC}"
    opkg remove luci-app-store luci-lib-taskd luci-lib-xterm taskd
    echo -e "${GREEN}iStore 卸载完成。${NC}"
}

# ====== 安装 SFTP 服务 ======
install_sftp() {
    echo -e "${YELLOW}正在安装 SFTP 服务...${NC}"
    opkg update
    opkg install vsftpd openssh-sftp-server
    echo -e "${GREEN}SFTP 服务安装完成。${NC}"
}

uninstall_sftp() {
    echo -e "${YELLOW}正在卸载 SFTP 服务...${NC}"
    opkg remove vsftpd openssh-sftp-server
    echo -e "${GREEN}SFTP 服务卸载完成。${NC}"
}

# ====== 菜单 ======
while true; do
    echo -e "${YELLOW}========================${NC}"
    echo -e "${YELLOW}  OpenWrt 管理脚本${NC}"
    echo -e "${YELLOW}========================${NC}"
    echo "1. 更新软件源"
    echo "2. 安装 OpenClash"
    echo "3. 安装 iStore"
    echo "4. 卸载 OpenClash"
    echo "5. 卸载 iStore"
    echo "6. 安装 SFTP 服务"
    echo "7. 卸载 SFTP 服务"
    echo "0. 退出"
    echo -e "${YELLOW}========================${NC}"
    read -p "请输入选项 [0-7]: " choice
    case $choice in
        1) update_feeds ;;
        2) install_openclash ;;
        3) install_istore ;;
        4) uninstall_openclash ;;
        5) uninstall_istore ;;
        6) install_sftp ;;
        7) uninstall_sftp ;;
        0) echo -e "${GREEN}退出脚本${NC}"; exit 0 ;;
        *) echo -e "${RED}无效选项，请重新输入。${NC}" ;;
    esac
done
