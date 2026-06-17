<template>
  <div v-if="visible && record" class="modal-fullscreen" @click="$emit('close')">
    <div class="modal-body" @click.stop>
      <div class="modal-header">
        <div style="flex: 1;">
          <div class="title-section">
            <h3 class="modal-title">{{ record.title }}</h3>
          </div>
          <div class="modal-meta">
            <span>{{ record.outline.pages.length }} 张图片 · {{ formattedDate }}</span>
          </div>
        </div>
        <div class="header-actions">
          <button class="btn download-btn" @click="$emit('downloadAll')">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            打包下载
          </button>
          <button class="close-icon" @click="$emit('close')">×</button>
        </div>
      </div>

      <!-- 文案区域（小红书图文）：已有文案 -->
      <div v-if="contentHtml && record.type !== 'quick'" class="modal-content-section">
        <div class="content-block" v-if="record.content?.titles?.length">
          <div class="content-label">标题</div>
          <div class="content-titles">{{ record.content.titles.join('  |  ') }}</div>
        </div>
        <div class="content-block" v-if="record.content?.copywriting">
          <div class="content-label">文案</div>
          <div class="content-copy">{{ record.content.copywriting }}</div>
        </div>
        <div class="content-block" v-if="record.content?.tags?.length">
          <div class="content-label">标签</div>
          <div class="content-tags">
            <span v-for="tag in record.content.tags" :key="tag" class="content-tag">#{{ tag }}</span>
          </div>
        </div>
      </div>

      <!-- 文案区域（小红书图文）：未生成文案 -->
      <div v-if="!contentHtml && record.type !== 'quick'" class="modal-content-section content-empty">
        <div class="content-empty-text">尚未生成文案</div>
        <button class="btn generate-content-btn" :disabled="generatingContent" @click="$emit('generateContent')">
          <svg v-if="!generatingContent" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2l1.912 5.813a2 2 0 0 0 1.275 1.275L21 12l-5.813 1.912a2 2 0 0 0-1.275 1.275L12 22l-1.912-5.813a2 2 0 0 0-1.275-1.275L3 12l5.813-1.912a2 2 0 0 0 1.275-1.275L12 2z"/></svg>
          <div v-else class="spinner-small-inline"></div>
          {{ generatingContent ? '生成中...' : '生成文案' }}
        </button>
      </div>

      <!-- 提示词区域（快速生图） -->
      <div v-if="record.type === 'quick' && record.prompt" class="modal-content-section">
        <div class="content-block">
          <div class="content-label">输入提示词</div>
          <div class="content-copy">{{ record.prompt }}</div>
        </div>
      </div>

      <!-- 图片网格 -->
      <div class="modal-gallery-grid">
        <div v-for="(img, idx) in (record.images?.generated || [])" :key="idx" class="modal-img-item">
          <!-- 有图片 -->
          <div v-if="img" @click="lightboxSrc = '/api/images/' + record.images?.task_id + '/' + img + '?t=' + imgVersion" class="modal-img-preview" :class="{ 'regenerating': regeneratingImages.has(idx) }">
            <img :src="`/api/images/${record.images?.task_id}/${img}?t=${imgVersion}`" loading="lazy" decoding="async" />
            <div class="modal-img-overlay">
              <button class="modal-overlay-btn" @click.stop="$emit('regenerate', idx)" :disabled="regeneratingImages.has(idx)">
                {{ regeneratingImages.has(idx) ? '重绘中...' : '重新生成' }}
              </button>
            </div>
          </div>
          <!-- 空/失败图片 -->
          <div v-else class="modal-img-failed" :class="{ 'regenerating': regeneratingImages.has(idx) }">
            <div class="failed-icon">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="9" y1="9" x2="15" y2="15"/><line x1="15" y1="9" x2="9" y2="15"/></svg>
            </div>
            <div class="failed-text">未生成</div>
            <button class="modal-overlay-btn failed-retry-btn" @click.stop="$emit('regenerate', idx)" :disabled="regeneratingImages.has(idx)">
              {{ regeneratingImages.has(idx) ? '重绘中...' : '重新生成' }}
            </button>
          </div>
          <div class="img-footer">
            <span>Page {{ idx + 1 }}</span>
            <span v-if="img" class="download-link" @click="$emit('download', img, idx)">下载</span>
            <span v-else class="download-link dimmed">—</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 灯箱 -->
    <div v-if="lightboxSrc" class="inner-lightbox" @click="lightboxSrc = null">
      <button class="inner-lightbox-close" @click="lightboxSrc = null">×</button>
      <img :src="lightboxSrc" class="inner-lightbox-img" @click.stop />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'

