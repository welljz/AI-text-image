<template>
  <div class="container" style="max-width: 1200px;">

    <!-- Header Area -->
    <div class="page-header">
      <div>
        <h1 class="page-title">我的创作</h1>
      </div>
      <div style="display: flex; gap: 10px;">
        <button
          class="btn"
          @click="handleScanAll"
          :disabled="isScanning"
          style="border: 1px solid var(--border-color);"
        >
          <svg v-if="!isScanning" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 6px;"><path d="M23 4v6h-6"></path><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"></path></svg>
          <div v-else class="spinner-small" style="margin-right: 6px;"></div>
          {{ isScanning ? '同步中...' : '同步历史' }}
        </button>
        <button class="btn btn-primary" @click="router.push('/')">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 6px;"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
          新建图文
        </button>
      </div>
    </div>

    <!-- Stats Overview -->
    <StatsOverview v-if="stats" :stats="stats" :orphanCount="orphanTotal" />

    <!-- Toolbar: Tabs & Search -->
    <div class="toolbar-wrapper">
      <div class="tabs-container" style="margin-bottom: 0; border-bottom: none;">
        <div
          class="tab-item"
          :class="{ active: currentTab === 'all' }"
          @click="switchTab('all')"
        >
          全部
        </div>
        <div
          class="tab-item"
          :class="{ active: currentTab === 'completed' }"
          @click="switchTab('completed')"
        >
          已完成
        </div>
        <div
          class="tab-item"
          :class="{ active: currentTab === 'draft' }"
          @click="switchTab('draft')"
        >
          草稿箱
        </div>
        <div
          class="tab-item"
          :class="{ active: currentTab === 'orphan' }"
          @click="switchTab('orphan')"
        >
          游离图片
        </div>
      </div>

      <!-- 类型切换 -->
      <div class="type-tabs">
        <button
          class="type-tab"
          :class="{ active: currentType === 'rednote' }"
          @click="switchType('rednote')"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
          小红书图文
        </button>
        <button
          class="type-tab"
          :class="{ active: currentType === 'quick' }"
          @click="switchType('quick')"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
          快速生图
        </button>
      </div>

      <div class="search-mini">
        <svg class="icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
        <input
          v-model="searchKeyword"
          type="text"
          placeholder="搜索标题..."
          @keyup.enter="handleSearch"
        />
      </div>
    </div>

    <!-- Content Area -->
    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
    </div>

    <!-- 游离图片 -->
    <div v-if="currentTab === 'orphan' && orphans.length > 0" class="gallery-grid">
      <div v-for="orphan in orphans" :key="orphan.task_id" class="gallery-card orphan-card">
        <div class="card-cover" @click="previewOrphanImages(orphan)">
          <img
            v-if="orphan.images.length > 0"
            :src="`/api/images/${orphan.task_id}/${orphan.images[0]}`"
            alt="preview"
            loading="lazy"
            decoding="async"
          />
          <div v-else class="cover-placeholder">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="9" y1="9" x2="15" y2="15"/><line x1="15" y1="9" x2="9" y2="15"/></svg>
          </div>
          <div class="card-overlay">
            <button class="overlay-btn" @click.stop="previewOrphanImages(orphan)">查看图片</button>
          </div>
          <div class="status-badge" style="background: rgba(250, 173, 20, 0.9);">未关联</div>
        </div>
        <div class="card-footer">
          <div class="card-title" :title="orphan.task_id">{{ orphan.task_id }}</div>
          <div class="card-meta">
            <span>{{ orphan.image_count }}张</span>
            <span class="dot">·</span>
            <span>{{ orphan.total_size_kb }}KB</span>
            <div class="more-actions-wrapper">
              <button class="more-btn" @click.stop="confirmDeleteOrphan(orphan)">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <polyline points="3 6 5 6 21 6"></polyline>
                  <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-else-if="currentTab === 'orphan' && !loadingOrphans && orphans.length === 0" class="empty-state-large">
      <div class="empty-img">
        <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
      </div>
      <h3>没有游离图片</h3>
      <p class="empty-tips">所有任务目录都已关联到历史记录</p>
    </div>

    <div v-else-if="currentTab !== 'orphan' && records.length === 0" class="empty-state-large">
      <div class="empty-img">
        <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path><polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline><line x1="12" y1="22.08" x2="12" y2="12"></line></svg>
      </div>
      <h3>暂无相关记录</h3>
      <p class="empty-tips">去创建一个新的作品吧</p>
    </div>

    <div v-else-if="currentTab !== 'orphan'" class="gallery-grid">
      <GalleryCard
        v-for="record in records"
        :key="record.id"
        :record="record"
        @preview="viewImages"
        @edit="loadRecord"
        @delete="confirmDelete"
      />
    </div>

    <!-- Pagination -->
    <div v-if="currentTab !== 'orphan' && totalPages > 1" class="pagination-wrapper">
       <button class="page-btn" :disabled="currentPage === 1" @click="changePage(currentPage - 1)">Previous</button>
       <span class="page-indicator">{{ currentPage }} / {{ totalPages }}</span>
       <button class="page-btn" :disabled="currentPage === totalPages" @click="changePage(currentPage + 1)">Next</button>
    </div>

    <!-- Image Viewer Modal -->
    <ImageGalleryModal
      v-if="viewingRecord"
      :visible="!!viewingRecord"
      :record="viewingRecord"
      :regeneratingImages="regeneratingImages"
      :generatingContent="generatingContent"
      @close="closeGallery"
      @showOutline="showOutlineModal = true"
      @generateContent="generateContentForRecord"
      @regenerate="regenerateHistoryImage"
      @downloadAll="downloadAllImages"
      @download="downloadImage"
    />

    <!-- 大纲查看模态框 -->
    <OutlineModal
      v-if="showOutlineModal && viewingRecord"
      :visible="showOutlineModal"
      :pages="viewingRecord.outline.pages"
      @close="showOutlineModal = false"
    />

  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useToast } from '../composables/toast'
