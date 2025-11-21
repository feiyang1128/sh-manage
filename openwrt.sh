#!/bin/sh

# ====== 可配置区域 ======
# ====== 脚本配置 =======
REMOTE_SCRIPT_URL="https://sh.feiyang.gq/openwrt.sh"
LOCAL_SCRIPT_PATH="/root/opt.sh"
GITHUB_PROXY="https://gh-proxy.org/"  # 更换更稳定的代理
TMP_DIR="/tmp/install_tmp"
# ====== 软件配置 =====
ISTORE_URL="https://istore.linkease.com/repo/all/store/"

# ====== 颜色定义 ======
GREEN='\033[0;32m'   # 成功
RED='\033[0;31m'     # 失败
YELLOW='\033[0;33m'  # 警告/进行中
NC='\033[0m'         # 默认颜色

# ====== 公共函数 ======
# ======安装/更新远程脚本并保存到本地 ======
get_script() {
    echo -e "${YELLOW}安装/更新脚本中..."
    wget -qO "$LOCAL_SCRIPT_PATH" "$REMOTE_SCRIPT_URL" || { echo -e "${RED}脚本安装/更新失败！"; exit 1; }
    echo -e "${GREEN}脚本安装/更新成功！${NC}"
    # 重新执行脚本并退出
    bash "$0" && exit 0
}

# 删除脚本文件并清理相关文件
delete_script() {
    echo -e "${YELLOW}确定要删除脚本文件吗？(y/n)${NC}"
    read -p "请输入 (y/n): " confirmation
    if [[ "$confirmation" == "y" || "$confirmation" == "Y" ]]; then
        echo -e "${YELLOW}正在删除脚本文件...${NC}"
        if [ -f "$LOCAL_SCRIPT_PATH" ]; then
            rm -f "$LOCAL_SCRIPT_PATH" && echo -e "${GREEN}脚本文件已删除。${NC}"&& exit 0 || echo -e "${RED}脚本删除失败！${NC}"
        else
            echo -e "${RED}脚本文件不存在，无法删除！${NC}"
        fi
    else
        echo -e "${GREEN}取消删除操作。${NC}"
    fi
}

# 获取系统架构类型并返回 amd64 或 arm64
get_architecture() {
    arch=$(uname -m)
    if [ "$arch" = "aarch64" ]; then
        echo "arm64"
    elif [ "$arch" = "x86_64" ]; then
        echo "amd64"
    else
        echo "未知架构：$arch"
    fi
}
# 获取 GitHub 项目最新版本号
get_latest_version() {
    local repo=$1
    local add_v=$2  # 第二个参数，用于控制是否加上 'v'

    # 检查 jq 是否已安装，如果没有安装，则安装
    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}未检测到 jq，正在安装 jq...${NC}"
        opkg update && opkg install jq || { echo -e "${RED}jq 安装失败！${NC}"; return 1; }
        echo -e "${GREEN}jq 安装成功！${NC}"
    fi
    
    echo -e "${YELLOW}正在获取 GitHub 项目 '$repo' 的最新版本号...${NC}"
    
    # 调用 GitHub API 获取最新版本信息
    latest_version=$(curl -s "$GITHUB_PROXYhttps://api.github.com/repos/$repo/releases" | jq -r '.[0].tag_name')
   
    
    if [ "$latest_version" != "null" ]; then
        # 如果需要添加 'v'，并且版本号不以 'v' 开头，则添加
        if [ "$add_v" == "true" ] && [[ "$latest_version" != v* ]]; then
            latest_version="v$latest_version"
        # 如果不需要 'v'，并且版本号以 'v' 开头，则去掉 'v'
        elif [ "$add_v" == "false" ] && [[ "$latest_version" == v* ]]; then
            latest_version="${latest_version#v}"
        fi
        echo -e "${GREEN}最新版本号：$latest_version${NC}"
    else
        echo -e "${RED}获取最新版本失败！${NC}"
        return 1
    fi
}


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

# 捕获退出信号
trap 'if [ "$$" = "$BASHPID" ]; then cleanup_tmp_dir; echo -e "\n${RED}脚本已退出${NC}\n"; fi' EXIT
trap 'exit 1' INT TER

# ====== 安装 OpenClash 函数 ======
install_openclash() {
    create_tmp_dir
    echo -e "${YELLOW}正在获取 OpenClash 最新版本号...${NC}"
    
    # 获取最新版本号
    get_latest_version "vernesong/OpenClash" "false" || return 1

    echo -e "${GREEN}准备安装 OpenClash，版本：v$latest_version${NC}"
    
    # 准备下载链接
    ipk_url="https://github.com/vernesong/OpenClash/releases/download/v${latest_version}/luci-app-openclash_${latest_version}_all.ipk"
    wget_url="$ipk_url"
    [ -n "$GITHUB_PROXY" ] && wget_url="${GITHUB_PROXY}${ipk_url#https://}"

    echo -e "${YELLOW}开始下载 OpenClash...${NC}"
    echo -e "${YELLOW}下载链接：$wget_url${NC}"
    
    if wget -O "$TMP_DIR/luci-app-openclash.ipk" "$wget_url"; then
        echo -e "${GREEN}下载成功！${NC}"
    else
        echo -e "${RED}下载失败！尝试直接下载...${NC}"
        # 尝试不使用代理下载
        if wget -O "$TMP_DIR/luci-app-openclash.ipk" "$ipk_url"; then
            echo -e "${GREEN}直接下载成功！${NC}"
        else
            echo -e "${RED}所有下载方式都失败！${NC}"
            return 1
        fi
    fi

    # 安装 OpenClash
    echo -e "${YELLOW}安装 OpenClash...${NC}"
    opkg install "$TMP_DIR/luci-app-openclash.ipk" || opkg install --force-depends "$TMP_DIR/luci-app-openclash.ipk"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OpenClash 安装完成。${NC}"
        
        # 安装内核
        architecture=$(get_architecture)
        echo -e "${YELLOW}当前系统架构：$architecture${NC}"
        
        echo -e "${YELLOW}正在下载 OpenClash 内核文件...${NC}"
        kernel_url="${GITHUB_PROXY}https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-${architecture}.tar.gz"
        
        # 创建核心目录
        mkdir -p /etc/openclash/core/
        
        if wget -O "$TMP_DIR/clash-linux-$architecture.tar.gz" "$kernel_url"; then
            # 解压并移动内核
            tar -xzvf "$TMP_DIR/clash-linux-$architecture.tar.gz" -C /etc/openclash/core/
            mv /etc/openclash/core/clash /etc/openclash/core/clash_meta 2>/dev/null
            chmod +x /etc/openclash/core/clash_meta 2>/dev/null
            echo -e "${GREEN}OpenClash 内核安装完成。${NC}"
        else
            echo -e "${YELLOW}内核下载失败，您可能需要手动安装内核。${NC}"
        fi
    else
        echo -e "${RED}OpenClash 安装失败！${NC}"
        return 1
    fi
}

