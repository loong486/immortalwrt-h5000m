@echo off
chcp 65001 >nul

echo ================================================================
echo             ImmortalWrt H5000M 鍥轰欢宸ョ▼ GitHub 涓€閿帹閫佽剼鏈?
echo ================================================================
echo.

cd /d "%~dp0"

:: 妫€鏌?Git
where git >nul 2>&1
if %errorlevel% equ 0 goto :has_git

:: 妫€鏌?WSL
wsl.exe -e true >nul 2>&1
if %errorlevel% equ 0 goto :use_wsl

echo [閿欒] 褰撳墠绯荤粺鏈娴嬪埌 Git 鎴?WSL 鐜锛?
echo 璇峰畨瑁?Git for Windows 鍚庨噸璇? https://git-scm.com/download/win
echo.
pause
exit /b 1

:use_wsl
echo 姝ｅ湪璋冪敤 WSL 鐜鎵ц鎺ㄩ€?..
wsl.exe bash ./push_to_github.sh %*
pause
exit /b 0

:has_git
if not exist ".git" (
    echo [1/4] 鍒濆鍖栨湰鍦?Git 浠撳簱...
    git init
)

:: 妫€鏌?Git 韬唤
git config user.name >nul 2>&1
if %errorlevel% neq 0 (
    git config user.name "loong486"
    git config user.email "loong486@users.noreply.github.com"
)

:: 鑾峰彇杩滅▼婧?
set "EXISTING_URL="
for /f "tokens=*" %%i in ('git remote get-url origin 2^>nul') do set "EXISTING_URL=%%i"

set "REPO_URL=%~1"
if not "%REPO_URL%"=="" goto :setup_remote

if not "%EXISTING_URL%"=="" (
    echo [1/4] 妫€娴嬪埌宸插叧鑱旂殑 GitHub 浠撳簱:
    echo       %EXISTING_URL%
    echo.
    set "INPUT_URL="
    set /p "INPUT_URL=璇疯緭鍏ユ柊鐨勪粨搴撳湴鍧€ [鐩存帴鍥炶溅淇濇寔榛樿]: "
) else (
    echo [1/4] 璇烽厤缃繙绋?GitHub 浠撳簱:
    set "INPUT_URL="
    set /p "INPUT_URL=璇疯緭鍏ユ偍鐨?GitHub 浠撳簱鍦板潃: "
)

if "%INPUT_URL%"=="" (
    set "REPO_URL=%EXISTING_URL%"
) else (
    set "REPO_URL=%INPUT_URL%"
)

if "%REPO_URL%"=="" (
    echo [閿欒] 鏈彁渚涗粨搴撳湴鍧€锛屾搷浣滀腑姝€?
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

:: 妫€鏌ュ伐浣滃尯
echo.
echo [2/4] 妫€鏌ユ湰鍦版枃浠剁姸鎬?..
git status --porcelain | findstr /r "." >nul 2>&1
if %errorlevel% neq 0 goto :no_uncommitted

set "COMMIT_MSG=%~2"
if "%COMMIT_MSG%"=="" (
    set "USER_MSG="
    set /p "USER_MSG=璇疯緭鍏ユ湰娆℃彁浜よ鏄?[鐩存帴鍥炶溅浣跨敤榛樿璇存槑]: "
) else (
    set "USER_MSG=%COMMIT_MSG%"
)

if "%USER_MSG%"=="" set "USER_MSG=feat: update firmware config, packages and scripts"

echo 姝ｅ湪鏆傚瓨骞舵彁浜ゆ枃浠?..
git add .
git commit -m "%USER_MSG%"
goto :do_push

:no_uncommitted
echo 鏈湴宸ヤ綔鍖哄共鍑€锛屾棤鏈殏瀛樻枃浠讹紝灏嗙洿鎺ユ帹閫佸凡鏈夋彁浜ゃ€?

:do_push
echo.
echo [3/4] 姝ｅ湪鎺ㄩ€佸埌 GitHub: %REPO_URL% ...
git push -u origin main
if %errorlevel% equ 0 goto :push_success

echo.
echo ================================================================
echo [鎻愮ず] 鎺ㄩ€佹湭鎴愬姛锛?
echo.
echo 甯歌鍘熷洜涓庤В鍐冲姙娉?
echo   1. 缃戠粶杩炴帴澶辫触 (SSL/TLS Handshake Failed):
echo      - 璇峰紑鍚唬鐞?鍔犻€熻蒋浠?(濡?Watt Toolkit / Clash / 绉戝涓婄綉)
echo      - 鎴栬€呭鏋滄偍鐨勪唬鐞嗙鍙ｄ负 7890锛屽彲鍦ㄦ彁绀烘椂閰嶇疆 Git 浠ｇ悊
echo   2. 杩滅▼鍘嗗彶涓嶅悓姝?(闇€瑕嗙洊鎺ㄩ€?:
echo.
echo 璇烽€夋嫨鍚庣画鎿嶄綔:
echo   [1] 灏濊瘯寮哄埗瑕嗙洊鎺ㄩ€?(git push --force)
echo   [2] 灏濊瘯鎷夊彇鍚堝苟 (git pull --rebase)
echo   [3] 璁剧疆 Git 浠ｇ悊骞堕噸璇?(濡?http://127.0.0.1:7890)
echo   [4] 閫€鍑鸿剼鏈?
echo ================================================================
set "RETRY_CHOICE="
set /p "RETRY_CHOICE=璇疯緭鍏ラ€夐」缂栧彿 [1/2/3/4] (榛樿 1): "
if "%RETRY_CHOICE%"=="" set "RETRY_CHOICE=1"

if "%RETRY_CHOICE%"=="1" (
    echo 姝ｅ湪鎵ц寮哄埗鎺ㄩ€?..
    git push -u origin main --force
    if %errorlevel% equ 0 goto :push_success
)

if "%RETRY_CHOICE%"=="2" (
    echo 姝ｅ湪鎷夊彇杩滅▼鏇存柊...
    git pull --rebase origin main
    echo 閲嶆柊鎺ㄩ€?..
    git push -u origin main
    if %errorlevel% equ 0 goto :push_success
)

if "%RETRY_CHOICE%"=="3" (
    set "PROXY_ADDR="
    set /p "PROXY_ADDR=璇疯緭鍏ヤ唬鐞嗗湴鍧€ (渚嬪 http://127.0.0.1:7890): "
    if not "%PROXY_ADDR%"=="" (
        git config --global http.proxy "%PROXY_ADDR%"
        git config --global https.proxy "%PROXY_ADDR%"
        echo 宸查厤缃?Git 浠ｇ悊涓?%PROXY_ADDR%锛屾鍦ㄩ噸鏂版帹閫?..
        git push -u origin main
        if %errorlevel% equ 0 goto :push_success
    )
)

echo.
echo ================================================================
echo [閿欒] 鎺ㄩ€佹湭瀹屾垚锛佽妫€鏌ョ綉缁滄垨鏉冮檺鍚庨噸璇曘€?
echo ================================================================
pause
exit /b 1

:push_success
echo.
echo ================================================================
echo [4/4] 鎺ㄩ€佹垚鍔燂紒浠ｇ爜宸插悓姝ヨ嚦 GitHub銆?
echo GitHub Actions 鑷姩鍖栫紪璇戝凡鑷姩瑙﹀彂锛岃鍓嶅線浠撳簱椤甸潰鏌ョ湅銆?
echo ================================================================
echo.
pause
exit /b 0
