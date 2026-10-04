@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM ============================================================
REM  git_sync.bat  —— 一键同步当前 Git 仓库
REM  用法:  git_sync.bat [提交信息]
REM ============================================================

set "MSG=%*"
if "%MSG%"=="" set "MSG=auto sync: %date% %time%"

echo ============================================
echo   Git 同步开始
echo ============================================

REM ---------- 1. 检查 git ----------
where git >nul 2>nul
if errorlevel 1 (
    echo [X] 未找到 git，请先安装 Git 并加入 PATH。
    exit /b 1
)

REM ---------- 2. 检查是否在仓库中 ----------
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
    echo [X] 当前目录不是 Git 仓库。
    exit /b 1
)

REM ---------- 3. 当前分支 ----------
for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set "BRANCH=%%b"
echo [*] 当前分支: !BRANCH!

if "!BRANCH!"=="HEAD" (
    echo [X] 处于 detached HEAD 状态，请先切换到某个分支。
    exit /b 1
)

REM ---------- 4. 是否存在远程 ----------
set "HAS_REMOTE=0"
for /f "delims=" %%r in ('git remote 2^>nul') do set "HAS_REMOTE=1"

REM ---------- 5. 暂存 + 提交 ----------
git add -A
git diff --cached --quiet
if errorlevel 1 (
    echo [*] 提交本地改动...
    git commit -m "%MSG%"
    if errorlevel 1 (
        echo [X] 提交失败。
        exit /b 1
    )
) else (
    echo [*] 没有需要提交的改动。
)

if "!HAS_REMOTE!"=="0" (
    echo [WARN] 没有配置远程仓库，已完成本地提交，跳过 pull/push。
    goto :done
)

REM ---------- 6. 是否有上游分支 ----------
set "HAS_UPSTREAM=0"
git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >nul 2>nul
if not errorlevel 1 set "HAS_UPSTREAM=1"

REM ---------- 7. 拉取远程（rebase） ----------
if "!HAS_UPSTREAM!"=="1" (
    echo [*] 拉取远程更新 ^(pull --rebase^)...
    git pull --rebase --autostash
    if errorlevel 1 (
        echo [X] pull 失败，可能存在冲突，请手动解决后重试。
        echo     解决冲突后可执行: git rebase --continue
        exit /b 1
    )
) else (
    echo [WARN] 当前分支没有上游，跳过 pull。
)

REM ---------- 8. 推送 ----------
if "!HAS_UPSTREAM!"=="1" (
    echo [*] 推送到远程...
    git push
) else (
    echo [*] 首次推送并设置上游...
    git push -u origin "!BRANCH!"
)
if errorlevel 1 (
    echo [X] push 失败。
    exit /b 1
)

:done
echo ============================================
echo   同步完成
echo ============================================
endlocal
exit /b 0