uninstall_openclash() {
    echo -e "${YELLOW}正在卸载 OpenClash...${NC}"
    opkg remove luci-app-openclash
    rm -rf "/etc/openclash/"
    echo -e "${GREEN}OpenClash 卸载完成。${NC}"
}

#=======安装 openclash 必备组件====
install_beforeopenclash() {
     echo -e "${YELLOW}正在安装 openclash 必备组件...${NC}"
     opkg install bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base
     echo -e "${GREEN}openclash 必备组件 安装完成。${NC}"
}

#=======卸载 openclash 必备组件====
uninstall_beforeopenclash() {
    echo -e "${YELLOW}正在卸载 openclash 必备组件...${NC}"
    opkg remove bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base
    echo -e "${GREEN}openclash 必备组件 卸载完成。${NC}"
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
        
        if wget -O "$filename" "$url"; then
            echo -e "${YELLOW}安装 $pkg...${NC}"
            opkg install "$filename" || opkg install --force-depends "$filename" || { 
                echo -e "${RED}安装 $pkg 失败！${NC}"
                return 1
            }
        else
            echo -e "${RED}下载 $pkg 失败！${NC}"
            return 1
        fi
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
    opkg install vsftpd openssh-sftp-server
    echo -e "${GREEN}SFTP 服务安装完成。${NC}"
}

uninstall_sftp() {
    echo -e "${YELLOW}正在卸载 SFTP 服务...${NC}"
    opkg remove vsftpd openssh-sftp-server
    echo -e "${GREEN}SFTP 服务卸载完成。${NC}"
}
# ====== 安装 docker 服务 ======
install_docker() {
    echo -e "${YELLOW}正在安装 Docker...${NC}"    
    # 安装 Docker 相关软件包
    opkg install dockerd luci-app-dockerman luci-i18n-dockerman-zh-cn || { echo -e "${RED}Docker 安装失败！${NC}"; return 1; }
    echo -e "${GREEN}Docker 安装成功！${NC}"
}
# 卸载 Docker
uninstall_docker() {
    echo -e "${YELLOW}正在卸载 Docker...${NC}"
    # 卸载 Docker 及相关软件包
    opkg remove dockerd luci-app-dockerman luci-i18n-dockerman-zh-cn || { echo -e "${RED}Docker 卸载失败！${NC}"; return 1; }
    echo -e "${GREEN}Docker 卸载完成。${NC}"
}

show_menu() {
    while true; do
        echo -e "${YELLOW}=================================================${NC}"
        echo -e "${GREEN}==========欢迎使用 Feiyang OpenWrt 管理脚本=========${NC}"
        echo -e "${YELLOW}========    脚本管理  sh /root/opt.sh   ==========${NC}"  
        echo -e "${YELLOW}=================================================${NC}"
        echo "1. 更新软件源"
        echo "2. 安装 OpenClash"
        echo "3. 安装 iStore"
        echo "4. 卸载 OpenClash"
        echo "5. 卸载 iStore"
        echo "6. 安装 SFTP 服务"
        echo "7. 卸载 SFTP 服务"
        echo "8. 安装 openclash 必备组件"
        echo "9. 卸载 openclash 必备组件"
        echo "10. 安装 Docker"
        echo "11. 卸载 Docker"
        echo "12. 更新脚本"
        echo "13. 删除脚本"
        echo "0. 退出"
        echo -e "${YELLOW}=================================================${NC}"

        read -p "请输入选项 [0-13]: " choice

        case $choice in
            1) update_feeds ;;
            2) install_openclash ;;
            3) install_istore ;;
            4) uninstall_openclash ;;
            5) uninstall_istore ;;
            6) install_sftp ;;
            7) uninstall_sftp ;;
            8) install_beforeopenclash ;;
            9) uninstall_beforeopenclash ;;
            10) install_docker ;;
            11) uninstall_docker ;;
            12) get_script ;;
            13) delete_script ;;
            0) echo -e "${GREEN}退出脚本${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选项，请重新输入。${NC}" ;;
        esac

        read -p "任务已完成，是否继续操作？(任意键继续，N/n 退出脚本): " exit_choice
        if [[ "$exit_choice" == "N" || "$exit_choice" == "n" ]]; then
            echo -e "${GREEN}退出脚本${NC}"
            exit 0
        fi
    done
}


# 判断是否第一次运行并自动保存
if [ ! -f "$LOCAL_SCRIPT_PATH" ]; then
    get_script
fi

# 调用菜单
show_menu
