export type Theme = 'dark' | 'light'

const STORAGE_KEY = 'pulse.theme'

const current = ref<Theme>('dark')

function apply(theme: Theme) {
  if (typeof document === 'undefined') return
  const root = document.documentElement
  if (theme === 'dark') root.classList.add('dark')
  else root.classList.remove('dark')
  root.style.colorScheme = theme
}

export function useTheme() {
  function init() {
    if (typeof window === 'undefined') return
    const stored = window.localStorage.getItem(STORAGE_KEY) as Theme | null
    const theme: Theme = stored === 'light' || stored === 'dark' ? stored : 'dark'
    current.value = theme
    apply(theme)
  }

  function set(theme: Theme) {
    current.value = theme
    if (typeof window !== 'undefined') window.localStorage.setItem(STORAGE_KEY, theme)
    apply(theme)
  }

  function toggle() {
    set(current.value === 'dark' ? 'light' : 'dark')
  }

  return { theme: current, init, set, toggle }
}
