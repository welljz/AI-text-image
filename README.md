# AI图文创作

AI 驱动的社交媒体图文生成器。输入主题，一键生成小红书图文、快速生图。

## 功能

- **小红书图文** — 输入主题 → AI 生成大纲 → 编辑调整 → 批量生成封面+内容页
- **快速生图** — 输入描述直接生图，支持比例选择（1:1 / 3:4 / 16:9 / 9:16）和质量选择
- **多模型支持** — Replicate、OpenAI、Google GenAI、AstraFlow、火山引擎、云雾AI 等
- **历史记录** — 所有生成记录自动保存，支持查看和重新生成

## 技术栈

| 层 | 技术 |
|------|------|
| 后端 | Python 3 + Flask |
| 前端 | Vue 3 + TypeScript + Vite |
| 状态管理 | Pinia |
| 包管理 | uv (Python) / pnpm (前端) |

## 本地运行

**前置：** Python 3.11+、Node.js 18+、pnpm、uv

```bash
git clone git@github.com:welljz/AI-text-image.git
cd AI-text-image

# 配置 API
cp image_providers.yaml.example image_providers.yaml
cp text_providers.yaml.example text_providers.yaml
# 编辑配置文件，填入 API Key

# 安装依赖
uv sync
cd frontend && pnpm install && cd ..

# 启动
uv run python -m backend.app          # 后端 :12398
cd frontend && pnpm dev               # 前端 :5173
```

## 配置

在 Web 设置页面或直接编辑 YAML 配置文件管理 API 服务商。

支持的生图服务商类型：`replicate` | `openai_compatible` | `image_api` | `google_genai`

## License

MIT
