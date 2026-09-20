#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "=================================================="
    echo "用法: ./push_to_github.sh [你的GitHub仓库地址]"
    echo "示例: ./push_to_github.sh https://github.com/your-username/immortalwrt-h5000m.git"
    echo "=================================================="
    exit 1
fi

REPO_URL="$1"
cd "$(dirname "$0")"

if [ ! -d ".git" ]; then
    echo "正在初始化本地 Git 仓库..."
    git init
fi

if ! git config user.name >/dev/null 2>&1; then
    git config user.name "loong486"
    git config user.email "loong486@users.noreply.github.com"
fi

git branch -M main
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO_URL"

echo "正在暂存并提交代码..."
git add .
git commit -m "Update: integrate OpenList and improve scripts" 2>/dev/null || true

echo "正在推送到 GitHub: ${REPO_URL} ..."
if ! git push -u origin main; then
    echo "提示: 检测到远程可能存在冲突或不同步，正在尝试覆盖推送..."
    git push -u origin main --force
fi

echo ""
echo "=================================================="
echo "推送完成！代码已同步至 GitHub。"
echo "GitHub Actions 自动化编译已自动触发，可前往仓库 Actions 页面查看构建状态。"
echo "=================================================="