@echo off
setlocal
cd /d C:\Users\liujh\Desktop\cj-memo
echo === HEALTH ===
curl.exe -sS --max-time 5 http://127.0.0.1:8080/api/health
echo.
echo === REGISTER ===
curl.exe -sS -X POST -H "Content-Type: application/json" -d "@reg.json" --max-time 5 http://127.0.0.1:8080/api/user/register
echo.
echo === LOGIN ===
curl.exe -sS -X POST -H "Content-Type: application/json" -d "@reg.json" --max-time 5 http://127.0.0.1:8080/api/user/login
echo.
echo === INFO (no token) ===
curl.exe -sS --max-time 5 http://127.0.0.1:8080/api/user/info
echo.