interface ViewingRecord {
  id: string
  title: string
  type?: string
  prompt?: string
  updated_at: string
  outline: { raw: string; pages: Array<{ type: string; content: string; visual_prompt?: string; index?: number }> }
  images: { task_id: string; generated: (string | null)[] }
  content?: { titles: string[]; copywriting: string; tags: string[] }
}

const props = defineProps<{
  visible: boolean
  record: ViewingRecord | null
  regeneratingImages: Set<number>
  generatingContent?: boolean
}>()

defineEmits<{
  (e: 'close'): void
  (e: 'showOutline'): void
  (e: 'generateContent'): void
  (e: 'downloadAll'): void
  (e: 'download', filename: string, index: number): void
  (e: 'regenerate', index: number): void
}>()

const lightboxSrc = ref<string | null>(null)
const imgVersion = ref(Date.now())

// 监听重绘完成，刷新图片版本
watch(() => props.regeneratingImages.size, (n, o) => {
  if (n < (o || 0)) imgVersion.value = Date.now()
})

const formattedDate = computed(() => {
  if (!props.record) return ''
  const d = new Date(props.record.updated_at)
  return `${d.getMonth() + 1}/${d.getDate()}`
})

const contentHtml = computed(() => {
  if (!props.record?.content) return false
  const c = props.record.content
  return (c.titles?.length || c.copywriting || c.tags?.length)
})
</script>

<style scoped>
.modal-fullscreen {
  position: fixed; inset: 0; background: rgba(0, 0, 0, 0.9); z-index: 999;
  display: flex; align-items: center; justify-content: center; padding: 40px;
}
.modal-body {
  background: var(--bg-card); width: 100%; max-width: 1000px; height: 90vh;
  border-radius: 16px; display: flex; flex-direction: column; overflow: hidden;
  border: 1px solid var(--border-color);
}
.modal-header {
  padding: 20px; border-bottom: 1px solid var(--border-color);
  display: flex; justify-content: space-between; align-items: flex-start; flex-shrink: 0; gap: 20px;
}
.title-section { display: flex; align-items: flex-start; gap: 12px; margin-bottom: 4px; }
.modal-title { flex: 1; margin: 0; font-size: 18px; font-weight: 600; line-height: 1.4; color: var(--text-main); }
.modal-meta { font-size: 12px; color: var(--text-secondary); display: flex; align-items: center; gap: 12px; margin-top: 8px; }
.header-actions { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
.download-btn {
  padding: 8px 16px; font-size: 13px; font-weight: 600; display: flex; align-items: center; gap: 6px;
  background: var(--primary); color: #080c14; border-radius: 8px; border: none; cursor: pointer;
}
.close-icon { background: none; border: none; font-size: 24px; cursor: pointer; color: var(--text-secondary); }
.close-icon:hover { color: var(--primary); }

/* 文案区域 */
.modal-content-section {
  padding: 16px 20px; border-bottom: 1px solid var(--border-color);
  background: rgba(255,255,255,0.02); flex-shrink: 0;
}
.content-block { margin-bottom: 10px; }
.content-block:last-child { margin-bottom: 0; }
.content-label {
  font-size: 11px; color: var(--primary); text-transform: uppercase; letter-spacing: 1px;
  font-weight: 600; margin-bottom: 4px;
}
.content-titles { font-size: 14px; color: var(--text-main); font-weight: 500; }
.content-copy { font-size: 13px; color: var(--text-sub); line-height: 1.7; max-height: 80px; overflow-y: auto; }
.content-tags { display: flex; flex-wrap: wrap; gap: 6px; }
.content-tag {
  font-size: 12px; color: var(--primary); background: rgba(0,229,255,0.08);
  padding: 2px 10px; border-radius: 12px;
}

/* 未生成文案区域 */
.content-empty {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.content-empty-text {
  font-size: 13px;
  color: var(--text-placeholder);
}
.generate-content-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 16px;
  border-radius: 6px;
  border: 1px solid var(--primary);
  background: rgba(0, 229, 255, 0.08);
  color: var(--primary);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  flex-shrink: 0;
}
.generate-content-btn:hover:not(:disabled) {
  background: var(--primary);
  color: #080c14;
}
.generate-content-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.spinner-small-inline {
  width: 14px;
  height: 14px;
  border: 2px solid var(--primary);
  border-top-color: transparent;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}

/* 图片网格 */
.modal-gallery-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 16px; padding: 20px; overflow-y: auto; flex: 1;
}
.modal-img-item { display: flex; flex-direction: column; }

