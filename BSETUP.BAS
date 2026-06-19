' Copyright (c) 2026 Rick Reedus
' Command-line setup utility for Backlash performance-related settings.

' Program constants define config paths and fixed table sizes used by this utility.
' The SYSTEM\*.CFG filenames match the Backlash runtime configuration files edited here.
CONST MAX_CFG_LINES = 4096
CONST APP_NAME = "Backlash Setup"
CONST SETTING_COUNT = 16

CONST CFG_DISPLAY = "SYSTEM\DISPLAY.CFG"
CONST CFG_SHELL = "SYSTEM\SHELL.CFG"
CONST CFG_DESKTOP = "SYSTEM\DESKTOP.CFG"
CONST CFG_MOUSE = "SYSTEM\MOUSE.CFG"
CONST CFG_SOUND = "SYSTEM\SOUND.CFG"
CONST CFG_SAVER = "SYSTEM\SCRNSAVR.CFG"
CONST CFG_THEME = "SYSTEM\THEME.CFG"
CONST CFG_SPLASH = "SYSTEM\SPLASH.CFG"

' Shared process state: gRoot holds the detected Backlash root path, gChanged records whether any config file was rewritten,
' gStatus carries the last user-visible result message, and gSelected stores the highlighted row in the full-screen menu.
DIM SHARED gRoot AS STRING
DIM SHARED gChanged AS INTEGER
DIM SHARED gStatus AS STRING
DIM SHARED gSelected AS INTEGER

' Forward declarations are grouped before implementation so command parsing, drawing, and setting routines can call each other freely.
DECLARE FUNCTION CleanUpper(BYVAL textIn AS STRING) AS STRING
DECLARE FUNCTION LastSlashPos(BYVAL textIn AS STRING) AS INTEGER
DECLARE FUNCTION AddSlash(BYVAL pathIn AS STRING) AS STRING
DECLARE FUNCTION JoinRoot(BYVAL relPath AS STRING) AS STRING
DECLARE FUNCTION FileExists(BYVAL fileName AS STRING) AS INTEGER
DECLARE FUNCTION CandidateHasBacklashCfg(BYVAL candidateRoot AS STRING) AS INTEGER
DECLARE FUNCTION DetectBacklashRoot() AS STRING
DECLARE FUNCTION ReadCfgValueSimple(BYVAL relPath AS STRING, BYVAL keyName AS STRING, BYVAL defaultValue AS STRING) AS STRING
DECLARE FUNCTION BoolText(BYVAL textIn AS STRING) AS STRING
DECLARE FUNCTION OnOffText(BYVAL textIn AS STRING) AS STRING
DECLARE FUNCTION ResolutionText(BYVAL valueText AS STRING) AS STRING
DECLARE FUNCTION ColorDepthText(BYVAL valueText AS STRING) AS STRING
DECLARE FUNCTION CurrentDragText() AS STRING
DECLARE FUNCTION CurrentEventsText() AS STRING
DECLARE FUNCTION CurrentDetectText() AS STRING
DECLARE FUNCTION CurrentWallpaperText() AS STRING
DECLARE FUNCTION CurrentSplashText() AS STRING
DECLARE FUNCTION CurrentGradText() AS STRING
DECLARE FUNCTION ValidOnOff(BYVAL valueText AS STRING) AS INTEGER
DECLARE FUNCTION ValidDriver(BYVAL valueText AS STRING) AS INTEGER
DECLARE FUNCTION ValidResolution(BYVAL valueText AS STRING) AS INTEGER
DECLARE FUNCTION ValidColorDepth(BYVAL valueText AS STRING) AS INTEGER
DECLARE FUNCTION SettingLabel(BYVAL idx AS INTEGER) AS STRING
DECLARE FUNCTION SettingValue(BYVAL idx AS INTEGER) AS STRING
DECLARE FUNCTION SettingHelp(BYVAL idx AS INTEGER) AS STRING
DECLARE FUNCTION NextOnOff(BYVAL valueText AS STRING) AS STRING
DECLARE FUNCTION NextResolution(BYVAL valueText AS STRING) AS STRING
DECLARE FUNCTION NextDepth(BYVAL valueText AS STRING) AS STRING
DECLARE FUNCTION NextDriver(BYVAL valueText AS STRING) AS STRING
DECLARE FUNCTION MouseHit(BYREF hitRow AS INTEGER, BYREF hitCol AS INTEGER) AS INTEGER
DECLARE FUNCTION PadRight(BYVAL textIn AS STRING, BYVAL wide AS INTEGER) AS STRING
DECLARE FUNCTION BoxText(BYVAL textIn AS STRING, BYVAL wide AS INTEGER) AS STRING

DECLARE SUB PrintHeader()
DECLARE SUB PrintHelp()
DECLARE SUB PrintStatus()
DECLARE SUB WriteCfgValueSimple(BYVAL relPath AS STRING, BYVAL keyName AS STRING, BYVAL newValue AS STRING)
DECLARE SUB StoreBackupValue(BYVAL relPath AS STRING, BYVAL backupKey AS STRING, BYVAL valueText AS STRING)
DECLARE SUB SetResolution(BYVAL valueText AS STRING)
DECLARE SUB SetColorDepth(BYVAL valueText AS STRING)
DECLARE SUB SetDragMode(BYVAL valueText AS STRING)
DECLARE SUB SetAudioEnabled(BYVAL valueText AS STRING)
DECLARE SUB SetAudioDriver(BYVAL valueText AS STRING)
DECLARE SUB SetAudioEvents(BYVAL valueText AS STRING)
DECLARE SUB SetAudioDetect(BYVAL valueText AS STRING)
DECLARE SUB SetScreensaver(BYVAL valueText AS STRING)
DECLARE SUB SetWallpaper(BYVAL valueText AS STRING)
DECLARE SUB SetSplash(BYVAL valueText AS STRING)
DECLARE SUB SetGradients(BYVAL valueText AS STRING)
DECLARE SUB SetMouseTrails(BYVAL valueText AS STRING)
DECLARE SUB SetDesktopIcons(BYVAL valueText AS STRING)
DECLARE SUB SetTaskbar(BYVAL valueText AS STRING)
DECLARE SUB SetClock(BYVAL valueText AS STRING)
DECLARE SUB SetTaskbarVolume(BYVAL valueText AS STRING)
DECLARE SUB ApplyProfile(BYVAL profileName AS STRING)
DECLARE SUB CycleSetting(BYVAL idx AS INTEGER)
DECLARE SUB DrawText(BYVAL rowNum AS INTEGER, BYVAL colNum AS INTEGER, BYVAL textIn AS STRING, BYVAL foreColor AS INTEGER, BYVAL backColor AS INTEGER)
DECLARE SUB DrawBox(BYVAL row1 AS INTEGER, BYVAL col1 AS INTEGER, BYVAL row2 AS INTEGER, BYVAL col2 AS INTEGER, BYVAL titleText AS STRING, BYVAL foreColor AS INTEGER, BYVAL backColor AS INTEGER)
DECLARE SUB DrawButton(BYVAL rowNum AS INTEGER, BYVAL col1 AS INTEGER, BYVAL col2 AS INTEGER, BYVAL textIn AS STRING, BYVAL selectedFlag AS INTEGER)
DECLARE SUB DrawSetupScreen()
DECLARE SUB WaitMouseRelease()
DECLARE SUB InteractiveMenu()
DECLARE SUB HandleCommandLine()

' Returns trimmed uppercase text for command names, config keys, and option values.
' Input: any string. Output: normalized comparison string. Side effects: none.
FUNCTION CleanUpper(BYVAL textIn AS STRING) AS STRING
    CleanUpper = UCASE$(TRIM$(textIn))
END FUNCTION

' Finds the last DOS or Unix-style path separator in a path string.
' Input: path text. Output: one-based separator position, or zero when no separator exists. Side effects: none.
FUNCTION LastSlashPos(BYVAL textIn AS STRING) AS INTEGER
    DIM i AS INTEGER

    LastSlashPos = 0
    FOR i = LEN(textIn) TO 1 STEP -1
        IF MID$(textIn, i, 1) = "\" OR MID$(textIn, i, 1) = "/" THEN
            LastSlashPos = i
            EXIT FUNCTION
        END IF
    NEXT i
END FUNCTION

' Normalizes a directory path so later path joins can append filenames safely.
' Input: directory text. Output: unchanged empty string or directory ending in a slash. Side effects: none.
FUNCTION AddSlash(BYVAL pathIn AS STRING) AS STRING
    pathIn = TRIM$(pathIn)
    IF pathIn = "" THEN
        AddSlash = ""
    ELSEIF RIGHT$(pathIn, 1) = "\" OR RIGHT$(pathIn, 1) = "/" THEN
        AddSlash = pathIn
    ELSE
        AddSlash = pathIn + "\"
    END IF
END FUNCTION

