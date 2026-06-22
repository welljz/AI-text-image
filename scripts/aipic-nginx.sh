#!/bin/bash
# aipic-nginx: 域名绑定 Nginx 配置 helper
# 用法: aipic-nginx set <domain>  |  aipic-nginx clear
set -e
PROJECT_DIR="__PROJECT_DIR__"
NGX_ENV="${PROJECT_DIR}/nginx_env.yaml"

if [ ! -f "$NGX_ENV" ]; then
    echo "[✗] nginx_env.yaml 不存在，请先运行 install.sh"
    exit 1
fi

# 读取环境信息
CONF_DIR=$(grep "^conf_dir:" $NGX_ENV | sed 's/^conf_dir: //')
MODE=$(grep "^mode:" $NGX_ENV | sed 's/^mode: //')
LINK_DIR=$(grep "^link_dir:" $NGX_ENV | sed 's/^link_dir: //')
NGINX_BIN=$(grep "^nginx_bin:" $NGX_ENV | sed 's/^nginx_bin: //')
FLASK_PORT=$(grep "^flask_port:" $NGX_ENV | sed 's/^flask_port: //')

ACTION="${1:-}"
DOMAIN="${2:-}"

# 从 PROJECT_DIR 提取 service slug（目录名）
SERVICE_SLUG=$(basename "$PROJECT_DIR")
CONF_FILE="${CONF_DIR}/${SERVICE_SLUG}-domain.conf"

reload_nginx() {
    $NGINX_BIN -t && (systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || $NGINX_BIN -s reload)
}

case "$ACTION" in
    set)
        if [ -z "$DOMAIN" ]; then
            echo "[✗] 用法: $0 set <domain>"
            exit 1
        fi
        # 去掉可能的 http(s):// 前缀
        DOMAIN=$(echo "$DOMAIN" | sed -e 's|^https\{0,1\}://||' -e 's|/.*||')
        echo "配置域名: $DOMAIN (端口 80)"

        # 写入 80 端口 server block
        cat > "$CONF_FILE" << SERVEREOF
server {
    listen 80;
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
SERVEREOF

        # link 模式创建软链接
        if [ "$MODE" = "link" ] && [ -n "$LINK_DIR" ] && [ -d "$LINK_DIR" ]; then
            ln -sf "$CONF_FILE" "${LINK_DIR}/${SERVICE_SLUG}-domain.conf"
        fi

        echo "[1/2] 测试 Nginx 配置..."
        if $NGINX_BIN -t 2>&1; then
            echo "[2/2] 重载 Nginx..."
            if reload_nginx; then
                echo "[✓] 域名已生效: http://${DOMAIN}"
            else
                echo "[✗] Nginx 重载失败"
                exit 1
            fi
        else
            echo "[✗] Nginx 配置测试失败，已保留旧配置"
            rm -f "$CONF_FILE"
            [ "$MODE" = "link" ] && rm -f "${LINK_DIR}/${SERVICE_SLUG}-domain.conf"
            exit 1
        fi
        ;;
    clear)
        echo "清除域名配置..."
        if [ -f "$CONF_FILE" ]; then
            [ "$MODE" = "link" ] && rm -f "${LINK_DIR}/${SERVICE_SLUG}-domain.conf"
            rm -f "$CONF_FILE"
            reload_nginx
            echo "[✓] 域名配置已清除"
        else
            echo "[i] 无需清除（配置文件不存在）"
        fi
        ;;
    *)
        echo "用法: $0 {set <domain> | clear}"
        exit 1
        ;;
esac
