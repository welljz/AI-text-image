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
PYTHON_MIN_VERSION="${PYTHON_MIN_VERSION:-3.9}"

# 服务名直接取目录名
SERVICE_SLUG="$(basename "$PROJECT_DIR")"
NGINX_CONF="/etc/nginx/sites-available/${SERVICE_SLUG}"
NGINX_LINK="/etc/nginx/sites-enabled/${SERVICE_SLUG}"
SYSTEMD_SERVICE="/etc/systemd/system/${SERVICE_SLUG}.service"

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
    apt install -y -qq "$pkg"
}

# ========================================================
title "1/7  检测环境 + 安装系统依赖"
# ========================================================

# Python
if has python3; then
    PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    if [ "$(printf '%s\n' "$PYTHON_MIN_VERSION" "$PY_VER" | sort -V | head -1)" = "$PYTHON_MIN_VERSION" ]; then
        log "Python $PY_VER ✓"
    else
        err "Python 版本过低: $PY_VER (需要 >= $PYTHON_MIN_VERSION)"
        exit 1
    fi
else
    warn "未检测到 Python3，将安装"
fi

# 系统包（按需安装，不重复）
info "检查系统依赖..."
apt update -qq

# 基础工具
for pkg in curl ca-certificates gnupg unzip git; do
    ensure_pkg "$pkg"
done

# Python 生态
for pkg in python3 python3-venv python3-pip; do
    ensure_pkg "$pkg"
done

# Python3 → python 软链接
if ! has python; then
    ln -sf /usr/bin/python3 /usr/bin/python
fi

# Nginx
ensure_pkg nginx

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

# ========================================================
title "2/7  安装 Node.js ${NODE_MAJOR} + pnpm"
# ========================================================
if ! has node; then
    info "安装 Node.js ${NODE_MAJOR}..."
    NODE_SETUP_URL="https://deb.nodesource.com/setup_${NODE_MAJOR}.x"
    NODE_SETUP_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/nodesource/deb/setup_${NODE_MAJOR}.x"

    if safe_curl "$NODE_SETUP_URL" "$NODE_SETUP_MIRROR" | bash - 2>/dev/null; then
        apt install -y -qq nodejs
        log "Node.js $(node -v) 安装完成"
    else
        warn "NodeSource 不可达，尝试 apt 默认版本..."
        apt install -y -qq nodejs 2>/dev/null || {
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
    # 软链接到标准路径
    for uv_path in "$HOME/.local/bin/uv" "/usr/local/bin/uv"; do
        if [ -f "$uv_path" ] && [ ! -f "/usr/local/bin/uv" ]; then
            ln -sf "$uv_path" /usr/local/bin/uv 2>/dev/null || true
        fi
    done
    log "uv $(uv --version 2>/dev/null || echo 'installed') 安装完成"
else
    log "uv $(uv --version) 已安装"
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

if ! pnpm install --no-frozen-lockfile 2>/dev/null; then
    warn "官方源不可达，尝试国内镜像..."
    pnpm config set registry https://registry.npmmirror.com 2>/dev/null || true
    pnpm install --no-frozen-lockfile || {
        err "前端依赖安装失败"
        err "请手动执行: cd $PROJECT_DIR/frontend && pnpm install"
        exit 1
    }
fi
log "前端依赖安装完成"

info "构建前端 (pnpm build)..."
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

# ── 清理旧版服务名（redink → aipic 迁移） ──────────
NEED_REDINK_CLEANUP=0
if [ "$SERVICE_SLUG" = "aipic" ] && systemctl is-active --quiet redink 2>/dev/null; then
    NEED_REDINK_CLEANUP=1
fi

# ── Nginx ───────────────────────────────────────────
info "配置 Nginx (${SERVICE_SLUG})..."
cat > "$NGINX_CONF" << NGINXEOF
server {
    listen ${NGINX_PORT};
    server_name _;

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

# 清理同名旧软链接再创建（防止指向错误）
rm -f "$NGINX_LINK"
ln -sf "$NGINX_CONF" "$NGINX_LINK"

# 先测试新配置再重载
if nginx -t 2>/dev/null; then
    systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
    log "Nginx 重载成功 → 端口 $NGINX_PORT"
else
    err "Nginx 配置测试失败，请手动检查 $NGINX_CONF"
    # 回滚软链接
    rm -f "$NGINX_LINK"
    exit 1
fi

# ── 新 Nginx 配置生效后，安全清理旧版 ──
if [ "$NEED_REDINK_CLEANUP" = 1 ]; then
    info "停止旧版 redink 服务..."
    systemctl stop redink 2>/dev/null || true
    systemctl disable redink 2>/dev/null || true
    rm -f /etc/systemd/system/redink.service
    rm -f /etc/nginx/sites-enabled/redink /etc/nginx/sites-available/redink
    systemctl daemon-reload
    systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
    log "旧版 redink 已清理"
fi

# ── systemd ─────────────────────────────────────────
info "配置 systemd 服务 (${SERVICE_SLUG})..."
UV_BIN=$(which uv 2>/dev/null || echo "/root/.local/bin/uv")
cat > "$SYSTEMD_SERVICE" << SYSTEMDEOF
[Unit]
Description=AI Image Generator (${SERVICE_SLUG})
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
Environment=FLASK_PORT=${FLASK_PORT}
ExecStart=${UV_BIN} run python backend/app.py
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
for i in $(seq 1 15); do
    if curl -s http://127.0.0.1:$FLASK_PORT/api/health > /dev/null 2>&1; then
        log "服务健康检查通过 ✓"
        HEALTH_OK=1
        break
    fi
    sleep 1
done
if [ "$HEALTH_OK" = 0 ]; then
    warn "健康检查超时，请手动检查: systemctl status ${SERVICE_SLUG}"
fi

# ========================================================
echo -e "\n${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     🎨 安装完成！                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo -e ""
echo -e "  访问地址:  ${CYAN}http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo '服务器IP'):${NGINX_PORT}${NC}"
echo -e "  项目目录:  ${CYAN}${PROJECT_DIR}${NC}"
if [ "$SERVICE_SLUG" != "aipic" ]; then
    echo -e "  实例名称:  ${YELLOW}${SERVICE_SLUG}${NC}"
fi
echo -e ""
if [ ! -f "$PROJECT_DIR/image_providers.yaml" ] || grep -q "xxxxxxxx" "$PROJECT_DIR/image_providers.yaml" 2>/dev/null; then
    echo -e "  ${YELLOW}⚠ 请先配置 API Key:${NC}"
    echo -e "    ${CYAN}${PROJECT_DIR}/text_providers.yaml${NC}"
    echo -e "    ${CYAN}${PROJECT_DIR}/image_providers.yaml${NC}"
    echo -e "  或在页面内通过「系统设置」配置"
    echo -e ""
fi
echo -e "  管理命令:"
echo -e "    systemctl status ${SERVICE_SLUG}    查看状态"
echo -e "    systemctl restart ${SERVICE_SLUG}   重启服务"
echo -e "    journalctl -u ${SERVICE_SLUG} -f    查看日志"
echo -e ""