/* 有图片的预览 */
.modal-img-preview {
  aspect-ratio: 3/4; overflow: hidden; border-radius: 8px; position: relative;
  cursor: pointer; background: rgba(255,255,255,0.02);
}
.modal-img-preview img { width: 100%; height: 100%; object-fit: cover; transition: transform 0.2s; }
.modal-img-preview:hover img { transform: scale(1.05); }
.modal-img-preview.regenerating { opacity: 0.5; }
.modal-img-overlay {
  position: absolute; inset: 0; background: rgba(0,0,0,0.5); opacity: 0;
  transition: opacity 0.2s; display: flex; align-items: center; justify-content: center;
}
.modal-img-preview:hover .modal-img-overlay { opacity: 1; }
.modal-overlay-btn {
  padding: 6px 14px; border-radius: 6px; border: 1px solid rgba(255,255,255,0.3);
  background: rgba(0,0,0,0.5); color: #fff; font-size: 12px; cursor: pointer;
}
.modal-overlay-btn:disabled { opacity: 0.5; cursor: not-allowed; }

/* 空/失败图片占位 */
.modal-img-failed {
  aspect-ratio: 3/4; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 10px;
  background: rgba(255,255,255,0.02); border-radius: 8px;
  border: 1px dashed rgba(255, 77, 79, 0.3);
  position: relative;
}
.modal-img-failed.regenerating {
  opacity: 0.5;
  border-color: rgba(0, 229, 255, 0.3);
}
.failed-icon { color: var(--text-placeholder); opacity: 0.6; }
.failed-text { font-size: 13px; color: var(--text-placeholder); }
.failed-retry-btn {
  border: 1px solid var(--primary) !important;
  background: rgba(0, 229, 255, 0.1) !important;
  color: var(--primary) !important;
}
.failed-retry-btn:hover {
  background: var(--primary) !important;
  color: #080c14 !important;
}

/* 图片底部 */
.img-footer {
  display: flex; justify-content: space-between; align-items: center;
  padding: 8px 4px; font-size: 12px;
}
.img-footer span:first-child { color: var(--text-sub); }
.download-link { color: var(--primary); cursor: pointer; }
.download-link:hover { text-decoration: underline; }
.download-link.dimmed { color: var(--text-placeholder); cursor: default; }
.download-link.dimmed:hover { text-decoration: none; }

/* 灯箱 */
.inner-lightbox {
  position: fixed; inset: 0; z-index: 9999;
  background: rgba(0, 0, 0, 0.95); display: flex; align-items: center; justify-content: center;
  backdrop-filter: blur(8px);
}
.inner-lightbox-close {
  position: absolute; top: 20px; right: 30px; background: none; border: none;
  color: #fff; font-size: 40px; cursor: pointer; z-index: 1; line-height: 1;
}
.inner-lightbox-img {
  max-width: 90vw; max-height: 90vh; object-fit: contain;
  border-radius: 8px; box-shadow: 0 8px 60px rgba(0,0,0,0.5);
}
</style>
