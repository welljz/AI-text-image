<template>
  <Teleport to="body">
    <div class="toast-container">
      <TransitionGroup name="toast">
        <div
          v-for="t in toasts"
          :key="t.id"
          class="toast-item"
          :class="t.type"
          :title="'点击复制消息'"
          @mouseenter="pause(t.id)"
          @mouseleave="resume(t.id)"
          @click="copyMessage(t.message)"
        >
          <span class="toast-icon">{{ iconMap[t.type] }}</span>
          <span class="toast-msg">{{ t.message }}</span>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { useToast } from '../composables/toast'

const { toasts, pause, resume } = useToast()

const iconMap: Record<string, string> = {
  success: '✓',
  error: '✕',
  info: 'ℹ',
  warning: '⚠'
}

function copyMessage(msg: string) {
  navigator.clipboard.writeText(msg).then(() => {
    const item = toasts.value.at(-1)
    // 短暂闪烁反馈由 CSS :active 处理
  }).catch(() => {})
}
</script>

<style scoped>
.toast-container {
  position: fixed;
  top: 24px;
  right: 24px;
  z-index: 99999;
  display: flex;
  flex-direction: column;
  gap: 10px;
  pointer-events: none;
}

.toast-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 20px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  min-width: 240px;
  max-width: 420px;
  pointer-events: auto;
  cursor: pointer;
  backdrop-filter: blur(12px);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  user-select: none;
}

.toast-item:hover {
  transform: translateX(-4px);
}

.toast-item:active {
  transform: scale(0.97);
}

.toast-icon {
  font-size: 16px;
  font-weight: 700;
  flex-shrink: 0;
}

.toast-msg {
  line-height: 1.4;
  word-break: break-word;
}

/* types */
.toast-item.success {
  background: rgba(34, 197, 94, 0.85);
  color: #fff;
}
.toast-item.error {
  background: rgba(239, 68, 68, 0.85);
  color: #fff;
}
.toast-item.info {
  background: rgba(59, 130, 246, 0.85);
  color: #fff;
}
.toast-item.warning {
  background: rgba(250, 173, 20, 0.85);
  color: #fff;
}

/* transitions */
.toast-enter-active {
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}
.toast-leave-active {
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}
.toast-enter-from {
  opacity: 0;
  transform: translateX(40px);
}
.toast-leave-to {
  opacity: 0;
  transform: translateX(40px);
}
</style>
