import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/consumer': {
        target: 'http://127.0.0.1:5001',
        secure: false,
      },
      '/admin': {
        target: 'http://127.0.0.1:5001',
        secure: false,
      },
    },
  },
})
