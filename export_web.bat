@echo off
echo 導出極光連線網頁版本...
echo.

if not exist "..\web_build" mkdir "..\web_build"

echo 開始導出...
godot --path . --export-release "Web" "..\web_build"

echo.
echo 導出完成！
echo 文件已保存到 ..\web_build 目錄
echo.
echo 要測試網頁版本，請在瀏覽器中打開 ..\web_build\index.html
echo.
pause