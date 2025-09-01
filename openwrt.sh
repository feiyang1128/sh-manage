#!/bin/sh

# ====== 可配置区域 ======
# ====== 脚本配置 ========
REMOTE_SCRIPT_URL="https://sh.feiyang.gq/openwrt.sh"
LOCAL_SCRIPT_PATH="/root/opt.sh"
GITHUB_PROXY="https://ghproxy.feiyang.gq/"
TMP_DIR="/tmp/install_tmp"
# ====== 软件配置 ======
OPENCLASH_REPO="vernesong/OpenClash"
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
            rm -f "$LOCAL_SCRIPT_PATH" && echo -e "${GREEN}脚本文件已删除。${NC}" || echo -e "${RED}脚本删除失败！${NC}"
        else
            echo -e "${RED}脚本文件不存在，无法删除！${NC}"
        fi
    else
        echo -e "${GREEN}取消删除操作。${NC}"
    fi
}

# 获取系统架构类型并返回 amd64 或 arm64
get_architecture() {
    # 获取系统架构
    arch=$(uname -m)

    # 判断架构类型并返回相应的值
    if [ "$arch" = "aarch64" ]; then
        echo "arm64"
    elif [ "$arch" = "x86_64" ]; then
        echo "amd64"
    else
        echo "未知架构：$arch"
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

# 定义清理函数
cleanup_tmp_dir() {
    if [ -d "$TMP_DIR" ]; then
        echo -e "${YELLOW}清理临时文件夹：$TMP_DIR${NC}"
        rm -rf "$TMP_DIR"
    fi
}

# 捕获退出信号
trap 'cleanup_tmp_dir; echo -e "\n${RED}脚本已退出${NC}\n"' EXIT   # 统一清理和打印
trap 'exit 1' INT TERM                                         # Ctrl+C 或终止只退出，不重复打印

# ====== 获取 GitHub 最新版本号（使用 API，兼容 BusyBox） ======
get_latest_github_version() {
    repo="$1"
    latest_version=""
    wait_time=0
    max_wait=30   # 最大等待时间 30 秒
    interval=2    # 每次重试间隔 2 秒

    while [ -z "$latest_version" ] && [ $wait_time -lt $max_wait ]; do
        # 请求 GitHub API 并抓取标准版本号
        latest_version=$(curl -s "https://targetproxy.feiyang.gq/?target=https://api.github.com/repos/$repo/releases" \
            | grep '"tag_name":' \
            | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' \
            | head -n 1)
        
        if [ -z "$latest_version" ]; then
            echo -e "${YELLOW}暂未获取到版本号，等待 $interval 秒...${NC}"
            sleep $interval
            wait_time=$((wait_time + interval))
        fi
    done

    if [ -z "$latest_version" ]; then
        echo -e "${RED}超过 $max_wait 秒仍未获取到版本号！${NC}"
        return 1
    fi
    echo "$latest_version"
}


# ====== 安装 OpenClash ======
install_openclash() {
    create_tmp_dir
    echo -e "${YELLOW}正在获取 OpenClash 最新版本号...${NC}"
    
latest_version=$(get_latest_github_version "$OPENCLASH_REPO")
if [ $? -ne 0 ]; then
    echo "获取版本号失败，安装取消！"
    exit 1
fi
echo "准备安装 OpenClash，版本：$latest_version"
latest_version=$(echo "$latest_version" | tr -d 'a-zA-Z')
    # 准备下载链接
    ipk_url="https://github.com/vernesong/OpenClash/releases/download/v${latest_version}/luci-app-openclash_${latest_version}_all.ipk"
    wget_url="$ipk_url"
    [ -n "$GITHUB_PROXY" ] && wget_url="${GITHUB_PROXY}${ipk_url#https://}"

    # 等待并开始下载
    echo -e "${YELLOW}开始下载 OpenClash...${NC}"
    wget -O "$TMP_DIR/luci-app-openclash.ipk" "$wget_url" || { echo -e "${RED}下载失败！${NC}"; return 1; }

    # 安装 OpenClash
    echo -e "${YELLOW}安装 OpenClash...${NC}"
    opkg install "$TMP_DIR/luci-app-openclash.ipk" || opkg install --force-depends "$TMP_DIR/luci-app-openclash.ipk"
    echo -e "${GREEN}OpenClash 安装完成。${NC}"
    architecture=$(get_architecture)
    echo "当前系统架构：$architecture"
    if [ $? -ne 0 ]; then
    echo -e "${RED}无法获取架构信息，退出安装openclash内核。${NC}"
    exit 1
fi
    # 下载并解压 OpenClash 内核
    echo -e "${YELLOW}正在下载 OpenClash 内核文件...${NC}"
    wget -O "$TMP_DIR/clash-linux-arm64.tar.gz" "${GITHUB_PROXY}https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-$architecture.tar.gz"

    # 解压并移动到目标目录
    tar -xzvf "$TMP_DIR/clash-linux-$architecture.tar.gz" -C /etc/openclash/core/

    # 重命名文件为 clash_meta
    mv /etc/openclash/core/clash /etc/openclash/core/clash_meta
    echo -e "${GREEN}OpenClash 内核安装完成。${NC}"
}


uninstall_openclash() {
    echo -e "${YELLOW}正在卸载 OpenClash...${NC}"
    opkg remove luci-app-openclash
    rm -rf "/etc/openclash/"
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
    
    # 遍历每个包，下载并安装
    for pkg in $taskd $xterm $libtaskd $appstore; do
        url="${ISTORE_URL}${pkg}"
        filename="$TMP_DIR/$(basename $pkg)"
        echo -e "${YELLOW}下载：$url${NC}"
        
        # 下载包
        wget -O "$filename" "$url" || { 
            echo -e "${RED}下载 $pkg 失败！iStore 安装失败。${NC}"
            return 1  # 下载失败，直接退出函数
        }
        
        echo -e "${YELLOW}安装 $pkg...${NC}"
        
        # 安装包
        opkg install "$filename" || opkg install --force-depends "$filename" || { 
            echo -e "${RED}安装 $pkg 失败！iStore 安装失败。${NC}"
            return 1  # 安装失败，直接退出函数
        }
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

show_menu() {
    while true; do
        # ====== 主菜单 ======
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
        echo "8. 更新脚本"
        echo "9. 删除脚本"
        echo "0. 退出"
        echo -e "${YELLOW}=================================================${NC}"

        read -p "请输入选项 [0-9]: " choice

        case $choice in
            1) update_feeds ;;
            2) install_openclash ;;
            3) install_istore ;;
            4) uninstall_openclash ;;
            5) uninstall_istore ;;
            6) install_sftp ;;
            7) uninstall_sftp ;;
            8) get_script ;;
            9) delete_script ;;
            0) echo -e "${GREEN}退出脚本${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选项，请重新输入。${NC}" ;;
        esac

        # 执行完任务后询问是否退出
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
