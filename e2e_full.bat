@echo off
setlocal
set TOKEN=
set BASE=http://127.0.0.1:8080
echo === LOGIN ===
curl.exe -sS -X POST -H "Content-Type: application/json" -d "@reg.json" --max-time 5 %BASE%/api/user/login
echo.
echo.
rem extract token via jq-less path: use powershell inline
for /f "tokens=*" %%L in ('powershell -NoProfile -Command "(curl.exe -sS -X POST -H 'Content-Type: application/json' -d '@reg.json' --max-time 5 %BASE%/api/user/login | ConvertFrom-Json).data.token"') do set TOKEN=%%L
echo TOKEN=%TOKEN%
echo.
echo === CREATE EVENT ===
curl.exe -sS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer %TOKEN%" -d "@create_event.json" --max-time 5 %BASE%/api/event
echo.
echo.
echo === LIST EVENTS ===
curl.exe -sS -H "Authorization: Bearer %TOKEN%" --max-time 5 %BASE%/api/event/list
echo.
echo.
echo === INFO ===
curl.exe -sS -H "Authorization: Bearer %TOKEN%" --max-time 5 %BASE%/api/user/info
echo.
