@echo off
echo 導出極光連線移動設備版本...
echo.

if not exist "..\mobile_build" mkdir "..\mobile_build"

echo 選擇導出平台:
echo 1. Android (APK)
echo 2. iOS (Xcode項目)
echo.

set /p choice="請輸入選擇 (1 或 2): "

if "%choice%"=="1" (
    echo 導出Android版本...
    godot --path . --export "Android" "..\mobile_build\neon_pulse.apk"
    echo Android APK已導出到 ..\mobile_build\neon_pulse.apk
) else if "%choice%"=="2" (
    echo 導出iOS版本...
    godot --path . --export "iOS" "..\mobile_build\ios"
    echo iOS項目已導出到 ..\mobile_build\ios
) else (
    echo 無效選擇
)

echo.
echo 導出完成！
pause