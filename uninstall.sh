#!/bin/bash
# ============================================================
#  AI图文创作 — 一键卸载脚本
#  用法:
#    sudo bash uninstall.sh                  # 交互式（需确认）
#    sudo bash uninstall.sh -y               # 跳过确认
#    curl -fsSL <raw-url> | sudo bash -s -- -y
#  多实例:
#    AIPIC_DIR=/var/www/aipic-test sudo bash uninstall.sh -y
# ============================================================
set -e

# ── 颜色 ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }
info()  { echo -e "${BLUE}[i]${NC} $1"; }
title() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ── 参数解析 ──────────────────────────────────────────
FORCE=0
if [ "${1:-}" = "-y" ] || [ "${1:-}" = "--yes" ]; then
    FORCE=1
fi

# ── 配置（与 install.sh 保持一致） ──────────────────────
PROJECT_DIR="${AIPIC_DIR:-/var/www/aipic}"
SERVICE_SLUG="$(basename "$PROJECT_DIR")"
NGINX_CONF="/etc/nginx/sites-available/${SERVICE_SLUG}"
NGINX_LINK="/etc/nginx/sites-enabled/${SERVICE_SLUG}"
SYSTEMD_SERVICE="/etc/systemd/system/${SERVICE_SLUG}.service"

# ── 路径安全校验 ──────────────────────────────────────
# 防止路径穿越攻击（如 AIPIC_DIR=/var/www/../../../etc/nginx）
RESOLVED_DIR="$(realpath -m "$PROJECT_DIR" 2>/dev/null || echo "$PROJECT_DIR")"
case "$RESOLVED_DIR" in
    /|/etc|/etc/*|/var|/home|/home/*|/root|/usr|/usr/*|/opt|/tmp|/bin|/sbin|/boot|/dev|/proc|/sys|/run|/var/log|/var/run|/var/lock)
        err "非法的安装目录: $PROJECT_DIR → $RESOLVED_DIR"
        err "请设置 AIPIC_DIR 为 /var/www/ 下的子目录"
        exit 1 ;;
esac
# 必须至少有二级路径（如 /var/www/xxx）
if [ "$(dirname "$RESOLVED_DIR")" = "/" ]; then
    err "非法的安装目录: $PROJECT_DIR（不能为顶级目录的子目录）"
    err "请设置 AIPIC_DIR 为 /var/www/ 下的子目录"
    exit 1
fi
PROJECT_DIR="$RESOLVED_DIR"
SERVICE_SLUG="$(basename "$PROJECT_DIR")"
NGINX_CONF="/etc/nginx/sites-available/${SERVICE_SLUG}"
NGINX_LINK="/etc/nginx/sites-enabled/${SERVICE_SLUG}"
SYSTEMD_SERVICE="/etc/systemd/system/${SERVICE_SLUG}.service"

# ── 检查 ──────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    err "请用 root 用户运行: sudo bash uninstall.sh"
    exit 1
fi

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════╗"
echo "  ║     AI图文创作  一键卸载          ║"
echo "  ╚══════════════════════════════════╝"
echo -e "${NC}"

# ── 检查是否有东西可卸载 ────────────────────────────────
FOUND=0
if [ -d "$PROJECT_DIR" ]; then
    FOUND=1
fi
if [ -f "$SYSTEMD_SERVICE" ]; then
    FOUND=1
fi
if [ -f "$NGINX_CONF" ] || [ -L "$NGINX_LINK" ]; then
    FOUND=1
fi

if [ "$FOUND" = 0 ]; then
    warn "未检测到 ${SERVICE_SLUG} 的安装痕迹，无需卸载"
    exit 0
fi

# ── 确认 ──────────────────────────────────────────────
echo -e "${YELLOW}将要卸载:${NC}"
echo "  服务名称:  ${SERVICE_SLUG}"
[ -d "$PROJECT_DIR" ]       && echo "  项目目录:  ${PROJECT_DIR}"
[ -f "$SYSTEMD_SERVICE" ]   && echo "  systemd:   ${SYSTEMD_SERVICE}"
[ -f "$NGINX_CONF" ]        && echo "  Nginx配置: ${NGINX_CONF}"
if id "$SERVICE_SLUG" &>/dev/null; then
    echo "  系统用户:  ${SERVICE_SLUG}"
fi
echo ""

if [ "$FORCE" = 0 ]; then
    read -p "确认卸载? [y/N] " -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        info "已取消"
        exit 0
    fi
fi

# ========================================================
title "1/5  停止服务"
# ========================================================
if systemctl is-active --quiet ${SERVICE_SLUG} 2>/dev/null; then
    systemctl stop ${SERVICE_SLUG}
    log "已停止 ${SERVICE_SLUG} 服务"
else
    log "${SERVICE_SLUG} 服务未运行"
fi

if systemctl is-enabled --quiet ${SERVICE_SLUG} 2>/dev/null; then
    systemctl disable ${SERVICE_SLUG} 2>/dev/null || true
    log "已禁用 ${SERVICE_SLUG} 开机自启"
fi

# ========================================================
title "2/5  移除 systemd 服务"
# ========================================================
if [ -f "$SYSTEMD_SERVICE" ]; then
    rm -f "$SYSTEMD_SERVICE"
    systemctl daemon-reload
    log "已移除 ${SYSTEMD_SERVICE}"
else
    log "systemd 服务文件不存在，跳过"
fi

# ========================================================
title "3/5  移除 Nginx 配置"
# ========================================================
NGINX_RELOAD=0
if [ -f "$NGINX_CONF" ] || [ -L "$NGINX_LINK" ]; then
    rm -f "$NGINX_LINK" "$NGINX_CONF"
    NGINX_RELOAD=1
    log "已移除 Nginx 配置"
else
    log "Nginx 配置不存在，跳过"
fi

if [ "$NGINX_RELOAD" = 1 ]; then
    if nginx -t 2>/dev/null; then
        systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
        log "Nginx 已重载"
    else
        err "Nginx 配置测试失败，请手动检查 /etc/nginx/sites-enabled/"
    fi
fi

# ========================================================
title "4/5  移除系统用户"
# ========================================================
if id "$SERVICE_SLUG" &>/dev/null; then
    # 仅删除 install.sh 创建的 nologin + 无家目录用户
    USER_SHELL=$(getent passwd "$SERVICE_SLUG" | cut -d: -f7)
    USER_HOME=$(getent passwd "$SERVICE_SLUG" | cut -d: -f6)
    if [ "$USER_SHELL" = "/usr/sbin/nologin" ] && { [ "$USER_HOME" = "/nonexistent" ] || [ ! -d "$USER_HOME" ]; }; then
        userdel "$SERVICE_SLUG" 2>/dev/null || warn "无法删除用户 ${SERVICE_SLUG}（可能被占用）"
        log "已移除系统用户 ${SERVICE_SLUG}"
    else
        warn "用户 ${SERVICE_SLUG} 非安装脚本创建 (shell: ${USER_SHELL}, home: ${USER_HOME})，跳过"
    fi
else
    log "系统用户 ${SERVICE_SLUG} 不存在，跳过"
fi

# ========================================================
title "5/5  移除项目目录"
# ========================================================
if [ -d "$PROJECT_DIR" ]; then
    rm -rf "$PROJECT_DIR"
    log "已移除 ${PROJECT_DIR}"
else
    log "项目目录不存在，跳过"
fi

# ========================================================
echo -e "\n${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     🧹 卸载完成！                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  已移除内容:"
echo "    - systemd 服务: ${SERVICE_SLUG}"
echo "    - Nginx 配置:   ${SERVICE_SLUG}"
echo "    - 项目目录:     ${PROJECT_DIR}"
echo ""
echo "  以下内容未删除（系统级组件，可能被其他服务使用）:"
echo "    - 系统包: nginx, python3, nodejs, pnpm, uv"
echo "    - 安装日志: /var/log/${SERVICE_SLUG}-install.log"
echo ""
