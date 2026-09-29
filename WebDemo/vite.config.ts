import { defineConfig } from 'vite'
import path from 'path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  // 网页演示版会被部署到任意路径/子目录，资源一律用相对路径。
  // 注意：只有 WebDemo 是网页版，FigmaMakeLatest-v3 那份是打进 iOS App 的，别加这个。
  base: './',
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

  // App 把 js 读成字符串内联进普通 <script> 执行，ESM 末尾的 export{...} 会导致整段不执行（白屏）。
  // assetsInlineLimit：把图片全部转成内嵌 data URI 塞进 js。
  // 原因：base:'./' + iife 打包下，运行时图片路径被解析到站点根目录——实测请求的是
  // /xxx.png 而不是 /assets/xxx.png，服务器返回兜底 html → 浏览器拿到 html 当图片，全部显示不出来。
  // 内嵌之后不依赖任何路径解析，扔到任何目录、任何服务器上都不会丢图。
  build: {
    assetsInlineLimit: 4 * 1024 * 1024,
    rollupOptions: {
      output: {
        format: 'iife',
        inlineDynamicImports: true,
      },
    },
  },
})
