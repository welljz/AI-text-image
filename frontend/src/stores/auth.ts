import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { login as apiLogin, changeAccount as apiChangeAccount } from '../api'

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

  async function login(username: string, password: string): Promise<{ success: boolean; error?: string }> {
    const res = await apiLogin(username, password)
    if (res.success && res.token) {
      setAuth(res.token, res.username || username)
    }
    return res
  }

  function logout() {
    clearAuth()
  }

  async function changeAccount(newUsername?: string, oldPassword?: string, newPassword?: string): Promise<{ success: boolean; error?: string }> {
    return await apiChangeAccount(newUsername, oldPassword, newPassword)
  }

  return {
    token,
    username,
    isAuthenticated,
    login,
    logout,
    changeAccount
  }
})
