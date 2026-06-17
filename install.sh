#!/bin/bash
# ============================================================
#  红墨 AI图文生成器 — 一键安装脚本
#  用法: curl -fsSL <raw-url> | sudo bash
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

# ── 配置常量 ──────────────────────────────────────────
PROJECT_DIR="/var/www/aipic"
REPO_URL="https://github.com/welljz/AI-text-image.git"
NGINX_CONF="/etc/nginx/sites-available/redink"
NGINX_LINK="/etc/nginx/sites-enabled/redink"
SYSTEMD_SERVICE="/etc/systemd/system/redink.service"
FLASK_PORT=50123
NGINX_PORT=8083
NODE_MAJOR=22

# ── 检查 ──────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    err "请用 root 用户运行: curl ... | sudo bash"
    exit 1
fi

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════╗"
echo "  ║   红墨 AI图文生成器  一键安装   ║"
echo "  ╚══════════════════════════════════╝"
echo -e "${NC}"

# ========================================================
title "1/7  安装系统依赖"
# ========================================================
apt update -qq
apt install -y -qq \
    nginx \
    python3 \
    python3-venv \
    python3-pip \
    git \
    curl \
    unzip \
    ca-certificates \
    gnupg

# Python3 → python 软链接
if ! command -v python &>/dev/null; then
    ln -sf /usr/bin/python3 /usr/bin/python
fi
log "系统依赖安装完成 (nginx, python3, git, curl...)"

# ========================================================
title "2/7  安装 Node.js ${NODE_MAJOR} + pnpm"
# ========================================================
if ! command -v node &>/dev/null; then
    info "添加 NodeSource 源..."
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    apt install -y -qq nodejs
    log "Node.js $(node -v) 安装完成"
else
    log "Node.js $(node -v) 已安装，跳过"
fi

if ! command -v pnpm &>/dev/null; then
    info "安装 pnpm..."
    npm install -g pnpm --silent
    log "pnpm $(pnpm -v) 安装完成"
else
    log "pnpm $(pnpm -v) 已安装，跳过"
fi

# ========================================================
title "3/7  安装 uv (Python 包管理器)"
# ========================================================
if ! command -v uv &>/dev/null; then
    info "安装 uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    # 软链接到标准路径，兼容 systemd
    if [ -f "$HOME/.local/bin/uv" ] && [ ! -f "/usr/local/bin/uv" ]; then
        ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
    fi
    log "uv $(uv --version) 安装完成"
else
    log "uv $(uv --version) 已安装，跳过"
fi

# 确保 uv 在后续命令可用
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# ========================================================
title "4/7  拉取项目代码"
# ========================================================
if [ -d "$PROJECT_DIR/.git" ]; then
    info "项目目录已存在，执行 git pull..."
    cd "$PROJECT_DIR"
    git pull origin main
    log "代码更新完成"
else
    info "克隆仓库..."
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    log "代码克隆完成"
fi

# ========================================================
title "5/7  安装项目依赖 + 构建前端"
# ========================================================
cd "$PROJECT_DIR"

# 后端
info "安装 Python 依赖 (uv sync)..."
uv sync --no-dev
log "Python 依赖安装完成"

# 前端
info "安装前端依赖 (pnpm install)..."
cd "$PROJECT_DIR/frontend"
export CI=true  # 避免 TTY 检测
pnpm install --no-frozen-lockfile
log "前端依赖安装完成"

info "构建前端 (pnpm build)..."
pnpm build
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

# ── Nginx ───────────────────────────────────────────
info "配置 Nginx..."
cat > "$NGINX_CONF" << 'NGINXEOF'
server {
    listen 8083;
    server_name _;

    proxy_read_timeout 360s;
    proxy_send_timeout 360s;
    proxy_buffering off;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    chunked_transfer_encoding on;

    location / {
        proxy_pass http://127.0.0.1:50123;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
NGINXEOF

# 软链接（幂等）
if [ ! -L "$NGINX_LINK" ] && [ ! -f "$NGINX_LINK" ]; then
    ln -sf "$NGINX_CONF" "$NGINX_LINK"
    log "Nginx 配置已启用"
fi

# 测试并重载
if nginx -t 2>/dev/null; then
    systemctl reload nginx 2>/dev/null || service nginx reload
    log "Nginx 重载成功 → 端口 $NGINX_PORT"
else
    err "Nginx 配置测试失败，请手动检查"
fi

# ── systemd ─────────────────────────────────────────
info "配置 systemd 服务..."
UV_BIN=$(which uv || echo "/root/.local/bin/uv")
cat > "$SYSTEMD_SERVICE" << SYSTEMDEOF
[Unit]
Description=RedInk AI Image Generator
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=${UV_BIN} run python backend/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMDEOF

systemctl daemon-reload
systemctl enable redink 2>/dev/null || true
log "systemd 服务配置完成"

# ========================================================
title "7/7  启动服务"
# ========================================================

# 停止旧进程（如果存在）
if systemctl is-active --quiet redink 2>/dev/null; then
    systemctl restart redink
    log "服务已重启"
else
    systemctl start redink
    log "服务已启动"
fi

# 等待启动
info "等待服务启动..."
for i in $(seq 1 15); do
    if curl -s http://127.0.0.1:$NGINX_PORT/api/health > /dev/null 2>&1; then
        log "服务健康检查通过 ✓"
        break
    fi
    sleep 1
done

# ========================================================
echo -e "\n${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     🎨 安装完成！                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo -e ""
echo -e "  访问地址:  ${CYAN}http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo '服务器IP'):${NGINX_PORT}${NC}"
echo -e "  项目目录:  ${CYAN}${PROJECT_DIR}${NC}"
echo -e ""
if [ ! -f "$PROJECT_DIR/image_providers.yaml" ] || grep -q "xxxxxxxx" "$PROJECT_DIR/image_providers.yaml" 2>/dev/null; then
    echo -e "  ${YELLOW}⚠ 请先配置 API Key:${NC}"
    echo -e "    ${CYAN}${PROJECT_DIR}/text_providers.yaml${NC}"
    echo -e "    ${CYAN}${PROJECT_DIR}/image_providers.yaml${NC}"
    echo -e "  或在页面内通过「系统设置」配置"
    echo -e ""
fi
echo -e "  管理命令:"
echo -e "    systemctl status redink    查看状态"
echo -e "    systemctl restart redink   重启服务"
echo -e "    journalctl -u redink -f    查看日志"
echo -e ""
