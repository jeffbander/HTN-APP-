import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/consumer': {
        target: 'https://127.0.0.1:3001',
        secure: false,
      },
      '/admin': {
        target: 'https://127.0.0.1:3001',
        secure: false,
      },
    },
  },
})
