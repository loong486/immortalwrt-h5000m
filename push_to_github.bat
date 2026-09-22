@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ================================================================
echo             ImmortalWrt H5000M 固件工程 GitHub 一键推送脚本
echo ================================================================
echo.

cd /d "%~dp0"

:: 检查 Git 或 WSL 环境
where git >nul 2>&1
if %errorlevel% equ 0 goto :env_ok

wsl.exe -e true >nul 2>&1
if %errorlevel% equ 0 goto :use_wsl

echo [错误] 当前系统未检测到 Git 或 WSL 环境！
echo 请任选以下一种方式安装后再运行本脚本：
echo   1. 安装 Git for Windows: https://git-scm.com/download/win
echo   2. 安装 WSL (在终端执行): wsl --install
echo.
pause
exit /b 1

:use_wsl
echo 正在通过 WSL 执行推送脚本...
wsl.exe bash ./push_to_github.sh %*
pause
exit /b 0

:env_ok
:: 检查或初始化本地仓库
if not exist ".git" (
    echo [1/4] 正在初始化本地 Git 仓库...
    git init
)

:: 检查 Git 用户名配置
git config user.name >nul 2>&1
if %errorlevel% neq 0 (
    git config user.name "loong486"
    git config user.email "loong486@users.noreply.github.com"
)

:: 获取已配置的远程地址
set "EXISTING_URL="
for /f "tokens=*" %%i in ('git remote get-url origin 2^>nul') do set "EXISTING_URL=%%i"

:: 确定推送目标地址
set "REPO_URL=%~1"
if not defined REPO_URL (
    if defined EXISTING_URL (
        echo [1/4] 检测到已关联的 GitHub 仓库:
        echo       !EXISTING_URL!
        echo.
        set /p "INPUT_URL=请输入新的仓库地址 (直接回车保持默认): "
        if "!INPUT_URL!"=="" (
            set "REPO_URL=!EXISTING_URL!"
        ) else (
            set "REPO_URL=!INPUT_URL!"
        )
    ) else (
        echo [1/4] 请配置远程 GitHub 仓库:
        set /p "REPO_URL=请输入您的 GitHub 仓库地址: "
    )
)

if not defined REPO_URL (
    echo [错误] 未提供仓库地址，操作已中止。
    pause
    exit /b 1
)

:: 设置默认分支与远程源
git branch -M main >nul 2>&1
if defined EXISTING_URL (
    if not "!REPO_URL!"=="!EXISTING_URL!" (
        git remote set-url origin "!REPO_URL!"
    )
) else (
    git remote add origin "!REPO_URL!"
)

:: 检查本地修改并处理提交
echo.
echo [2/4] 检查本地更改...
set "STATUS_TEMP=%TEMP%\git_st_%RANDOM%.tmp"
git status --porcelain > "!STATUS_TEMP!"
set /a HAS_CHANGES=0
for %%A in ("!STATUS_TEMP!") do if %%~zA gtr 0 set HAS_CHANGES=1
del "!STATUS_TEMP!" 2>nul

if %HAS_CHANGES% equ 1 (
    echo 检测到本地有未提交的更新。
    set "COMMIT_MSG=%~2"
    if not defined COMMIT_MSG (
        set "DEFAULT_MSG=feat: update firmware config, packages and scripts"
        set /p "COMMIT_MSG=请输入本次提交说明 (直接回车使用默认说明): "
        if "!COMMIT_MSG!"=="" set "COMMIT_MSG=!DEFAULT_MSG!"
    )
    echo 正在暂存并提交代码...
    git add .
    git commit -m "!COMMIT_MSG!"
) else (
    echo 本地工作区干净，无新增未提交文件，将直接推送已有提交。
)

:: 推送代码
echo.
echo [3/4] 正在推送到 GitHub: !REPO_URL! ...
git push -u origin main
if %errorlevel% equ 0 goto :push_success

echo.
echo ================================================================
echo [提示] 常规推送遇到冲突或拒绝，通常因为远程仓库历史与本地不同步。
echo.
echo 请选择处理方式:
echo   [1] 覆盖推送 (强制覆盖远程，适用于个人云端构建仓库) - 推荐
echo   [2] 变基拉取后推送 (git pull --rebase origin main)
echo   [3] 取消退出
echo ================================================================
set /p "RETRY_OPT=请输入选项编号 [1/2/3] (默认 1): "
if "!RETRY_OPT!"=="" set "RETRY_OPT=1"

if "!RETRY_OPT!"=="1" (
    echo 正在执行覆盖推送 (git push --force)...
    git push -u origin main --force
    if %errorlevel% equ 0 goto :push_success
)

if "!RETRY_OPT!"=="2" (
    echo 正在尝试变基合并远程代码...
    git pull --rebase origin main
    echo 正在重新推送...
    git push -u origin main
    if %errorlevel% equ 0 goto :push_success
)

echo.
echo ================================================================
echo [错误] 推送仍未成功！
echo 请检查:
echo   1. 仓库地址是否正确: !REPO_URL!
echo   2. 是否拥有写入权限（GitHub 账号登录、SSH 密钥或 Personal Access Token）
echo   3. 网络是否能够稳定连接 github.com
echo ================================================================
pause
exit /b 1

:push_success
echo.
echo ================================================================
echo [4/4] 恭喜！代码已成功同步推送到 GitHub！
echo.
echo GitHub Actions 自动化编译已被自动触发。
echo 您可进入仓库页面点击顶部的 [Actions] 标签页查看实时构建进度。
echo 构建完成后固件将自动上传至 Releases 与 Artifacts。
echo ================================================================
echo.
pause
exit /b 0