<template>
  <div class="container" style="max-width: 100%;">
    <div class="page-header" style="max-width: 1200px; margin: 0 auto 30px auto;">
      <div>
        <h1 class="page-title">编辑大纲</h1>
        <p class="page-subtitle">
          调整页面顺序，修改文案，打造完美内容
          <span v-if="isSaving" class="save-indicator saving">保存中...</span>
          <span v-else class="save-indicator saved">已保存</span>
        </p>
      </div>
      <div style="display: flex; gap: 12px;">
        <button class="btn btn-secondary" @click="goBack" style="background: var(--bg-card); border: 1px solid var(--border-color);">
          上一步
        </button>
        <button class="btn btn-primary" @click="startGeneration">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 6px;"><path d="M20.24 12.24a6 6 0 0 0-8.49-8.49L5 10.5V19h8.5z"></path><line x1="16" y1="8" x2="2" y2="22"></line><line x1="17.5" y1="15" x2="9" y2="15"></line></svg>
          开始生成图片
        </button>
      </div>
    </div>

    <div class="outline-grid">
      <div
        v-for="(page, idx) in store.outline.pages"
        :key="page.index"
        class="card outline-card"
        :draggable="true"
        @dragstart="onDragStart($event, idx)"
        @dragover.prevent="onDragOver($event, idx)"
        @drop="onDrop($event, idx)"
        :class="{ 'dragging-over': dragOverIndex === idx }"
      >
        <div class="card-top-bar">
          <div class="page-info">
             <span class="page-number">P{{ idx + 1 }}</span>
             <span class="page-type" :class="page.type">{{ getPageTypeName(page.type) }}</span>
          </div>
          <div class="card-controls">
            <button class="icon-btn" @click="toggleEdit(idx)" :title="editingIdx === idx ? '预览' : '编辑'">
              <svg v-if="editingIdx === idx" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>
              <svg v-else width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>
            </button>
            <div class="drag-handle" title="拖拽排序">
               <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="12" r="1"></circle><circle cx="9" cy="5" r="1"></circle><circle cx="9" cy="19" r="1"></circle><circle cx="15" cy="12" r="1"></circle><circle cx="15" cy="5" r="1"></circle><circle cx="15" cy="19" r="1"></circle></svg>
            </div>
            <button class="icon-btn" @click="deletePage(idx)" title="删除此页">
               <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
            </button>
          </div>
        </div>

        <!-- Markdown 预览 / 编辑 -->
        <div v-if="editingIdx !== idx" class="md-preview" v-html="renderMarkdown(page.content)" @dblclick="toggleEdit(idx)"></div>
        <textarea
          v-else
          v-model="page.content"
          class="textarea-paper"
          placeholder="在此输入文案..."
          @input="store.updatePage(page.index, page.content)"
        />

        <!-- 生图样式 -->
        <div class="prompt-section">
          <div class="prompt-label">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/></svg>
            生图样式
          </div>
          <textarea
            v-model="page.visual_prompt"
            class="prompt-textarea"
            placeholder="AI 图片生成的视觉描述..."
            @input="store.updatePage(page.index, page.content)"
            rows="2"
          />
          <div class="prompt-chars">{{ (page.visual_prompt || '').length }} 字</div>
        </div>
      </div>

      <div class="card add-card-dashed" @click="addPage('content')">
        <div class="add-content">
          <div class="add-icon">+</div>
          <span>添加页面</span>
        </div>
      </div>
    </div>

    <div style="height: 100px;"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, nextTick, watch, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useGeneratorStore } from '../stores/generator'
import { updateHistory, createHistory } from '../api'

const router = useRouter()
const store = useGeneratorStore()

const dragOverIndex = ref<number | null>(null)
const draggedIndex = ref<number | null>(null)
const isSaving = ref(false)
const editingIdx = ref<number | null>(null)

const getPageTypeName = (type: string) => {
  const names: Record<string, string> = { cover: '封面', content: '内容', summary: '总结' }
  return names[type] || '内容'
}

function toggleEdit(idx: number) {
  editingIdx.value = editingIdx.value === idx ? null : idx
}

