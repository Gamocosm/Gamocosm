@echo off

DEL /F /Q /S %CD%\..\tmp\pids
docker-compose up
