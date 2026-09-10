import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  root: '.',
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
    // Local QA profiles, render intermediates and D1 state are not source.
    // Windows locks browser session files; watching them can crash dev startup.
    watch: { ignored: ['**/.tmp/**', '**/.wrangler/**', '**/art/**'] },
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8788',
      },
    },
  },
  build: {
    outDir: 'dist',
    rollupOptions: {
      input: path.resolve(__dirname, 'index.html'),
      output: {
        manualChunks(id) {
          // Phaser and Three are reached only through lazy gameplay screens.
          // Keep their engine code separate without pulling React/Fiber into
          // the first-player entry chunk.
          if (id.includes('/node_modules/phaser/')) return 'phaser-runtime';
          if (id.includes('/node_modules/three/')) return 'three-runtime';
          return undefined;
        },
      },
    },
  },
  optimizeDeps: {
    include: ['react', 'react-dom', 'zustand'],
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
    dedupe: ['react', 'react-dom'],
  },
});
