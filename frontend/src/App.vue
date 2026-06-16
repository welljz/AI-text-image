<template>
  <div id="app">
    <aside class="layout-sidebar">
      <div class="logo-area">
        <span class="logo-text-glow">AI图文创作</span>
      </div>

      <nav class="nav-menu">
        <RouterLink to="/" class="nav-item" active-class="active">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect></svg>
          创作中心
        </RouterLink>
        <RouterLink to="/history" class="nav-item" active-class="active">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
          历史记录
        </RouterLink>
        <RouterLink to="/settings" class="nav-item" active-class="active">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"></circle><path d="M12 1v6m0 6v6m-6-6h6m6 0h-6"></path><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>
          系统设置
        </RouterLink></nav>
    </aside>

    <main class="layout-main">
      <RouterView v-slot="{ Component, route }">
        <component :is="Component" />

        <footer v-if="route.path !== '/'" class="global-footer">
          <div class="footer-content">
            <div class="footer-text">© 2026 AI图文创作</div>
          </div>
        </footer>
      </RouterView>
    </main>

    <div class="theme-float" @click="toggleTheme" :title="isDark ? '切换明亮' : '切换暗黑'">
      <svg v-if="!isDark" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
      <svg v-else width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>
    </div>
  </div>
</template>

<script setup lang="ts">
import { RouterView, RouterLink } from 'vue-router'
import { ref, onMounted } from 'vue'
import { setupAutoSave } from './stores/generator'


const isDark = ref(false)

function toggleTheme() {
  isDark.value = !isDark.value
  document.documentElement.setAttribute('data-theme', isDark.value ? 'dark' : '')
  localStorage.setItem('theme', isDark.value ? 'dark' : 'light')
}

// 初始化主题
const savedTheme = localStorage.getItem('theme')
if (savedTheme === 'dark') {
  isDark.value = true
  document.documentElement.setAttribute('data-theme', 'dark')
} else if (!savedTheme) {
  // 默认明亮
  isDark.value = false
}

onMounted(() => {
  setupAutoSave()
})
</script>

<style scoped>

.theme-float {
  position: fixed; bottom: 24px; right: 24px; z-index: 500;
  width: 44px; height: 44px; border-radius: 50%;
  background: var(--bg-card); border: 1px solid var(--border-color);
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; transition: all 0.2s;
  color: var(--text-sub); box-shadow: var(--shadow-md);
}
.theme-float:hover { color: var(--primary); border-color: var(--primary); transform: scale(1.1); }
.theme-toggle {
  display: flex; align-items: center; gap: 10px; padding: 10px 14px;
  border-radius: var(--radius-md); cursor: pointer; transition: all 0.2s;
  color: var(--text-sub); font-size: 13px; margin-top: 4px;
  border: 1px solid transparent;
}
.theme-toggle:hover { background: var(--primary-light); color: var(--primary); border-color: var(--border-hover); }
.theme-toggle-label { display: none; font-weight: 500; }
</style>
