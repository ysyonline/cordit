@echo off
rem ============================================================
rem  M7 video #7 recording launcher (user plays, Godot captures)
rem  Project: cordit (Godot 4.7.2)  Output: evidence/m7-gameplay.avi
rem  ASCII only in this file to avoid codepage issues.
rem  Mirrors record_m5_gameplay.bat, but:
rem   - target scene is res://scenes/main.tscn (normal entry,
rem     NOT auto-demo) per m7-video7-shotlist.md
rem   - NO --quit-after: the user plays manually and quits from
rem     the in-game menu (or Alt+F4); Movie Maker writes the avi
rem     on exit.
rem   - console exe used so a capture log is available for
rem     evidence/m7-recording.log (zero-ERROR check).
rem  Usage: play the game; when done, quit the game normally.
rem  The console window prints "Done recording movie..." at end;
rem  then copy the console text into evidence\m7-recording.log.
rem ============================================================
setlocal
chcp 65001 >nul

rem -- Godot console exe (winget install, verified 2026-09-12) --
set "GODOT_EXE=C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

rem -- Project root = parent of the tools\ folder this bat lives in --
set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

echo Project root: %ROOT%
echo.

if not exist "%GODOT_EXE%" (
    echo [ERROR] Godot console exe not found:
    echo   %GODOT_EXE%
    pause
    exit /b 1
)

rem -- Remove stale output so success check below is meaningful --
if exist "%ROOT%\evidence\m7-gameplay.avi" del "%ROOT%\evidence\m7-gameplay.avi"

echo ============================================================
echo  M7 video #7: Movie Maker 640x360 @ 30 FPS, main.tscn entry
echo  1) Game window opens - play per m7-video7-shotlist.md
echo     (read save at ruins_f2, clear B4 then B5, reach ending)
echo  2) When finished, QUIT THE GAME NORMALLY (menu quit or Alt+F4)
echo  3) After quit, come back here and follow the prompt.
echo ============================================================
echo.
pause

pushd "%ROOT%"
"%GODOT_EXE%" --path "%ROOT%" --write-movie "%ROOT%\evidence\m7-gameplay.avi" --fixed-fps 30 res://scenes/main.tscn
set RC=%ERRORLEVEL%
popd

echo.
if exist "%ROOT%\evidence\m7-gameplay.avi" (
    echo [OK] Recording finished: %ROOT%\evidence\m7-gameplay.avi
    echo      Exit code: %RC%
) else (
    echo [FAIL] No avi produced. Exit code: %RC%
    echo        Scroll up and check the Godot log for errors.
)

echo.
echo NEXT: save this console output as evidence\m7-recording.log
echo       (right-click console window title - Select All - Enter,
echo        then paste into a text file named m7-recording.log)
echo.
echo This window stays open. Press any key to close.
pause >nul
endlocal
