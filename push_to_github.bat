@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "REPO_URL=%~1"
if defined REPO_URL goto :got_url

echo ==================================================
echo 用法: push_to_github.bat [你的GitHub仓库地址]
echo 示例: push_to_github.bat https://github.com/your-username/immortalwrt-h5000m.git
echo ==================================================
set /p REPO_URL="请输入您的 GitHub 仓库地址: "
if not defined REPO_URL goto :no_url
if "!REPO_URL!"=="" goto :no_url
goto :got_url

:no_url
echo.
echo 未输入仓库地址，已退出。
echo.
pause
exit /b 1

:got_url
cd /d "%~dp0"

where git >nul 2>&1
if %errorlevel% equ 0 goto :use_git

wsl.exe -e true >nul 2>&1
if %errorlevel% equ 0 goto :use_wsl

echo.
echo ==================================================
echo [错误] 当前系统未检测到可用的 Git 或 WSL 环境！
echo 请任选以下一种方式安装后再运行本脚本：
echo   1. 安装 Git for Windows: https://git-scm.com/download/win
echo   2. 安装 WSL (在终端执行): wsl --install
echo ==================================================
echo.
goto :end

:use_git
echo.
echo 正在检查本地 Git 仓库...
if not exist ".git" (
    echo 正在初始化本地 Git 仓库...
    git init
)

git config user.name >nul 2>&1
if %errorlevel% neq 0 (
    git config user.name "loong486"
    git config user.email "loong486@users.noreply.github.com"
)

git branch -M main
git remote remove origin >nul 2>&1
git remote add origin "!REPO_URL!"

echo 正在暂存并提交代码...
git add .
git commit -m "Update: integrate OpenList and improve scripts" >nul 2>&1

echo.
echo 正在推送到 GitHub: !REPO_URL! ...
git push -u origin main
if %errorlevel% neq 0 (
    echo.
    echo 提示: 检测到远程可能存在冲突或不同步，正在尝试覆盖推送...
    git push -u origin main --force
)

if %errorlevel% equ 0 (
    echo.
    echo ==================================================
    echo 推送成功！代码已同步至 GitHub。
    echo GitHub Actions 自动化编译已自动触发，请前往仓库页面查看构建状态。
    echo ==================================================
) else (
    echo.
    echo ==================================================
    echo [错误] 推送失败！
    echo 请检查：
    echo   1. 仓库地址是否正确: !REPO_URL!
    echo   2. 是否具备该仓库的写入权限（是否登录 GitHub 或配置了 SSH 密钥 / Personal Access Token）
    echo   3. 网络是否能正常连接 github.com
    echo ==================================================
)
goto :end

:use_wsl
echo.
echo 正在通过 WSL 环境推送代码到 GitHub:
echo !REPO_URL!
echo.
wsl.exe bash ./push_to_github.sh "!REPO_URL!"
goto :end

:end
pause
exit /b 0