import { defineConfig } from 'vite'
import path from 'path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    // The React and Tailwind plugins are both required for Make, even if
    // Tailwind is not being actively used – do not remove them
    react(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      // Alias @ to the src directory
      '@': path.resolve(__dirname, './src'),
    },
  },

  // File types to support raw imports. Never add .css, .tsx, or .ts files to this.
  assetsInclude: ['**/*.svg', '**/*.csv'],

  // App 里是把 js 读成字符串、内联进 <script>（普通脚本，不是 type="module"）执行的。
  // 默认的 ESM 输出会在末尾带 export{...}，普通脚本遇到 export 是语法错误 → 整段不执行 → 白屏。
  // 所以这里强制输出单文件 IIFE，并把懒加载 chunk 一起内联，产物才能被直接内联执行。
  build: {
    rollupOptions: {
      output: {
        format: 'iife',
        inlineDynamicImports: true,
      },
    },
  },
})
