#!/usr/bin/env bash

clashui() {
    case ${1:-} in
    -h | --help)
        ui_help
        return 0
        ;;
    switch)
        shift
        _ui_switch "$@"
        return
        ;;
    '')
        ;;
    *)
        _ui_error '用法: clashctl ui [switch <zashboard|metacubexd|none>]'
        return 1
        ;;
    esac

    if [ "$(_ui_frontend)" = none ]; then
        _ui_error 'Web 前端已关闭（CLASHCTL_UI_FRONTEND=none）'
        _ui_detail '启用' 'clashctl ui switch zashboard'
        return 1
    fi

    [ -f "$CLASH_RESOURCES_DIR/dist/index.html" ] || _ci_provision ui || return 1
    _detect_ext_addr
    service_is_active >&/dev/null || service_start >/dev/null
    service_is_active >&/dev/null || _errorcat "无法启动服务，请检查日志" || return

    local query_url='https://api64.ipify.org'
    local public_ip
    public_ip=$(curl -s --noproxy "*" --location --max-time 2 "$query_url")
    local public_address="http://${public_ip:-公网}:${EXT_PORT}/ui"

    local local_ip=$EXT_IP
    local local_address="http://${local_ip}:${EXT_PORT}/ui"

    local common_address='http://board.zash.run.place'
    
    printf "\n"
    printf "╔═══════════════════════════════════════════════╗\n"
    printf "║                  Web 控制台                   ║\n"
    printf "║═══════════════════════════════════════════════║\n"
    printf "║                                               ║\n"
    printf "║     🔓 注意放行端口：%-5s                    ║\n" "$EXT_PORT"
    printf "║     🏠 内网：%-31s  ║\n" "$local_address"
    printf "║     🌏 公网：%-31s  ║\n" "$public_address"
    printf "║     ☁️  公共：%-31s  ║\n" "$common_address"
    printf "║                                               ║\n"
    printf "╚═══════════════════════════════════════════════╝\n"
    printf "\n"
}

# 切换 Web 前端：写入 .env 并即时下载；none 关闭并移除本地前端文件。
_ui_switch() {
    local target=${1:-}

    if [ -z "$target" ] && [ -t 0 ] && [ -t 1 ]; then
        printf '当前前端：%s\n' "$(_ui_frontend)"
        printf '可选前端：zashboard / metacubexd / none\n'
        printf '请输入要切换的前端：'
        IFS= read -r target || return 1
    fi
    case ${target:-} in
    zashboard | metacubexd | none) ;;
    '')
        _ui_error '用法: clashctl ui switch <zashboard|metacubexd|none>'
        return 1
        ;;
    *)
        _ui_error "不支持的前端：$target（可选 zashboard|metacubexd|none）"
        return 1
        ;;
    esac

    _set_env CLASHCTL_UI_FRONTEND "$target" || return 1
    export CLASHCTL_UI_FRONTEND=$target
    if [ "$target" = none ]; then
        command rm -rf -- "$CLASH_RESOURCES_DIR/dist" 2>/dev/null
        _okcat 'Web 前端已关闭'
        return 0
    fi
    _ci_provision ui || return 1
    _okcat "Web 前端已切换为：$target"
}

ui_help() {
    cat <<EOF

Usage:
  clashctl ui                          显示 Web 面板地址（按需下载前端）
  clashctl ui switch <frontend>        切换前端：zashboard | metacubexd | none

前端由 .env 中的 CLASHCTL_UI_FRONTEND 记录，切换后立即生效，无需重启内核。

EOF
}
