/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    './components/**/*.{vue,js,ts}',
    './layouts/**/*.vue',
    './pages/**/*.vue',
    './app.vue',
    './plugins/**/*.{js,ts}',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Satoshi', 'ui-sans-serif', 'system-ui', '-apple-system', 'sans-serif'],
      },
      colors: {
        brand: {
          50: '#ECFEFF',
          100: '#CFFAFE',
          200: '#A5F3FC',
          300: '#67E8F9',
          400: '#22D3EE',
          500: '#06B6D4',
          600: '#0891B2',
          700: '#0E7490',
          800: '#155E75',
          900: '#164E63',
        },
        accent: {
          50: '#ECFDF5',
          100: '#D1FAE5',
          300: '#6EE7B7',
          500: '#10B981',
          600: '#059669',
          700: '#047857',
        },
        ai: {
          50: '#F5F3FF',
          100: '#EDE9FE',
          300: '#C4B5FD',
          400: '#A78BFA',
          500: '#8B5CF6',
          600: '#7C3AED',
          700: '#6D28D9',
        },
        warning: { 50: '#FFFBEB', 500: '#F59E0B', 700: '#B45309' },
        danger: { 50: '#FEF2F2', 500: '#EF4444', 700: '#B91C1C' },
        info: { 50: '#EFF6FF', 500: '#3B82F6', 700: '#1D4ED8' },
        ink: {
          900: '#06141A',
          700: '#1E2A33',
          500: '#475569',
          300: '#94A3B8',
          100: '#E2E8F0',
          50: '#F1F5F9',
        },
      },
      boxShadow: {
        soft: '0 1px 2px rgba(6,20,26,0.04), 0 4px 16px rgba(6,20,26,0.06)',
      },
    },
  },
  plugins: [],
}
