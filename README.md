# AI图文创作

AI 驱动的社交媒体图文生成器。输入主题，一键生成小红书图文、快速生图。

## 功能

- **小红书图文** — 输入主题 → AI 生成大纲 → 编辑调整 → 批量生成封面+内容页
- **快速生图** — 输入描述直接生图，支持比例选择（1:1 / 3:4 / 16:9 / 9:16）和质量选择
- **批量生图** — 多行 prompt 一键批量生成
- **多模型支持** — Google GenAI、OpenAI 兼容、Replicate、AstraFlow 等
- **历史记录** — 自动保存，支持预览、重新生成、下载

## 安装

```bash
# 一行命令，空服务器直接跑（Ubuntu 20.04+ / Debian 11+）
curl -fsSL https://raw.githubusercontent.com/welljz/AI-text-image/main/install.sh | sudo bash

# 私有仓库
git clone git@github.com:you/repo.git /var/www/aipic && sudo bash /var/www/aipic/install.sh
```

安装后访问 `http://<IP>:8083`，在「系统设置」填写 API Key 即可使用。

## 技术栈

Python 3.11+ / Flask · Vue 3 / TypeScript / Vite · uv · pnpm

## 开发

```bash
git clone git@github.com:welljz/AI-text-image.git && cd AI-text-image
uv sync
cd frontend && pnpm install && cd ..
cp image_providers.yaml.example image_providers.yaml
cp text_providers.yaml.example text_providers.yaml
# 编辑 *.yaml 填入 API Key
uv run python backend/app.py          # 后端 50123
cd frontend && pnpm dev               # 前端 5173
```

## Docker

```bash
cp image_providers.yaml.example image_providers.yaml
cp text_providers.yaml.example text_providers.yaml
# 编辑填入 API Key
docker compose up -d
```

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 0.3.0 | 2026-06 | 批量生图、预览重新生成、一键安装脚本 |
| 0.2.0 | 2026-06 | 多模型支持、主题切换、大纲编辑优化 |

## License

MIT
