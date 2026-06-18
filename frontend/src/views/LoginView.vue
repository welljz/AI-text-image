<template>
  <div class="login-page">
    <div class="login-card card">
      <div class="login-header">
        <h1 class="logo-text-glow">AI图文创作</h1>
        <p class="login-subtitle">请输入密码以继续</p>
      </div>

      <form @submit.prevent="handleLogin" class="login-form">
        <div class="form-group">
          <input
            v-model="password"
            type="password"
            class="input"
            placeholder="输入密码"
            :disabled="loading"
            autofocus
          />
        </div>

        <div v-if="errorMsg" class="error-msg">{{ errorMsg }}</div>

        <button type="submit" class="btn btn-primary login-btn" :disabled="loading || !password">
          <span v-if="loading" class="spinner-sm"></span>
          <span v-else>登 录</span>
        </button>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const password = ref('')
const loading = ref(false)
const errorMsg = ref('')

async function handleLogin() {
  if (!password.value) return
  loading.value = true
  errorMsg.value = ''

  const result = await authStore.login(password.value)

  if (result.success) {
    const redirect = (router.currentRoute.value.query.redirect as string) || '/'
    router.replace(redirect)
  } else {
    errorMsg.value = result.error || '登录失败'
    password.value = ''
  }

  loading.value = false
}
</script>

<style scoped>
.login-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  background: var(--bg-body);
}

.login-card {
  width: 420px;
  max-width: 90vw;
  padding: 48px 40px;
  text-align: center;
}

.login-header {
  margin-bottom: 32px;
}

.login-header h1 {
  font-size: 28px;
  margin: 0 0 8px;
}

.login-subtitle {
  color: var(--text-sub);
  font-size: 15px;
  margin: 0;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.form-group {
  width: 100%;
}

.login-btn {
  width: 100%;
  padding: 14px;
  font-size: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}
</style>
