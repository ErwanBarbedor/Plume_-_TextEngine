@echo off
chcp 65001 > nul
set LUA_PATH=%~dp0?\init.lua;%~dp0?.lua;%LUA_PATH%
lua54 "%~dp0cli.lua" -p %*