import {
  getHistoryList,
  getHistoryStats,
  searchHistory,
  deleteHistory,
  getHistory,
  type HistoryRecord,
  regenerateImage as apiRegenerateImage,
  generateContent as apiGenerateContent,
  updateHistory,
  scanAllTasks,
  getOrphanTasks,
  deleteOrphanTask,
  type OrphanTask
} from '../api'
import { useGeneratorStore } from '../stores/generator'

// 引入组件
import StatsOverview from '../components/history/StatsOverview.vue'
import GalleryCard from '../components/history/GalleryCard.vue'
import ImageGalleryModal from '../components/history/ImageGalleryModal.vue'
import OutlineModal from '../components/history/OutlineModal.vue'

const router = useRouter()
const route = useRoute()
const store = useGeneratorStore()
const toast = useToast()

// 数据状态
const records = ref<HistoryRecord[]>([])
const loading = ref(false)
const stats = ref<any>(null)
const currentTab = ref('all')
const currentType = ref('rednote')
const searchKeyword = ref('')
const currentPage = ref(1)
const totalPages = ref(1)

// 查看器状态
const viewingRecord = ref<any>(null)
const regeneratingImages = ref<Set<number>>(new Set())
const showOutlineModal = ref(false)
const generatingContent = ref(false)
const isScanning = ref(false)

// 孤立任务状态
const orphans = ref<OrphanTask[]>([])
const loadingOrphans = ref(false)
const orphanTotal = ref(0)

/**
 * 加载历史记录列表
 */
