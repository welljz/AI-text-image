<template>
  <!-- 主题输入组合框 -->
  <div class="composer-container">
    <!-- 输入区域 -->
    <div class="composer-input-wrapper">
      <div class="search-icon-static">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M21 21L16.65 16.65M19 11C19 15.4183 15.4183 19 11 19C6.58172 19 3 15.4183 3 11C3 6.58172 6.58172 3 11 3C15.4183 3 19 6.58172 19 11Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </div>
      <textarea
        ref="textareaRef"
        :value="modelValue"
        @input="handleInput"
        class="composer-textarea"
        placeholder="输入主题，例如：秋季显白美甲..."
        @keydown.enter.prevent="handleEnter"
        :disabled="loading"
        rows="1"
      ></textarea>
    </div>

    <!-- 页数选择 -->
    <div class="page-count-row">
      <span class="page-count-label">生成页数</span>
      <div class="page-count-controls">
        <button class="pc-btn" @click="decrement" :disabled="loading || pageCount <= 2">−</button>
        <span class="pc-value">{{ pageCount }}</span>
        <button class="pc-btn" @click="increment" :disabled="loading || pageCount >= 18">+</button>
      </div>

    </div>
    <!-- 图片风格 -->
    <div class="style-row">
      <span class="style-label">图片风格</span>
      <div class="style-options">
        <button v-for="s in styleOptions" :key="s.value"
          class="style-btn" :class="{ active: selectedStyle === s.value }"
          @click="selectStyle(s.value)" :disabled="loading">{{ s.label }}</button>
      </div>
    </div>

    
<!-- 工具栏 -->
    <div class="composer-toolbar">
      <div class="toolbar-right">
        <button
          class="btn btn-primary generate-btn"
          @click="$emit('generate')"
          :disabled="!modelValue.trim() || loading"
        >
          <span v-if="loading" class="spinner-sm"></span>
          <span v-else>生成大纲</span>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  modelValue: string
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void
  (e: 'generate'): void
  (e: 'update:pageCount', value: number): void
  (e: 'update:style', value: string): void
}>()

const textareaRef = ref<HTMLTextAreaElement | null>(null)
const pageCount = ref(4)

const styleOptions = [
  { label: '不限', value: '' },
  { label: '3D黏土风', value: '3D黏土风格，温暖治愈，柔和质感' },
  { label: '日系清新', value: '日系清新风格，明亮通透，简约干净' },
  { label: '科技极简', value: '科技极简风格，深色基调，利落干净' },
  { label: '国潮复古', value: '国潮复古风格，中式典雅，沉稳大气' },
  { label: '扁平插画', value: '扁平插画风格，色块简洁，现代利落' },
]
const selectedStyle = ref('')
function selectStyle(v: string) {
  selectedStyle.value = v
  emit('update:style', v)
}

function decrement() {
  if (pageCount.value > 2) {
    pageCount.value--
    emit('update:pageCount', pageCount.value)
  }
}

function increment() {
  if (pageCount.value < 18) {
    pageCount.value++
    emit('update:pageCount', pageCount.value)
  }
}

function handleInput(event: Event) {
  const target = event.target as HTMLTextAreaElement
  emit('update:modelValue', target.value)
  adjustHeight()
}

function handleEnter(e: KeyboardEvent) {
  if (e.shiftKey) return
  emit('generate')
}

function adjustHeight() {
  const el = textareaRef.value
  if (!el) return
  el.style.height = 'auto'
  el.style.height = Math.max(64, Math.min(el.scrollHeight, 200)) + 'px'
}

</script>

<style scoped>
.composer-container {
  background: var(--bg-card);
  border-radius: 16px;
  padding: 16px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  border: 1px solid var(--border-color);
}

.composer-input-wrapper {
  display: flex;
  align-items: flex-start;
  gap: 12px;
}

.search-icon-static {
  flex-shrink: 0;
  padding-top: 8px;
  color: var(--text-secondary);
}

.composer-textarea {
  flex: 1;
  border: none;
  outline: none;
  font-size: 16px;
  line-height: 1.6;
  resize: none;
  min-height: 44px;
  max-height: 200px;
  padding: 8px 0;
  font-family: inherit;
  color: var(--text-main);
  background: transparent;
}

.composer-textarea::placeholder { color: var(--text-placeholder); }
.composer-textarea:disabled { background: transparent; color: var(--text-secondary); }

/* 页数选择 */
.page-count-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 0;
  margin-top: 4px;
}

.page-count-label {
  font-size: 13px;
  color: var(--text-sub);
}

.page-count-controls {
  display: flex;
  align-items: center;
  gap: 2px;
  background: rgba(255,255,255,0.04);
  border-radius: 8px;
  border: 1px solid var(--border-color);
}

.pc-btn {
  width: 32px;
  height: 32px;
  border: none;
  background: transparent;
  color: var(--text-main);
  font-size: 18px;
  cursor: pointer;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s;
}

.pc-btn:hover:not(:disabled) {
  color: var(--primary);
  background: rgba(0, 229, 255, 0.08);
}

.pc-btn:disabled { opacity: 0.3; cursor: not-allowed; }

.pc-value {
  min-width: 28px;
  text-align: center;
  font-size: 14px;
  font-weight: 600;
  color: var(--primary);
  font-variant-numeric: tabular-nums;
}

/* 工具栏 */
.composer-toolbar {
  display: flex; justify-content: flex-end; align-items: center;
  margin-top: 12px; padding-top: 12px;
  border-top: 1px solid var(--border-color);
}

.generate-btn { padding: 10px 24px; font-size: 15px; border-radius: 100px; display: flex; align-items: center; gap: 8px; }
.generate-btn:disabled { opacity: 0.5; cursor: not-allowed; }

.spinner-sm {
  width: 16px; height: 16px;
  border: 2px solid currentColor; border-top-color: transparent;
  border-radius: 50%; animation: spin 1s linear infinite;
}

@keyframes spin { to { transform: rotate(360deg); } }

/* 风格选择 */
.style-row { display: flex; align-items: center; gap: 12px; padding: 6px 0; }
.style-label { font-size: 13px; color: var(--text-sub); flex-shrink: 0; }
.style-options { display: flex; gap: 6px; flex-wrap: wrap; }
.style-btn {
  padding: 4px 12px; border-radius: 100px; font-size: 12px; cursor: pointer;
  background: rgba(255,255,255,0.04); color: var(--text-sub);
  border: 1px solid var(--border-color); transition: all 0.15s;
}
.style-btn:hover { border-color: var(--primary); color: var(--primary); }
.style-btn:disabled { opacity: 0.4; cursor: not-allowed; }
.style-btn.active {
  background: rgba(0,229,255,0.1); color: var(--primary);
  border-color: var(--primary); font-weight: 600;
}


/* 风格选择 */
.style-row { display: flex; align-items: center; gap: 12px; padding: 6px 0; }
.style-label { font-size: 13px; color: var(--text-sub); flex-shrink: 0; }
.style-options { display: flex; gap: 6px; flex-wrap: wrap; }
</style>
