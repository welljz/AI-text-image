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

      <!-- 账户安全 -->
      <div class="card">
        <div class="section-header">
          <div>
            <h2 class="section-title">账户安全</h2>
            <p class="section-desc">修改登录密码</p>
          </div>
        </div>

        <form @submit.prevent="handleChangePassword" class="password-form">
          <div class="form-row">
            <input
              v-model="oldPassword"
              type="password"
              class="input"
              placeholder="旧密码"
              :disabled="changing"
            />
          </div>
          <div class="form-row">
            <input
              v-model="newPassword"
              type="password"
              class="input"
              placeholder="新密码（至少 6 位）"
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

          <button type="submit" class="btn btn-primary" :disabled="changing || !oldPassword || !newPassword || !confirmPassword">
            <span v-if="changing" class="spinner-sm"></span>
            <span v-else>修改密码</span>
          </button>
        </form>
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

// ── 密码修改 ──────────────────────────────────────────
const authStore = useAuthStore()
const router = useRouter()
const toast = useToast()

const oldPassword = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const changing = ref(false)
const pwdError = ref('')
const pwdSuccess = ref('')

async function handleChangePassword() {
  pwdError.value = ''
  pwdSuccess.value = ''

  if (newPassword.value.length < 6) {
    pwdError.value = '新密码至少 6 位'
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    pwdError.value = '两次输入的新密码不一致'
    return
  }

  changing.value = true
  const result = await authStore.changePassword(oldPassword.value, newPassword.value)
  changing.value = false

  if (result.success) {
    pwdSuccess.value = result.message || '密码修改成功，请重新登录'
    toast.success('密码修改成功，即将跳转登录页...')
    oldPassword.value = ''
    newPassword.value = ''
    confirmPassword.value = ''
    // 清除登录态并跳转
    setTimeout(() => {
      authStore.logout()
      router.replace('/login')
    }, 1500)
  } else {
    pwdError.value = result.error || '修改失败'
  }
}
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
</style>
