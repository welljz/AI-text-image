# AI图文创作

AI 驱动的社交媒体图文生成器。输入主题，一键生成小红书图文、快速生图。

## 功能

- **小红书图文** — 输入主题 → AI 生成大纲 → 编辑调整 → 批量生成封面+内容页
- **快速生图** — 输入描述直接生图，支持比例选择（1:1 / 3:4 / 16:9 / 9:16）和质量选择
- **批量生图** — 多行 prompt 一键批量生成
- **多模型支持** — Google GenAI、OpenAI 兼容、Replicate、AstraFlow 等
- **历史记录** — 自动保存，支持预览、重新生成、下载

## 安装

### 环境要求

- Ubuntu 20.04+ / Debian 11+
- Python ≥ 3.11
- 2GB+ 可用内存

### 前置准备

**公开仓库**（默认）无需额外操作，install.sh 通过 HTTPS 拉取代码。

**私有仓库**需要配置 SSH Key，二选一：

**方式一：Deploy Key（推荐）** — 仅授权单个仓库，不影响账号下其他项目

```bash
# 1. 服务器上生成密钥
ssh-keygen -t ed25519 -C "deploy" -f ~/.ssh/id_ed25519 -N ""

# 2. 查看公钥，复制全部内容
cat ~/.ssh/id_ed25519.pub

# 3. 添加到 GitHub
#    仓库 → Settings → Deploy keys → Add deploy key
#    ☑ Allow write access（如需推送）
```

**方式二：账号级 SSH Key** — 一个 Key 通吃所有仓库，适合个人项目

```bash
# 同上生成密钥，然后添加到 GitHub
#    头像 → Settings → SSH and GPG keys → New SSH key
```

### 私有仓库部署

```bash
curl -fsSL https://raw.githubusercontent.com/welljz/AI-text-image/main/install.sh | \
  sudo bash -s -- git@github.com:you/private-repo.git
```

### 线上服务器部署（公开仓库，一键安装）

```bash
curl -fsSL https://raw.githubusercontent.com/welljz/AI-text-image/main/install.sh | sudo bash
```

安装后访问 `http://<服务器IP>:8083`，在「系统设置」填写 API Key。

### 本地开发

```bash
git clone git@github.com:welljz/AI-text-image.git && cd AI-text-image

# 后端
uv sync
cp image_providers.yaml.example image_providers.yaml
cp text_providers.yaml.example text_providers.yaml
# 编辑 *.yaml 填入 API Key
uv run python backend/app.py              # → localhost:50123

# 前端（新终端）
cd frontend && pnpm install && pnpm dev   # → localhost:5173
```

### 本地测试安装（模拟线上环境）

用于验证安装脚本流程，不影响当前运行的项目：

```bash
# 1. 复制项目作为测试源
sudo cp -r /var/www/aipic /var/www/aipic-test

# 2. 指定测试目录和端口运行安装
sudo AIPIC_DIR=/var/www/aipic-test AIPIC_PORT=8084 AIPIC_FLASK=50124 bash /var/www/aipic/install.sh

# 3. 浏览器验证 http://localhost:8084

# 4. 测试完清理
sudo systemctl stop aipic-test
sudo systemctl disable aipic-test
sudo rm -rf /var/www/aipic-test \
  /etc/systemd/system/aipic-test.service \
  /etc/nginx/sites-{available,enabled}/aipic-test
sudo systemctl daemon-reload && sudo systemctl reload nginx
```

### 多实例部署

同一台服务器运行多个独立实例（不同端口、不同目录）：

```bash
sudo AIPIC_DIR=/var/www/aipic-prod AIPIC_PORT=8083 AIPIC_FLASK=50123 bash install.sh
sudo AIPIC_DIR=/var/www/aipic-staging AIPIC_PORT=8084 AIPIC_FLASK=50124 bash install.sh
```

### 卸载

```bash
# 交互式（需确认）
sudo bash uninstall.sh

# 跳过确认（适合脚本）
sudo bash uninstall.sh -y

# 卸载指定实例
AIPIC_DIR=/var/www/aipic-test sudo bash uninstall.sh -y
```

卸载会移除：systemd 服务、Nginx 配置、项目目录、系统用户。不会删除系统级组件（nginx / nodejs / pnpm / uv）。

### 可配置环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `AIPIC_DIR` | `/var/www/aipic` | 项目安装目录 |
| `AIPIC_PORT` | `8083` | Nginx 对外端口 |
| `AIPIC_FLASK` | `50123` | Flask 内部端口 |
| `NODE_MAJOR` | `22` | Node.js 大版本号 |
| `UV_INSTALL_URL` | `astral.sh/uv/install.sh` | uv 安装源 |
| `PYTHON_MIN_VERSION` | `3.11` | Python 最低版本要求 |

## 技术栈

Python 3.11+ / Flask · Vue 3 / TypeScript / Vite · uv · pnpm

```

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 0.3.0 | 2026-06 | 批量生图、预览重新生成、一键安装脚本 |
| 0.2.0 | 2026-06 | 多模型支持、主题切换、大纲编辑优化 |

## License

MIT
