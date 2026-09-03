@echo off
rem ============================================================
rem  One-click gameplay recording for M5 gate video.
rem  Project: cordit (Godot 4.7.2)  Output: evidence/m5-gameplay.avi
rem  ASCII only in this file to avoid codepage issues.
rem  Mirrors record_m4_gameplay.bat; differences:
rem   - target scene  res://evidence/_m5_auto_demo.tscn
rem   - quit-after 5400 (demo runs ~90-110 s; script self-quits
rem     via get_tree().quit(), so this is only a safety cap)
rem ============================================================
setlocal
chcp 65001 >nul

rem -- Godot exe (user-installed portable copy, 2026-08-31) --
set "GODOT_EXE=D:\software\Godot\Godot_v4.7.2-stable_win64.exe"

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
if exist "%ROOT%\evidence\m5-gameplay.avi" del "%ROOT%\evidence\m5-gameplay.avi"

echo Starting Godot Movie Maker (30 fps, demo self-quits; cap 5400 frames)...
echo Success line to look for:  Done recording movie at path: ...m5-gameplay.avi
echo.

pushd "%ROOT%"
"%GODOT_EXE%" --path "%ROOT%" --write-movie "%ROOT%\evidence\m5-gameplay.avi" --fixed-fps 30 --quit-after 5400 res://evidence/_m5_auto_demo.tscn
set RC=%ERRORLEVEL%
popd

echo.
if exist "%ROOT%\evidence\m5-gameplay.avi" (
    echo [OK] Recording finished: %ROOT%\evidence\m5-gameplay.avi
    echo      Exit code: %RC%
) else (
    echo [FAIL] No avi produced. Exit code: %RC%
    echo        Scroll up and check the Godot log for errors.
)

echo.
echo This window stays open. Press any key to close.
pause >nul
endlocal
