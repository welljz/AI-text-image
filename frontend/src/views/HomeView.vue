<template>
  <div class="container home-container">
    <!-- Hero Area -->
    <div class="hero-section">

      <!-- Tab 切换 -->
      <div class="tab-bar">
        <button class="tab-btn" :class="{ active: activeTab === 'rednote' }" @click="activeTab = 'rednote'">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
          小红书图文
        </button>
        <button class="tab-btn" :class="{ active: activeTab === 'quick' }" @click="activeTab = 'quick'">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3l1.912 5.813a2 2 0 0 0 1.275 1.275L21 12l-5.813 1.912a2 2 0 0 0-1.275 1.275L12 21l-1.912-5.813a2 2 0 0 0-1.275-1.275L3 12l5.813-1.912a2 2 0 0 0 1.275-1.275L12 3z"/></svg>
          快速生图
        </button>
      </div>

      <!-- ========== 小红书图文 Tab ========== -->
      <template v-if="activeTab === 'rednote'">
        <div class="hero-content">
          <div class="brand-pill">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 6px;"><path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/></svg>
            AI 驱动的智能创作引擎
          </div>
          <div class="platform-slogan">
            让传播不再需要门槛，让创作从未如此简单
          </div>
          <h1 class="page-title">灵感一触即发</h1>
          <p class="page-subtitle">输入你的创意主题，让 AI 帮你生成爆款标题、正文和封面图</p>
        </div>

        <ComposerInput
          v-model="topic"
          :loading="loading"
          @generate="handleGenerate"
          @update:pageCount="pageCount = $event"
          @update:style="imgStyle = $event"
        />
      </template>

      <!-- ========== 快速生图 Tab ========== -->
      <template v-else>
        <div class="hero-content">
          <div class="brand-pill quick-pill">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 6px;"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
            极速出图，无需等待
          </div>
          <h1 class="page-title">快速生图</h1>
          <p class="page-subtitle">输入描述，AI 直接生成图片，无需大纲和文案</p>
        </div>

        <div class="quick-input-area">
          <!-- 多图模式开关 -->
          <div class="batch-toggle-row">
            <button
              class="batch-toggle-btn"
              :class="{ active: batchMode }"
              @click="batchMode = !batchMode; quickResult = ''; batchResults = []"
              :disabled="quickLoading"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
              {{ batchMode ? '多图模式' : '单张模式' }}
            </button>
            <span v-if="batchMode" class="batch-count">已输入 {{ batchPromptCount }} 行</span>
          </div>
          <textarea
            v-model="quickPrompt"
            class="quick-textarea"
            :placeholder="batchMode ? '一行描述一张图片，例如：\n电商首页，深色主题，产品卡片布局\n商品列表页，筛选栏+网格卡片\n商品详情页，大图+购买按钮\n购物车页面，清单+价格汇总' : '描述你想要的图片内容，例如：一只坐在窗台上的橘猫，阳光透过百叶窗洒在它身上，温暖的光影，摄影风格'"
            rows="4"
            :disabled="quickLoading"
            @keydown.ctrl.enter="handleQuickGenerate"
            @input="batchMode && (batchPromptCount = quickPrompt.split('\n').filter(l => l.trim()).length)"
          ></textarea>

          <!-- 参考图片上传 -->
          <div class="quick-image-upload">
            <div class="quick-image-previews" v-if="quickImagePreviews.length > 0">
              <div v-for="(img, idx) in quickImagePreviews" :key="idx" class="quick-image-item">
                <img :src="img.preview" :alt="`参考图 ${idx + 1}`" />
                <button class="quick-image-remove" @click="removeQuickImage(idx)">×</button>
              </div>
            </div>
            <label class="quick-upload-btn" :class="{ active: quickImageFiles.length > 0 }">
              <input
                type="file"
                accept="image/*"
                multiple
                @change="handleQuickImageUpload"
                :disabled="quickLoading"
                style="display: none;"
              />
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
                <circle cx="8.5" cy="8.5" r="1.5"></circle>
                <polyline points="21 15 16 10 5 21"></polyline>
              </svg>
              <span>上传参考图</span>
              <span v-if="quickImageFiles.length > 0" class="quick-badge">{{ quickImageFiles.length }}</span>
            </label>
          </div>

          <div class="quick-actions">
            <div class="quick-selectors">
              <div class="ratio-selector">
                <span class="ratio-label">比例</span>
                <button
                  v-for="r in ratios"
                  :key="r.value"
                  class="ratio-btn"
                  :class="{ active: quickRatio === r.value }"
                  @click="quickRatio = r.value"
                  :disabled="quickLoading"
                >{{ r.label }}</button>
              </div>
              <div class="ratio-selector">
                <span class="ratio-label">质量</span>
                <button
                  v-for="q in qualityOptions"
                  :key="q.value"
                  class="ratio-btn"
                  :class="{ active: quickQuality === q.value }"
                  @click="quickQuality = q.value"
                  :disabled="quickLoading"
                >{{ q.label }}</button>
              </div>
            </div>
            <div style="display: flex; align-items: center; gap: 12px;">
              <span class="quick-hint">Ctrl + Enter</span>
              <button class="btn btn-primary quick-btn" @click="handleQuickGenerate" :disabled="quickLoading || !quickPrompt.trim()">
                <svg v-if="!quickLoading" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/></svg>
                <div v-else class="spinner-small-white"></div>
                {{ quickLoading ? '生成中...' : batchMode && batchPromptCount > 0 ? `生成全部 (${batchPromptCount} 张)` : '生成图片' }}
              </button>
            </div>
          </div>
        </div>

        <!-- 生成结果：单张 -->
        <div v-if="quickResult && !batchMode" class="quick-result">
          <div class="quick-result-img" @click="quickLightbox = true">
            <img :src="quickResult" alt="生成结果" />
            <div class="quick-img-overlay">
              <span>点击查看大图</span>
            </div>
          </div>
          <div class="quick-result-actions">
            <span class="quick-done-label">生成完成</span>
            <button class="btn" @click="downloadQuickImage" style="border: 1px solid var(--border-color);">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
              下载
            </button>
            <button class="btn" @click="resetQuick" style="border: 1px solid var(--border-color);">再来一张</button>
          </div>
        </div>

        <!-- 生成结果：批量 -->
        <div v-if="batchResults.length > 0 && batchMode" class="batch-result">
          <div class="batch-result-header">
            <span class="quick-done-label">{{ batchResults.filter(r => r.image_url).length }}/{{ batchResults.length }} 张生成完成</span>
            <button class="btn" @click="resetQuick" style="border: 1px solid var(--border-color);">重新生成</button>
          </div>
          <div class="batch-result-grid">
            <div v-for="(item, idx) in batchResults" :key="idx" class="batch-result-card">
              <div v-if="item.image_url" class="batch-result-img" @click="batchLightboxSrc = item.image_url">
                <img :src="item.image_url" :alt="`图片 ${idx + 1}`" loading="lazy" />
                <div class="quick-img-overlay"><span>查看大图</span></div>
              </div>
              <div v-else class="batch-result-failed">
                <span>生成失败</span>
              </div>
              <div class="batch-result-footer">
                <span class="batch-result-index">#{{ idx + 1 }}</span>
                <span class="batch-result-prompt" :title="item.prompt">{{ item.prompt?.slice(0, 30) }}{{ item.prompt?.length > 30 ? '...' : '' }}</span>
                <a v-if="item.image_url" :href="item.image_url + '?thumbnail=false'" download class="batch-download-icon" @click.stop>
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                </a>
              </div>
            </div>
          </div>
        </div>

        <!-- 灯箱 -->
        <div v-if="quickLightbox || batchLightboxSrc" class="quick-lightbox" @click="quickLightbox = false; batchLightboxSrc = null">
          <button class="quick-lightbox-close" @click="quickLightbox = false; batchLightboxSrc = null">×</button>
          <img :src="batchLightboxSrc || quickResult" @click.stop />
        </div>
      </template>
    </div>

    <!-- 版权信息 -->
    <div class="page-footer">
      <div class="footer-copyright">© 2026 AI图文创作</div>
    </div>

    <!-- 错误提示 -->
    <div v-if="errorMsg" class="error-toast">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>
      {{ errorMsg }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useGeneratorStore } from '../stores/generator'