// 简易 Markdown 渲染
function renderMarkdown(text: string): string {
  if (!text) return '<span class="md-empty">双击编辑内容...</span>'
  // 防呆：字面 \n → 真实换行
  let html = text.replace(/\\n/g, '\n')
  // HTML 转义
  html = html
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  // 标题
  html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>')
  html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>')
  html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>')
  // 粗体
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
  // 列表
  html = html.replace(/^[•\-\*] (.+)$/gm, '<li>$1</li>')
  html = html.replace(/(<li>.*<\/li>\n?)+/g, '<ul>$&</ul>')
  // 换行
  html = html.replace(/\n\n/g, '<br><br>')
  html = html.replace(/\n/g, '<br>')
  return html
}

const onDragStart = (e: DragEvent, index: number) => {
  draggedIndex.value = index
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.dropEffect = 'move'
  }
}

const onDragOver = (e: DragEvent, index: number) => {
  if (draggedIndex.value === index) return
  dragOverIndex.value = index
}

const onDrop = (e: DragEvent, index: number) => {
  dragOverIndex.value = null
  if (draggedIndex.value !== null && draggedIndex.value !== index) {
    store.movePage(draggedIndex.value, index)
  }
  draggedIndex.value = null
}

const deletePage = (index: number) => {
  if (confirm('确定要删除这一页吗？')) {
    store.deletePage(index)
  }
}

const addPage = (type: 'cover' | 'content' | 'summary') => {
  store.addPage(type, '')
  nextTick(() => window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' }))
}

const goBack = () => router.back()

const startGeneration = async () => {
  if (saveTimer !== null) {
    clearTimeout(saveTimer)
    saveTimer = null
    await autoSaveOutline()
  }
  router.push('/generate')
}

let saveTimer: number | null = null

const autoSaveOutline = async () => {
  if (!store.recordId) {
    if (store.outline.pages && store.outline.pages.length > 0) {
      try {
        const result = await createHistory(
          store.topic || '未命名主题',
          { raw: store.outline.raw, pages: store.outline.pages },
          store.taskId || undefined
        )
        if (result.success && result.record_id) {
          store.setRecordId(result.record_id)
        } else {
          console.warn('自动保存：创建历史记录失败')
          return
        }
      } catch (error) {
        console.error('自动保存：创建历史记录出错:', error)
        return
      }
    } else {
      return
    }
  }

  if (!store.outline.pages || store.outline.pages.length === 0) return

  try {
    isSaving.value = true
    const result = await updateHistory(store.recordId, {
      outline: { raw: store.outline.raw, pages: store.outline.pages }
    })
    if (!result.success) console.error('自动保存失败:', result.error)
  } catch (error) {
    console.error('自动保存出错:', error)
  } finally {
    isSaving.value = false
  }
}

const debouncedSave = () => {
  if (saveTimer !== null) clearTimeout(saveTimer)
  saveTimer = window.setTimeout(() => { autoSaveOutline(); saveTimer = null }, 300)
}

const checkAndCreateHistory = async () => {
  if (store.recordId) return
  if (store.outline.pages && store.outline.pages.length > 0) {
    try {
      const result = await createHistory(
        store.topic || '未命名主题',
        { raw: store.outline.raw, pages: store.outline.pages },
        store.taskId || undefined
      )
      if (result.success && result.record_id) store.setRecordId(result.record_id)
    } catch (error) {
      console.error('创建历史记录出错:', error)
    }
  }
}

onMounted(async () => { await checkAndCreateHistory() })
onUnmounted(() => { if (saveTimer !== null) { clearTimeout(saveTimer); saveTimer = null } })

watch(() => store.outline.pages, () => debouncedSave(), { deep: true })
</script>

<style scoped>
.save-indicator {
  margin-left: 12px;
  font-size: 12px;
  font-weight: 500;
  padding: 2px 8px;
  border-radius: 4px;
  transition: all 0.3s ease;
}
.save-indicator.saving { color: #1890ff; background: rgba(24, 144, 255, 0.1); }
.save-indicator.saved { color: #52c41a; background: rgba(82, 196, 26, 0.1); opacity: 0.7; }

.outline-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
  max-width: 1400px;
  margin: 0 auto;
  padding: 0 20px;
}

.outline-card {
  display: flex;
  flex-direction: column;
  padding: 16px;
  transition: all 0.2s ease;
  border: 1px solid var(--border-color);
  border-radius: 12px;
  background: var(--bg-card);
  min-height: 360px;
  position: relative;
}

.outline-card:hover {
  transform: translateY(-2px);
  border-color: var(--border-hover);
  box-shadow: 0 4px 20px rgba(0, 229, 255, 0.06);
}

.outline-card.dragging-over {
  border: 2px dashed var(--primary);
  opacity: 0.8;
}

.card-top-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--border-color);
}

