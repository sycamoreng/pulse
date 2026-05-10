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
          50: '#F0F8FF',
          100: '#A0D2FF',
          200: '#7DB9E8',
          500: '#3087B9',
          700: '#0A445C',
          900: '#073042',
        },
        accent: {
          500: '#26C165',
        },
        ink: {
          900: '#0B1E27',
          700: '#2A3F49',
          500: '#536771',
          300: '#8B9CA5',
          100: '#E8EEF2',
          50: '#F5F8FA',
        },
      },
      boxShadow: {
        soft: '0 1px 2px rgba(7,48,66,0.04), 0 4px 16px rgba(7,48,66,0.06)',
      },
    },
  },
  plugins: [],
}
