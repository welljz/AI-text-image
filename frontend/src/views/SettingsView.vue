<template>
  <div class="container">
    <div class="page-header">
      <h1 class="page-title">系统设置</h1>
      <p class="page-subtitle">配置文本生成和图片生成的 API 服务</p>
    </div>

    <div v-if="loading" class="loading-container">
      <div class="spinner"></div>
      <p>加载配置中...</p>
    </div>

    <div v-else class="settings-container">
      <!-- Tab 导航 -->
      <div class="tabs-container">
        <div class="tab-item" :class="{ active: activeTab === 'providers' }" @click="activeTab = 'providers'">服务商</div>
        <div class="tab-item" :class="{ active: activeTab === 'account' }" @click="activeTab = 'account'">账户</div>
        <div class="tab-item" :class="{ active: activeTab === 'system' }" @click="activeTab = 'system'">系统</div>
      </div>

      <!-- 服务商 Tab：文本 + 图片 -->
      <template v-if="activeTab === 'providers'">
      <!-- 文本生成配置 -->
      <div class="card">
        <div class="section-header">
          <div>
            <h2 class="section-title">文本生成配置</h2>
            <p class="section-desc">用于生成小红书图文大纲</p>
          </div>
          <button class="btn btn-small" @click="openAddTextModal">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="12" y1="5" x2="12" y2="19"></line>
              <line x1="5" y1="12" x2="19" y2="12"></line>
            </svg>
            添加
          </button>
        </div>

        <!-- 服务商列表表格 -->
        <ProviderTable
          :providers="textConfig.providers"
          :activeProvider="textConfig.active_provider"
          @activate="activateTextProvider"
          @edit="openEditTextModal"
          @delete="deleteTextProvider"
          @test="testTextProviderInList"
        />
      </div>

      <!-- 图片生成配置 -->
      <div class="card">
        <div class="section-header">
          <div>
            <h2 class="section-title">图片生成配置</h2>
            <p class="section-desc">用于生成小红书配图</p>
          </div>
          <button class="btn btn-small" @click="openAddImageModal">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="12" y1="5" x2="12" y2="19"></line>
              <line x1="5" y1="12" x2="19" y2="12"></line>
            </svg>
            添加
          </button>
        </div>

        <!-- 服务商列表表格 -->
        <ProviderTable
          :providers="imageConfig.providers"
          :activeProvider="imageConfig.active_provider"
          @activate="activateImageProvider"
          @edit="openEditImageModal"
          @delete="deleteImageProvider"
          @test="testImageProviderInList"
        />
      </div>
      </template>

      <!-- 账户 Tab：账户安全 -->
      <div v-if="activeTab === 'account'" class="card">
        <div class="section-header">
          <div>
            <h2 class="section-title">账户安全</h2>
            <p class="section-desc">修改用户名或登录密码</p>
          </div>
        </div>

        <form @submit.prevent="handleChangeAccount" class="password-form">
          <div class="form-row">
            <input
              v-model="newUsername"
              type="text"
              class="input"
              placeholder="用户名（留空则不修改）"
              :disabled="changing"
            />
          </div>
          <div class="form-row">
            <input
              v-model="oldPassword"
              type="password"
              class="input"
              placeholder="旧密码（改密码时必填）"
              :disabled="changing"
            />
          </div>
          <div class="form-row">
            <input
              v-model="newPassword"
              type="password"
              class="input"
              placeholder="新密码（留空则不修改，至少 6 位）"
              :disabled="changing"
            />
          </div>
          <div class="form-row">
            <input
              v-model="confirmPassword"
              type="password"
              class="input"
              placeholder="确认新密码"
              :disabled="changing"
            />
          </div>

          <div v-if="pwdError" class="error-msg">{{ pwdError }}</div>
          <div v-if="pwdSuccess" class="success-msg">{{ pwdSuccess }}</div>

          <button type="submit" class="btn btn-primary" :disabled="changing || (!newUsername && !newPassword)">
            <span v-if="changing" class="spinner-sm"></span>
            <span v-else>保存修改</span>
          </button>
        </form>
      </div>

      <!-- 系统 Tab：系统更新 -->
      <div v-if="activeTab === 'system'" class="card">
        <div class="section-header">
          <div>
            <h2 class="section-title">系统更新</h2>
            <p class="section-desc">检查并更新到最新版本，不影响已生成内容</p>
          </div>
        </div>

        <div class="update-section">
          <div v-if="updateChecking" class="update-status">
            <span class="spinner-sm"></span> 检查中...
          </div>

          <div v-else-if="updateInfo" class="update-info">
            <div class="update-row">
              <span class="update-label">当前版本</span>
              <code class="commit-tag">{{ updateInfo.current_commit }}</code>
              <span class="commit-msg">{{ updateInfo.current_message }}</span>
            </div>

            <div v-if="updateInfo.has_update" class="update-available">
              <div class="update-row">
                <span class="update-label">最新版本</span>
                <code class="commit-tag new">{{ updateInfo.latest_commit }}</code>
              </div>
              <div v-if="updateInfo.new_commits?.length" class="new-commits">
                <div v-for="(c, i) in updateInfo.new_commits" :key="i" class="commit-line">{{ c }}</div>
              </div>

              <div v-if="!updating && !updateDone" class="update-actions">
                <button class="btn btn-primary" @click="startUpdate" :disabled="updating">
                  一键更新
                </button>
              </div>
            </div>

            <div v-else class="update-row up-to-date">
              <span class="update-label">✓ 已是最新版本</span>
            </div>
          </div>

          <div v-if="updateError" class="error-msg">{{ updateError }}</div>

          <!-- 更新进度 -->
          <div v-if="updating || updateDone" class="update-progress">
            <div v-if="updating" class="update-status">
              <span class="spinner-sm"></span> 更新中...
            </div>
            <pre v-if="updateLog" class="update-log">{{ updateLog }}</pre>

            <div v-if="updateDone && !updateError" class="update-actions">
              <button class="btn btn-primary" @click="restartAfterUpdate" :disabled="restarting">
                <span v-if="restarting" class="spinner-sm"></span>
                <span v-else>重启服务</span>
              </button>
            </div>
            <div v-if="restarting" class="update-status">
              <span class="spinner-sm"></span> 服务重启中，请稍候...
            </div>
          </div>

          <div v-if="!updateChecking && !updating && !restarting" class="update-actions">
            <button class="btn btn-secondary" @click="fetchUpdateInfo" :disabled="updateChecking">
              检查更新
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 文本服务商弹窗 -->
    <ProviderModal
      :visible="showTextModal"
      :isEditing="!!editingTextProvider"
      :formData="textForm"
      :testing="testingText"
      :typeOptions="textTypeOptions"
      providerCategory="text"
      @close="closeTextModal"
      @save="saveTextProvider"
      @test="testTextConnection"
      @update:formData="updateTextForm"
    />

    <!-- 图片服务商弹窗 -->
    <ImageProviderModal
      :visible="showImageModal"
      :isEditing="!!editingImageProvider"
      :formData="imageForm"
      :testing="testingImage"
      :typeOptions="imageTypeOptions"
      @close="closeImageModal"
      @save="saveImageProvider"
      @test="testImageConnection"
      @update:formData="updateImageForm"
    />
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import ProviderTable from '../components/settings/ProviderTable.vue'
import ProviderModal from '../components/settings/ProviderModal.vue'
import ImageProviderModal from '../components/settings/ImageProviderModal.vue'
import {
  useProviderForm,
  textTypeOptions,
  imageTypeOptions
} from '../composables/useProviderForm'
import { useAuthStore } from '../stores/auth'
import { useToast } from '../composables/toast'
import { checkUpdate, doUpdate, getUpdateStatus, restartService } from '../api'
import type { CheckUpdateResponse } from '../api'

