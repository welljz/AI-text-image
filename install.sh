#!/bin/bash
# ============================================================
#  AI图文创作 — 一键安装脚本
#  用法:
#    公开仓库: curl -fsSL <raw-url> | sudo bash
#    私有仓库: curl -fsSL <raw-url> | sudo bash -s -- <repo-url>
#    本地运行: sudo bash install.sh [repo-url]
#  多实例/测试:
#    AIPIC_DIR=/var/www/aipic-test AIPIC_PORT=8084 AIPIC_FLASK=50124 sudo bash install.sh
#  适配: Ubuntu 20.04+ / Debian 11+
# ============================================================
set -e

# ── 异常退出清理 ──────────────────────────────────────
_cleanup() {
    local _exit_code=$?
    if [ "$_exit_code" -ne 0 ]; then
        echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        err "安装中断 (退出码: $_exit_code)"
        if [ -n "${NGINX_CONF:-}" ] && [ -f "$NGINX_CONF" ]; then
            warn "Nginx 配置已保留: $NGINX_CONF"
            warn "请手动检查: ${NGINX_BIN:-nginx} -t"
        fi
        info "安装日志: /var/log/${SERVICE_SLUG:-aipic}-install.log"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}
trap _cleanup EXIT

# ── 非交互式安装（防止 apt 弹配置提示破坏 stdin） ──────────
export DEBIAN_FRONTEND=noninteractive
APT_OPTS="-y -qq -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

# ── 颜色 ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }
info()  { echo -e "${BLUE}[i]${NC} $1"; }
title() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ── 配置（支持环境变量覆盖） ──────────────────────────
PROJECT_DIR="${AIPIC_DIR:-/var/www/aipic}"
DEFAULT_REPO="https://github.com/welljz/AI-text-image.git"
REPO_URL="${1:-$DEFAULT_REPO}"
FLASK_PORT="${AIPIC_FLASK:-50123}"
NGINX_PORT="${AIPIC_PORT:-8083}"
NODE_MAJOR="${NODE_MAJOR:-22}"
UV_INSTALL_URL="${UV_INSTALL_URL:-https://astral.sh/uv/install.sh}"
PYTHON_MIN_VERSION="${PYTHON_MIN_VERSION:-3.11}"
DOMAIN="${AIPIC_DOMAIN:-_}"

# 服务名直接取目录名
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

# ── 安装日志持久化 ──
mkdir -p /var/log
exec > >(tee -a /var/log/${SERVICE_SLUG}-install.log) 2>&1

# ── 检查 ──────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    err "请用 root 用户运行: curl ... | sudo bash"
    exit 1
fi

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════╗"
echo "  ║     AI图文创作  一键安装          ║"
echo "  ╚══════════════════════════════════╝"
echo -e "${NC}"

# ── 网络可达性检查 ────────────────────────────────────
info "检查网络连接..."
if ! curl -fsSL --connect-timeout 5 https://github.com -o /dev/null 2>/dev/null; then
    if ! curl -fsSL --connect-timeout 5 https://www.google.com -o /dev/null 2>/dev/null; then
        warn "外网不可达，安装可能失败"
        warn "请确保服务器能访问互联网，或预先安装好依赖"
    fi
fi

# ── 辅助函数 ──────────────────────────────────────────

# 检测命令是否存在
has() { command -v "$1" &>/dev/null; }

# 安全的 curl 下载（支持重试和镜像回退）
safe_curl() {
    local url="$1" mirror="$2"
    if curl -fsSL --connect-timeout 10 --retry 2 "$url" -o "${3:-/dev/stdout}" 2>/dev/null; then
        return 0
    fi
    if [ -n "$mirror" ]; then
        warn "主源不可达，尝试镜像: $mirror"
        curl -fsSL --connect-timeout 10 --retry 2 "$mirror" -o "${3:-/dev/stdout}" 2>/dev/null && return 0
    fi
    return 1
}

# 检查并安装单个系统包
ensure_pkg() {
    local pkg="$1"
    if dpkg -s "$pkg" &>/dev/null; then
        log "$pkg 已安装"
        return 0
    fi
    info "安装 $pkg ..."
    apt install $APT_OPTS "$pkg"
}

# ── 预飞确认 ──────────────────────────────────────────
echo ""
info "安装目标: ${SERVICE_SLUG}"
info "项目目录: ${PROJECT_DIR}"
info "对外端口: ${NGINX_PORT}  (Flask: ${FLASK_PORT})"
[ "$DOMAIN" != "_" ] && info "域名:     ${DOMAIN}"
echo ""
info "3 秒后开始安装，Ctrl+C 取消..."
sleep 3

