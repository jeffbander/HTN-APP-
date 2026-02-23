import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Skip proxying for browser page navigations (serve SPA instead)
function bypassForHtml(req) {
  if (req.headers.accept?.includes('text/html')) {
    return '/index.html'
  }
}

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
      '/dashboard': {
        target: 'http://127.0.0.1:5001',
        secure: false,
        bypass: bypassForHtml,
      },
      '/super-admin': {
        target: 'http://127.0.0.1:5001',
        secure: false,
      },
      '/union-leader': {
        target: 'http://127.0.0.1:5001',
        secure: false,
      },
      '/shipping': {
        target: 'http://127.0.0.1:5001',
        secure: false,
      },
      '/nurse': {
        target: 'http://127.0.0.1:5001',
        secure: false,
      },
    },
  },
})