.page-info { display: flex; align-items: center; gap: 8px; }
.page-number { font-size: 13px; font-weight: 700; color: var(--text-secondary); font-family: 'Inter', sans-serif; }
.page-type {
  font-size: 11px; padding: 2px 8px; border-radius: 4px; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.5px;
}
.page-type.cover { color: #FF4D4F; background: rgba(255, 77, 79, 0.12); }
.page-type.content { color: #00e5ff; background: rgba(0, 229, 255, 0.08); }
.page-type.summary { color: #52C41A; background: rgba(82, 196, 26, 0.12); }

.card-controls { display: flex; gap: 6px; opacity: 0.5; transition: opacity 0.2s; }
.outline-card:hover .card-controls { opacity: 1; }

.drag-handle { cursor: grab; padding: 2px; color: var(--text-secondary); }
.drag-handle:active { cursor: grabbing; }

.icon-btn {
  background: none; border: none; cursor: pointer;
  color: var(--text-secondary); padding: 2px; transition: color 0.2s;
}
.icon-btn:hover { color: var(--primary); }

/* Markdown 预览 */
.md-preview {
  flex: 1;
  font-size: 15px;
  line-height: 1.8;
  color: var(--text-main);
  padding: 4px 0;
  overflow: hidden;
}
.md-preview :deep(h1) { font-size: 20px; font-weight: 700; margin: 4px 0; }
.md-preview :deep(h2) { font-size: 17px; font-weight: 600; margin: 4px 0; color: var(--primary); }
.md-preview :deep(h3) { font-size: 15px; font-weight: 600; margin: 2px 0; }
.md-preview :deep(strong) { color: var(--primary); font-weight: 600; }
.md-preview :deep(ul) { padding-left: 16px; margin: 4px 0; }
.md-preview :deep(li) { margin: 2px 0; }
.md-preview :deep(br) { display: block; content: ''; margin-top: 4px; }
.md-empty { color: var(--text-placeholder); font-style: italic; }

/* 编辑 textarea */
.textarea-paper {
  flex: 1;
  width: 100%;
  border: none;
  background: rgba(255,255,255,0.03);
  border-radius: 8px;
  padding: 10px;
  font-size: 15px;
  line-height: 1.7;
  color: var(--text-main);
  resize: none;
  font-family: 'JetBrains Mono', 'Menlo', 'Monaco', monospace;
  margin-bottom: 8px;
}
.textarea-paper:focus { outline: none; box-shadow: 0 0 0 1px var(--primary); }

/* 生图样式区域 */
.prompt-section {
  border-top: 1px solid var(--border-color);
  padding-top: 10px;
  margin-top: 4px;
}

.prompt-label {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  color: var(--primary);
  text-transform: uppercase;
  letter-spacing: 1px;
  margin-bottom: 6px;
  font-weight: 600;
}

.prompt-textarea {
  width: 100%;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: rgba(255,255,255,0.03);
  padding: 8px 10px;
  font-size: 12px;
  line-height: 1.6;
  color: var(--text-sub);
  resize: vertical;
  font-family: inherit;
  min-height: 48px;
}
.prompt-textarea:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 1px rgba(0, 229, 255, 0.15);
}
.prompt-textarea::placeholder { color: var(--text-placeholder); }

.prompt-chars {
  text-align: right;
  font-size: 11px;
  color: var(--text-secondary);
  margin-top: 4px;
}

/* 添加卡片 */
.add-card-dashed {
  border: 2px dashed var(--border-color);
  background: transparent;
  box-shadow: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  min-height: 360px;
  color: var(--text-secondary);
  transition: all 0.2s;
}
.add-card-dashed:hover {
  border-color: var(--primary);
  color: var(--primary);
  background: rgba(0, 229, 255, 0.03);
}
.add-content { text-align: center; }
.add-icon { font-size: 32px; font-weight: 300; margin-bottom: 8px; }
</style>
