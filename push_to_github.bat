@echo off
chcp 65001 >nul
title ImmortalWrt H5000M - GitHub 一键同步工具

echo ================================================================
echo           ImmortalWrt H5000M 固件工程 GitHub 一键同步
echo ================================================================
echo.

cd /d "%~dp0"

:: 检查 Git
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 当前系统未检测到 Git 命令！
    echo 请先安装 Git for Windows: https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

:: 初始化 Git 仓库 (若未初始化)
if not exist ".git" (
    echo [1/4] 初始化本地 Git 仓库...
    git init
    git branch -M main
)

:: 检查默认 Git 用户信息
git config user.name >nul 2>&1
if %errorlevel% neq 0 (
    git config user.name "loong486"
    git config user.email "loong486@users.noreply.github.com"
)

:: 获取远程仓库地址
set "EXISTING_URL="
for /f "tokens=*" %%i in ('git remote get-url origin 2^>nul') do set "EXISTING_URL=%%i"

set "REPO_URL=%~1"
if not "%REPO_URL%"=="" goto :setup_remote

if not "%EXISTING_URL%"=="" (
    echo [1/4] 检测到已绑定的 GitHub 仓库:
    echo       %EXISTING_URL%
    echo.
    set "INPUT_URL="
    set /p "INPUT_URL=请输入新的仓库地址 [直接回车保持默认]: "
) else (
    echo [1/4] 请输入您的 GitHub 仓库地址 (例如 https://github.com/loong486/immortalwrt-h5000m.git):
    set "INPUT_URL="
    set /p "INPUT_URL=仓库地址: "
)

if "%INPUT_URL%"=="" (
    set "REPO_URL=%EXISTING_URL%"
) else (
    set "REPO_URL=%INPUT_URL%"
)

if "%REPO_URL%"=="" (
    echo [错误] 仓库地址为空，操作已取消。
    pause
    exit /b 1
)

:setup_remote
git branch -M main >nul 2>&1
if not "%EXISTING_URL%"=="" (
    if not "%REPO_URL%"=="%EXISTING_URL%" (
        git remote set-url origin "%REPO_URL%"
    )
) else (
    git remote add origin "%REPO_URL%"
)

:: 检查工作区修改
echo.
echo [2/4] 检查本地文件状态...
git status --porcelain | findstr /r "." >nul 2>&1
if %errorlevel% neq 0 goto :no_uncommitted

set "COMMIT_MSG=%~2"
if "%COMMIT_MSG%"=="" (
    set "USER_MSG="
    set /p "USER_MSG=请输入本次提交说明 [直接回车使用默认]: "
) else (
    set "USER_MSG=%COMMIT_MSG%"
)

if "%USER_MSG%"=="" set "USER_MSG=feat: update firmware configuration and scripts"

echo 正在暂存并提交更新...
git add -A
git commit -m "%USER_MSG%"
goto :do_push

:no_uncommitted
echo 本地工作区干净，无未暂存文件，将直接推送已有提交。

:do_push
echo.
echo [3/4] 正在推送到 GitHub (%REPO_URL%)...
git push -u origin main
if %errorlevel% equ 0 goto :push_success

echo.
echo ================================================================
echo [提示] 推送未成功完成，常见原因：
echo   1. 网络连接不稳定或 SSL 握手超时 (建议开启网络加速或代理)
echo   2. 远端存在未同步的历史提交 (可选择强制覆盖或拉取合并)
echo.
echo 请选择重试方式:
echo   [1] 强制覆盖推送 (git push --force)
echo   [2] 拉取并变基合并后推送 (git pull --rebase)
echo   [3] 退出
echo ================================================================
set "RETRY_CHOICE="
set /p "RETRY_CHOICE=请输入选项 [1/2/3] (默认 1): "
if "%RETRY_CHOICE%"=="" set "RETRY_CHOICE=1"

if "%RETRY_CHOICE%"=="1" (
    echo 正在执行强制推送...
    git push -u origin main --force
    if %errorlevel% equ 0 goto :push_success
)

if "%RETRY_CHOICE%"=="2" (
    echo 正在拉取远端更新...
    git pull --rebase origin main
    git push -u origin main
    if %errorlevel% equ 0 goto :push_success
)

echo.
echo [错误] 推送失败，请检查网络设置或 GitHub 权限后重试。
pause
exit /b 1

:push_success
echo.
echo ================================================================
echo [4/4] 推送成功！代码已同步至 GitHub。
echo GitHub Actions 云端编译已自动触发，请前往仓库页面查看进度。
echo ================================================================
echo.
pause
exit /b 0
