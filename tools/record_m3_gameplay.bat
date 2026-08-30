@echo off
rem ============================================================
rem  One-click gameplay recording for M3 gate-3 video.
rem  Project: cordit (Godot 4.7.2)  Output: evidence/m3-gameplay.avi
rem  ASCII only in this file to avoid codepage issues.
rem ============================================================
setlocal
chcp 65001 >nul

rem -- Godot console exe (WinGet install path, reparse point: use full path) --
set "GODOT_EXE=C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

rem -- Project root = parent of the tools\ folder this bat lives in --
set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

echo Project root: %ROOT%
echo.

if not exist "%GODOT_EXE%" (
    echo [ERROR] Godot exe not found:
    echo   %GODOT_EXE%
    echo Edit GODOT_EXE at the top of this file if the path changed.
    pause
    exit /b 1
)

rem -- Remove stale output so success check below is meaningful --
if exist "%ROOT%\evidence\m3-gameplay.avi" del "%ROOT%\evidence\m3-gameplay.avi"

echo Starting Godot Movie Maker (30 fps, ~17 s of footage)...
echo Success line to look for:  Done recording movie at path: ...m3-gameplay.avi
echo.

pushd "%ROOT%"
"%GODOT_EXE%" --path "%ROOT%" --write-movie "%ROOT%\evidence\m3-gameplay.avi" --fixed-fps 30 --quit-after 660 res://evidence/_m3_auto_demo.tscn
set RC=%ERRORLEVEL%
popd

echo.
if exist "%ROOT%\evidence\m3-gameplay.avi" (
    echo [OK] Recording finished: %ROOT%\evidence\m3-gameplay.avi
    echo      Exit code: %RC%
) else (
    echo [FAIL] No avi produced. Exit code: %RC%
    echo        Scroll up and check the Godot log for errors.
)

echo.
echo This window stays open. Press any key to close.
pause >nul
endlocal
