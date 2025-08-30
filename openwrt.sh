#!/bin/sh

# ====== 可配置区域 ======
GITHUB_PROXY="https://ghproxy.feiyang.gq/"
OPENCLASH_URL="https://github.com/vernesong/OpenClash/releases/latest"
ISTORE_URL="https://istore.linkease.com/repo/all/store/"

# 临时文件夹路径
TMP_DIR="/tmp/openwrt_install_tmp"

# ====== 公共函数 ======
update_feeds() {
    echo "正在更新软件源..."
    opkg update
    echo "软件源更新完成。"
}

# ====== 创建临时文件夹 ======
create_tmp_dir() {
    mkdir -p "$TMP_DIR"
    echo "使用临时文件夹：$TMP_DIR"
}

# ====== 清理临时文件夹 ======
cleanup_tmp_dir() {
    if [ -d "$TMP_DIR" ]; then
        echo "清理临时文件夹：$TMP_DIR"
        rm -rf "$TMP_DIR"
    fi
}

# 捕获中断信号和退出，自动清理
trap cleanup_tmp_dir INT TERM EXIT

# ====== 安装 OpenClash ======
install_openclash() {
    create_tmp_dir

    echo "正在获取 OpenClash 最新版本号..."
    latest_version=$(curl -Ls -o /dev/null -w %{url_effective} "${GITHUB_PROXY}${OPENCLASH_URL}" | awk -F '/' '{print $NF}')
    echo "最新版本为：$latest_version"

    ipk_url="https://github.com/vernesong/OpenClash/releases/download/v${latest_version}/luci-app-openclash_${latest_version}_all.ipk"
    wget_url="$ipk_url"
    [ -n "$GITHUB_PROXY" ] && wget_url="${GITHUB_PROXY}${ipk_url#https://}"

    echo "开始下载 OpenClash..."
    wget -O "$TMP_DIR/luci-app-openclash.ipk" "$wget_url" || { echo "下载失败！"; return; }

    echo "安装 OpenClash..."
    opkg install "$TMP_DIR/luci-app-openclash.ipk" || opkg install --force-depends "$TMP_DIR/luci-app-openclash.ipk"
    echo "OpenClash 安装完成。"
}

# ====== 卸载 OpenClash ======
uninstall_openclash() {
    echo "正在卸载 OpenClash..."
    opkg remove luci-app-openclash
    echo "OpenClash 卸载完成。"
}

# ====== 安装 iStore ======
install_istore() {
    create_tmp_dir

    echo "正在获取 iStore 最新版本信息..."
    files=$(curl -s "${GITHUB_PROXY}${ISTORE_URL}" | grep -o 'href="[^"]*\.ipk"' | cut -d '"' -f2)

    taskd=$(echo "$files" | grep 'taskd' | sort -V | tail -n1)
    xterm=$(echo "$files" | grep 'luci-lib-xterm' | sort -V | tail -n1)
    libtaskd=$(echo "$files" | grep 'luci-lib-taskd' | sort -V | tail -n1)
    appstore=$(echo "$files" | grep 'luci-app-store' | sort -V | tail -n1)

    echo "下载并安装 iStore 所需的 4 个组件..."
    for pkg in $taskd $xterm $libtaskd $appstore; do
        url="https://github.com${pkg}"
        wget_url="$url"
        [ -n "$GITHUB_PROXY" ] && wget_url="${GITHUB_PROXY}${url#https://}"
        filename="$TMP_DIR/$(basename $pkg)"
        echo "下载：$pkg"
        wget -O "$filename" "$wget_url" || { echo "下载 $pkg 失败！"; continue; }
        echo "安装 $pkg..."
        opkg install "$filename" || opkg install --force-depends "$filename"
    done

    echo "iStore 安装完成。"
}

# ====== 卸载 iStore ======
uninstall_istore() {
    echo "正在卸载 iStore..."
    opkg remove luci-app-store luci-lib-taskd luci-lib-xterm taskd
    echo "iStore 卸载完成。"
}

# ====== 安装 SFTP 服务 ======
install_sftp() {
    echo "正在安装 SFTP 服务..."
    opkg update
    opkg install vsftpd openssh-sftp-server
    echo "SFTP 服务安装完成。"
}

# ====== 卸载 SFTP 服务 ======
uninstall_sftp() {
    echo "正在卸载 SFTP 服务..."
    opkg remove vsftpd openssh-sftp-server
    echo "SFTP 服务卸载完成。"
}

# ====== 菜单 ======
while true; do
    echo "========================"
    echo "  OpenWrt 管理脚本"
    echo "========================"
    echo "1. 更新软件源"
    echo "2. 安装 OpenClash"
    echo "3. 安装 iStore"
    echo "4. 卸载 OpenClash"
    echo "5. 卸载 iStore"
    echo "6. 安装 SFTP 服务"
    echo "7. 卸载 SFTP 服务"
    echo "0. 退出"
    echo "========================"
    read -p "请输入选项 [0-7]: " choice
    case $choice in
        1) update_feeds ;;
        2) install_openclash ;;
        3) install_istore ;;
        4) uninstall_openclash ;;
        5) uninstall_istore ;;
        6) install_sftp ;;
        7) uninstall_sftp ;;
        0) echo "退出脚本"; exit 0 ;;
        *) echo "无效选项，请重新输入。" ;;
    esac
done
