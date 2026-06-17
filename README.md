# AI图文创作

AI 驱动的社交媒体图文生成器。输入主题，一键生成小红书图文、快速生图。

## 功能

- **小红书图文** — 输入主题 → AI 生成大纲 → 编辑调整 → 批量生成封面+内容页
- **快速生图** — 输入描述直接生图，支持比例选择（1:1 / 3:4 / 16:9 / 9:16）和质量选择
- **批量生图** — 多行 prompt 一键批量生成
- **多模型支持** — Replicate、OpenAI、Google GenAI、AstraFlow、火山引擎、云迹AI 等
- **历史记录** — 所有生成记录自动保存，支持预览、重新生成、下载

## 一行安装

```bash
# 公开仓库 — 空服务器直接运行
curl -fsSL https://raw.githubusercontent.com/welljz/AI-text-image/main/install.sh | sudo bash

# 私有仓库 — 先配好 SSH key，然后
git clone git@github.com:your/repo.git /var/www/aipic && sudo bash /var/www/aipic/install.sh
```

脚本会自动完成：系统依赖 → Node.js + pnpm → uv → 克隆/构建 → Nginx → systemd 自启动。
安装后访问 `http://<服务器IP>:8083`，首次使用需填写 API Key（`/var/www/aipic/*.yaml` 或页面内「系统设置」）。

> Ubuntu 20.04+ / Debian 11+

## 技术栈

| 层 | 技术 |
|------|------|
| 后端 | Python 3 + Flask |
| 前端 | Vue 3 + TypeScript + Vite |
| 状态管理 | Pinia |
| 包管理 | uv (Python) / pnpm (前端) |

---

## 环境要求

### 运行时

| 依赖 | 最低版本 | 当前使用 | 说明 |
|------|---------|---------|------|
| Python | ≥ 3.11 | 3.14.4 | 后端运行环境 |
| Node.js | ≥ 18 | 22.22.3 | 前端构建和开发 |
| uv | ≥ 0.5 | 0.11.20 | Python 包管理器（替代 pip） |
| pnpm | ≥ 8 | 11.5.3 | 前端包管理器（替代 npm） |

### 操作系统

- Linux（推荐 Ubuntu 22.04+）
- macOS（Apple Silicon / Intel）
- Windows（WSL2 推荐，或原生）

---

## 包管理器安装

### 安装 uv（Python 包管理）

```bash
# Linux / macOS / WSL
curl -LsSf https://astral.sh/uv/install.sh | sh

# 或使用 pip 安装
pip install uv

# 验证
uv --version
```

> 比 pip 快 10-100 倍，自动管理虚拟环境，锁定依赖版本（uv.lock），确保团队和部署环境一致。

### 安装 pnpm（前端包管理）

```bash
# 通过 npm 安装（推荐）
npm install -g pnpm

# 或通过 corepack（Node.js 16.9+ 内置）
corepack enable
corepack prepare pnpm@latest --activate

# 验证
pnpm --version
```

> 比 npm 快 2-3 倍，磁盘空间省 50%+，严格的依赖隔离避免幽灵依赖。

---

## 项目依赖

### Python 后端（pyproject.toml）

| 包名 | 版本 | 用途 |
|------|------|------|
| `flask` | ≥ 3.0.0 | Web 框架，处理 HTTP 请求和路由 |
| `flask-cors` | ≥ 4.0.0 | 跨域资源共享，允许前端开发服务器访问后端 |
| `google-genai` | ≥ 1.0.0 | Google Gemini SDK，调用 Gemini 系列模型 |
| `pyyaml` | ≥ 6.0.0 | 解析 YAML 配置文件（服务商配置） |
| `python-dotenv` | ≥ 1.0.0 | 加载 .env 环境变量文件 |
| `requests` | ≥ 2.31.0 | HTTP 客户端，调用第三方 API |
| `pillow` | ≥ 12.0.0 | 图片处理（缩放、格式转换、合成） |

共 **7 个依赖**，无重型框架。

### 前端运行时（package.json）