/**
 * 系统设置页面
 *
 * 功能：
 * - 管理文本生成服务商配置
 * - 管理图片生成服务商配置
 * - 测试 API 连接
 */

// 使用 composable 管理表单状态和逻辑
const {
  // 状态
  loading,
  testingText,
  testingImage,

  // 配置数据
  textConfig,
  imageConfig,

  // 文本服务商弹窗
  showTextModal,
  editingTextProvider,
  textForm,

  // 图片服务商弹窗
  showImageModal,
  editingImageProvider,
  imageForm,

  // 方法
  loadConfig,

  // 文本服务商方法
  activateTextProvider,
  openAddTextModal,
  openEditTextModal,
  closeTextModal,
  saveTextProvider,
  deleteTextProvider,
  testTextConnection,
  testTextProviderInList,
  updateTextForm,

  // 图片服务商方法
  activateImageProvider,
  openAddImageModal,
  openEditImageModal,
  closeImageModal,
  saveImageProvider,
  deleteImageProvider,
  testImageConnection,
  testImageProviderInList,
  updateImageForm
} = useProviderForm()

onMounted(() => {
  loadConfig()
})

// Tab 切换
const activeTab = ref<'providers' | 'account' | 'system'>('providers')

// ── 账户修改 ──────────────────────────────────────────
const authStore = useAuthStore()
const router = useRouter()
const toast = useToast()

