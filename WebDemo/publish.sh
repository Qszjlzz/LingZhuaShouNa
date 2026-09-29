#!/bin/bash
# ============================================================
#  网页演示版 · 发布脚本
#  - 公网主链接永久固定：永远是 根目录的 index.html
#  - 每个历史版本存成一份 vN.html（同样永久可访问，方便回看/对比）
#  用法：cd WebDemo && ./publish.sh  然后部署本目录下的 dist/
#
#  注意：服务器只支持一层子目录，所以历史版本必须平铺成 vN.html + assets/，
#        不能做成 vN/index.html（那种结构传上去会取不到 js，页面白屏）。
# ============================================================
set -e
cd "$(dirname "$0")"

npm run build

# 1) 把这一版存进持久的历史目录 versions/vN（不会被 build 清掉）
NEXT=1
while [ -d "versions/v$NEXT" ]; do NEXT=$((NEXT+1)); done
rm -rf "versions/v$NEXT"
cp -r dist "versions/v$NEXT"
echo "→ 已归档 versions/v$NEXT"

# 2) 平铺组装 dist：根=最新版；每个版本一份 vN.html，各自的 js 全部汇入同一个 assets/
rm -rf dist && mkdir -p dist/assets
cp -r "versions/v$NEXT/." dist/
for d in versions/v*; do
  N=$(basename "$d")                       # v1 / v2 / ...
  cp "$d/index.html" "dist/$N.html"        # 历史版本的可访问入口
  cp "$d"/assets/*.js dist/assets/ 2>/dev/null || true
done
echo "→ dist 就绪：根=最新（$(ls dist/assets | wc -l | tr -d ' ') 个 js），入口：$(ls dist/*.html | xargs -n1 basename | tr '\n' ' ')"
