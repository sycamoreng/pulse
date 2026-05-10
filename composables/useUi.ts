type ToastKind = 'success' | 'error' | 'info' | 'warning'
export interface Toast { id: number; kind: ToastKind; title: string; description?: string; duration: number }

const toasts = ref<Toast[]>([])
let tid = 0

export function useToast() {
  const push = (kind: ToastKind, title: string, description?: string, duration = 3800) => {
    const id = ++tid
    toasts.value = [...toasts.value, { id, kind, title, description, duration }]
    if (duration > 0) setTimeout(() => dismiss(id), duration)
    return id
  }
  const dismiss = (id: number) => { toasts.value = toasts.value.filter(t => t.id !== id) }
  return {
    toasts,
    dismiss,
    success: (t: string, d?: string) => push('success', t, d),
    error: (t: string, d?: string) => push('error', t, d, 5500),
    info: (t: string, d?: string) => push('info', t, d),
    warning: (t: string, d?: string) => push('warning', t, d),
  }
}

export interface ConfirmOptions {
  title: string
  message?: string
  confirmText?: string
  cancelText?: string
  tone?: 'default' | 'danger'
}
interface ConfirmState extends ConfirmOptions { open: boolean; resolve?: (v: boolean) => void }
const confirmState = ref<ConfirmState>({ open: false, title: '' })

export function useConfirm() {
  const ask = (opts: ConfirmOptions) => new Promise<boolean>((resolve) => {
    confirmState.value = { ...opts, open: true, resolve }
  })
  const resolve = (ok: boolean) => {
    confirmState.value.resolve?.(ok)
    confirmState.value = { ...confirmState.value, open: false, resolve: undefined }
  }
  return { state: confirmState, ask, resolve }
}
