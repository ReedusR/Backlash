' STARFLD.BAS
' Backlash starfield screensaver
' Compile from APPS\SCRNSAVR\SAVERS:
' fbc -lang fb STARFLD.BAS
'
' BACKLASH_SCREENSAVER
' NAME=Starfield
' PROGRAM=STARFLD.EXE
' CONFIG=STARFLD.CFG
' SETTING=STAR_COUNT|Number of stars|INTEGER|20|300|140
' SETTING=SPEED|Speed|INTEGER|1|10|5
' END_BACKLASH_SCREENSAVER

CONST MAX_STARS AS INTEGER = 300
CONST Z_NEAR AS INTEGER = 18
CONST Z_FAR AS INTEGER = 260
CONST WORLD_X AS INTEGER = 1400
CONST WORLD_Y AS INTEGER = 1050

TYPE StarRec
    x AS INTEGER
    y AS INTEGER
    z AS INTEGER
    speed AS INTEGER
END TYPE

DIM SHARED stars(1 TO MAX_STARS) AS StarRec
DIM SHARED scrW AS INTEGER
DIM SHARED scrH AS INTEGER
DIM SHARED scrDepth AS INTEGER
DIM SHARED centerX AS INTEGER
DIM SHARED centerY AS INTEGER
DIM SHARED focal AS INTEGER
DIM SHARED lowColorMode AS INTEGER
DIM SHARED cfgFile AS STRING
DIM SHARED saverCfgFile AS STRING
DIM SHARED activeStars AS INTEGER
DIM SHARED speedSetting AS INTEGER

DECLARE FUNCTION FileExists(BYVAL fileName AS STRING) AS INTEGER
DECLARE FUNCTION FindDisplayCfg() AS STRING
DECLARE FUNCTION FindSaverCfg() AS STRING
DECLARE FUNCTION ReadCfgValue(BYVAL fileName AS STRING, BYVAL keyName AS STRING, BYVAL defaultValue AS STRING) AS STRING
DECLARE FUNCTION CleanNumber(BYVAL src AS STRING, BYVAL fallback AS INTEGER) AS INTEGER
DECLARE FUNCTION ClampInteger(BYVAL n AS INTEGER, BYVAL lowLimit AS INTEGER, BYVAL highLimit AS INTEGER) AS INTEGER
DECLARE SUB LoadSaverSettings()
DECLARE SUB PickMode()
DECLARE FUNCTION SetBestScreenMode() AS INTEGER
DECLARE SUB ResetStar(BYVAL idx AS INTEGER)
DECLARE FUNCTION ProjectX(BYVAL sx AS INTEGER, BYVAL sz AS INTEGER) AS INTEGER
DECLARE FUNCTION ProjectY(BYVAL sy AS INTEGER, BYVAL sz AS INTEGER) AS INTEGER
DECLARE FUNCTION StarColor(BYVAL z AS INTEGER, BYVAL seed AS INTEGER) AS UINTEGER
DECLARE FUNCTION StarSize(BYVAL seed AS INTEGER) AS INTEGER
DECLARE SUB DrawStar(BYVAL x1 AS INTEGER, BYVAL y1 AS INTEGER, BYVAL x2 AS INTEGER, BYVAL y2 AS INTEGER, BYVAL z AS INTEGER, BYVAL seed AS INTEGER)
DECLARE FUNCTION ShouldExitSaver(BYVAL startTime AS DOUBLE, BYREF baseMouseSet AS INTEGER, BYREF baseMx AS INTEGER, BYREF baseMy AS INTEGER) AS INTEGER

' ---------------------------
' Config discovery and display mode setup
' ---------------------------

