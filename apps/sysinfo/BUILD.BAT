REM Batch helper for a Backlash tool. It groups DOS commands that would otherwise need to be typed manually.
REM
@ECHO OFF
IF EXIST SYSINH.BAS GOTO LOCAL
FBC -lang fb APPS\SYSINFO\SYSINH.BAS -x APPS\SYSINFO\SYSINH.EXE
GOTO END
:LOCAL
FBC -lang fb SYSINH.BAS -x SYSINH.EXE
:END
