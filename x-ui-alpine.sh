#!/bin/sh
# ==================================================
# x-ui Alpine 静态编译 + OpenRC 管理菜单版
# 作者: fei yang
# ==================================================

XUI_DIR="/usr/local/x-ui"
XUI_BIN="$XUI_DIR/x-ui"
XUI_SERVICE="/etc/init.d/x-ui"
CONFIG_FILE="$XUI_DIR/config.json"

set -e

# ------------------- 安装依赖 -------------------
install_dependencies() {
    echo ">>> 安装依赖..."
    apk update
    apk add --no-cache git bash go build-base curl wget tar unzip openrc gcompat libc6-compat jq
}

# ------------------- 编译 x-ui -------------------
build_xui() {
    echo ">>> 下载 x-ui 源码..."
    cd /tmp
    rm -rf x-ui
    git clone https://github.com/vaxilu/x-ui.git
    cd x-ui

    echo ">>> 编译静态二进制..."
    export CGO_ENABLED=0
    export GOOS=linux
    export GOARCH=amd64
    go build -o x-ui main.go

    echo ">>> 安装 x-ui..."
    mkdir -p $XUI_DIR
    mv x-ui $XUI_BIN
    chmod +x $XUI_BIN

    # 初始化配置文件
    if [ ! -f $CONFIG_FILE ]; then
        echo '{"username":"admin","password":"admin","port":54321}' > $CONFIG_FILE
    fi
}

# ------------------- OpenRC 服务 -------------------
setup_service() {
    echo ">>> 配置 OpenRC 服务..."
    cat >$XUI_SERVICE <<'EOF'
#!/sbin/openrc-run

name="x-ui"
description="x-ui panel"
command="/usr/local/x-ui/x-ui"
command_background=true
pidfile="/var/run/x-ui.pid"
command_args=">>/var/log/x-ui.log 2>&1"

depend() {
    need net
}
EOF

    chmod +x $XUI_SERVICE
    rc-update add x-ui default
}

# ------------------- 服务操作 -------------------
start_xui()   { rc-service x-ui start; echo ">>> 启动完成"; }
stop_xui()    { rc-service x-ui stop; echo ">>> 已停止"; }
restart_xui() { rc-service x-ui restart; echo ">>> 已重启"; }
status_xui()  { rc-service x-ui status; }
logs_xui()    { tail -n 50 -f /var/log/x-ui.log; }

# ------------------- 配置修改 -------------------
change_port() {
    read -p "请输入新的面板端口: " port
    jq ".port=$port" $CONFIG_FILE > $CONFIG_FILE.tmp && mv $CONFIG_FILE.tmp $CONFIG_FILE
    echo ">>> 面板端口已修改为 $port"
    restart_xui
}
change_user() {
    read -p "请输入新的用户名: " user
    jq ".username=\"$user\"" $CONFIG_FILE > $CONFIG_FILE.tmp && mv $CONFIG_FILE.tmp $CONFIG_FILE
    echo ">>> 面板用户名已修改为 $user"
    restart_xui
}
change_pwd() {
    read -p "请输入新的密码: " pwd
    jq ".password=\"$pwd\"" $CONFIG_FILE > $CONFIG_FILE.tmp && mv $CONFIG_FILE.tmp $CONFIG_FILE
    echo ">>> 面板密码已修改"
    restart_xui
}

# ------------------- 卸载 -------------------
uninstall_xui() {
    echo ">>> 停止服务并卸载..."
    rc-service x-ui stop || true
    rc-update del x-ui || true
    rm -f $XUI_SERVICE
    rm -rf $XUI_DIR
    echo ">>> x-ui 已卸载"
}

# ------------------- 更新 -------------------
update_xui() {
    echo ">>> 更新 x-ui..."
    stop_xui
    build_xui
    start_xui
}

# ------------------- 菜单 -------------------
menu() {
    while true; do
        clear
        echo "====== x-ui 管理脚本 (Alpine 版) ======"
        echo "1. 安装 x-ui"
        echo "2. 更新 x-ui"
        echo "3. 卸载 x-ui"
        echo "---------------------------"
        echo "4. 启动 x-ui"
        echo "5. 停止 x-ui"
        echo "6. 重启 x-ui"
        echo "7. 查看状态"
        echo "8. 查看日志"
        echo "---------------------------"
        echo "9. 修改面板端口"
        echo "10. 修改用户名"
        echo "11. 修改密码"
        echo "0. 退出"
        echo "======================================"
        read -p "请输入选项: " num
        case "$num" in
            1) install_dependencies; build_xui; setup_service; start_xui ;;
            2) update_xui ;;
            3) uninstall_xui ;;
            4) start_xui ;;
            5) stop_xui ;;
            6) restart_xui ;;
            7) status_xui ;;
            8) logs_xui ;;
            9) change_port ;;
            10) change_user ;;
            11) change_pwd ;;
            0) exit 0 ;;
            *) echo "无效选项"; sleep 1 ;;
        esac
    done
}

# ------------------- 入口 -------------------
menu