FUNCTION FileExists(BYVAL fileName AS STRING) AS INTEGER
    DIM f AS INTEGER

    f = FREEFILE
    IF OPEN(fileName FOR INPUT AS #f) = 0 THEN
        CLOSE #f
        RETURN -1
    END IF

    RETURN 0
END FUNCTION

FUNCTION FindDisplayCfg() AS STRING
    IF FileExists("SYSTEM\DISPLAY.CFG") <> 0 THEN RETURN "SYSTEM\DISPLAY.CFG"
    IF FileExists("\SYSTEM\DISPLAY.CFG") <> 0 THEN RETURN "\SYSTEM\DISPLAY.CFG"
    IF FileExists("..\..\SYSTEM\DISPLAY.CFG") <> 0 THEN RETURN "..\..\SYSTEM\DISPLAY.CFG"
    RETURN "SYSTEM\DISPLAY.CFG"
END FUNCTION

FUNCTION FindSaverCfg() AS STRING
    RETURN "STARFLD.CFG"
END FUNCTION

FUNCTION ReadCfgValue(BYVAL fileName AS STRING, BYVAL keyName AS STRING, BYVAL defaultValue AS STRING) AS STRING
    DIM f AS INTEGER
    DIM lineIn AS STRING
    DIM p AS INTEGER
    DIM k AS STRING
    DIM v AS STRING

    f = FREEFILE
    IF OPEN(fileName FOR INPUT AS #f) <> 0 THEN RETURN defaultValue

    DO WHILE NOT EOF(f)
        LINE INPUT #f, lineIn
        lineIn = TRIM$(lineIn)

        IF lineIn <> "" THEN
            IF LEFT$(lineIn, 1) <> "#" AND LEFT$(lineIn, 1) <> ";" THEN
                p = INSTR(lineIn, "=")
                IF p > 0 THEN
                    k = UCASE$(TRIM$(LEFT$(lineIn, p - 1)))
                    v = TRIM$(MID$(lineIn, p + 1))

                    IF LEN(v) >= 2 THEN
                        IF LEFT$(v, 1) = CHR$(34) AND RIGHT$(v, 1) = CHR$(34) THEN
                            v = MID$(v, 2, LEN(v) - 2)
                        END IF
                    END IF

                    IF k = UCASE$(keyName) THEN
                        CLOSE #f
                        RETURN v
                    END IF
                END IF
            END IF
        END IF
    LOOP

    CLOSE #f
    RETURN defaultValue
END FUNCTION

FUNCTION CleanNumber(BYVAL src AS STRING, BYVAL fallback AS INTEGER) AS INTEGER
    DIM i AS INTEGER
    DIM ch AS STRING
    DIM digits AS STRING

    digits = ""
    src = TRIM$(src)

    FOR i = 1 TO LEN(src)
        ch = MID$(src, i, 1)
        IF ch >= "0" AND ch <= "9" THEN
            digits = digits + ch
        ELSEIF digits <> "" THEN
            EXIT FOR
        END IF
    NEXT i

    IF digits = "" THEN RETURN fallback
    RETURN CINT(VAL(digits))
END FUNCTION

FUNCTION ClampInteger(BYVAL n AS INTEGER, BYVAL lowLimit AS INTEGER, BYVAL highLimit AS INTEGER) AS INTEGER
    IF n < lowLimit THEN RETURN lowLimit
    IF n > highLimit THEN RETURN highLimit
    RETURN n
END FUNCTION

SUB LoadSaverSettings()
    saverCfgFile = FindSaverCfg()
    activeStars = ClampInteger(CleanNumber(ReadCfgValue(saverCfgFile, "STAR_COUNT", "140"), 140), 20, MAX_STARS)
    speedSetting = ClampInteger(CleanNumber(ReadCfgValue(saverCfgFile, "SPEED", "5"), 5), 1, 10)
END SUB

SUB PickMode()
    DIM modeText AS STRING
    DIM depthText AS STRING
    DIM modeVal AS INTEGER

    cfgFile = FindDisplayCfg()

    modeText = ReadCfgValue(cfgFile, "resolution", "")
    IF modeText = "" THEN modeText = ReadCfgValue(cfgFile, "mode", "")

    modeVal = CleanNumber(modeText, 2)

    SELECT CASE modeVal
        CASE 1
            scrW = 640
            scrH = 480
        CASE 2
            scrW = 800
            scrH = 600
        CASE 3
            scrW = 1024
            scrH = 768
        CASE 640
            scrW = 640
            scrH = 480
        CASE 800
            scrW = 800
            scrH = 600
        CASE 1024
            scrW = 1024
            scrH = 768
        CASE ELSE
            scrW = 800
            scrH = 600
    END SELECT

    depthText = ReadCfgValue(cfgFile, "colordepth", "")
    IF depthText = "" THEN depthText = ReadCfgValue(cfgFile, "color_depth", "")
    IF depthText = "" THEN depthText = ReadCfgValue(cfgFile, "colors", "")

    scrDepth = CleanNumber(depthText, 8)

    SELECT CASE scrDepth
        CASE 4, 8, 15, 16, 24, 32
        CASE 256
            scrDepth = 8
        CASE ELSE
            scrDepth = 8
    END SELECT

    centerX = scrW \ 2
    centerY = scrH \ 2
    focal = scrW \ 2
END SUB

FUNCTION SetBestScreenMode() AS INTEGER
    lowColorMode = 0

    IF SCREENRES(scrW, scrH, scrDepth, 1) = 0 THEN
        IF scrDepth <= 8 THEN lowColorMode = -1
        RETURN -1
    END IF

    scrW = 640
    scrH = 480
    scrDepth = 8
    centerX = scrW \ 2
    centerY = scrH \ 2
    focal = scrW \ 2
    lowColorMode = -1

    IF SCREENRES(scrW, scrH, scrDepth, 1) = 0 THEN RETURN -1

    scrW = 320
    scrH = 200
    scrDepth = 8
    centerX = scrW \ 2
    centerY = scrH \ 2
    focal = scrW \ 2
    lowColorMode = -1

    SCREEN 13
    RETURN -1
END FUNCTION

' ---------------------------
' Star field state, projection, and drawing
' ---------------------------

SUB ResetStar(BYVAL idx AS INTEGER)
    stars(idx).x = CINT(RND * (WORLD_X * 2)) - WORLD_X
    stars(idx).y = CINT(RND * (WORLD_Y * 2)) - WORLD_Y
    stars(idx).z = Z_NEAR + CINT(RND * (Z_FAR - Z_NEAR))
    stars(idx).speed = 1 + (speedSetting \ 2) + CINT(RND * speedSetting)
END SUB

FUNCTION ProjectX(BYVAL sx AS INTEGER, BYVAL sz AS INTEGER) AS INTEGER
    IF sz <= 0 THEN RETURN -32768
    RETURN centerX + CINT((CLNG(sx) * CLNG(focal)) \ sz)
END FUNCTION

FUNCTION ProjectY(BYVAL sy AS INTEGER, BYVAL sz AS INTEGER) AS INTEGER
    IF sz <= 0 THEN RETURN -32768
    RETURN centerY + CINT((CLNG(sy) * CLNG(focal)) \ sz)
END FUNCTION

FUNCTION StarColor(BYVAL z AS INTEGER, BYVAL seed AS INTEGER) AS UINTEGER
    DIM colorPick AS INTEGER

    colorPick = ABS(seed) MOD 4

    IF lowColorMode <> 0 THEN
        SELECT CASE colorPick
            CASE 1
                RETURN 12
            CASE 2
                RETURN 14
            CASE 3
                RETURN 9
        END SELECT

        IF z < 55 THEN RETURN 15
        IF z < 120 THEN RETURN 7
        RETURN 8
    END IF

    SELECT CASE colorPick
        CASE 1
            IF z < 55 THEN RETURN RGB(255, 64, 64)
            IF z < 120 THEN RETURN RGB(180, 32, 32)
            RETURN RGB(95, 16, 16)
        CASE 2
            IF z < 55 THEN RETURN RGB(255, 255, 64)
            IF z < 120 THEN RETURN RGB(180, 180, 32)
            RETURN RGB(95, 95, 16)
        CASE 3
            IF z < 55 THEN RETURN RGB(64, 128, 255)
            IF z < 120 THEN RETURN RGB(32, 80, 180)
            RETURN RGB(16, 40, 95)
    END SELECT

    IF z < 55 THEN RETURN RGB(255, 255, 255)
    IF z < 120 THEN RETURN RGB(180, 180, 180)
    RETURN RGB(95, 95, 95)
END FUNCTION

FUNCTION StarSize(BYVAL seed AS INTEGER) AS INTEGER
    RETURN 1 + (ABS(seed) MOD 4)
END FUNCTION

SUB DrawStar(BYVAL x1 AS INTEGER, BYVAL y1 AS INTEGER, BYVAL x2 AS INTEGER, BYVAL y2 AS INTEGER, BYVAL z AS INTEGER, BYVAL seed AS INTEGER)
    DIM c AS UINTEGER
    DIM s AS INTEGER
    DIM leftX AS INTEGER
    DIM topY AS INTEGER
    DIM rightX AS INTEGER
    DIM bottomY AS INTEGER

    IF x2 < 0 OR x2 >= scrW THEN EXIT SUB
    IF y2 < 0 OR y2 >= scrH THEN EXIT SUB

    IF x1 < 0 OR x1 >= scrW OR y1 < 0 OR y1 >= scrH THEN
        x1 = x2
        y1 = y2
    END IF

    c = StarColor(z, seed)
    s = StarSize(seed)

    LINE (x1, y1)-(x2, y2), c

    IF s > 1 THEN
        leftX = x2 - (s \ 2)
        topY = y2 - (s \ 2)
        rightX = leftX + s - 1
        bottomY = topY + s - 1

        IF leftX < 0 THEN leftX = 0
        IF topY < 0 THEN topY = 0
        IF rightX >= scrW THEN rightX = scrW - 1
        IF bottomY >= scrH THEN bottomY = scrH - 1

        LINE (leftX, topY)-(rightX, bottomY), c, BF
    END IF
END SUB

' ---------------------------
' Saver exit checks
' ---------------------------

FUNCTION ShouldExitSaver(BYVAL startTime AS DOUBLE, BYREF baseMouseSet AS INTEGER, BYREF baseMx AS INTEGER, BYREF baseMy AS INTEGER) AS INTEGER
    DIM k AS STRING
    DIM mx AS INTEGER
    DIM my AS INTEGER
    DIM mw AS INTEGER
    DIM mb AS INTEGER

    k = INKEY$
    IF k <> "" THEN RETURN -1

    GETMOUSE mx, my, mw, mb
    IF mb <> 0 THEN RETURN -1

    RETURN 0
END FUNCTION

DIM i AS INTEGER
DIM oldX AS INTEGER
DIM oldY AS INTEGER
DIM newX AS INTEGER
DIM newY AS INTEGER
DIM wrapped AS INTEGER
DIM startTime AS DOUBLE
DIM baseMouseSet AS INTEGER
DIM baseMx AS INTEGER
DIM baseMy AS INTEGER

RANDOMIZE TIMER

LoadSaverSettings
PickMode
SetBestScreenMode

FOR i = 1 TO activeStars
    ResetStar i
NEXT i

startTime = TIMER
baseMouseSet = 0

DO
    SCREENLOCK
    CLS

    FOR i = 1 TO activeStars
        oldX = ProjectX(stars(i).x, stars(i).z)
        oldY = ProjectY(stars(i).y, stars(i).z)

        stars(i).z = stars(i).z - stars(i).speed
        wrapped = 0

        IF stars(i).z <= Z_NEAR THEN
            ResetStar i
            wrapped = -1
        END IF

        newX = ProjectX(stars(i).x, stars(i).z)
        newY = ProjectY(stars(i).y, stars(i).z)

        IF newX < 0 OR newX >= scrW OR newY < 0 OR newY >= scrH THEN
            ResetStar i
        ELSE
            IF wrapped <> 0 THEN
                oldX = newX
                oldY = newY
            END IF

            DrawStar oldX, oldY, newX, newY, stars(i).z, stars(i).x + stars(i).y
        END IF
    NEXT i

    SCREENUNLOCK

    IF ShouldExitSaver(startTime, baseMouseSet, baseMx, baseMy) <> 0 THEN EXIT DO

    SLEEP 12, 1
LOOP

SYSTEM 0