import { generateOutline, createHistory, text2img, text2imgBatch } from '../api'

import ComposerInput from '../components/home/ComposerInput.vue'

const router = useRouter()
const store = useGeneratorStore()

// --- Tab ---
const activeTab = ref<'rednote' | 'quick'>('rednote')

// --- 小红书图文 ---
const topic = ref('')
const loading = ref(false)
const pageCount = ref(4)
const imgStyle = ref('')

async function handleGenerate() {
  if (!topic.value.trim()) return

  loading.value = true
  errorMsg.value = ''

  try {
    const result = await generateOutline(
      topic.value.trim(),
      pageCount.value,
      imgStyle.value || undefined
    )

    if (result.success && result.pages) {
      store.setTopic(topic.value.trim())
      store.setOutline(result.outline || '', result.pages)

      try {
        const historyResult = await createHistory(
          topic.value.trim(),
          {
            raw: result.outline || '',
            pages: result.pages
          }
        )

        if (historyResult.success && historyResult.record_id) {
          store.setRecordId(historyResult.record_id)
        } else {
          console.error('创建历史记录失败:', historyResult.error || '未知错误')
          store.setRecordId(null)
        }
      } catch (err: any) {
        console.error('创建历史记录异常:', err.message || err)
        store.setRecordId(null)
      }

      router.push('/outline')
    } else {
      errorMsg.value = result.error || '生成大纲失败'
    }
  } catch (err: any) {
    errorMsg.value = err.message || '网络错误，请重试'
  } finally {
    loading.value = false
  }
}

