@echo off
echo ===================================================
echo   Starting Microsoft Edge with Remote Debugging (9222)
echo ===================================================

set EDGE_PATH="C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if not exist %EDGE_PATH% set EDGE_PATH="C:\Program Files\Microsoft\Edge\Application\msedge.exe"

set PROFILE_DIR=%USERPROFILE%\.edge-ai-profile

start "" %EDGE_PATH% --remote-debugging-port=9222 --user-data-dir="%PROFILE_DIR%" --restore-last-session --start-maximized "https://www.tripo3d.ai/app" "https://gemini.google.com" "https://aistudio.google.com"

echo Edge launched on port 9222 with dedicated AI profile: %PROFILE_DIR%
echo Ready for Antigravity, Playwright, and MCP control!