const newUsername = ref('')
const oldPassword = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const changing = ref(false)
const pwdError = ref('')
const pwdSuccess = ref('')

async function handleChangeAccount() {
  pwdError.value = ''
  pwdSuccess.value = ''

  // 修改密码时的验证
  if (newPassword.value) {
    if (newPassword.value.length < 6) {
      pwdError.value = '新密码至少 6 位'
      return
    }
    if (newPassword.value !== confirmPassword.value) {
      pwdError.value = '两次输入的新密码不一致'
      return
    }
    if (!oldPassword.value) {
      pwdError.value = '修改密码需要输入旧密码'
      return
    }
  }

  // 至少修改一项
  if (!newUsername.value.trim() && !newPassword.value) {
    pwdError.value = '请填写用户名或新密码'
    return
  }

  changing.value = true
  const result = await authStore.changeAccount(
    newUsername.value.trim() || undefined,
    oldPassword.value || undefined,
    newPassword.value || undefined
  )
  changing.value = false

  if (result.success) {
    pwdSuccess.value = result.message || '修改成功'
    toast.success(result.message || '修改成功')

    // 更新本地存储的用户名
    if (result.username) {
      localStorage.setItem('auth_username', result.username)
    }

    newUsername.value = ''
    oldPassword.value = ''
    newPassword.value = ''
    confirmPassword.value = ''

    // 改密码需重新登录
    if (result.require_relogin) {
      setTimeout(() => {
        authStore.logout()
        router.replace('/login')
      }, 1500)
    }
  } else {
    pwdError.value = result.error || '修改失败'
  }
}

// ── 系统更新 ──────────────────────────────────────────
const updateChecking = ref(false)
const updating = ref(false)
const updateDone = ref(false)
const restarting = ref(false)
const updateInfo = ref<CheckUpdateResponse | null>(null)
const updateLog = ref('')
const updateError = ref('')
let _updatePollTimer: ReturnType<typeof setInterval> | null = null

async function fetchUpdateInfo() {
  updateChecking.value = true
  updateError.value = ''
  updateInfo.value = null

  const res = await checkUpdate()
  updateChecking.value = false

  if (res.success) {
    updateInfo.value = res
  } else {
    updateError.value = res.error || '检查更新失败'
  }
}

async function startUpdate() {
  updating.value = true
  updateDone.value = false
  updateError.value = ''
  updateLog.value = ''

  const res = await doUpdate()
  if (!res.success) {
    updateError.value = res.error || '更新失败'
    updating.value = false
    return
  }

  // 轮询更新进度
  let pollCount = 0
  let consecutiveErrors = 0
  const MAX_POLLS = 80       // 最长 2 分钟
  const MAX_CONSECUTIVE_ERRORS = 5

  _updatePollTimer = setInterval(async () => {
    pollCount++
    const status = await getUpdateStatus()

    if (!status.success || status.error) {
      consecutiveErrors++
    } else {
      consecutiveErrors = 0
    }

    if (status.log) {
      updateLog.value = status.log
    }

    if (status.done) {
      updating.value = false
      updateDone.value = true
      if (status.error) {
        updateError.value = '更新过程中出现错误，请查看日志'
      }
      if (_updatePollTimer) clearInterval(_updatePollTimer)
      return
    }

    // 连续获取状态失败，可能服务已中断
    if (consecutiveErrors >= MAX_CONSECUTIVE_ERRORS) {
      updating.value = false
      updateError.value = '无法获取更新状态（服务可能已中断），请稍后刷新页面查看'
      if (_updatePollTimer) clearInterval(_updatePollTimer)
      return
    }

    // 超时
    if (pollCount >= MAX_POLLS) {
      updating.value = false
      updateError.value = '更新超时，请刷新页面后重试'
      if (_updatePollTimer) clearInterval(_updatePollTimer)
    }
  }, 1500)
}