' Builds a config filename from the detected Backlash root and a relative SYSTEM path.
' Input: relative filename. Output: root-qualified filename when gRoot is known. Side effects: none.
FUNCTION JoinRoot(BYVAL relPath AS STRING) AS STRING
    IF gRoot = "" THEN
        JoinRoot = relPath
    ELSE
        JoinRoot = gRoot + relPath
    END IF
END FUNCTION

' Tests whether a file can be opened for input.
' Input: filename. Output: nonzero for existing readable file, zero otherwise. Side effects: opens and closes the file.
FUNCTION FileExists(BYVAL fileName AS STRING) AS INTEGER
    DIM f AS INTEGER

    FileExists = 0
    f = FREEFILE
    IF OPEN(fileName FOR INPUT AS #f) = 0 THEN
        CLOSE #f
        FileExists = -1
    END IF
END FUNCTION

' Verifies that a directory looks like a Backlash install by checking the required SYSTEM config files.
' Input: candidate root path. Output: nonzero only when display, shell, and sound configs are present. Side effects: none.
FUNCTION CandidateHasBacklashCfg(BYVAL candidateRoot AS STRING) AS INTEGER
    candidateRoot = AddSlash(candidateRoot)
    CandidateHasBacklashCfg = 0
    IF FileExists(candidateRoot + CFG_DISPLAY) = 0 THEN EXIT FUNCTION
    IF FileExists(candidateRoot + CFG_SHELL) = 0 THEN EXIT FUNCTION
    IF FileExists(candidateRoot + CFG_SOUND) = 0 THEN EXIT FUNCTION
    CandidateHasBacklashCfg = -1
END FUNCTION

' Locates the Backlash root from the current directory, parent directories, or the executable path.
' Output: path prefix for config files, or empty when the current directory is already the root. Side effects: file existence checks only.
FUNCTION DetectBacklashRoot() AS STRING
    DIM programPath AS STRING
    DIM programDir AS STRING
    DIM slashPos AS INTEGER

    DetectBacklashRoot = ""

    IF CandidateHasBacklashCfg("") <> 0 THEN EXIT FUNCTION
    IF CandidateHasBacklashCfg("..") <> 0 THEN
        DetectBacklashRoot = "..\"
        EXIT FUNCTION
    END IF
    IF CandidateHasBacklashCfg("..\..") <> 0 THEN
        DetectBacklashRoot = "..\..\"
        EXIT FUNCTION
    END IF

    programPath = COMMAND(0)
    slashPos = LastSlashPos(programPath)
    IF slashPos > 0 THEN
        programDir = LEFT$(programPath, slashPos)
        IF CandidateHasBacklashCfg(programDir) <> 0 THEN
            DetectBacklashRoot = AddSlash(programDir)
            EXIT FUNCTION
        END IF
        IF CandidateHasBacklashCfg(programDir + "..") <> 0 THEN
            DetectBacklashRoot = AddSlash(programDir + "..")
            EXIT FUNCTION
        END IF
        IF CandidateHasBacklashCfg(programDir + "..\..") <> 0 THEN
            DetectBacklashRoot = AddSlash(programDir + "..\..")
            EXIT FUNCTION
        END IF
    END IF
END FUNCTION

' Reads a simple KEY=VALUE entry from one Backlash config file.
' Inputs: relative config filename, key name, fallback value. Output: trimmed value or fallback. Side effects: opens and closes the config file.
FUNCTION ReadCfgValueSimple(BYVAL relPath AS STRING, BYVAL keyName AS STRING, BYVAL defaultValue AS STRING) AS STRING
    DIM f AS INTEGER
    DIM lineIn AS STRING
    DIM workLine AS STRING
    DIM p AS INTEGER
    DIM curKey AS STRING

    ReadCfgValueSimple = defaultValue
    f = FREEFILE
    IF OPEN(JoinRoot(relPath) FOR INPUT AS #f) <> 0 THEN EXIT FUNCTION

    DO WHILE NOT EOF(f)
        LINE INPUT #f, lineIn
        workLine = TRIM$(lineIn)
        IF workLine <> "" THEN
            IF LEFT$(workLine, 1) <> ";" AND LEFT$(workLine, 1) <> "#" AND LEFT$(workLine, 1) <> "[" THEN
                p = INSTR(workLine, "=")
                IF p > 0 THEN
                    curKey = CleanUpper(LEFT$(workLine, p - 1))
                    IF curKey = CleanUpper(keyName) THEN
                        ReadCfgValueSimple = TRIM$(MID$(workLine, p + 1))
                        CLOSE #f
                        EXIT FUNCTION
                    END IF
                END IF
            END IF
        END IF
    LOOP

    CLOSE #f
END FUNCTION

' Rewrites or appends a simple KEY=VALUE entry in one Backlash config file.
' Inputs: relative config filename, key name, new value. Side effects: writes SYSTEM\BSETUP.TMP, replaces the target file, sets gChanged.
SUB WriteCfgValueSimple(BYVAL relPath AS STRING, BYVAL keyName AS STRING, BYVAL newValue AS STRING)
    DIM fileLines(1 TO MAX_CFG_LINES) AS STRING
    DIM lineCount AS INTEGER
    DIM f AS INTEGER
    DIM lineIn AS STRING
    DIM workLine AS STRING
    DIM p AS INTEGER
    DIM curKey AS STRING
    DIM foundLine AS INTEGER
    DIM i AS INTEGER
    DIM targetPath AS STRING
    DIM tempPath AS STRING

    targetPath = JoinRoot(relPath)
    tempPath = JoinRoot("SYSTEM\BSETUP.TMP")
    lineCount = 0
    foundLine = 0

    f = FREEFILE
    IF OPEN(targetPath FOR INPUT AS #f) = 0 THEN
        DO WHILE NOT EOF(f)
            LINE INPUT #f, lineIn
            IF lineCount < MAX_CFG_LINES THEN
                lineCount = lineCount + 1
                fileLines(lineCount) = lineIn
            END IF
        LOOP
        CLOSE #f
    END IF

    FOR i = 1 TO lineCount
        workLine = TRIM$(fileLines(i))
        IF workLine <> "" THEN
            IF LEFT$(workLine, 1) <> ";" AND LEFT$(workLine, 1) <> "#" AND LEFT$(workLine, 1) <> "[" THEN
                p = INSTR(workLine, "=")
                IF p > 0 THEN
                    curKey = CleanUpper(LEFT$(workLine, p - 1))
                    IF curKey = CleanUpper(keyName) THEN
                        foundLine = i
                        EXIT FOR
                    END IF
                END IF
            END IF
        END IF
    NEXT i

    IF foundLine > 0 THEN
        fileLines(foundLine) = keyName + "=" + newValue
    ELSE
        IF lineCount > 0 THEN
            IF TRIM$(fileLines(lineCount)) <> "" AND lineCount < MAX_CFG_LINES THEN
                lineCount = lineCount + 1
                fileLines(lineCount) = ""
            END IF
        END IF
        IF lineCount < MAX_CFG_LINES THEN
            lineCount = lineCount + 1
            fileLines(lineCount) = keyName + "=" + newValue
        END IF
    END IF

    f = FREEFILE
    IF OPEN(tempPath FOR OUTPUT AS #f) <> 0 THEN
        gStatus = "Could not write temp file: " + tempPath
        EXIT SUB
    END IF

    FOR i = 1 TO lineCount
        PRINT #f, fileLines(i)
    NEXT i
    CLOSE #f

    IF FileExists(targetPath) <> 0 THEN KILL targetPath
    NAME tempPath AS targetPath
    gChanged = -1
END SUB

' Stores the original wallpaper or splash value once so OFF/ON toggles can restore it later.
' Inputs: config file, backup key name, current value. Side effects: may write a backup key to the selected config file.
SUB StoreBackupValue(BYVAL relPath AS STRING, BYVAL backupKey AS STRING, BYVAL valueText AS STRING)
    DIM existingValue AS STRING

    existingValue = ReadCfgValueSimple(relPath, backupKey, "")
    IF TRIM$(existingValue) = "" AND TRIM$(valueText) <> "" THEN
        WriteCfgValueSimple relPath, backupKey, valueText
    END IF
END SUB

' Converts accepted boolean words and numeric values into Backlash numeric boolean text.
' Input: ON/OFF, YES/NO, TRUE/FALSE, or 1/0 text. Output: "1" for true, "0" for false. Side effects: none.
FUNCTION BoolText(BYVAL textIn AS STRING) AS STRING
    DIM workText AS STRING

    workText = CleanUpper(textIn)
    IF workText = "1" OR workText = "YES" OR workText = "ON" OR workText = "TRUE" THEN
        BoolText = "1"
    ELSE
        BoolText = "0"
    END IF
END FUNCTION

' Formats a boolean config value for display.
' Input: boolean text. Output: "On" or "Off". Side effects: none.
FUNCTION OnOffText(BYVAL textIn AS STRING) AS STRING
    IF BoolText(textIn) = "1" THEN
        OnOffText = "On"
    ELSE
        OnOffText = "Off"
    END IF
END FUNCTION

' Validates user-supplied ON/OFF style input.
' Input: command value text. Output: nonzero when the value can be converted by BoolText. Side effects: none.
FUNCTION ValidOnOff(BYVAL valueText AS STRING) AS INTEGER
    DIM workText AS STRING

    workText = CleanUpper(valueText)
    ValidOnOff = 0
    IF workText = "1" OR workText = "0" THEN ValidOnOff = -1
    IF workText = "ON" OR workText = "OFF" THEN ValidOnOff = -1
    IF workText = "YES" OR workText = "NO" THEN ValidOnOff = -1
    IF workText = "TRUE" OR workText = "FALSE" THEN ValidOnOff = -1
END FUNCTION

' Validates the supported Backlash audio driver names.
' Input: driver text. Output: nonzero for NONE, PCSPKR, AUTO, ADLIB, or SBLASTER. Side effects: none.
FUNCTION ValidDriver(BYVAL valueText AS STRING) AS INTEGER
    DIM workText AS STRING

    workText = CleanUpper(valueText)
    ValidDriver = 0
    IF workText = "NONE" THEN ValidDriver = -1
    IF workText = "PCSPKR" THEN ValidDriver = -1
    IF workText = "AUTO" THEN ValidDriver = -1
    IF workText = "ADLIB" THEN ValidDriver = -1
    IF workText = "SBLASTER" THEN ValidDriver = -1
END FUNCTION

' Validates display resolution input against the resolution modes accepted by the current shell.
' Input: numeric or WIDTHxHEIGHT text. Output: nonzero for 640x480, 800x600, or 1024x768. Side effects: none.
FUNCTION ValidResolution(BYVAL valueText AS STRING) AS INTEGER
    DIM workText AS STRING

    workText = CleanUpper(valueText)
    ValidResolution = 0
    IF workText = "1" OR workText = "640" OR workText = "640X480" THEN ValidResolution = -1
    IF workText = "2" OR workText = "800" OR workText = "800X600" THEN ValidResolution = -1
    IF workText = "3" OR workText = "1024" OR workText = "1024X768" THEN ValidResolution = -1
END FUNCTION

' Validates color depth input against Backlash display depth values.
' Input: numeric or named depth. Output: nonzero for 16-color, 256-color, high-color, or true-color values. Side effects: none.
FUNCTION ValidColorDepth(BYVAL valueText AS STRING) AS INTEGER
    DIM workText AS STRING

    workText = CleanUpper(valueText)
    ValidColorDepth = 0
    IF workText = "4" OR workText = "16COLOR" OR workText = "16COLORS" THEN ValidColorDepth = -1
    IF workText = "8" OR workText = "256" OR workText = "256COLOR" OR workText = "256COLORS" THEN ValidColorDepth = -1
    IF workText = "16" OR workText = "HIGH" OR workText = "HIGHCOLOR" THEN ValidColorDepth = -1
    IF workText = "32" OR workText = "TRUE" OR workText = "TRUECOLOR" THEN ValidColorDepth = -1
END FUNCTION

' Converts stored resolution codes into readable labels for status screens.
' Input: config value or equivalent text. Output: formatted resolution label. Side effects: none.
FUNCTION ResolutionText(BYVAL valueText AS STRING) AS STRING
    SELECT CASE CleanUpper(valueText)
    CASE "1", "640", "640X480"
        ResolutionText = "640 x 480"
    CASE "2", "800", "800X600"
        ResolutionText = "800 x 600"
    CASE "3", "1024", "1024X768"
        ResolutionText = "1024 x 768"
    CASE ELSE
        ResolutionText = valueText
    END SELECT
END FUNCTION

' Converts stored color depth codes into readable labels for status screens.
' Input: config value. Output: formatted color depth label. Side effects: none.
FUNCTION ColorDepthText(BYVAL valueText AS STRING) AS STRING
    SELECT CASE CleanUpper(valueText)
    CASE "4"
        ColorDepthText = "16 colors"
    CASE "8"
        ColorDepthText = "256 colors"
    CASE "16"
        ColorDepthText = "High color"
    CASE "32"
        ColorDepthText = "True color"
    CASE ELSE
        ColorDepthText = valueText
    END SELECT
END FUNCTION

' Reports the effective drag/resize mode from the two related shell config keys.
' Output: "Contents" or "Outline". Side effects: reads SYSTEM\SHELL.CFG.
FUNCTION CurrentDragText() AS STRING
    DIM showContents AS STRING
    DIM outlineDrag AS STRING

    showContents = ReadCfgValueSimple(CFG_SHELL, "showwindowcontentsdrag", "")
    outlineDrag = ReadCfgValueSimple(CFG_SHELL, "outlinewindowdrag", "1")

    IF TRIM$(showContents) <> "" THEN
        IF BoolText(showContents) = "1" THEN
            CurrentDragText = "Contents"
        ELSE
            CurrentDragText = "Outline"
        END IF
    ELSEIF BoolText(outlineDrag) = "1" THEN
        CurrentDragText = "Outline"
    ELSE
        CurrentDragText = "Contents"
    END IF
END FUNCTION

' Reports whether any configured sound event is currently enabled.
' Output: "On" when click, menu, error, startup, or shutdown sound is enabled. Side effects: reads SYSTEM\SOUND.CFG.
FUNCTION CurrentEventsText() AS STRING
    IF BoolText(ReadCfgValueSimple(CFG_SOUND, "click", "1")) = "1" THEN
        CurrentEventsText = "On"
        EXIT FUNCTION
    END IF
    IF BoolText(ReadCfgValueSimple(CFG_SOUND, "menu", "1")) = "1" THEN
        CurrentEventsText = "On"
        EXIT FUNCTION
    END IF
    IF BoolText(ReadCfgValueSimple(CFG_SOUND, "error", "1")) = "1" THEN
        CurrentEventsText = "On"
        EXIT FUNCTION
    END IF
    IF BoolText(ReadCfgValueSimple(CFG_SOUND, "startup", "0")) = "1" THEN
        CurrentEventsText = "On"
        EXIT FUNCTION
    END IF
    IF BoolText(ReadCfgValueSimple(CFG_SOUND, "shutdown", "0")) = "1" THEN
        CurrentEventsText = "On"
        EXIT FUNCTION
    END IF
    CurrentEventsText = "Off"
END FUNCTION

' Reports whether audio hardware detection is enabled for AdLib or Sound Blaster.
' Output: "On" when either detection flag is enabled. Side effects: reads SYSTEM\SOUND.CFG.
FUNCTION CurrentDetectText() AS STRING
    IF BoolText(ReadCfgValueSimple(CFG_SOUND, "adlib_detect", "1")) = "1" THEN
        CurrentDetectText = "On"
        EXIT FUNCTION
    END IF
    IF BoolText(ReadCfgValueSimple(CFG_SOUND, "sb_detect", "1")) = "1" THEN
        CurrentDetectText = "On"
        EXIT FUNCTION
    END IF
    CurrentDetectText = "Off"
END FUNCTION

' Reports whether a desktop wallpaper path is configured.
' Output: "On" when SYSTEM\THEME.CFG has a wallpaper value. Side effects: reads the theme config file.
FUNCTION CurrentWallpaperText() AS STRING
    IF TRIM$(ReadCfgValueSimple(CFG_THEME, "wallpaper", "")) <> "" THEN
        CurrentWallpaperText = "On"
    ELSE
        CurrentWallpaperText = "Off"
    END IF
END FUNCTION

' Reports whether startup splash wallpaper is configured.
' Output: "On" when SYSTEM\SPLASH.CFG has a wallpaper value. Side effects: reads the splash config file.
FUNCTION CurrentSplashText() AS STRING
    IF TRIM$(ReadCfgValueSimple(CFG_SPLASH, "wallpaper", "")) <> "" THEN
        CurrentSplashText = "On"
    ELSE
        CurrentSplashText = "Off"
    END IF
END FUNCTION

' Reports whether any titlebar or taskbar gradient flag is enabled.
' Output: "On" when a 16/high-color or 256-color gradient flag is enabled. Side effects: reads the theme config file.
FUNCTION CurrentGradText() AS STRING
    IF BoolText(ReadCfgValueSimple(CFG_THEME, "titlebar_gradient", "0")) = "1" THEN
        CurrentGradText = "On"
        EXIT FUNCTION
    END IF
    IF BoolText(ReadCfgValueSimple(CFG_THEME, "taskbar_gradient", "0")) = "1" THEN
        CurrentGradText = "On"
        EXIT FUNCTION
    END IF
    IF BoolText(ReadCfgValueSimple(CFG_THEME, "titlebar_gradient_8", "0")) = "1" THEN
        CurrentGradText = "On"
        EXIT FUNCTION
    END IF
    IF BoolText(ReadCfgValueSimple(CFG_THEME, "taskbar_gradient_8", "0")) = "1" THEN
        CurrentGradText = "On"
        EXIT FUNCTION
    END IF
    CurrentGradText = "Off"
END FUNCTION

' Pads or clips text to a fixed width for full-screen drawing.
' Inputs: source text and target width. Output: exactly wide characters. Side effects: none.
FUNCTION PadRight(BYVAL textIn AS STRING, BYVAL wide AS INTEGER) AS STRING
    IF wide <= 0 THEN
        PadRight = ""
    ELSEIF LEN(textIn) >= wide THEN
        PadRight = LEFT$(textIn, wide)
    ELSE
        PadRight = textIn + SPACE$(wide - LEN(textIn))
    END IF
END FUNCTION

' Produces a fixed-width value field for the menu grid.
' Inputs: value text and field width. Output: clipped or space-padded text. Side effects: none.
FUNCTION BoxText(BYVAL textIn AS STRING, BYVAL wide AS INTEGER) AS STRING
    IF LEN(textIn) > wide THEN textIn = LEFT$(textIn, wide)
    BoxText = textIn + SPACE$(wide - LEN(textIn))
END FUNCTION

' Maps a menu setting index to the label shown in the full-screen interface.
' Input: one-based setting index. Output: display label. Side effects: none.
FUNCTION SettingLabel(BYVAL idx AS INTEGER) AS STRING
    SELECT CASE idx
    CASE 1
        SettingLabel = "Display resolution"
    CASE 2
        SettingLabel = "Color depth"
    CASE 3
        SettingLabel = "Window drag/resize"
    CASE 4
        SettingLabel = "Audio"
    CASE 5
        SettingLabel = "Audio driver"
    CASE 6
        SettingLabel = "Audio events"
    CASE 7
        SettingLabel = "Audio detection"
    CASE 8
        SettingLabel = "Taskbar volume"
    CASE 9
        SettingLabel = "Screensaver"
    CASE 10
        SettingLabel = "Desktop wallpaper"
    CASE 11
        SettingLabel = "Startup splash"
    CASE 12
        SettingLabel = "Gradients"
    CASE 13
        SettingLabel = "Mouse trails"
    CASE 14
        SettingLabel = "Desktop icons"
    CASE 15
        SettingLabel = "Taskbar"
    CASE 16
        SettingLabel = "Clock"
    CASE ELSE
        SettingLabel = ""
    END SELECT
END FUNCTION

' Reads and formats the current value for one menu setting.
' Input: one-based setting index. Output: display value. Side effects: reads the related config file.
FUNCTION SettingValue(BYVAL idx AS INTEGER) AS STRING
    SELECT CASE idx
    CASE 1
        SettingValue = ResolutionText(ReadCfgValueSimple(CFG_DISPLAY, "resolution", "2"))
    CASE 2
        SettingValue = ColorDepthText(ReadCfgValueSimple(CFG_DISPLAY, "colordepth", "16"))
    CASE 3
        SettingValue = CurrentDragText()
    CASE 4
        SettingValue = OnOffText(ReadCfgValueSimple(CFG_SOUND, "enabled", "1"))
    CASE 5
        SettingValue = CleanUpper(ReadCfgValueSimple(CFG_SOUND, "driver", "PCSPKR"))
    CASE 6
        SettingValue = CurrentEventsText()
    CASE 7
        SettingValue = CurrentDetectText()
    CASE 8
        SettingValue = OnOffText(ReadCfgValueSimple(CFG_SOUND, "taskbar_volume", "1"))
    CASE 9
        SettingValue = OnOffText(ReadCfgValueSimple(CFG_SAVER, "enabled", "NO"))
    CASE 10
        SettingValue = CurrentWallpaperText()
    CASE 11
        SettingValue = CurrentSplashText()
    CASE 12
        SettingValue = CurrentGradText()
    CASE 13
        SettingValue = OnOffText(ReadCfgValueSimple(CFG_MOUSE, "traileffect", "0"))
    CASE 14
        SettingValue = OnOffText(ReadCfgValueSimple(CFG_DESKTOP, "showicons", "1"))
    CASE 15
        SettingValue = OnOffText(ReadCfgValueSimple(CFG_DESKTOP, "showtaskbar", "1"))
    CASE 16
        SettingValue = OnOffText(ReadCfgValueSimple(CFG_DESKTOP, "showclock", "1"))
    CASE ELSE
        SettingValue = ""
    END SELECT
END FUNCTION

' Provides the short performance explanation shown for the selected menu setting.
' Input: one-based setting index. Output: help text. Side effects: none.
FUNCTION SettingHelp(BYVAL idx AS INTEGER) AS STRING
    SELECT CASE idx
    CASE 1
        SettingHelp = "Lower resolution reduces drawing work. Values cycle 640x480, 800x600, 1024x768."
    CASE 2
        SettingHelp = "Lower color depth reduces bitmap and redraw cost."
    CASE 3
        SettingHelp = "Outline mode is faster than drawing full window contents while dragging/resizing."
    CASE 4
        SettingHelp = "Turns Backlash sound output on or off."
    CASE 5
        SettingHelp = "Selects the sound driver Backlash will use."
    CASE 6
        SettingHelp = "Turns click, menu, error, startup, and shutdown sound events on or off."
    CASE 7
        SettingHelp = "Turns AdLib and Sound Blaster detection on or off."
    CASE 8
        SettingHelp = "Shows or hides the taskbar volume control."
    CASE 9
        SettingHelp = "Disabling the screensaver removes idle saver startup work."
    CASE 10
        SettingHelp = "Disabling wallpaper reduces desktop redraw work."
    CASE 11
        SettingHelp = "Disabling splash wallpaper shortens startup drawing work."
    CASE 12
        SettingHelp = "Disabling gradients reduces titlebar and taskbar drawing work."
    CASE 13
        SettingHelp = "Disabling mouse trails reduces pointer redraw work."
    CASE 14
        SettingHelp = "Desktop icons add redraw and hit-test work."
    CASE 15
        SettingHelp = "Taskbar visibility setting."
    CASE 16
        SettingHelp = "Clock updates add periodic redraw work."
    CASE ELSE
        SettingHelp = ""
    END SELECT
END FUNCTION

' Returns the opposite ON/OFF command value for cycling toggle settings.
' Input: current boolean value. Output: ON or OFF. Side effects: none.
FUNCTION NextOnOff(BYVAL valueText AS STRING) AS STRING
    IF BoolText(valueText) = "1" THEN
        NextOnOff = "OFF"
    ELSE
        NextOnOff = "ON"
    END IF
END FUNCTION

' Advances to the next supported display resolution code used by the menu cycle action.
' Input: current resolution value. Output: next resolution code. Side effects: none.
FUNCTION NextResolution(BYVAL valueText AS STRING) AS STRING
    SELECT CASE CleanUpper(valueText)
    CASE "1", "640", "640X480"
        NextResolution = "2"
    CASE "2", "800", "800X600"
        NextResolution = "3"
    CASE ELSE
        NextResolution = "1"
    END SELECT
END FUNCTION

' Advances to the next color depth code used by the menu cycle action.
' Input: current depth value. Output: next depth code. Side effects: none.
FUNCTION NextDepth(BYVAL valueText AS STRING) AS STRING
    SELECT CASE CleanUpper(valueText)
    CASE "4"
        NextDepth = "8"
    CASE "8"
        NextDepth = "16"
    CASE "16"
        NextDepth = "32"
    CASE ELSE
        NextDepth = "4"
    END SELECT
END FUNCTION

' Advances to the next audio driver name used by the menu cycle action.
' Input: current driver name. Output: next driver name. Side effects: none.
FUNCTION NextDriver(BYVAL valueText AS STRING) AS STRING
    SELECT CASE CleanUpper(valueText)
    CASE "NONE"
        NextDriver = "PCSPKR"
    CASE "PCSPKR"
        NextDriver = "AUTO"
    CASE "AUTO"
        NextDriver = "ADLIB"
    CASE "ADLIB"
        NextDriver = "SBLASTER"
    CASE ELSE
        NextDriver = "NONE"
    END SELECT
END FUNCTION

' Converts a left mouse click into 80x25 text-screen row and column coordinates.
' Outputs: hit row and column. Return: nonzero when the left button is down. Side effects: reads current mouse state.
FUNCTION MouseHit(BYREF hitRow AS INTEGER, BYREF hitCol AS INTEGER) AS INTEGER
    DIM mx AS INTEGER
    DIM my AS INTEGER
    DIM mw AS INTEGER
    DIM mb AS INTEGER
    DIM resultCode AS INTEGER

    MouseHit = 0
    hitRow = 0
    hitCol = 0
    resultCode = GETMOUSE(mx, my, mw, mb)
    IF resultCode <> 0 THEN EXIT FUNCTION
    IF (mb AND 1) = 0 THEN EXIT FUNCTION

    IF mx >= 0 AND mx <= 79 AND my >= 0 AND my <= 24 THEN
        hitCol = mx + 1
        hitRow = my + 1
    ELSE
        hitCol = (mx \ 8) + 1
        hitRow = (my \ 16) + 1
    END IF

    MouseHit = -1
END FUNCTION

' Prints the command-line title used by help and status output.
' Side effects: writes to the console.
SUB PrintHeader()
    PRINT APP_NAME
    PRINT
END SUB

' Prints command-line syntax for every setting this utility can edit.
' Side effects: writes to the console only.
SUB PrintHelp()
    PrintHeader
    PRINT "Usage:"
    PRINT "  BSETUP                  full-screen setup interface"
    PRINT "  BSETUP STATUS           show current settings"
    PRINT "  BSETUP PROFILE FAST     apply low-overhead settings"
    PRINT "  BSETUP PROFILE NORMAL   apply normal settings"
    PRINT "  BSETUP RES 1|2|3        1=640x480, 2=800x600, 3=1024x768"
    PRINT "  BSETUP DEPTH 4|8|16|32  4=16 colors, 8=256, 16=high, 32=true"
    PRINT "  BSETUP DRAG OUTLINE     outline-only window dragging/resizing"
    PRINT "  BSETUP DRAG CONTENTS    show window contents while dragging/resizing"
    PRINT "  BSETUP AUDIO ON|OFF"
    PRINT "  BSETUP DRIVER NONE|PCSPKR|AUTO|ADLIB|SBLASTER"
    PRINT "  BSETUP EVENTS ON|OFF    click/menu/error/startup/shutdown sounds"
    PRINT "  BSETUP DETECT ON|OFF    AdLib/Sound Blaster hardware detection"
    PRINT "  BSETUP SAVER ON|OFF"
    PRINT "  BSETUP WALL OFF|ON      disables/restores desktop wallpaper backup"
    PRINT "  BSETUP SPLASH OFF|ON    disables/restores startup splash wallpaper backup"
    PRINT "  BSETUP GRAD ON|OFF      title/taskbar gradients"
    PRINT "  BSETUP TRAILS ON|OFF    mouse trails"
    PRINT "  BSETUP ICONS ON|OFF     desktop icons"
    PRINT "  BSETUP TASKBAR ON|OFF"
    PRINT "  BSETUP CLOCK ON|OFF"
    PRINT "  BSETUP TRAYVOL ON|OFF   taskbar volume control"
END SUB

' Prints current performance-related Backlash settings from the config files.
' Side effects: reads config files and writes a console report.
SUB PrintStatus()
    PrintHeader
    PRINT "Display resolution: "; ResolutionText(ReadCfgValueSimple(CFG_DISPLAY, "resolution", "2"))
    PRINT "Color depth:        "; ColorDepthText(ReadCfgValueSimple(CFG_DISPLAY, "colordepth", "16"))
    PRINT "Window drag/resize: "; CurrentDragText()
    PRINT "Desktop icons:      "; OnOffText(ReadCfgValueSimple(CFG_DESKTOP, "showicons", "1"))
    PRINT "Taskbar:            "; OnOffText(ReadCfgValueSimple(CFG_DESKTOP, "showtaskbar", "1"))
    PRINT "Clock:              "; OnOffText(ReadCfgValueSimple(CFG_DESKTOP, "showclock", "1"))
    PRINT "Mouse trails:       "; OnOffText(ReadCfgValueSimple(CFG_MOUSE, "traileffect", "0"))
    PRINT "Audio:              "; OnOffText(ReadCfgValueSimple(CFG_SOUND, "enabled", "1"))
    PRINT "Audio driver:       "; CleanUpper(ReadCfgValueSimple(CFG_SOUND, "driver", "PCSPKR"))
    PRINT "Audio events:       "; CurrentEventsText()
    PRINT "Audio detection:    "; CurrentDetectText()
    PRINT "Taskbar volume:     "; OnOffText(ReadCfgValueSimple(CFG_SOUND, "taskbar_volume", "1"))
    PRINT "Screensaver:        "; OnOffText(ReadCfgValueSimple(CFG_SAVER, "enabled", "NO")); "  Timeout="; ReadCfgValueSimple(CFG_SAVER, "timeout", "0"); " min"
    PRINT "Desktop wallpaper:  "; CurrentWallpaperText()
    PRINT "Startup splash:     "; CurrentSplashText()
    PRINT "Taskbar gradient:   "; OnOffText(ReadCfgValueSimple(CFG_THEME, "taskbar_gradient", "0"))
    PRINT "Titlebar gradient:  "; OnOffText(ReadCfgValueSimple(CFG_THEME, "titlebar_gradient", "0"))
END SUB

' Validates and stores the display resolution code in SYSTEM\DISPLAY.CFG.
' Input: resolution code or size text. Side effects: may rewrite DISPLAY.CFG and update gStatus.
SUB SetResolution(BYVAL valueText AS STRING)
    DIM workText AS STRING

    workText = CleanUpper(valueText)
    IF ValidResolution(workText) = 0 THEN
        gStatus = "Valid resolutions: 1=640x480, 2=800x600, 3=1024x768."
        EXIT SUB
    END IF

    SELECT CASE workText
    CASE "640", "640X480"
        workText = "1"
    CASE "800", "800X600"
        workText = "2"
    CASE "1024", "1024X768"
        workText = "3"
    END SELECT

    WriteCfgValueSimple CFG_DISPLAY, "RESOLUTION", workText
    gStatus = "Resolution set to " + ResolutionText(workText) + "."
END SUB

' Validates and stores the display color depth in SYSTEM\DISPLAY.CFG.
' Input: numeric or named depth. Side effects: may rewrite DISPLAY.CFG and update gStatus.
SUB SetColorDepth(BYVAL valueText AS STRING)
    DIM workText AS STRING

    workText = CleanUpper(valueText)
    IF ValidColorDepth(workText) = 0 THEN
        gStatus = "Valid color depths: 4, 8, 16, 32."
        EXIT SUB
    END IF

    SELECT CASE workText
    CASE "16COLOR", "16COLORS"
        workText = "4"
    CASE "256", "256COLOR", "256COLORS"
        workText = "8"
    CASE "HIGH", "HIGHCOLOR"
        workText = "16"
    CASE "TRUE", "TRUECOLOR"
        workText = "32"
    END SELECT

    WriteCfgValueSimple CFG_DISPLAY, "COLORDEPTH", workText
    gStatus = "Color depth set to " + ColorDepthText(workText) + "."
END SUB

' Stores the shell window drag/resize behavior using the config keys read by Backlash.
' Input: OUTLINE or CONTENTS. Side effects: rewrites drag keys in SYSTEM\SHELL.CFG and updates gStatus.
SUB SetDragMode(BYVAL valueText AS STRING)
    DIM workText AS STRING

    workText = CleanUpper(valueText)
    IF workText = "OUTLINE" OR workText = "0" THEN
        WriteCfgValueSimple CFG_SHELL, "SHOWWINDOWCONTENTSDRAG", "0"
        WriteCfgValueSimple CFG_SHELL, "OUTLINEWINDOWDRAG", "1"
        gStatus = "Window drag/resize set to outline."
    ELSEIF workText = "CONTENTS" OR workText = "CONTENT" OR workText = "1" THEN
        WriteCfgValueSimple CFG_SHELL, "SHOWWINDOWCONTENTSDRAG", "1"
        WriteCfgValueSimple CFG_SHELL, "OUTLINEWINDOWDRAG", "0"
        gStatus = "Window drag/resize set to show contents."
    ELSE
        gStatus = "Valid drag modes: OUTLINE or CONTENTS."
    END IF
END SUB

' Enables or disables Backlash sound output.
' Input: ON/OFF value. Side effects: rewrites ENABLED in SYSTEM\SOUND.CFG and updates gStatus.
SUB SetAudioEnabled(BYVAL valueText AS STRING)
    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid audio values: ON or OFF."
        EXIT SUB
    END IF

    WriteCfgValueSimple CFG_SOUND, "ENABLED", BoolText(valueText)
    gStatus = "Audio set to " + OnOffText(valueText) + "."
END SUB

' Stores the selected Backlash audio driver name.
' Input: supported driver name. Side effects: rewrites DRIVER in SYSTEM\SOUND.CFG and updates gStatus.
SUB SetAudioDriver(BYVAL valueText AS STRING)
    DIM workText AS STRING

    workText = CleanUpper(valueText)
    IF ValidDriver(workText) = 0 THEN
        gStatus = "Valid drivers: NONE, PCSPKR, AUTO, ADLIB, SBLASTER."
        EXIT SUB
    END IF

    WriteCfgValueSimple CFG_SOUND, "DRIVER", workText
    gStatus = "Audio driver set to " + workText + "."
END SUB

' Enables or disables all configured sound event triggers as a group.
' Input: ON/OFF value. Side effects: rewrites click, menu, error, startup, and shutdown keys in SYSTEM\SOUND.CFG.
SUB SetAudioEvents(BYVAL valueText AS STRING)
    DIM boolValue AS STRING

    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid event values: ON or OFF."
        EXIT SUB
    END IF

    boolValue = BoolText(valueText)
    WriteCfgValueSimple CFG_SOUND, "CLICK", boolValue
    WriteCfgValueSimple CFG_SOUND, "MENU", boolValue
    WriteCfgValueSimple CFG_SOUND, "ERROR", boolValue
    WriteCfgValueSimple CFG_SOUND, "STARTUP", boolValue
    WriteCfgValueSimple CFG_SOUND, "SHUTDOWN", boolValue
    gStatus = "Audio events set to " + OnOffText(valueText) + "."
END SUB

' Enables or disables audio hardware detection probes.
' Input: ON/OFF value. Side effects: rewrites ADLIB_DETECT and SB_DETECT in SYSTEM\SOUND.CFG.
SUB SetAudioDetect(BYVAL valueText AS STRING)
    DIM boolValue AS STRING

    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid detection values: ON or OFF."
        EXIT SUB
    END IF

    boolValue = BoolText(valueText)
    WriteCfgValueSimple CFG_SOUND, "ADLIB_DETECT", boolValue
    WriteCfgValueSimple CFG_SOUND, "SB_DETECT", boolValue
    gStatus = "Audio hardware detection set to " + OnOffText(valueText) + "."
END SUB

' Enables or disables the Backlash screensaver and adjusts timeout for the disabled state.
' Input: ON/OFF value. Side effects: rewrites SYSTEM\SCRNSAVR.CFG and updates gStatus.
SUB SetScreensaver(BYVAL valueText AS STRING)
    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid screensaver values: ON or OFF."
        EXIT SUB
    END IF

    IF BoolText(valueText) = "1" THEN
        WriteCfgValueSimple CFG_SAVER, "ENABLED", "YES"
        IF VAL(ReadCfgValueSimple(CFG_SAVER, "TIMEOUT", "0")) <= 0 THEN WriteCfgValueSimple CFG_SAVER, "TIMEOUT", "10"
    ELSE
        WriteCfgValueSimple CFG_SAVER, "ENABLED", "NO"
        WriteCfgValueSimple CFG_SAVER, "TIMEOUT", "0"
    END IF
    gStatus = "Screensaver set to " + OnOffText(valueText) + "."
END SUB

' Enables or disables desktop wallpaper while preserving the last wallpaper path in backup keys.
' Input: ON/OFF value. Side effects: rewrites wallpaper keys in SYSTEM\THEME.CFG and updates gStatus.
SUB SetWallpaper(BYVAL valueText AS STRING)
    DIM oldPath AS STRING
    DIM oldMode AS STRING
    DIM backupPath AS STRING
    DIM backupMode AS STRING

    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid wallpaper values: ON or OFF."
        EXIT SUB
    END IF

    IF BoolText(valueText) = "1" THEN
        backupPath = ReadCfgValueSimple(CFG_THEME, "BSETUP_WALLPAPER", "")
        backupMode = ReadCfgValueSimple(CFG_THEME, "BSETUP_WALLPAPER_MODE", "1")
        IF TRIM$(backupPath) = "" THEN
            gStatus = "No wallpaper backup exists. Use the Wallpaper app to choose one."
            EXIT SUB
        END IF
        IF VAL(backupMode) <= 0 THEN backupMode = "1"
        WriteCfgValueSimple CFG_THEME, "WALLPAPER", backupPath
        WriteCfgValueSimple CFG_THEME, "WALLPAPER_MODE", backupMode
        gStatus = "Desktop wallpaper restored."
    ELSE
        oldPath = ReadCfgValueSimple(CFG_THEME, "WALLPAPER", "")
        oldMode = ReadCfgValueSimple(CFG_THEME, "WALLPAPER_MODE", "1")
        StoreBackupValue CFG_THEME, "BSETUP_WALLPAPER", oldPath
        StoreBackupValue CFG_THEME, "BSETUP_WALLPAPER_MODE", oldMode
        WriteCfgValueSimple CFG_THEME, "WALLPAPER", ""
        WriteCfgValueSimple CFG_THEME, "WALLPAPER_MODE", "0"
        gStatus = "Desktop wallpaper disabled."
    END IF
END SUB

' Enables or disables startup splash wallpaper while preserving the last splash path in backup keys.
' Input: ON/OFF value. Side effects: rewrites wallpaper keys in SYSTEM\SPLASH.CFG and updates gStatus.
SUB SetSplash(BYVAL valueText AS STRING)
    DIM oldPath AS STRING
    DIM oldMode AS STRING
    DIM backupPath AS STRING
    DIM backupMode AS STRING

    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid splash values: ON or OFF."
        EXIT SUB
    END IF

    IF BoolText(valueText) = "1" THEN
        backupPath = ReadCfgValueSimple(CFG_SPLASH, "BSETUP_SPLASH_WALLPAPER", "")
        backupMode = ReadCfgValueSimple(CFG_SPLASH, "BSETUP_SPLASH_MODE", "fit")
        IF TRIM$(backupPath) = "" THEN backupPath = "SYSTEM\SPLASH.BMP"
        IF TRIM$(backupMode) = "" THEN backupMode = "fit"
        WriteCfgValueSimple CFG_SPLASH, "wallpaper", backupPath
        WriteCfgValueSimple CFG_SPLASH, "mode", backupMode
        gStatus = "Startup splash wallpaper restored."
    ELSE
        oldPath = ReadCfgValueSimple(CFG_SPLASH, "wallpaper", "")
        oldMode = ReadCfgValueSimple(CFG_SPLASH, "mode", "fit")
        StoreBackupValue CFG_SPLASH, "BSETUP_SPLASH_WALLPAPER", oldPath
        StoreBackupValue CFG_SPLASH, "BSETUP_SPLASH_MODE", oldMode
        WriteCfgValueSimple CFG_SPLASH, "wallpaper", ""
        gStatus = "Startup splash wallpaper disabled."
    END IF
END SUB

' Enables or disables titlebar and taskbar gradients for supported color-depth modes.
' Input: ON/OFF value. Side effects: rewrites gradient keys in SYSTEM\THEME.CFG and updates gStatus.
SUB SetGradients(BYVAL valueText AS STRING)
    DIM boolValue AS STRING

    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid gradient values: ON or OFF."
        EXIT SUB
    END IF

    boolValue = BoolText(valueText)
    WriteCfgValueSimple CFG_THEME, "TASKBAR_GRADIENT", boolValue
    WriteCfgValueSimple CFG_THEME, "TITLEBAR_GRADIENT", boolValue
    WriteCfgValueSimple CFG_THEME, "TASKBAR_GRADIENT_8", boolValue
    WriteCfgValueSimple CFG_THEME, "TITLEBAR_GRADIENT_8", boolValue
    gStatus = "Taskbar/titlebar gradients set to " + OnOffText(valueText) + "."
END SUB

' Enables or disables mouse trail drawing.
' Input: ON/OFF value. Side effects: rewrites TRAILEFFECT in SYSTEM\MOUSE.CFG and updates gStatus.
SUB SetMouseTrails(BYVAL valueText AS STRING)
    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid mouse trail values: ON or OFF."
        EXIT SUB
    END IF

    WriteCfgValueSimple CFG_MOUSE, "TRAILEFFECT", BoolText(valueText)
    gStatus = "Mouse trails set to " + OnOffText(valueText) + "."
END SUB

' Enables or disables desktop icon display.
' Input: ON/OFF value. Side effects: rewrites SHOWICONS in SYSTEM\DESKTOP.CFG and updates gStatus.
SUB SetDesktopIcons(BYVAL valueText AS STRING)
    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid icon values: ON or OFF."
        EXIT SUB
    END IF

    WriteCfgValueSimple CFG_DESKTOP, "SHOWICONS", BoolText(valueText)
    gStatus = "Desktop icons set to " + OnOffText(valueText) + "."
END SUB

' Enables or disables taskbar display.
' Input: ON/OFF value. Side effects: rewrites SHOWTASKBAR in SYSTEM\DESKTOP.CFG and updates gStatus.
SUB SetTaskbar(BYVAL valueText AS STRING)
    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid taskbar values: ON or OFF."
        EXIT SUB
    END IF

    WriteCfgValueSimple CFG_DESKTOP, "SHOWTASKBAR", BoolText(valueText)
    gStatus = "Taskbar set to " + OnOffText(valueText) + "."
END SUB

' Enables or disables the taskbar clock.
' Input: ON/OFF value. Side effects: rewrites SHOWCLOCK in SYSTEM\DESKTOP.CFG and updates gStatus.
SUB SetClock(BYVAL valueText AS STRING)
    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid clock values: ON or OFF."
        EXIT SUB
    END IF

    WriteCfgValueSimple CFG_DESKTOP, "SHOWCLOCK", BoolText(valueText)
    gStatus = "Clock set to " + OnOffText(valueText) + "."
END SUB

' Enables or disables the taskbar volume control flag.
' Input: ON/OFF value. Side effects: rewrites TASKBAR_VOLUME in SYSTEM\SOUND.CFG and updates gStatus.
SUB SetTaskbarVolume(BYVAL valueText AS STRING)
    IF ValidOnOff(valueText) = 0 THEN
        gStatus = "Valid taskbar volume values: ON or OFF."
        EXIT SUB
    END IF

    WriteCfgValueSimple CFG_SOUND, "TASKBAR_VOLUME", BoolText(valueText)
    gStatus = "Taskbar volume control set to " + OnOffText(valueText) + "."
END SUB

' Applies a grouped performance profile by calling the same setter routines used by direct commands.
' Input: FAST or NORMAL. Side effects: rewrites several config files and updates gStatus.
SUB ApplyProfile(BYVAL profileName AS STRING)
    DIM workText AS STRING

    workText = CleanUpper(profileName)
    IF workText = "FAST" THEN
        SetResolution "1"
        SetColorDepth "4"
        SetDragMode "OUTLINE"
        SetAudioEnabled "OFF"
        SetAudioEvents "OFF"
        SetAudioDetect "OFF"
        SetScreensaver "OFF"
        SetWallpaper "OFF"
        SetSplash "OFF"
        SetGradients "OFF"
        SetMouseTrails "OFF"
        SetClock "OFF"
        SetTaskbarVolume "OFF"
        gStatus = "FAST profile applied."
    ELSEIF workText = "NORMAL" THEN
        SetResolution "2"
        SetColorDepth "16"
        SetDragMode "OUTLINE"
        SetAudioEnabled "ON"
        SetAudioEvents "ON"
        SetAudioDetect "ON"
        SetScreensaver "ON"
        SetWallpaper "ON"
        SetSplash "ON"
        SetGradients "ON"
        SetMouseTrails "OFF"
        SetClock "ON"
        SetTaskbarVolume "ON"
        gStatus = "NORMAL profile applied."
    ELSE
        gStatus = "Valid profiles: FAST or NORMAL."
    END IF
END SUB

' Handles Enter/click changes from the full-screen menu by cycling the selected setting.
' Input: one-based setting index. Side effects: calls the matching setter and updates config files as needed.
SUB CycleSetting(BYVAL idx AS INTEGER)
    SELECT CASE idx
    CASE 1
        SetResolution NextResolution(ReadCfgValueSimple(CFG_DISPLAY, "resolution", "2"))
    CASE 2
        SetColorDepth NextDepth(ReadCfgValueSimple(CFG_DISPLAY, "colordepth", "16"))
    CASE 3
        IF CurrentDragText() = "Outline" THEN
            SetDragMode "CONTENTS"
        ELSE
            SetDragMode "OUTLINE"
        END IF
    CASE 4
        SetAudioEnabled NextOnOff(ReadCfgValueSimple(CFG_SOUND, "enabled", "1"))
    CASE 5
        SetAudioDriver NextDriver(ReadCfgValueSimple(CFG_SOUND, "driver", "PCSPKR"))
    CASE 6
        SetAudioEvents NextOnOff(CurrentEventsText())
    CASE 7
        SetAudioDetect NextOnOff(CurrentDetectText())
    CASE 8
        SetTaskbarVolume NextOnOff(ReadCfgValueSimple(CFG_SOUND, "taskbar_volume", "1"))
    CASE 9
        SetScreensaver NextOnOff(ReadCfgValueSimple(CFG_SAVER, "enabled", "NO"))
    CASE 10
        SetWallpaper NextOnOff(CurrentWallpaperText())
    CASE 11
        SetSplash NextOnOff(CurrentSplashText())
    CASE 12
        SetGradients NextOnOff(CurrentGradText())
    CASE 13
        SetMouseTrails NextOnOff(ReadCfgValueSimple(CFG_MOUSE, "traileffect", "0"))
    CASE 14
        SetDesktopIcons NextOnOff(ReadCfgValueSimple(CFG_DESKTOP, "showicons", "1"))
    CASE 15
        SetTaskbar NextOnOff(ReadCfgValueSimple(CFG_DESKTOP, "showtaskbar", "1"))
    CASE 16
        SetClock NextOnOff(ReadCfgValueSimple(CFG_DESKTOP, "showclock", "1"))
    END SELECT
END SUB

' Draws one text run at a fixed 80x25 console position.
' Inputs: row, column, text, foreground color, background color. Side effects: changes console color and cursor position.
SUB DrawText(BYVAL rowNum AS INTEGER, BYVAL colNum AS INTEGER, BYVAL textIn AS STRING, BYVAL foreColor AS INTEGER, BYVAL backColor AS INTEGER)
    COLOR foreColor, backColor
    LOCATE rowNum, colNum
    PRINT textIn;
END SUB

' Draws a single-line DOS text box around a screen region.
' Inputs: bounds, optional title, colors. Side effects: writes box characters to the console.
SUB DrawBox(BYVAL row1 AS INTEGER, BYVAL col1 AS INTEGER, BYVAL row2 AS INTEGER, BYVAL col2 AS INTEGER, BYVAL titleText AS STRING, BYVAL foreColor AS INTEGER, BYVAL backColor AS INTEGER)
    DIM i AS INTEGER
    DIM lineWide AS INTEGER

    lineWide = col2 - col1 - 1
    COLOR foreColor, backColor
    LOCATE row1, col1
    PRINT CHR$(218); STRING$(lineWide, CHR$(196)); CHR$(191);
    FOR i = row1 + 1 TO row2 - 1
        LOCATE i, col1
        PRINT CHR$(179); SPACE$(lineWide); CHR$(179);
    NEXT i
    LOCATE row2, col1
    PRINT CHR$(192); STRING$(lineWide, CHR$(196)); CHR$(217);
    IF TRIM$(titleText) <> "" THEN
        LOCATE row1, col1 + 2
        PRINT " "; titleText; " ";
    END IF
END SUB

' Draws a centered bracket-style action button in the full-screen interface.
' Inputs: row, column bounds, label, selected flag. Side effects: writes to the console.
SUB DrawButton(BYVAL rowNum AS INTEGER, BYVAL col1 AS INTEGER, BYVAL col2 AS INTEGER, BYVAL textIn AS STRING, BYVAL selectedFlag AS INTEGER)
    DIM wide AS INTEGER
    DIM labelText AS STRING
    DIM padLeft AS INTEGER

    wide = col2 - col1 + 1
    labelText = "[ " + textIn + " ]"
    IF LEN(labelText) > wide THEN labelText = LEFT$(labelText, wide)
    padLeft = (wide - LEN(labelText)) \ 2
    IF selectedFlag <> 0 THEN
        COLOR 0, 7
    ELSE
        COLOR 15, 1
    END IF
    LOCATE rowNum, col1
    PRINT SPACE$(wide);
    LOCATE rowNum, col1 + padLeft
    PRINT labelText;
END SUB

' Redraws the full-screen setup interface from the current config values and selected row.
' Side effects: clears the screen, reads config files for displayed values, and writes the full menu.
SUB DrawSetupScreen()
    DIM i AS INTEGER
    DIM rowNum AS INTEGER
    DIM colNum AS INTEGER
    DIM valCol AS INTEGER
    DIM labelText AS STRING
    DIM valueText AS STRING
    DIM leftMark AS STRING
    DIM helpText AS STRING

    COLOR 7, 1
    CLS
    DrawBox 1, 1, 25, 80, " Backlash Setup Utility ", 15, 1
    DrawText 3, 4, PadRight("Arrows select. Enter/click value changes setting. F=FAST N=NORMAL S=STATUS H=HELP", 72), 7, 1

    DrawBox 5, 3, 16, 78, " Performance Settings ", 15, 1
    DrawText 6, 6, "Setting", 14, 1
    DrawText 6, 28, "Value", 14, 1
    DrawText 6, 43, "Setting", 14, 1
    DrawText 6, 65, "Value", 14, 1
    DrawText 7, 5, STRING$(70, CHR$(196)), 8, 1

    FOR i = 1 TO SETTING_COUNT
        IF i <= 8 THEN
            rowNum = 7 + i
            colNum = 5
            valCol = 27
        ELSE
            rowNum = 7 + (i - 8)
            colNum = 42
            valCol = 64
        END IF

        labelText = SettingLabel(i)
        valueText = SettingValue(i)
        leftMark = " "

        IF i = gSelected THEN
            leftMark = CHR$(16)
            DrawText rowNum, colNum, PadRight(leftMark + " " + labelText, 21), 0, 7
            DrawText rowNum, valCol, " " + BoxText(valueText, 10) + " ", 0, 7
        ELSE
            DrawText rowNum, colNum, PadRight("  " + labelText, 21), 15, 1
            DrawText rowNum, valCol, " " + BoxText(valueText, 10) + " ", 0, 3
        END IF
    NEXT i

    DrawBox 17, 3, 21, 78, " Selected Setting ", 15, 1
    DrawText 18, 6, PadRight(SettingLabel(gSelected) + ": " + SettingValue(gSelected), 68), 14, 1
    IF TRIM$(gStatus) = "" THEN
        helpText = SettingHelp(gSelected)
    ELSE
        helpText = gStatus
    END IF
    DrawText 19, 6, PadRight(LEFT$(helpText, 68), 68), 10, 1
    IF LEN(helpText) > 68 THEN
        DrawText 20, 6, PadRight(MID$(helpText, 69, 68), 68), 10, 1
    ELSE
        DrawText 20, 6, SPACE$(68), 10, 1
    END IF

    DrawBox 22, 3, 24, 78, " Actions ", 15, 1
    DrawButton 23, 6, 17, "FAST", 0
    DrawButton 23, 20, 33, "NORMAL", 0
    DrawButton 23, 36, 49, "STATUS", 0
    DrawButton 23, 52, 64, "HELP", 0
    DrawButton 23, 67, 75, "EXIT", 0
END SUB

' Waits for the left mouse button to be released before accepting another click.
' Side effects: polls mouse state and sleeps briefly between checks.
SUB WaitMouseRelease()
    DIM mx AS INTEGER
    DIM my AS INTEGER
    DIM mw AS INTEGER
    DIM mb AS INTEGER
    DIM resultCode AS INTEGER

    DO
        resultCode = GETMOUSE(mx, my, mw, mb)
        IF resultCode <> 0 THEN EXIT DO
        IF (mb AND 1) = 0 THEN EXIT DO
        SLEEP 25
    LOOP
END SUB

' Runs the keyboard and mouse driven full-screen setup menu.
' Side effects: changes text mode to 80x25, reads keys/mouse clicks, calls setters, and clears the screen on exit.
SUB InteractiveMenu()
    DIM keyText AS STRING
    DIM hitRow AS INTEGER
    DIM hitCol AS INTEGER
    DIM idx AS INTEGER
    DIM quitFlag AS INTEGER

    WIDTH 80, 25
    gSelected = 1
    gStatus = "Click a value box or press ENTER to change the selected setting."
    quitFlag = 0

    DO
        DrawSetupScreen
        DO
            keyText = INKEY$
            IF keyText <> "" THEN EXIT DO
            IF MouseHit(hitRow, hitCol) <> 0 THEN EXIT DO
            SLEEP 20
        LOOP

        IF keyText <> "" THEN
            IF LEN(keyText) = 1 THEN
                SELECT CASE ASC(keyText)
                CASE 13
                    CycleSetting gSelected
                CASE 27
                    quitFlag = -1
                CASE ELSE
                    SELECT CASE CleanUpper(keyText)
                    CASE "F"
                        ApplyProfile "FAST"
                    CASE "N"
                        ApplyProfile "NORMAL"
                    CASE "S"
                        CLS
                        PrintStatus
                        PRINT
                        PRINT "Press any key to return."
                        SLEEP
                    CASE "H", "?"
                        CLS
                        PrintHelp
                        PRINT
                        PRINT "Press any key to return."
                        SLEEP
                    CASE "Q", "X"
                        quitFlag = -1
                    END SELECT
                END SELECT
            ELSEIF LEN(keyText) >= 2 THEN
                SELECT CASE ASC(RIGHT$(keyText, 1))
                CASE 72
                    gSelected = gSelected - 1
                    IF gSelected < 1 THEN gSelected = SETTING_COUNT
                    gStatus = ""
                CASE 80
                    gSelected = gSelected + 1
                    IF gSelected > SETTING_COUNT THEN gSelected = 1
                    gStatus = ""
                CASE 75
                    IF gSelected > 8 THEN gSelected = gSelected - 8
                    gStatus = ""
                CASE 77
                    IF gSelected <= 8 THEN gSelected = gSelected + 8
                    IF gSelected > SETTING_COUNT THEN gSelected = SETTING_COUNT
                    gStatus = ""
                CASE 73
                    gSelected = gSelected - 8
                    IF gSelected < 1 THEN gSelected = 1
                    gStatus = ""
                CASE 81
                    gSelected = gSelected + 8
                    IF gSelected > SETTING_COUNT THEN gSelected = SETTING_COUNT
                    gStatus = ""
                END SELECT
            END IF
        ELSE
            WaitMouseRelease
            IF hitRow >= 8 AND hitRow <= 15 THEN
                IF hitCol >= 5 AND hitCol <= 38 THEN
                    idx = hitRow - 7
                    IF idx >= 1 AND idx <= 8 THEN
                        gSelected = idx
                        IF hitCol >= 27 AND hitCol <= 38 THEN
                            CycleSetting gSelected
                        ELSE
                            gStatus = ""
                        END IF
                    END IF
                ELSEIF hitCol >= 42 AND hitCol <= 75 THEN
                    idx = hitRow - 7 + 8
                    IF idx >= 9 AND idx <= SETTING_COUNT THEN
                        gSelected = idx
                        IF hitCol >= 64 AND hitCol <= 75 THEN
                            CycleSetting gSelected
                        ELSE
                            gStatus = ""
                        END IF
                    END IF
                END IF
            END IF
            IF hitRow = 23 THEN
                IF hitCol >= 6 AND hitCol <= 17 THEN ApplyProfile "FAST"
                IF hitCol >= 20 AND hitCol <= 33 THEN ApplyProfile "NORMAL"
                IF hitCol >= 36 AND hitCol <= 49 THEN
                    CLS
                    PrintStatus
                    PRINT
                    PRINT "Press any key to return."
                    SLEEP
                END IF
                IF hitCol >= 52 AND hitCol <= 64 THEN
                    CLS
                    PrintHelp
                    PRINT
                    PRINT "Press any key to return."
                    SLEEP
                END IF
                IF hitCol >= 67 AND hitCol <= 75 THEN quitFlag = -1
            END IF
        END IF
    LOOP UNTIL quitFlag <> 0

    COLOR 7, 0
    CLS
END SUB

' Dispatches command-line arguments to status output, profiles, or individual setting setters.
' Side effects: may print help/status or rewrite config files depending on the command.
SUB HandleCommandLine()
    DIM arg1 AS STRING
    DIM arg2 AS STRING

    arg1 = CleanUpper(COMMAND(1))
    arg2 = CleanUpper(COMMAND(2))

    IF arg1 = "" THEN
        InteractiveMenu
        EXIT SUB
    END IF

    SELECT CASE arg1
    CASE "?", "/?", "HELP", "-H", "--HELP"
        PrintHelp
    CASE "STATUS"
        PrintStatus
    CASE "PROFILE"
        ApplyProfile arg2
        PRINT gStatus
    CASE "FAST"
        ApplyProfile "FAST"
        PRINT gStatus
    CASE "NORMAL"
        ApplyProfile "NORMAL"
        PRINT gStatus
    CASE "RES", "RESOLUTION"
        SetResolution arg2
        PRINT gStatus
    CASE "DEPTH", "COLOR", "COLORDEPTH"
        SetColorDepth arg2
        PRINT gStatus
    CASE "DRAG"
        SetDragMode arg2
        PRINT gStatus
    CASE "AUDIO", "SOUND"
        SetAudioEnabled arg2
        PRINT gStatus
    CASE "DRIVER"
        SetAudioDriver arg2
        PRINT gStatus
    CASE "EVENTS"
        SetAudioEvents arg2
        PRINT gStatus
    CASE "DETECT"
        SetAudioDetect arg2
        PRINT gStatus
    CASE "SAVER", "SCREENSAVER"
        SetScreensaver arg2
        PRINT gStatus
    CASE "WALL", "WALLPAPER"
        SetWallpaper arg2
        PRINT gStatus
    CASE "SPLASH"
        SetSplash arg2
        PRINT gStatus
    CASE "GRAD", "GRADIENT", "GRADIENTS"
        SetGradients arg2
        PRINT gStatus
    CASE "TRAILS", "MOUSETRAILS"
        SetMouseTrails arg2
        PRINT gStatus
    CASE "ICONS"
        SetDesktopIcons arg2
        PRINT gStatus
    CASE "TASKBAR"
        SetTaskbar arg2
        PRINT gStatus
    CASE "CLOCK"
        SetClock arg2
        PRINT gStatus
    CASE "TRAYVOL", "VOLUMEICON"
        SetTaskbarVolume arg2
        PRINT gStatus
    CASE ELSE
        PrintHelp
    END SELECT
END SUB

' Program entry point: find the Backlash config root before accepting commands or opening the menu.
gRoot = DetectBacklashRoot()
IF CandidateHasBacklashCfg(gRoot) = 0 THEN
    PRINT APP_NAME
    PRINT "Could not find Backlash SYSTEM config files."
    PRINT "Run BSETUP from the Backlash root directory or from an app subdirectory."
    END 1
END IF

' After setup completes, report whether any config file was changed so the user knows when restart/apply is needed.
gChanged = 0
gStatus = ""
HandleCommandLine

IF gChanged <> 0 THEN
    PRINT
    PRINT "Settings updated. Restart Backlash or use the matching app Apply button where required."
END IF
