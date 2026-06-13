REM Batch helper for a Backlash tool. It groups DOS commands that would otherwise need to be typed manually.
REM
@ECHO OFF
REM Backlash DOS launch/return wrapper
REM Usage: BACKLDR [BACKLASH.EXE]
cd c:\backlash

SET BL_EXE=BACKLASH.EXE
IF NOT "%1"=="" SET BL_EXE=%1

:BACKLOOP
IF EXIST SYSTEM\DOSRUN.BAT DEL SYSTEM\DOSRUN.BAT
%BL_EXE%
IF NOT EXIST SYSTEM\DOSRUN.BAT GOTO DONE
CALL SYSTEM\DOSRUN.BAT
GOTO BACKLOOP

:DONE