async function restartAfterUpdate() {
  restarting.value = true
  updateError.value = ''

  const res = await restartService()
  if (res.success) {
    // 轮询等待服务恢复，然后刷新页面
    let retries = 0
    const _checkAlive = setInterval(async () => {
      retries++
      try {
        const resp = await fetch('/api/health')
        if (resp.ok) {
          clearInterval(_checkAlive)
          window.location.reload()
        }
      } catch (_) {
        // 服务未恢复
      }
      if (retries > 30) {
        clearInterval(_checkAlive)
        restarting.value = false
        updateError.value = '服务重启超时，请手动刷新页面'
      }
    }, 2000)
  } else {
    restarting.value = false
    updateError.value = res.error || '重启失败'
  }
}

// 进入页面时自动检查一次
onMounted(() => {
  fetchUpdateInfo()
})
</script>

<style scoped>
.settings-container {
  max-width: 900px;
  margin: 0 auto;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 20px;
}

.section-title {
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 4px;
  color: var(--text-main);
}

.section-desc {
  font-size: 14px;
  color: var(--text-sub);
  margin: 0;
}

/* 按钮样式 */
.btn-small {
  padding: 6px 12px;
  font-size: 13px;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

/* 加载状态 */
.loading-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 80px 20px;
  color: var(--text-sub);
}

.password-form {
  display: flex;
  flex-direction: column;
  gap: 12px;
  max-width: 400px;
}

.password-form .form-row {
  width: 100%;
}

.form-actions {
  display: flex;
  gap: 8px;
  margin-top: 4px;
}

.success-msg {
  color: #16a34a;
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
  padding: 10px 14px;
  border-radius: var(--radius-md);
  font-size: 14px;
}

[data-theme="dark"] .success-msg {
  color: #4ade80;
  background: #052e16;
  border-color: #166534;
}

/* 系统更新 */
.update-section {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.update-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.update-row {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.update-label {
  font-size: 14px;
  color: var(--text-sub);
  min-width: 70px;
}

.commit-tag {
  font-family: monospace;
  font-size: 13px;
  background: var(--bg-card);
  padding: 2px 8px;
  border-radius: 4px;
  color: var(--text-main);
}

.commit-tag.new {
  background: #fef3c7;
  color: #92400e;
}

.commit-msg {
  font-size: 13px;
  color: var(--text-sub);
  max-width: 300px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.update-available {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px;
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-radius: var(--radius-md);
}

[data-theme="dark"] .update-available {
  background: #1e1b00;
  border-color: #4d3e00;
}

.new-commits {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.commit-line {
  font-family: monospace;
  font-size: 12px;
  color: var(--text-sub);
  padding-left: 8px;
}

.up-to-date {
  color: #16a34a;
  font-size: 14px;
}

[data-theme="dark"] .up-to-date {
  color: #4ade80;
}

.update-status {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: var(--text-sub);
}

.update-progress {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.update-log {
  font-family: monospace;
  font-size: 12px;
  background: #1e1e1e;
  color: #d4d4d4;
  padding: 12px;
  border-radius: var(--radius-md);
  max-height: 200px;
  overflow-y: auto;
  white-space: pre-wrap;
  word-break: break-all;
  line-height: 1.5;
}

.update-actions {
  display: flex;
  gap: 8px;
  margin-top: 4px;
}

.btn-secondary {
  padding: 8px 16px;
  font-size: 14px;
  border: 1px solid var(--border);
  background: var(--bg-card);
  color: var(--text-main);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all 0.2s;
}

.btn-secondary:hover {
  border-color: var(--primary);
  color: var(--primary);
}

.btn-secondary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
