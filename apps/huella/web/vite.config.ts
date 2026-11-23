import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'

export default defineConfig({
  plugins: [react()],
  resolve: { alias: { '@nucleo': path.resolve(__dirname, '../../../nucleo') } },
  server: { port: 5182, fs: { allow: [path.resolve(__dirname, '../../..')] } },
  build: { sourcemap: false, outDir: 'dist' },
})