# ========================================================
title "1/7  检测环境 + 安装系统依赖"
# ========================================================

# Python
if has python3; then
    PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    if [ "$(printf '%s\n' "$PYTHON_MIN_VERSION" "$PY_VER" | sort -V | head -1)" = "$PYTHON_MIN_VERSION" ]; then
        log "Python $PY_VER ✓"
    else
        warn "Python 版本过低: $PY_VER (需要 >= $PYTHON_MIN_VERSION)"
        _UPGRADE_PYTHON=1
    fi
else
    warn "未检测到 Python3，将安装"
    _UPGRADE_PYTHON=1
fi

if [ "${_UPGRADE_PYTHON:-0}" = 1 ]; then
    info "尝试安装 Python ${PYTHON_MIN_VERSION}..."
    if has apt; then
        ensure_pkg software-properties-common
        if add-apt-repository -y ppa:deadsnakes/ppa; then
            apt update -qq -o Acquire::http::Timeout=10 -o Acquire::ftp::Timeout=10 2>/dev/null || true
        else
            err "无法添加 deadsnakes PPA（网络不通或系统版本不支持）"
            err "请手动安装 Python >= ${PYTHON_MIN_VERSION} 后重试"
            exit 1
        fi
        PY_PKG="python${PYTHON_MIN_VERSION}"
        if ! dpkg -s "$PY_PKG" &>/dev/null; then
            apt install $APT_OPTS "$PY_PKG" "$PY_PKG-venv" "$PY_PKG-dev" || {
                err "无法安装 Python ${PYTHON_MIN_VERSION}"
                err "请手动安装 Python >= ${PYTHON_MIN_VERSION} 后重试"
                exit 1
            }
        fi
        log "Python ${PYTHON_MIN_VERSION} 安装完成 (deadsnakes)，未更改系统默认 python3"
    else
        err "Python 版本过低且无法自动升级 (非 apt 系统)"
        err "请手动安装 Python >= ${PYTHON_MIN_VERSION} 后重试"
        exit 1
    fi
fi

# 系统包（按需安装，不重复）
info "检查系统依赖..."
apt update -qq -o Acquire::http::Timeout=10 -o Acquire::ftp::Timeout=10 2>/dev/null || warn "apt update 部分源不可达，继续..."

# 基础工具
for pkg in curl ca-certificates gnupg unzip git; do
    ensure_pkg "$pkg"
done

# Python 生态
for pkg in python3 python3-venv python3-pip; do
    ensure_pkg "$pkg"
done

# Nginx — 优先复用已有（面板/apt），没有才装；不影响原有站点
NGINX_BIN=""
NGINX_MODE=""
NGINX_CONF_DIR=""
NGINX_LINK_DIR=""

