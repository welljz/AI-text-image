import { ref } from 'vue'

export interface ToastItem {
  id: number
  message: string
  type: 'success' | 'error' | 'info' | 'warning'
}

const toasts = ref<ToastItem[]>([])
let nextId = 0
const DURATION = 5000

// 每个 toast 独立的计时器状态
const timers = new Map<number, ReturnType<typeof setTimeout>>()
const remaining = new Map<number, number>()
const startedAt = new Map<number, number>()

function add(message: string, type: ToastItem['type'] = 'info') {
  const id = nextId++
  toasts.value.push({ id, message, type })
  startTimer(id, DURATION)
}

function startTimer(id: number, delay: number) {
  clear(id)
  startedAt.set(id, Date.now())
  remaining.set(id, delay)
  timers.set(id, setTimeout(() => remove(id), delay))
}

function clear(id: number) {
  const t = timers.get(id)
  if (t) { clearTimeout(t); timers.delete(id) }
}

function remove(id: number) {
  clear(id)
  remaining.delete(id)
  startedAt.delete(id)
  toasts.value = toasts.value.filter(t => t.id !== id)
}

function pause(id: number) {
  const t = timers.get(id)
  if (!t) return
  clearTimeout(t)
  timers.delete(id)
  const elapsed = Date.now() - (startedAt.get(id) || Date.now())
  remaining.set(id, Math.max(0, (remaining.get(id) || DURATION) - elapsed))
}

function resume(id: number) {
  const r = remaining.get(id)
  if (r !== undefined) startTimer(id, r)
}

export function useToast() {
  return {
    toasts,
    success: (msg: string) => add(msg, 'success'),
    error: (msg: string) => add(msg, 'error'),
    info: (msg: string) => add(msg, 'info'),
    warning: (msg: string) => add(msg, 'warning'),
    remove,
    pause,
    resume
  }
}