// --- 快速生图 ---
const quickPrompt = ref('')
const quickLoading = ref(false)
const quickResult = ref('')
const quickLightbox = ref(false)
const quickRatio = ref('1:1')
const quickQuality = ref('medium')
const errorMsg = ref('')
const ratios = [
  { label: '1:1', value: '1:1' },
  { label: '3:4', value: '3:4' },
  { label: '16:9', value: '16:9' },
  { label: '9:16', value: '9:16' },
]
const qualityOptions = [
  { label: '标准', value: 'medium' },
  { label: '高清', value: 'high' },
]

// --- 批量生图 ---
const batchMode = ref(false)
const batchResults = ref<any[]>([])
const batchPromptCount = ref(0)
const batchLightboxSrc = ref<string | null>(null)

// --- 快速生图 图片上传 ---
interface QuickImageItem { file: File; preview: string }
const quickImageFiles = ref<File[]>([])
const quickImagePreviews = ref<QuickImageItem[]>([])

function handleQuickImageUpload(event: Event) {
  const target = event.target as HTMLInputElement
  if (!target.files) return
  Array.from(target.files).forEach((file) => {
    if (quickImageFiles.value.length >= 5) return
    quickImageFiles.value.push(file)
    quickImagePreviews.value.push({ file, preview: URL.createObjectURL(file) })
  })
  target.value = ''
}

function removeQuickImage(index: number) {
  URL.revokeObjectURL(quickImagePreviews.value[index].preview)
  quickImagePreviews.value.splice(index, 1)
  quickImageFiles.value.splice(index, 1)
}

async function handleQuickGenerate() {
  if (!quickPrompt.value.trim() || quickLoading.value) return

  quickLoading.value = true
  errorMsg.value = ''
  quickResult.value = ''
  batchResults.value = []

  try {
    if (batchMode.value) {
      // 批量模式：按行拆分提示词
      const lines = quickPrompt.value.split('\n').filter((l: string) => l.trim())
      if (lines.length === 0) {
        errorMsg.value = '请输入至少一行提示词'
        quickLoading.value = false
        return
      }
      const result = await text2imgBatch(lines, quickRatio.value, quickQuality.value)
      if (result.success && result.images) {
        batchResults.value = result.images
      } else {
        errorMsg.value = result.error || '批量生成失败'
      }
    } else {
      // 单张模式
      const imgFiles = quickImageFiles.value.length > 0 ? quickImageFiles.value : undefined
      const result = await text2img(quickPrompt.value.trim(), quickRatio.value, quickQuality.value, imgFiles)
      if (result.success && result.image_url) {
        quickResult.value = result.image_url
      } else {
        errorMsg.value = result.error || '生成失败'
      }
    }
  } catch (err: any) {
    errorMsg.value = err.message || '网络错误，请重试'
  } finally {
    quickLoading.value = false
  }
}

function downloadQuickImage() {
  if (!quickResult.value) return
  const link = document.createElement('a')
  link.href = quickResult.value + '?thumbnail=false'
  link.download = 'generated.png'
  link.click()
}

function resetQuick() {
  quickResult.value = ''
  batchResults.value = []
  quickPrompt.value = ''
  batchPromptCount.value = 0
  quickImagePreviews.value.forEach(img => URL.revokeObjectURL(img.preview))
  quickImagePreviews.value = []
  quickImageFiles.value = []
}
</script>