_detect_nginx() {
    # ── 1. 按优先级找 nginx 二进制 ──
    for _bin in /www/server/nginx/sbin/nginx /usr/local/nginx/sbin/nginx /usr/sbin/nginx /usr/bin/nginx; do
        if [ -x "$_bin" ]; then
            NGINX_BIN="$_bin"
            break
        fi
    done
    [ -z "$NGINX_BIN" ] && NGINX_BIN="$(which nginx 2>/dev/null || echo '')"

    if [ -z "$NGINX_BIN" ] || [ ! -x "$NGINX_BIN" ]; then
        ensure_pkg nginx
        NGINX_BIN="$(which nginx 2>/dev/null || echo /usr/sbin/nginx)"
    fi
    log "Nginx 二进制: ${NGINX_BIN}"

    # ── 2. 获取 nginx 实际使用的配置文件路径 + 预存错误检查 ──
    _NGINX_TEST_OUT=$($NGINX_BIN -t 2>&1) || _NGINX_PRE_FAIL=1
    _nginx_conf=$(echo "$_NGINX_TEST_OUT" | grep 'configuration file' | grep -o '/[^ ]*nginx.conf' | head -1)
    _nginx_conf="${_nginx_conf:-/etc/nginx/nginx.conf}"
    if [ "${_NGINX_PRE_FAIL:-0}" = 1 ]; then
        warn "Nginx 当前配置有预存问题（与本次安装无关）:"
        echo "$_NGINX_TEST_OUT" | grep '\[emerg\]\|\[error\]' >&2 || true
        warn "将尝试继续，但可能需要手动修复这些预存问题"
    fi
    _NGINX_CONF_DIRNAME=$(dirname "$_nginx_conf")

    # ── 3. 探测放 vhost 配置的正确目录 ──
    # 判断是否为面板 nginx（避免面板二进制 + apt 目录的错配）
    case "$NGINX_BIN" in
        /www/server/*) _IS_PANEL_NGINX=1 ;;
        *)             _IS_PANEL_NGINX=0 ;;
    esac

    if [ -d "/etc/nginx/sites-available" ] && [ "$_IS_PANEL_NGINX" = 0 ]; then
        # 标准 Debian/Ubuntu apt 安装
        NGINX_CONF_DIR="/etc/nginx/sites-available"
        NGINX_LINK_DIR="/etc/nginx/sites-enabled"
        NGINX_MODE="link"
    elif [ -d "/www/server/panel/vhost/nginx" ]; then
        # 面板 nginx 的 vhost 目录（aaPanel / 宝塔）
        NGINX_CONF_DIR="/www/server/panel/vhost/nginx"
        NGINX_MODE="direct"
    elif [ -d "$_NGINX_CONF_DIRNAME/conf.d" ]; then
        # RHEL / CentOS 风格
        NGINX_CONF_DIR="$_NGINX_CONF_DIRNAME/conf.d"
        NGINX_MODE="direct"
    elif [ -d "/etc/nginx/conf.d" ]; then
        NGINX_CONF_DIR="/etc/nginx/conf.d"
        NGINX_MODE="direct"
    else
        # ── 解析 nginx.conf 的 include 指令，找真正的 vhost 目录 ──
        _found_inc_dir=""
        if [ -f "$_nginx_conf" ]; then
            _found_inc_dir=$(grep -oP 'include\s+\K[^;]+' "$_nginx_conf" 2>/dev/null | \
                grep -vE 'mime|fastcgi|modules|\.(dll|so)|enable-php' | \
                sed 's|/\*\.conf$||' | sed 's|/\*$||' | \
                while read -r _d; do [ -d "$_d" ] && echo "$_d" && break; done)
        fi
        if [ -n "$_found_inc_dir" ]; then
            NGINX_CONF_DIR="$_found_inc_dir"
            NGINX_MODE="direct"
        elif [ -d "/www/server/nginx/conf" ]; then
            NGINX_CONF_DIR="/www/server/nginx/conf"
            NGINX_MODE="direct"
            warn "面板 Nginx 检测到，但未找到 vhost include 目录；写入 ${NGINX_CONF_DIR}，请手动确认"
        else
            mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
            NGINX_CONF_DIR="/etc/nginx/sites-available"
            NGINX_LINK_DIR="/etc/nginx/sites-enabled"
            NGINX_MODE="link"
        fi
    fi
    log "Nginx 配置目录: ${NGINX_CONF_DIR}  (模式: ${NGINX_MODE})"
}
_detect_nginx

NGINX_CONF="${NGINX_CONF_DIR}/${SERVICE_SLUG}.conf"
[ "$NGINX_MODE" = "link" ] && NGINX_LINK="${NGINX_LINK_DIR}/${SERVICE_SLUG}.conf" || NGINX_LINK=""

# 检测包管理器类型（apt/yum/dnf）
if has apt; then
    PKG_MGR="apt"
elif has yum; then
    PKG_MGR="yum"
elif has dnf; then
    PKG_MGR="dnf"
else
    PKG_MGR="apt"  # 默认
fi
info "包管理器: $PKG_MGR"
log "系统依赖检查完成"

# ── 系统资源检查 ──
MEM_AVAIL_MB=$(awk '/MemAvailable/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo "0")
# 磁盘检查：若目标目录尚不存在，则检查其父目录
_DISK_CHECK_PATH="$PROJECT_DIR"
while [ ! -d "$_DISK_CHECK_PATH" ]; do
    _DISK_CHECK_PATH="$(dirname "$_DISK_CHECK_PATH")"
done
DISK_AVAIL_MB=$(df -m --output=avail "$_DISK_CHECK_PATH" 2>/dev/null | tail -1 || echo "0")
if [ "$MEM_AVAIL_MB" -gt 0 ] && [ "$MEM_AVAIL_MB" -lt 1800 ]; then
    warn "可用内存仅 ${MEM_AVAIL_MB}MB，前端构建可能失败 (建议 >= 2GB)"
fi
if [ "$DISK_AVAIL_MB" -gt 0 ] && [ "$DISK_AVAIL_MB" -lt 1000 ]; then
    err "磁盘空间不足: ${DISK_AVAIL_MB}MB (需要 >= 1GB)"
    exit 1
fi
log "内存 ${MEM_AVAIL_MB}MB / 磁盘 ${DISK_AVAIL_MB}MB"

# ========================================================
title "2/7  安装 Node.js ${NODE_MAJOR} + pnpm"
# ========================================================
if ! has node; then
    info "安装 Node.js ${NODE_MAJOR}..."
    NODE_SETUP_URL="https://deb.nodesource.com/setup_${NODE_MAJOR}.x"
    NODE_SETUP_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/nodesource/deb/setup_${NODE_MAJOR}.x"

    if safe_curl "$NODE_SETUP_URL" "$NODE_SETUP_MIRROR" | bash - 2>/dev/null; then
        apt install $APT_OPTS nodejs
        log "Node.js $(node -v) 安装完成"
    else
        warn "NodeSource 不可达，尝试 apt 默认版本..."
        apt install $APT_OPTS nodejs 2>/dev/null || {
            err "Node.js 安装失败，请手动安装 Node.js >= 18"
            exit 1
        }
        log "Node.js $(node -v) (apt 默认版本)"
    fi
else
    NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VER" -lt 18 ]; then
        warn "Node.js 版本过低 ($(node -v))，建议 >= 18"
    fi
    log "Node.js $(node -v) 已安装"
fi

# 验证 Node.js + npm 功能正常
if ! node -e 'console.log("ok")' 2>/dev/null | grep -q ok; then
    err "Node.js 安装后无法正常运行，请手动安装 Node.js >= 18"
    exit 1
fi
if ! has npm; then
    err "npm 未找到（Node.js 安装可能不完整），请手动安装 Node.js >= 18"
    exit 1
fi

# pnpm
if ! has pnpm; then
    info "安装 pnpm..."
    # 尝试 corepack（Node 16.9+ 内置，无需 npm）
    if has corepack; then
        corepack enable 2>/dev/null
        if corepack prepare pnpm@latest --activate 2>/dev/null; then
            SKIP_PNPM_NPM=1
        fi
    fi
    if [ -z "$SKIP_PNPM_NPM" ]; then
        npm install -g pnpm --silent 2>/dev/null || {
            warn "npm 安装失败，尝试 corepack..."
            corepack enable 2>/dev/null
            corepack prepare pnpm@latest --activate 2>/dev/null || {
                err "pnpm 安装失败，请手动安装: npm install -g pnpm"
                exit 1
            }
        }
    fi
    # 验证 pnpm 可用
    if has pnpm; then
        log "pnpm $(pnpm -v) 安装完成"
    else
        err "pnpm 未找到，请检查安装"
        exit 1
    fi
else
    log "pnpm $(pnpm -v) 已安装"
fi

# ========================================================
title "3/7  安装 uv (Python 包管理器)"
# ========================================================
if ! has uv; then
    info "安装 uv..."
    # 尝试官方安装脚本
    if safe_curl "$UV_INSTALL_URL" "" | sh 2>/dev/null; then
        log "uv 官方安装完成"
    else
        # 回退：pip 安装
        warn "官方脚本不可达，通过 pip 安装..."
        pip3 install uv -q 2>/dev/null || pip install uv -q 2>/dev/null || {
            err "uv 安装失败，请手动安装: pip install uv"
            exit 1
        }
    fi
    export PATH="$HOME/.local/bin:$PATH"
    # 复制到系统标准路径（systemd 服务以普通用户运行，需全局可访问）
    mkdir -p /usr/local/bin
    for uv_src in "$HOME/.local/bin/uv" "/usr/local/bin/uv"; do
        if [ -f "$uv_src" ]; then
            cp -f "$uv_src" /usr/local/bin/uv 2>/dev/null || true
            chmod 755 /usr/local/bin/uv 2>/dev/null || true
            break
        fi
    done
    log "uv $(uv --version 2>/dev/null || echo 'installed') 安装完成"
else
    log "uv $(uv --version) 已安装"
fi

# 确保 uv 在系统标准路径可用（systemd 以普通用户运行，不能访问 /root）
mkdir -p /usr/local/bin
_UV_REAL=$(readlink -f "$(which uv 2>/dev/null || echo /usr/local/bin/uv)" 2>/dev/null || echo "")
if [ -n "$_UV_REAL" ] && [ -f "$_UV_REAL" ]; then
    cp -f "$_UV_REAL" /usr/local/bin/uv 2>/dev/null || true
    chmod 755 /usr/local/bin/uv 2>/dev/null || true
elif [ ! -f /usr/local/bin/uv ]; then
    warn "uv 未在标准路径找到，systemd 服务可能启动失败"
fi

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# ========================================================
title "4/7  拉取项目代码"
# ========================================================
if [ -d "$PROJECT_DIR/.git" ]; then
    info "项目目录已存在，尝试 git pull 更新..."
    cd "$PROJECT_DIR"
    git pull origin main 2>/dev/null || warn "git pull 失败（网络不可达），使用现有代码继续"
elif [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/backend/app.py" ]; then
    info "项目目录已有代码，跳过克隆"
    cd "$PROJECT_DIR"
else
    info "克隆仓库: $REPO_URL"
    if ! git clone "$REPO_URL" "$PROJECT_DIR" 2>/dev/null; then
        if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/backend/app.py" ]; then
            warn "git clone 失败，但目录中已有代码，继续安装"
            cd "$PROJECT_DIR"
        else
            err "git clone 失败且目录中无代码"
            err "请手动下载: git clone $REPO_URL $PROJECT_DIR"
            err "或解压项目 zip 到 $PROJECT_DIR 后重新运行此脚本"
            exit 1
        fi
    else
        cd "$PROJECT_DIR"
        log "代码克隆完成"
    fi
fi

# ========================================================
title "5/7  安装项目依赖 + 构建前端"
# ========================================================
cd "$PROJECT_DIR"

# ── 后端 ──
info "安装 Python 依赖 (uv sync)..."
if ! uv sync --no-dev 2>/dev/null; then
    warn "默认源不可达，尝试清华镜像..."
    uv sync --no-dev --index-url https://pypi.tuna.tsinghua.edu.cn/simple || {
        err "Python 依赖安装失败"
        err "请手动执行: cd $PROJECT_DIR && uv sync --no-dev"
        exit 1
    }
fi
log "Python 依赖安装完成"

# ── 前端 ──
info "安装前端依赖 (pnpm install)..."
cd "$PROJECT_DIR/frontend"
export CI=true

if ! pnpm install --frozen-lockfile 2>/dev/null; then
    info "回退为宽松安装 (--no-frozen-lockfile)..."
    if ! pnpm install --no-frozen-lockfile 2>/dev/null; then
        warn "官方源不可达，尝试国内镜像..."
        pnpm config set registry https://registry.npmmirror.com 2>/dev/null || true
        pnpm install --no-frozen-lockfile || {
            err "前端依赖安装失败"
            err "请手动执行: cd $PROJECT_DIR/frontend && pnpm install"
            exit 1
        }
    fi
fi
log "前端依赖安装完成"

info "构建前端 (pnpm build)..."
rm -rf dist 2>/dev/null || true
if ! pnpm build; then
    err "前端构建失败"
    err "请手动执行: cd $PROJECT_DIR/frontend && pnpm build"
    exit 1
fi
log "前端构建完成 → frontend/dist/"

# ========================================================
title "6/7  配置文件"
# ========================================================
cd "$PROJECT_DIR"

# text_providers.yaml
if [ ! -f "text_providers.yaml" ]; then
    if [ -f "text_providers.yaml.example" ]; then
        cp text_providers.yaml.example text_providers.yaml
        warn "已创建 text_providers.yaml（模板）→ 请填写 API Key！"
    else
        warn "text_providers.yaml.example 不存在，跳过"
    fi
else
    log "text_providers.yaml 已存在，跳过"
fi

# image_providers.yaml
if [ ! -f "image_providers.yaml" ]; then
    if [ -f "image_providers.yaml.example" ]; then
        cp image_providers.yaml.example image_providers.yaml
        warn "已创建 image_providers.yaml（模板）→ 请填写 API Key！"
    else
        warn "image_providers.yaml.example 不存在，跳过"
    fi
else
    log "image_providers.yaml 已存在，跳过"
fi

# auth.yaml（登录密码）
if [ ! -f "auth.yaml" ]; then
    AIPIC_PASSWORD=$(openssl rand -base64 9 2>/dev/null || echo "$(date +%s)$RANDOM" | md5sum | cut -c1-12)
    cat > auth.yaml << AUTHEOF
username: admin
password: ${AIPIC_PASSWORD}
AUTHEOF
    chmod 600 auth.yaml
    log "已生成默认登录密码"
else
    log "auth.yaml 已存在，跳过"
    # 读取已有密码用于显示
    AIPIC_PASSWORD=$(grep '^password:' auth.yaml 2>/dev/null | sed 's/^password: //' || echo "已设置")
fi

# ── 清理旧版服务名（redink → aipic 迁移） ──────────
NEED_REDINK_CLEANUP=0
if [ "$SERVICE_SLUG" = "aipic" ] && systemctl is-active --quiet redink 2>/dev/null; then
    NEED_REDINK_CLEANUP=1
fi

# ── Nginx ───────────────────────────────────────────
# ── 端口冲突检查 ──
if ss -tlnp 2>/dev/null | grep -qE ":${FLASK_PORT}\s"; then
    # 如果已有同名 systemd 服务，说明是重装，跳过端口检查
    if [ -f "/etc/systemd/system/${SERVICE_SLUG}.service" ]; then
        warn "Flask 端口 ${FLASK_PORT} 已被占用（检测到已有 ${SERVICE_SLUG} 服务，推测为重装，继续）"
    else
        err "Flask 端口 ${FLASK_PORT} 已被占用，请设置 AIPIC_FLASK 环境变量后重试"
        exit 1
    fi
fi
if ss -tlnp 2>/dev/null | grep -qE ":${NGINX_PORT}\s"; then
    # 如果已有同名 Nginx 配置文件，说明是重装，跳过端口检查
    if [ -f "${NGINX_CONF_DIR}/${SERVICE_SLUG}.conf" ]; then
        warn "Nginx 端口 ${NGINX_PORT} 已被占用（检测到已有 ${SERVICE_SLUG} 配置，推测为重装，继续）"
    else
        err "Nginx 端口 ${NGINX_PORT} 已被占用，请设置 AIPIC_PORT 环境变量后重试"
        exit 1
    fi
fi

_NGINX_SKIPPED=0

info "配置 Nginx (${SERVICE_SLUG})..."

# ── Step A: 写入前预检查（排除本次安装无关的预存错误） ──
info "检查 Nginx 当前配置..."
if $NGINX_BIN -t >/dev/null 2>&1; then
    log "Nginx 当前配置正常"
else
    warn "当前 Nginx 存在预存配置问题（非本次安装导致），将继续尝试写入"
fi

# 备份旧配置
if [ -f "$NGINX_CONF" ]; then
    cp "$NGINX_CONF" "${NGINX_CONF}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
fi

# ── Step B: 写入配置 ──
cat > "$NGINX_CONF" << NGINXEOF
server {
    listen ${NGINX_PORT};
    server_name ${DOMAIN};

    proxy_read_timeout 360s;
    proxy_send_timeout 360s;
    proxy_buffering off;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    chunked_transfer_encoding on;

    location / {
        proxy_pass http://127.0.0.1:${FLASK_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
NGINXEOF

# 符号链接模式（sites-available → sites-enabled）
if [ -n "$NGINX_LINK" ]; then
    rm -f "$NGINX_LINK"
    ln -sf "$NGINX_CONF" "$NGINX_LINK"
fi

# ── Step C: 测试配置（显示完整错误输出以便诊断） ──
_NGINX_TEST_OUT=$($NGINX_BIN -t 2>&1) || _NGINX_TEST_FAIL=1
if [ "${_NGINX_TEST_FAIL:-0}" = 1 ]; then
    err "Nginx 配置测试失败"
    echo ""
    echo "$_NGINX_TEST_OUT" | grep -E '\[emerg\]|\[error\]|\[warn\]' >&2 || echo "$_NGINX_TEST_OUT" >&2
    echo ""
    # 区分：错误是否和本次写入的配置文件有关
    if echo "$_NGINX_TEST_OUT" | grep -q "$(basename "$NGINX_CONF")"; then
        err "↑ 错误与 ${SERVICE_SLUG}.conf 有关，回滚并退出"
        [ -n "$NGINX_LINK" ] && rm -f "$NGINX_LINK"
        rm -f "$NGINX_CONF"
        exit 1
    else
        warn "↑ 错误未提及 ${SERVICE_SLUG}.conf，可能是预存配置问题"
        warn "配置文件已保留: $NGINX_CONF"
        warn "请手动修复后执行: $NGINX_BIN -t && $NGINX_BIN -s reload"
        _NGINX_SKIPPED=1
    fi
else
    # ── Step D: 重载 Nginx（三种方式逐一尝试，去掉了 || true 兜底） ──
    _RELOAD_OK=0
    if systemctl reload nginx 2>/dev/null; then
        _RELOAD_OK=1
    elif service nginx reload 2>/dev/null; then
        _RELOAD_OK=1
    elif $NGINX_BIN -s reload 2>/dev/null; then
        _RELOAD_OK=1
    fi

    if [ "$_RELOAD_OK" = 1 ]; then
        log "Nginx 重载成功 → 端口 $NGINX_PORT"
    else
        err "Nginx 重载失败 — 配置通过测试但 reload 命令均未成功"
        warn "请手动重载: $NGINX_BIN -s reload"
        _NGINX_SKIPPED=1
    fi
fi

# ── 新 Nginx 配置生效后，安全清理旧版 ──
if [ "$NEED_REDINK_CLEANUP" = 1 ]; then
    info "停止旧版 redink 服务..."
    systemctl stop redink 2>/dev/null || true
    systemctl disable redink 2>/dev/null || true
    rm -f /etc/systemd/system/redink.service
    rm -f /etc/nginx/sites-enabled/redink /etc/nginx/sites-available/redink 2>/dev/null || true
    rm -f /www/server/panel/vhost/nginx/redink.conf 2>/dev/null || true
    rm -f /www/server/nginx/conf/redink.conf 2>/dev/null || true
    systemctl daemon-reload
    if [ "$_NGINX_SKIPPED" = 0 ]; then
        systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || $NGINX_BIN -s reload 2>/dev/null || true
    fi
    log "旧版 redink 已清理"
fi

# ── systemd ─────────────────────────────────────────
# ── 创建专用运行用户 ──
APP_USER="${SERVICE_SLUG}"
if ! id "$APP_USER" &>/dev/null; then
    useradd -r -s /usr/sbin/nologin -M "$APP_USER" 2>/dev/null || true
    log "创建系统用户: $APP_USER"
fi
chown -R "$APP_USER:$APP_USER" "$PROJECT_DIR" 2>/dev/null || true

# ── Git remote 切 HTTPS（SSH key 是 root 的，aipic 用户用不了） ──
# 公开仓库用 HTTPS 无需认证，确保 Web 后台一键更新能 git pull
cd "$PROJECT_DIR"
_REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo '')
case "$_REMOTE_URL" in
    git@github.com:*)
        _HTTPS_URL="https://github.com/$(echo "$_REMOTE_URL" | sed 's|git@github.com:||')"
        git remote set-url origin "$_HTTPS_URL" 2>/dev/null || true
        log "Git remote 已切换 HTTPS（供 ${APP_USER} 用户更新）"
        ;;
esac

# ── sudoers: 允许 aipic 用户重启自己的服务 ──
# 用于 Web 后台一键更新后自动重启
if [ ! -f "/etc/sudoers.d/${SERVICE_SLUG}" ]; then
    echo "${APP_USER} ALL=(root) NOPASSWD: /usr/bin/systemctl restart ${SERVICE_SLUG}, /usr/bin/systemctl status ${SERVICE_SLUG}" > "/etc/sudoers.d/${SERVICE_SLUG}"
    chmod 440 "/etc/sudoers.d/${SERVICE_SLUG}"
    log "sudoers 规则已添加: ${SERVICE_SLUG}"
fi

# ── 一键更新脚本 ──
cat > /usr/local/bin/${SERVICE_SLUG}-update << 'UPDEOF'
#!/bin/bash
set -e
PROJECT_DIR="__PROJECT_DIR__"
export HOME="$PROJECT_DIR"

log()   { echo "[✓] $1"; }
err()   { echo "[✗] $1"; }

cd "$PROJECT_DIR"

echo "[1/4] 拉取最新代码..."
if ! git pull origin main 2>&1; then
    err "git pull 失败（网络不可达或认证错误）"
    exit 1
fi
log "代码已更新"

echo "[2/4] 更新 Python 依赖..."
if ! /usr/local/bin/uv sync --no-dev 2>&1; then
    err "Python 依赖更新失败"
    exit 1
fi
log "Python 依赖已更新"

echo "[3/4] 更新前端依赖..."
cd frontend
if ! pnpm install --frozen-lockfile 2>&1 && ! pnpm install --no-frozen-lockfile 2>&1; then
    err "前端依赖更新失败"
    exit 1
fi
log "前端依赖已更新"

echo "[4/4] 构建前端..."
if ! pnpm build 2>&1; then
    err "前端构建失败"
    exit 1
fi
log "前端构建完成"
echo ""
log "更新完成，请重启服务使新代码生效"
UPDEOF
sed -i "s|__PROJECT_DIR__|${PROJECT_DIR}|g" /usr/local/bin/${SERVICE_SLUG}-update
chmod +x /usr/local/bin/${SERVICE_SLUG}-update
log "更新脚本已创建: /usr/local/bin/${SERVICE_SLUG}-update"

info "配置 systemd 服务 (${SERVICE_SLUG})..."
cat > "$SYSTEMD_SERVICE" << SYSTEMDEOF
[Unit]
Description=AI Image Generator (${SERVICE_SLUG})
After=network.target

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=$PROJECT_DIR
Environment=FLASK_PORT=${FLASK_PORT}
Environment=HOME=${PROJECT_DIR}
ExecStart=/usr/local/bin/uv run python backend/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMDEOF

systemctl daemon-reload
systemctl enable ${SERVICE_SLUG} 2>/dev/null || true
log "systemd 服务配置完成"

# ========================================================
title "7/7  启动服务"
# ========================================================

if systemctl is-active --quiet ${SERVICE_SLUG} 2>/dev/null; then
    systemctl restart ${SERVICE_SLUG}
    log "服务已重启"
else
    systemctl start ${SERVICE_SLUG}
    log "服务已启动"
fi

# 等待启动
info "等待服务启动..."
HEALTH_OK=0
for i in $(seq 1 30); do
    if curl -s http://localhost:$FLASK_PORT/api/health > /dev/null 2>&1; then
        log "服务健康检查通过 ✓"
        HEALTH_OK=1
        break
    fi
    sleep 2
done
if [ "$HEALTH_OK" = 0 ]; then
    err "健康检查超时，服务可能未正常启动"
    err "请手动检查: systemctl status ${SERVICE_SLUG}"
    err "查看日志: journalctl -u ${SERVICE_SLUG} -n 50"
    exit 1
fi

# ========================================================
echo -e "\n${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     🎨 安装完成！                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo -e ""
echo -e "  访问地址:  ${CYAN}http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo '服务器IP'):${NGINX_PORT}${NC}"
if [ "$_NGINX_SKIPPED" = 1 ]; then
    warn "⚠ Nginx 未重载，上述地址可能无法访问"
    warn "  请手动修复 Nginx 后执行: $NGINX_BIN -t && $NGINX_BIN -s reload"
    echo -e "  ${YELLOW}  Flask 直接端口: ${FLASK_PORT} (仅本地)${NC}"
    echo -e ""
fi
echo -e "  项目目录:  ${CYAN}${PROJECT_DIR}${NC}"
if [ "$SERVICE_SLUG" != "aipic" ]; then
    echo -e "  实例名称:  ${YELLOW}${SERVICE_SLUG}${NC}"
fi
echo -e ""
echo -e "  ${GREEN}🔐 登录凭据:${NC}"
echo -e "    用户名:  ${CYAN}admin${NC}"
echo -e "    密  码:  ${CYAN}${AIPIC_PASSWORD:-请查看 ${PROJECT_DIR}/auth.yaml}${NC}"
echo -e ""
if [ ! -f "$PROJECT_DIR/image_providers.yaml" ] || grep -q "xxxxxxxx" "$PROJECT_DIR/image_providers.yaml" 2>/dev/null; then
    echo -e "  ${YELLOW}⚠ 请先配置 API Key:${NC}"
    echo -e "    ${CYAN}${PROJECT_DIR}/text_providers.yaml${NC}"
    echo -e "    ${CYAN}${PROJECT_DIR}/image_providers.yaml${NC}"
    echo -e "  或在页面内通过「系统设置」配置"
    echo -e ""
fi
if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    warn "请开放防火墙端口: ufw allow ${NGINX_PORT}/tcp"
    echo -e ""
fi
echo -e "  管理命令:"
echo -e "    systemctl status ${SERVICE_SLUG}    查看状态"
echo -e "    systemctl restart ${SERVICE_SLUG}   重启服务"
echo -e "    journalctl -u ${SERVICE_SLUG} -f    查看日志"
echo -e ""