| 包名 | 版本 | 用途 |
|------|------|------|
| `vue` | ^3.4.0 | 前端框架 |
| `vue-router` | ^4.2.0 | 前端路由，页面导航 |
| `pinia` | ^2.1.0 | 状态管理，跨组件共享数据 |
| `axios` | ^1.6.0 | HTTP 客户端，请求后端 API |

### 前端开发依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| `vite` | ^5.0.0 | 构建工具，开发服务器 + 打包 |
| `typescript` | ^5.3.0 | TypeScript 编译器，类型检查 |
| `@vitejs/plugin-vue` | ^5.0.0 | Vite 的 Vue 3 SFC 编译插件 |
| `vue-tsc` | ^1.8.0 | Vue 模板类型检查 |

---

## 配置

### 1. 创建配置文件

```bash
cp image_providers.yaml.example image_providers.yaml
cp text_providers.yaml.example text_providers.yaml
```

### 2. 填写 API Key

编辑 `image_providers.yaml` 和 `text_providers.yaml`，填入各服务商的 API Key。

也可以在 Web 界面的「系统设置」页面进行可视化配置。

### 支持的生图服务商

| 类型 | 说明 |
|------|------|
| `google_genai` | Google Gemini 系列（Imagen） |
| `openai_compatible` | OpenAI 兼容接口（含第三方代理） |
| `image_api` | 通用图片生成 API |
| `replicate` | Replicate 平台模型 |

---

## 本地开发

### 一键启动（Linux / macOS）

```bash
git clone git@github.com:welljz/AI-text-image.git
cd AI-text-image

# 自动检测系统类型，安装依赖并启动
bash start.sh
```

### 手动启动

```bash
# 1. 克隆项目
git clone git@github.com:welljz/AI-text-image.git
cd AI-text-image

# 2. 安装后端依赖
uv sync

# 3. 安装前端依赖
cd frontend && pnpm install && cd ..

# 4. 配置 API Key（见上方「配置」章节）
cp image_providers.yaml.example image_providers.yaml
cp text_providers.yaml.example text_providers.yaml
# 编辑 yaml 文件，填入 API Key

# 5. 启动后端（端口 12398）
uv run python -m backend.app

# 6. 新开终端，启动前端开发服务器（端口 5173）
cd frontend && pnpm dev
```

### 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| 前端（开发热更新） | http://localhost:5173 | Vite 开发服务器 |
| 后端 API | http://localhost:12398 | Flask 直接访问 |

---

## 生产部署

### 方式一：install.sh 一键部署（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/welljz/AI-text-image/main/install.sh | sudo bash
```

脚本完成所有配置：Nginx 反向代理 + systemd 自启动，开箱即用。详见上方「一行安装」。

### 方式二：手动部署

参考 `install.sh` 脚本内容，按步骤执行：系统依赖 → Node.js + pnpm → uv → 克隆 → 构建前端 → Nginx → systemd。

---

## Docker 部署

适用场景：需要环境隔离、快速迁移、云平台一键部署。

### docker-compose（推荐）

```bash
# 1. 准备配置文件
cp image_providers.yaml.example image_providers.yaml
cp text_providers.yaml.example text_providers.yaml
# 编辑填入 API Key

# 2. 启动
docker compose up -d

# 3. 查看日志
docker compose logs -f

# 4. 停止
docker compose down
```

### Docker 命令

```bash
# 构建镜像
docker build -t aipic .

# 运行容器
docker run -d \
  --name aipic \
  -p 12398:12398 \
  -v $(pwd)/history:/app/history \
  -v $(pwd)/output:/app/output \
  -v $(pwd)/image_providers.yaml:/app/image_providers.yaml \
  -v $(pwd)/text_providers.yaml:/app/text_providers.yaml \
  aipic
```

### 镜像说明

多阶段构建，最终镜像精简：

```
Stage 1: node:22-slim  → pnpm build（前端构建）
Stage 2: python:3.11-slim → 最终运行镜像（仅 7 个 Python 包 + 前端静态文件）
```

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 0.3.0 | 2026-06 | 批量生图、大纲保存按钮、预览重新生成、一键安装脚本 |
| 0.2.0 | 2026-06 | 多模型支持、主题切换、大纲编辑优化 |

## License

MIT
