#!/bin/sh
# ==================================================
# x-ui 一键管理脚本 (适配 Alpine Linux + OpenRC)
# 原项目: https://github.com/vaxilu/x-ui
# 修改: fei yang (适配 Alpine)
# ==================================================

XUI_DIR="/usr/local/x-ui"
XUI_BIN="$XUI_DIR/x-ui"
XUI_SERVICE="/etc/init.d/x-ui"

set -e

install_xui() {
    echo ">>> 安装依赖..."
    apk update
    apk add --no-cache wget curl bash unzip tar openrc gcompat

    mkdir -p $XUI_DIR

    echo ">>> 获取 x-ui 最新版本..."
    LATEST_URL=$(curl -s https://api.github.com/repos/vaxilu/x-ui/releases/latest \
      | grep "browser_download_url" \
      | grep "linux-amd64.tar.gz" \
      | cut -d '"' -f 4)

    wget -O /tmp/x-ui.tar.gz "$LATEST_URL"
    tar -xzf /tmp/x-ui.tar.gz -C $XUI_DIR
    chmod +x $XUI_BIN

    echo ">>> 配置 OpenRC 服务..."
    cat >$XUI_SERVICE <<'EOF'
#!/sbin/openrc-run

name="x-ui"
description="x-ui panel"
command="/usr/local/x-ui/x-ui"
command_background=true
pidfile="/var/run/x-ui.pid"

depend() {
    need net
}
EOF

    chmod +x $XUI_SERVICE

    rc-update add x-ui default
    rc-service x-ui start

    echo ">>> 安装完成！"
    echo "访问面板: http://<服务器IP>:54321"
}

uninstall_xui() {
    echo ">>> 停止并移除服务..."
    rc-service x-ui stop || true
    rc-update del x-ui || true
    rm -f $XUI_SERVICE
    rm -rf $XUI_DIR
    echo ">>> x-ui 已卸载"
}

update_xui() {
    echo ">>> 更新 x-ui..."
    rc-service x-ui stop || true
    install_xui
}

start_xui() {
    rc-service x-ui start
}

stop_xui() {
    rc-service x-ui stop
}

restart_xui() {
    rc-service x-ui restart
}

status_xui() {
    rc-service x-ui status
}

logs_xui() {
    tail -n 50 -f /var/log/x-ui.log
}

change_port() {
    read -p "请输入新的面板端口: " port
    $XUI_BIN setting -port $port
    echo ">>> 面板端口已修改为 $port，重启生效"
    restart_xui
}

change_user() {
    read -p "请输入新的用户名: " user
    $XUI_BIN setting -username $user
    echo ">>> 面板用户名已修改为 $user"
    restart_xui
}

change_pwd() {
    read -p "请输入新的密码: " pwd
    $XUI_BIN setting -password $pwd
    echo ">>> 面板密码已修改"
    restart_xui
}

menu() {
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
        1) install_xui ;;
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
        *) echo "无效选项" ;;
    esac
}

menu