async function loadData() {
  loading.value = true
  try {
    let statusFilter = currentTab.value === 'all' ? undefined : currentTab.value
    const res = await getHistoryList(currentPage.value, 12, statusFilter, currentType.value)
    if (res.success) {
      records.value = res.records
      totalPages.value = res.total_pages
    }
  } catch(e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

/**
 * 加载统计数据
 */
async function loadStats() {
  try {
    const res = await getHistoryStats()
    if (res.success) stats.value = res
  } catch(e) {}
}

/**
 * 切换状态标签页
 */
function switchTab(tab: string) {
  currentTab.value = tab
  currentPage.value = 1
  if (tab === 'orphan') {
    loadOrphans()
  } else {
    loadData()
  }
}

/**
 * 切换类型（小红书 / 快速生图）
 */
function switchType(type: string) {
  currentType.value = type
  currentPage.value = 1
  loadData()
}

/**
 * 搜索历史记录
 */
async function handleSearch() {
  if (!searchKeyword.value.trim()) {
    loadData()
    return
  }
  loading.value = true
  try {
    const res = await searchHistory(searchKeyword.value)
    if (res.success) {
      records.value = res.records
      totalPages.value = 1
    }
  } catch(e) {} finally {
    loading.value = false
  }
}

/**
 * 加载记录并跳转到编辑页
 */
async function loadRecord(id: string) {
  const res = await getHistory(id)
  if (res.success && res.record) {
    store.setTopic(res.record.title)
    store.setOutline(res.record.outline.raw, res.record.outline.pages)
    store.setRecordId(res.record.id)
    if (res.record.images.generated.length > 0) {
      store.taskId = res.record.images.task_id
      store.images = res.record.outline.pages.map((page, idx) => {
        const filename = res.record!.images.generated[idx]
        return {
          index: idx,
          url: filename ? `/api/images/${res.record!.images.task_id}/${filename}` : '',
          status: filename ? 'done' : 'error',
          retryable: !filename
        }
      })
    }
    router.push('/outline')
  }
}

/**
 * 查看图片
 */
async function viewImages(id: string) {
  const res = await getHistory(id)
  if (res.success && res.record) {
    // 按大纲页数补齐 generated 数组：草稿/未生成图片时也能显示占位卡片
    const pages = res.record.outline?.pages || []
    const generated = res.record.images?.generated || []
    if (generated.length < pages.length) {
      res.record.images.generated = pages.map((_: any, i: number) => generated[i] || null)
    }
    viewingRecord.value = res.record
  }
}

/**
 * 在预览弹窗中生成文案
 */
async function generateContentForRecord() {
  if (!viewingRecord.value) return
  generatingContent.value = true

  try {
    const result = await apiGenerateContent(
      viewingRecord.value.title,
      viewingRecord.value.outline.raw
    )

    if (result.success) {
      await updateHistory(viewingRecord.value.id, {
        content: {
          titles: result.titles || [],
          copywriting: result.copywriting || '',
          tags: result.tags || []
        }
      })
      viewingRecord.value.content = {
        titles: result.titles || [],
        copywriting: result.copywriting || '',
        tags: result.tags || []
      }
    } else {
      toast.error('文案生成失败: ' + (result.error || '未知错误'))
    }
  } catch (e) {
    toast.error('文案生成失败: ' + String(e))
  } finally {
    generatingContent.value = false
  }
}

/**
 * 关闭图片查看器
 */
function closeGallery() {
  viewingRecord.value = null
  showOutlineModal.value = false
}

/**
 * 确认删除
 */
async function confirmDelete(record: any) {
  if(confirm('确定删除吗？')) {
    await deleteHistory(record.id)
    if (viewingRecord.value?.id === record.id) { viewingRecord.value = null; showOutlineModal.value = false }
    loadData()
    loadStats()
  }
}

/**
 * 加载孤立任务
 */
async function loadOrphans() {
  loadingOrphans.value = true
  try {
    const res = await getOrphanTasks()
    if (res.success) {
      orphans.value = res.orphans || []
      orphanTotal.value = res.total || 0
    }
  } catch (e) {
    console.error(e)
  } finally {
    loadingOrphans.value = false
  }
}

/**
 * 预览孤立任务图片
 */
function previewOrphanImages(orphan: OrphanTask) {
  const pages = orphan.images.map((img, i) => ({
    index: i,
    type: 'content' as const,
    content: ''
  }))
  viewingRecord.value = {
    id: orphan.task_id,
    title: `游离图片 · ${orphan.task_id}`,
    type: 'orphan',
    updated_at: orphan.created_at,
    outline: { raw: '', pages },
    images: {
      task_id: orphan.task_id,
      generated: orphan.images
    }
  }
}

/**
 * 确认删除孤立任务
 */
async function confirmDeleteOrphan(orphan: OrphanTask) {
  if (!confirm(`确定删除游离目录 ${orphan.task_id}（${orphan.image_count} 张图，${orphan.total_size_kb}KB）？`)) return
  try {
    const res = await deleteOrphanTask(orphan.task_id)
    if (res.success) {
      orphans.value = orphans.value.filter(o => o.task_id !== orphan.task_id)
      orphanTotal.value = orphans.value.length
      toast.success('已删除 ' + orphan.task_id)
    } else {
      toast.error('删除失败: ' + (res.error || '未知错误'))
    }
  } catch (e: any) {
    toast.error('删除失败: ' + (e?.message || e))
  }
}

/**
 * 切换页码
 */
function changePage(p: number) {
  currentPage.value = p
  loadData()
}

/**
 * 重新生成历史记录中的图片
 */
async function regenerateHistoryImage(index: number) {
  const record = viewingRecord.value
  if (!record) return

  regeneratingImages.value.add(index)

  try {
    // 草稿记录没有 task_id，需要先生成新的 task_id
    if (!record.images.task_id) {
      const newTaskId = 'task_' + crypto.randomUUID().split('-')[0]
      // 补齐 generated 数组（全部未生成）
      const pageCount = record.outline.pages.length
      record.images = {
        task_id: newTaskId,
        generated: new Array(pageCount).fill(null)
      }
      // 后端同步
      await updateHistory(record.id, {
        images: record.images,
        status: 'generating'
      })
    }

    const page = record.outline.pages[index]
    if (!page) return

    const context = {
      fullOutline: record.outline.raw || '',
      userTopic: record.title || ''
    }

    const result = await apiRegenerateImage(
      record.images.task_id,
      page,
      true,
      context
    )

    if (result.success && result.image_url) {
      const taskId = record.images.task_id
      const filename = result.image_url.split('/').pop()
      record.images.generated[index] = filename

      // 刷新图片
      const timestamp = Date.now()
      const imgElements = document.querySelectorAll(`img[src*="${taskId}/${filename}"]`)
      imgElements.forEach(img => {
        const baseUrl = (img as HTMLImageElement).src.split('?')[0]
        ;(img as HTMLImageElement).src = `${baseUrl}?t=${timestamp}`
      })

      await updateHistory(record.id, {
        images: {
          task_id: taskId,
          generated: record.images.generated
        }
      })

      regeneratingImages.value.delete(index)
    } else {
      regeneratingImages.value.delete(index)
      toast.error('重新生成失败: ' + (result.error || '未知错误'))
    }
  } catch (e) {
    regeneratingImages.value.delete(index)
    toast.error('重新生成失败: ' + String(e))
  }
}

/**
 * 下载单张图片
 */
function downloadImage(filename: string, index: number) {
  if (!viewingRecord.value) return
  const link = document.createElement('a')
  link.href = `/api/images/${viewingRecord.value.images.task_id}/${filename}?thumbnail=false`
  link.download = `page_${index + 1}.png`
  link.click()
}

/**
 * 打包下载所有图片
 */
function downloadAllImages() {
  if (!viewingRecord.value) return
  const link = document.createElement('a')
  link.href = `/api/history/${viewingRecord.value.id}/download`
  link.click()
}

/**
 * 扫描所有任务并同步
 */
async function handleScanAll() {
  isScanning.value = true
  try {
    const result = await scanAllTasks()
    if (result.success) {
      let message = `扫描完成！\n`
      message += `- 总任务数: ${result.total_tasks || 0}\n`
      message += `- 同步成功: ${result.synced || 0}\n`
      message += `- 同步失败: ${result.failed || 0}\n`

      if (result.orphan_tasks && result.orphan_tasks.length > 0) {
        message += `- 孤立任务（无记录）: ${result.orphan_tasks.length} 个\n`
      }

      toast.info(message)
      await loadData()
      await loadStats()
    } else {
      toast.error('扫描失败: ' + (result.error || '未知错误'))
    }
  } catch (e) {
    console.error('扫描失败:', e)
    toast.error('扫描失败: ' + String(e))
  } finally {
    isScanning.value = false
  }
}

onMounted(async () => {
  await loadData()
  await loadStats()

  // 检查路由参数，如果有 ID 则自动打开图片查看器
  if (route.params.id) {
    await viewImages(route.params.id as string)
  }

  // 预加载游离图片数量（静默）
  getOrphanTasks().then(res => {
    if (res.success) orphanTotal.value = res.total || 0
  }).catch(() => {})

  // 自动执行一次扫描（静默，不显示结果）
  try {
    const result = await scanAllTasks()
    orphanTotal.value = (result.orphan_tasks || []).length
    if (result.success && (result.synced || 0) > 0) {
      await loadData()
      await loadStats()
    }
  } catch (e) {
    console.error('自动扫描失败:', e)
  }
})
</script>

<style scoped>
/* Small Spinner */
.spinner-small {
  width: 16px;
  height: 16px;
  border: 2px solid var(--primary);
  border-top-color: transparent;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  display: inline-block;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

/* Toolbar */
.toolbar-wrapper {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  border-bottom: 1px solid var(--border-color);
  padding-bottom: 0;
}

/* Type Tabs */
.type-tabs {
  display: flex;
  gap: 8px;
  margin-bottom: 24px;
}
.type-tab {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 500;
  color: var(--text-sub);
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}
.type-tab:hover {
  border-color: var(--primary);
  color: var(--text-main);
}
.type-tab.active {
  background: var(--primary);
  color: #080c14;
  border-color: var(--primary);
}

.search-mini {
  position: relative;
  width: 240px;
  margin-bottom: 10px;
}

.search-mini input {
  width: 100%;
  padding: 8px 12px 8px 36px;
  border-radius: 100px;
  border: 1px solid var(--border-color);
  font-size: 14px;
  background: var(--bg-card);
  transition: border-color 0.2s, box-shadow 0.2s;
}

.search-mini input:focus {
  border-color: var(--primary);
  outline: none;
  box-shadow: 0 0 0 3px var(--primary-light);
}

.search-mini .icon {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  color: #ccc;
}

/* Gallery Grid */
.gallery-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 24px;
  margin-bottom: 40px;
}

/* Pagination */
.pagination-wrapper {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 16px;
  margin-top: 40px;
}

.page-btn {
  padding: 8px 16px;
  border: 1px solid var(--border-color);
  background: var(--bg-card);
  border-radius: 6px;
  cursor: pointer;
}

.page-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Empty State */
.empty-state-large {
  text-align: center;
  padding: 80px 0;
  color: var(--text-sub);
}

.empty-img {
  font-size: 64px;
  opacity: 0.5;
}

.empty-state-large .empty-tips {
  margin-top: 10px;
  color: var(--text-placeholder);
}

/* 游离图片卡片（复用 GalleryCard 视觉风格） */
.orphan-card {
  background: var(--bg-card);
  border-radius: 12px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.04);
  transition: transform 0.2s, box-shadow 0.2s;
}
.orphan-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.08);
}
.orphan-card .card-cover {
  aspect-ratio: 3/4;
  background: #f7f7f7;
  position: relative;
  overflow: hidden;
  cursor: pointer;
  border-radius: 12px 12px 0 0;
}
.orphan-card .card-cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.4s;
}
.orphan-card:hover .card-cover img {
  transform: scale(1.05);
}
.orphan-card .cover-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #e0e0e0;
  background: #fafafa;
}
.orphan-card .card-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition: opacity 0.2s;
  backdrop-filter: blur(2px);
}
.orphan-card:hover .card-overlay {
  opacity: 1;
}
.orphan-card .overlay-btn {
  padding: 8px 24px;
  border-radius: 100px;
  border: 1px solid rgba(8, 12, 20, 0.85);
  background: rgba(0, 229, 255, 0.15);
  color: white;
  font-size: 14px;
  cursor: pointer;
}
.orphan-card .status-badge {
  position: absolute;
  top: 12px;
  left: 12px;
  padding: 4px 10px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
  color: white;
  backdrop-filter: blur(4px);
}
.orphan-card .card-footer {
  padding: 16px;
  background: var(--bg-card);
  border-radius: 0 0 12px 12px;
}
.orphan-card .card-title {
  font-size: 13px;
  font-weight: 500;
  margin-bottom: 8px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  color: var(--text-sub);
  font-family: monospace;
}
.orphan-card .card-meta {
  display: flex;
  align-items: center;
  font-size: 12px;
  color: var(--text-sub);
}
.orphan-card .dot {
  margin: 0 6px;
}
.orphan-card .more-actions-wrapper {
  margin-left: auto;
}
.orphan-card .more-btn {
  background: none;
  border: none;
  color: var(--text-placeholder);
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
  transition: background-color 0.2s, color 0.2s;
}
.orphan-card .more-btn:hover {
  background: #fee;
  color: #ff4d4f;
}
</style>
