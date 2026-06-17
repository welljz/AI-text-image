<template>
  <!-- 大纲查看模态框 -->
  <div v-if="visible && pages" class="outline-modal-overlay" @click="$emit('close')">
    <div class="outline-modal-content" @click.stop>
      <div class="outline-modal-header">
        <h3>完整大纲</h3>
        <button class="close-icon" @click="$emit('close')">×</button>
      </div>
      <div class="outline-modal-body">
        <div v-for="(page, idx) in pages" :key="idx" class="outline-page-card">
          <div class="outline-page-card-header">
            <span class="page-badge">P{{ idx + 1 }}</span>
            <span class="page-type-badge" :class="page.type">{{ getPageTypeName(page.type) }}</span>
            <span class="word-count">{{ (page.content || '').length }} 字</span>
          </div>
          <div class="outline-page-card-content" v-text="page.content"></div>
          <div v-if="page.visual_prompt" class="outline-page-card-prompt">
            <span class="prompt-label">生图样式</span>
            <div class="prompt-text">{{ page.visual_prompt }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">

interface Page {
  type: string
  content: string
  visual_prompt?: string
}

defineProps<{
  visible: boolean
  pages: Page[] | null
}>()

defineEmits<{
  (e: 'close'): void
}>()

function getPageTypeName(type: string): string {
  const names: Record<string, string> = {
    cover: '封面',
    content: '内容',
    summary: '总结',
    checklist: '清单',
    comparison: '对比',
    steps: '步骤'
  }
  return names[type] || '内容'
}
</script>

<style scoped>
.outline-modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.75);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px;
}
.outline-modal-content {
  background: var(--bg-card);
  width: 100%;
  max-width: 800px;
  max-height: 85vh;
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
}
.outline-modal-header {
  padding: 20px 24px;
  border-bottom: 1px solid var(--border-color);
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-shrink: 0;
}
.outline-modal-header h3 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--text-main);
}
.close-icon {
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: var(--text-secondary);
  padding: 0;
  line-height: 1;
  transition: color 0.2s;
}
.close-icon:hover { color: var(--text-main); }
.outline-modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 20px 24px;
  background: rgba(255,255,255,0.02);
}
.outline-page-card {
  background: var(--bg-card);
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 16px;
  border: 1px solid var(--border-color);
  transition: all 0.2s;
}
.outline-page-card:last-child { margin-bottom: 0; }
.outline-page-card-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 14px;
  padding-bottom: 14px;
  border-bottom: 1px solid var(--border-color);
}
.page-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 36px;
  height: 24px;
  padding: 0 8px;
  background: var(--primary);
  color: white;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 700;
  font-family: 'Inter', sans-serif;
}
.page-type-badge {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
  background: #e9ecef;
  color: #6c757d;
}
.page-type-badge.cover { background: #e3f2fd; color: #1976d2; }
.page-type-badge.content { background: #f3e5f5; color: #7b1fa2; }
.page-type-badge.summary { background: #e8f5e9; color: #388e3c; }
.page-type-badge.checklist { background: #fff3e0; color: #e65100; }
.page-type-badge.comparison { background: #fce4ec; color: #c62828; }
.page-type-badge.steps { background: #e0f2f1; color: #00695c; }
.word-count {
  margin-left: auto;
  font-size: 11px;
  color: var(--text-secondary);
}
.outline-page-card-content {
  font-size: 14px;
  line-height: 1.8;
  color: var(--text-main);
  white-space: pre-wrap;
  word-break: break-word;
}
.outline-page-card-prompt {
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px solid var(--border-color);
}
.outline-page-card-prompt .prompt-label {
  font-size: 11px;
  color: var(--primary);
  text-transform: uppercase;
  letter-spacing: 1px;
  font-weight: 600;
}
.outline-page-card-prompt .prompt-text {
  font-size: 13px;
  color: var(--text-sub);
  margin-top: 4px;
  line-height: 1.6;
}
@media (max-width: 768px) {
  .outline-modal-overlay { padding: 20px; }
  .outline-modal-content { max-height: 90vh; }
  .outline-modal-header { padding: 16px 20px; }
  .outline-modal-body { padding: 16px 20px; }
}
</style>
