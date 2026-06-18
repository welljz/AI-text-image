import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { login as apiLogin, changePassword as apiChangePassword } from '../api'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('auth_token') || '')
  const username = ref(localStorage.getItem('auth_username') || '')

  const isAuthenticated = computed(() => !!token.value)

  function setAuth(newToken: string, newUsername: string) {
    token.value = newToken
    username.value = newUsername
    localStorage.setItem('auth_token', newToken)
    localStorage.setItem('auth_username', newUsername)
  }

  function clearAuth() {
    token.value = ''
    username.value = ''
    localStorage.removeItem('auth_token')
    localStorage.removeItem('auth_username')
  }

  async function login(password: string): Promise<{ success: boolean; error?: string }> {
    const res = await apiLogin(password)
    if (res.success && res.token) {
      setAuth(res.token, res.username || 'admin')
    }
    return res
  }

  function logout() {
    clearAuth()
  }

  async function changePassword(oldPassword: string, newPassword: string): Promise<{ success: boolean; error?: string }> {
    return await apiChangePassword(oldPassword, newPassword)
  }

  return {
    token,
    username,
    isAuthenticated,
    login,
    logout,
    changePassword
  }
})