<style scoped>
.home-container {
  max-width: 1100px;
  position: relative;
  z-index: 1;
}

.hero-section {
  text-align: center;
  margin-bottom: 40px;
  padding: 50px 60px;
  animation: fadeIn 0.6s ease-out;
  background: var(--bg-card);
  border-radius: 24px;
  border: 1px solid rgba(0, 255, 255, 0.15);
  box-shadow: 0 0 60px rgba(0, 255, 255, 0.06), 0 8px 32px rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(10px);
}

/* Tab Bar */
.tab-bar {
  display: flex;
  gap: 0;
  margin-bottom: 40px;
  border-bottom: 1px solid var(--border-color);
  padding-bottom: 0;
}
.tab-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px 20px;
  font-size: 15px;
  font-weight: 500;
  color: var(--text-sub);
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  transition: all 0.2s;
}
.tab-btn:hover { color: var(--text-main); }
.tab-btn.active {
  color: var(--primary);
  border-bottom-color: var(--primary);
}

.hero-content {
  margin-bottom: 36px;
}

.brand-pill {
  display: inline-flex;
  align-items: center;
  padding: 6px 16px;
  background: rgba(0, 255, 255, 0.08);
  color: var(--primary);
  border-radius: 100px;
  font-size: 13px;
  font-weight: 600;
  margin-bottom: 20px;
  letter-spacing: 0.5px;
  border: 1px solid rgba(0, 255, 255, 0.15);
  text-shadow: 0 0 20px rgba(0, 255, 255, 0.4);
}
.quick-pill {
  background: rgba(168, 85, 247, 0.1);
  color: #a855f7;
  border-color: rgba(168, 85, 247, 0.2);
  text-shadow: 0 0 20px rgba(168, 85, 247, 0.4);
}

.platform-slogan {
  font-size: 20px;
  font-weight: 600;
  color: var(--text-main);
  margin-bottom: 24px;
  line-height: 1.6;
  letter-spacing: 0.5px;
}

.page-subtitle {
  font-size: 16px;
  color: var(--text-sub);
  margin-top: 12px;
}

/* 快速生图 */
.quick-input-area {
  margin-bottom: 24px;
}
.quick-textarea {
  width: 100%;
  padding: 16px 20px;
  font-size: 15px;
  line-height: 1.8;
  color: var(--text-main);
  background: var(--bg-body);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  resize: vertical;
  min-height: 100px;
  outline: none;
  transition: border-color 0.2s;
  font-family: inherit;
}
.quick-textarea:focus {
  border-color: var(--primary);
}
.quick-textarea::placeholder {
  color: var(--text-placeholder);
}
.quick-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 12px;
}
.quick-selectors {
  display: flex;
  gap: 20px;
}
.ratio-selector {
  display: flex;
  align-items: center;
  gap: 4px;
}
.ratio-label {
  font-size: 12px;
  color: var(--text-secondary);
  margin-right: 6px;
}
.ratio-btn {
  padding: 4px 10px;
  font-size: 12px;
  font-weight: 500;
  color: var(--text-sub);
  background: var(--bg-body);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.15s;
}
.ratio-btn:hover {
  border-color: var(--primary);
  color: var(--text-main);
}
.ratio-btn.active {
  background: var(--primary);
  color: #080c14;
  border-color: var(--primary);
}
.ratio-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.quick-hint {
  font-size: 12px;
  color: var(--text-secondary);
}
.quick-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 12px 28px;
  font-size: 15px;
  font-weight: 600;
  min-width: 140px;
  justify-content: center;
}
.quick-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 生成结果 */
.quick-result {
  margin-top: 24px;
  padding-top: 24px;
  border-top: 1px solid var(--border-color);
}
.quick-result-img {
  position: relative;
  max-width: 100%;
  margin: 0 auto;
  border-radius: 12px;
  cursor: pointer;
  border: 1px solid var(--border-color);
  display: inline-block;
  line-height: 0;
}
.quick-result-img img {
  max-width: 600px;
  max-height: 70vh;
  border-radius: 12px;
  display: block;
  transition: transform 0.2s;
}
.quick-result-img:hover img {
  transform: scale(1.03);
}
.quick-img-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0,0,0,0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition: opacity 0.2s;
  color: #fff;
  font-size: 14px;
  font-weight: 500;
}
.quick-result-img:hover .quick-img-overlay {
  opacity: 1;
}
.quick-result-actions {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin-top: 16px;
}
.quick-done-label {
  font-size: 13px;
  color: var(--primary);
  font-weight: 600;
  margin-right: 8px;
}

/* 灯箱 */
.quick-lightbox {
  position: fixed;
  inset: 0;
  z-index: 9999;
  background: rgba(0, 0, 0, 0.92);
  display: flex;
  align-items: center;
  justify-content: center;
  backdrop-filter: blur(8px);
}
.quick-lightbox-close {
  position: absolute;
  top: 20px;
  right: 30px;
  background: none;
  border: none;
  color: #fff;
  font-size: 40px;
  cursor: pointer;
  z-index: 1;
  line-height: 1;
}
.quick-lightbox img {
  max-width: 90vw;
  max-height: 90vh;
  object-fit: contain;
  border-radius: 8px;
}

.spinner-small-white {
  width: 18px;
  height: 18px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}

.page-footer {
  text-align: center;
  padding: 24px 0 16px;
  margin-top: 20px;
}

.footer-copyright {
  font-size: 13px;
  color: var(--text-secondary);
  font-weight: 400;
}

.error-toast {
  position: fixed;
  bottom: 32px;
  left: 50%;
  transform: translateX(-50%);
  background: #FF4D4F;
  color: white;
  padding: 12px 24px;
  border-radius: 50px;
  box-shadow: 0 8px 24px rgba(255, 77, 79, 0.3);
  display: flex;
  align-items: center;
  gap: 8px;
  z-index: 1000;
  animation: slideUp 0.3s ease-out;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

/* 快速生图 图片上传 */
.quick-image-upload {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 0;
}
.quick-image-previews {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.quick-image-item {
  position: relative;
  width: 48px;
  height: 48px;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid var(--border-color);
}
.quick-image-item img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.quick-image-remove {
  position: absolute;
  top: -2px;
  right: -2px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #ef4444;
  color: #fff;
  border: none;
  font-size: 12px;
  line-height: 18px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  opacity: 0;
  transition: opacity .15s;
}
.quick-image-item:hover .quick-image-remove {
  opacity: 1;
}
.quick-upload-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 6px 12px;
  border-radius: 8px;
  border: 1px dashed var(--border-color);
  cursor: pointer;
  font-size: 13px;
  color: var(--text-secondary);
  transition: all .15s;
  user-select: none;
}
.quick-upload-btn:hover {
  border-color: var(--accent-color);
  color: var(--accent-color);
}
.quick-upload-btn.active {
  border-style: solid;
  border-color: var(--accent-color);
  color: var(--accent-color);
  background: var(--accent-bg);
}
.quick-badge {
  background: var(--accent-color);
  color: #fff;
  font-size: 11px;
  min-width: 18px;
  height: 18px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 4px;
}

/* 批量模式 */
.batch-toggle-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 8px;
}
.batch-toggle-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 12px;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: var(--bg-body);
  color: var(--text-sub);
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.15s;
}
.batch-toggle-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.batch-toggle-btn.active {
  background: rgba(168, 85, 247, 0.1);
  border-color: #a855f7;
  color: #a855f7;
}
.batch-count {
  font-size: 12px;
  color: var(--text-secondary);
}

/* 批量结果 */
.batch-result {
  margin-top: 24px;
  padding-top: 24px;
  border-top: 1px solid var(--border-color);
}
.batch-result-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.batch-result-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 16px;
}
.batch-result-card {
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid var(--border-color);
  background: var(--bg-card);
  transition: transform 0.15s;
}
.batch-result-card:hover {
  transform: translateY(-2px);
}
.batch-result-img {
  aspect-ratio: 3/4;
  overflow: hidden;
  cursor: pointer;
  position: relative;
  background: var(--bg-body);
}
.batch-result-img img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.2s;
}
.batch-result-img:hover img {
  transform: scale(1.05);
}
.batch-result-failed {
  aspect-ratio: 3/4;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 77, 79, 0.05);
  color: #ff4d4f;
  font-size: 12px;
  border: 1px dashed rgba(255, 77, 79, 0.2);
}
.batch-result-footer {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  font-size: 11px;
  color: var(--text-sub);
}
.batch-result-index {
  font-weight: 700;
  color: var(--text-secondary);
  min-width: 24px;
}
.batch-result-prompt {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.batch-download-icon {
  color: var(--primary);
  flex-shrink: 0;
}
.batch-download-icon:hover {
  color: var(--text-main);
}
</style>
