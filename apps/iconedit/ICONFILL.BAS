' Icon Editor helper source. It supports bitmap/icon drawing, fill work, palette handling, or icon file output.
'
' ICONFILL.BAS

CONST MAX_PIXELS = 16384
CONST STATUS_FILE = "FILLSTAT.TXT"
CONST COLOR_FILE = "FILLCOL.TXT"
CONST PAL256_FILE = "PAL256.CFG"

DIM SHARED fillQueue(0 TO MAX_PIXELS - 1) AS LONG

' ---------------------------
' Small file and text helpers
' ---------------------------

FUNCTION CleanArg(BYVAL textIn AS STRING) AS STRING
    textIn = TRIM$(textIn)
    IF LEN(textIn) >= 2 THEN
        IF LEFT$(textIn, 1) = CHR$(34) AND RIGHT$(textIn, 1) = CHR$(34) THEN
            textIn = MID$(textIn, 2, LEN(textIn) - 2)
        END IF
    END IF
    RETURN textIn
END FUNCTION

SUB WriteTextFileLocal(BYVAL fileName AS STRING, BYVAL textOut AS STRING)
    DIM f AS INTEGER
    f = FREEFILE
    IF OPEN(fileName FOR OUTPUT AS #f) <> 0 THEN EXIT SUB
    PRINT #f, textOut
    CLOSE #f
END SUB

SUB WriteStatus(BYVAL textOut AS STRING)
    WriteTextFileLocal STATUS_FILE, textOut
END SUB

SUB WriteColorIndex(BYVAL colorIndex AS INTEGER)
    IF colorIndex < 0 THEN colorIndex = 0
    IF colorIndex > 255 THEN colorIndex = 255
    WriteTextFileLocal COLOR_FILE, LTRIM$(STR$(colorIndex))
END SUB

FUNCTION ClampInt(BYVAL valueIn AS INTEGER, BYVAL lowVal AS INTEGER, BYVAL highVal AS INTEGER) AS INTEGER
    IF valueIn < lowVal THEN RETURN lowVal
    IF valueIn > highVal THEN RETURN highVal
    RETURN valueIn
END FUNCTION

FUNCTION MakeRgbLong(BYVAL redVal AS INTEGER, BYVAL greenVal AS INTEGER, BYVAL blueVal AS INTEGER) AS LONG
    redVal = ClampInt(redVal, 0, 255)
    greenVal = ClampInt(greenVal, 0, 255)
    blueVal = ClampInt(blueVal, 0, 255)
    RETURN CLNG(redVal) + CLNG(greenVal) * 256 + CLNG(blueVal) * 65536
END FUNCTION

FUNCTION FallbackPaletteRgb(BYVAL colorIndex AS INTEGER) AS LONG
    colorIndex = ClampInt(colorIndex, 0, 255)

    SELECT CASE colorIndex
    CASE 0
        RETURN MakeRgbLong(0, 0, 0)
    CASE 1
        RETURN MakeRgbLong(0, 0, 170)
    CASE 2
        RETURN MakeRgbLong(0, 170, 0)
    CASE 3
        RETURN MakeRgbLong(0, 170, 170)
    CASE 4
        RETURN MakeRgbLong(170, 0, 0)
    CASE 5
        RETURN MakeRgbLong(170, 0, 170)
    CASE 6
        RETURN MakeRgbLong(170, 85, 0)
    CASE 7
        RETURN MakeRgbLong(170, 170, 170)
    CASE 8
        RETURN MakeRgbLong(85, 85, 85)
    CASE 9
        RETURN MakeRgbLong(85, 85, 255)
    CASE 10
        RETURN MakeRgbLong(85, 255, 85)
    CASE 11
        RETURN MakeRgbLong(85, 255, 255)
    CASE 12
        RETURN MakeRgbLong(255, 85, 85)
    CASE 13
        RETURN MakeRgbLong(255, 0, 255)
    CASE 14
        RETURN MakeRgbLong(255, 255, 85)
    CASE 15
        RETURN MakeRgbLong(255, 255, 255)
    END SELECT

    RETURN MakeRgbLong(colorIndex, colorIndex, colorIndex)
END FUNCTION

FUNCTION PaletteRgbFromFile(BYVAL fileName AS STRING, BYVAL colorIndex AS INTEGER) AS LONG
    DIM f AS INTEGER
    DIM lineText AS STRING
    DIM eqPos AS INTEGER
    DIM comma1 AS INTEGER
    DIM comma2 AS INTEGER
    DIM palIndex AS INTEGER
    DIM redVal AS INTEGER
    DIM greenVal AS INTEGER
    DIM blueVal AS INTEGER
    DIM rgbText AS STRING

    colorIndex = ClampInt(colorIndex, 0, 255)

    f = FREEFILE
    IF OPEN(fileName FOR INPUT AS #f) <> 0 THEN
        RETURN FallbackPaletteRgb(colorIndex)
    END IF

    DO WHILE NOT EOF(f)
        LINE INPUT #f, lineText
        lineText = TRIM$(lineText)
        eqPos = INSTR(lineText, "=")
        IF eqPos > 1 THEN
            palIndex = VALINT(LEFT$(lineText, eqPos - 1))
            IF palIndex = colorIndex THEN
                rgbText = MID$(lineText, eqPos + 1)
                comma1 = INSTR(rgbText, ",")
                IF comma1 > 0 THEN
                    comma2 = INSTR(comma1 + 1, rgbText, ",")
                    IF comma2 > comma1 THEN
                        redVal = VALINT(LEFT$(rgbText, comma1 - 1))
                        greenVal = VALINT(MID$(rgbText, comma1 + 1, comma2 - comma1 - 1))
                        blueVal = VALINT(MID$(rgbText, comma2 + 1))
                        CLOSE #f
                        RETURN MakeRgbLong(redVal, greenVal, blueVal)
                    END IF
                END IF
            END IF
        END IF
    LOOP

    CLOSE #f
    RETURN FallbackPaletteRgb(colorIndex)
END FUNCTION

FUNCTION PayloadField(BYVAL payloadText AS STRING, BYVAL fieldNum AS INTEGER) AS STRING
    DIM i AS INTEGER
    DIM startPos AS INTEGER
    DIM pipePos AS INTEGER

    IF fieldNum < 1 THEN RETURN ""
    startPos = 1

    FOR i = 1 TO fieldNum - 1
        pipePos = INSTR(startPos, payloadText, "|")
        IF pipePos <= 0 THEN RETURN ""
        startPos = pipePos + 1
    NEXT

    pipePos = INSTR(startPos, payloadText, "|")
    IF pipePos <= 0 THEN
        RETURN MID$(payloadText, startPos)
    ELSE
        RETURN MID$(payloadText, startPos, pipePos - startPos)
    END IF
END FUNCTION

FUNCTION PayloadInt(BYVAL payloadText AS STRING, BYVAL fieldNum AS INTEGER) AS INTEGER
    RETURN VALINT(PayloadField(payloadText, fieldNum))
END FUNCTION

' ---------------------------
' BMP byte helpers
' ---------------------------

FUNCTION ByteAt(BYREF dataText AS STRING, BYVAL byteOffset AS LONG) AS INTEGER
    IF byteOffset < 0 OR byteOffset >= LEN(dataText) THEN RETURN 0
    RETURN ASC(MID$(dataText, byteOffset + 1, 1)) AND 255
END FUNCTION

FUNCTION U16At(BYREF dataText AS STRING, BYVAL byteOffset AS LONG) AS INTEGER
    RETURN ByteAt(dataText, byteOffset) + ByteAt(dataText, byteOffset + 1) * 256
END FUNCTION

FUNCTION U32At(BYREF dataText AS STRING, BYVAL byteOffset AS LONG) AS LONG
    DIM resultVal AS LONG
    resultVal = CLNG(ByteAt(dataText, byteOffset))
    resultVal = resultVal + CLNG(ByteAt(dataText, byteOffset + 1)) * 256
    resultVal = resultVal + CLNG(ByteAt(dataText, byteOffset + 2)) * 65536
    resultVal = resultVal + CLNG(ByteAt(dataText, byteOffset + 3)) * 16777216
    RETURN resultVal
END FUNCTION

SUB PutByteAt(BYREF dataText AS STRING, BYVAL byteOffset AS LONG, BYVAL byteValue AS INTEGER)
    IF byteOffset < 0 OR byteOffset >= LEN(dataText) THEN EXIT SUB
    byteValue = ClampInt(byteValue, 0, 255)
    MID(dataText, byteOffset + 1, 1) = CHR$(byteValue)
END SUB

FUNCTION PixelByteOffset(BYVAL dataOff AS LONG, BYVAL rowSize AS LONG, BYVAL bmpH AS INTEGER, BYVAL topDown AS INTEGER, BYVAL x AS INTEGER, BYVAL y AS INTEGER, BYVAL bpp AS INTEGER) AS LONG
    DIM fileY AS INTEGER
    IF topDown <> 0 THEN
        fileY = y
    ELSE
        fileY = bmpH - 1 - y
    END IF
    RETURN dataOff + CLNG(fileY) * rowSize + ((CLNG(x) * bpp) \ 8)
END FUNCTION

FUNCTION ReadPixelIndex(BYREF dataText AS STRING, BYVAL dataOff AS LONG, BYVAL rowSize AS LONG, BYVAL bmpH AS INTEGER, BYVAL topDown AS INTEGER, BYVAL x AS INTEGER, BYVAL y AS INTEGER, BYVAL bpp AS INTEGER) AS LONG
    DIM byteOffset AS LONG
    DIM byteVal AS INTEGER
    DIM blueVal AS INTEGER
    DIM greenVal AS INTEGER
    DIM redVal AS INTEGER

    byteOffset = PixelByteOffset(dataOff, rowSize, bmpH, topDown, x, y, bpp)
    byteVal = ByteAt(dataText, byteOffset)

    IF bpp = 8 THEN
        RETURN byteVal
    ELSEIF bpp = 4 THEN
        IF (x AND 1) = 0 THEN
            RETURN (byteVal \ 16) AND 15
        ELSE
            RETURN byteVal AND 15
        END IF
    ELSEIF bpp = 24 THEN
        blueVal = ByteAt(dataText, byteOffset)
        greenVal = ByteAt(dataText, byteOffset + 1)
        redVal = ByteAt(dataText, byteOffset + 2)
        RETURN MakeRgbLong(redVal, greenVal, blueVal)
    END IF

    RETURN 0
END FUNCTION

SUB WritePixelIndex(BYREF dataText AS STRING, BYVAL dataOff AS LONG, BYVAL rowSize AS LONG, BYVAL bmpH AS INTEGER, BYVAL topDown AS INTEGER, BYVAL x AS INTEGER, BYVAL y AS INTEGER, BYVAL bpp AS INTEGER, BYVAL colorValue AS LONG)
    DIM byteOffset AS LONG
    DIM byteVal AS INTEGER
    DIM redVal AS INTEGER
    DIM greenVal AS INTEGER
    DIM blueVal AS INTEGER

    byteOffset = PixelByteOffset(dataOff, rowSize, bmpH, topDown, x, y, bpp)

    IF bpp = 8 THEN
        PutByteAt dataText, byteOffset, CINT(colorValue AND 255)
    ELSEIF bpp = 4 THEN
        colorValue = colorValue AND 15
        byteVal = ByteAt(dataText, byteOffset)
        IF (x AND 1) = 0 THEN
            byteVal = (CINT(colorValue) * 16) OR (byteVal AND 15)
        ELSE
            byteVal = (byteVal AND 240) OR CINT(colorValue)
        END IF
        PutByteAt dataText, byteOffset, byteVal
    ELSEIF bpp = 24 THEN
        redVal = CINT(colorValue AND 255)
        greenVal = CINT((colorValue \ 256) AND 255)
        blueVal = CINT((colorValue \ 65536) AND 255)
        PutByteAt dataText, byteOffset, blueVal
        PutByteAt dataText, byteOffset + 1, greenVal
        PutByteAt dataText, byteOffset + 2, redVal
    END IF
END SUB

' ---------------------------
' Palette-payload and flood-fill commands
' ---------------------------

SUB SavePaletteColorFromPayload(BYVAL payloadText AS STRING)
    DIM localX AS INTEGER
    DIM localY AS INTEGER
    DIM ew AS INTEGER
    DIM eh AS INTEGER
    DIM sw AS INTEGER
    DIM swY AS INTEGER
    DIM sx AS INTEGER
    DIM sy AS INTEGER
    DIM colorIndex AS INTEGER

    localX = PayloadInt(payloadText, 2)
    localY = PayloadInt(payloadText, 3)
    ew = PayloadInt(payloadText, 7)
    eh = PayloadInt(payloadText, 8)
    IF ew <= 0 THEN ew = 214
    IF eh <= 0 THEN eh = 214

    sw = (ew - 6) \ 16
    swY = (eh - 6) \ 16
    IF swY < sw THEN sw = swY
    IF sw < 4 THEN sw = 4

    sx = (localX - 3) \ sw
    sy = (localY - 3) \ sw
    IF sx < 0 THEN sx = 0
    IF sx > 15 THEN sx = 15
    IF sy < 0 THEN sy = 0
    IF sy > 15 THEN sy = 15

    colorIndex = sy * 16 + sx
    colorIndex = ClampInt(colorIndex, 0, 255)
    WriteColorIndex colorIndex
    WriteStatus "Fill color " + LTRIM$(STR$(colorIndex))
END SUB

SUB FloodFillBmp(BYVAL bmpFile AS STRING, BYVAL startX AS INTEGER, BYVAL startY AS INTEGER, BYVAL fillColor AS INTEGER)
    DIM f AS INTEGER
    DIM dataText AS STRING
    DIM dataLen AS LONG
    DIM dataOff AS LONG
    DIM dibSize AS LONG
    DIM bmpWLong AS LONG
    DIM bmpHRaw AS LONG
    DIM bmpW AS INTEGER
    DIM bmpH AS INTEGER
    DIM topDown AS INTEGER
    DIM bpp AS INTEGER
    DIM rowSize AS LONG
    DIM maxColor AS INTEGER
    DIM targetColor AS LONG
    DIM fillValue AS LONG
    DIM curIdx AS LONG
    DIM nextIdx AS LONG
    DIM head AS LONG
    DIM tail AS LONG
    DIM x AS INTEGER
    DIM y AS INTEGER

    bmpFile = CleanArg(bmpFile)
    IF bmpFile = "" THEN
        WriteStatus "Fill failed: no file"
        EXIT SUB
    END IF

    f = FREEFILE
    IF OPEN(bmpFile FOR BINARY AS #f) <> 0 THEN
        WriteStatus "Fill failed: open"
        EXIT SUB
    END IF

    dataLen = LOF(f)
    IF dataLen < 54 THEN
        CLOSE #f
        WriteStatus "Fill failed: invalid BMP"
        EXIT SUB
    END IF

    dataText = SPACE$(dataLen)
    GET #f, 1, dataText
    CLOSE #f

    IF ByteAt(dataText, 0) <> ASC("B") OR ByteAt(dataText, 1) <> ASC("M") THEN
        WriteStatus "Fill failed: invalid BMP"
        EXIT SUB
    END IF

    dataOff = U32At(dataText, 10)
    dibSize = U32At(dataText, 14)
    bmpWLong = U32At(dataText, 18)
    bmpHRaw = U32At(dataText, 22)
    bpp = U16At(dataText, 28)

    IF dibSize < 40 THEN
        WriteStatus "Fill failed: BMP header"
        EXIT SUB
    END IF
    IF bmpWLong < 1 OR bmpWLong > 128 THEN
        WriteStatus "Fill failed: width"
        EXIT SUB
    END IF

    topDown = 0
    IF bmpHRaw < 0 THEN
        bmpHRaw = -bmpHRaw
        topDown = -1
    END IF
    IF bmpHRaw < 1 OR bmpHRaw > 128 THEN
        WriteStatus "Fill failed: height"
        EXIT SUB
    END IF

    IF bpp <> 4 AND bpp <> 8 AND bpp <> 24 THEN
        WriteStatus "Fill failed: 4/8/24-bit BMP only"
        EXIT SUB
    END IF

    bmpW = CINT(bmpWLong)
    bmpH = CINT(bmpHRaw)
    IF CLNG(bmpW) * CLNG(bmpH) > MAX_PIXELS THEN
        WriteStatus "Fill failed: bitmap too large"
        EXIT SUB
    END IF

    IF startX < 0 OR startX >= bmpW OR startY < 0 OR startY >= bmpH THEN
        WriteStatus "Fill failed: x/y outside bitmap"
        EXIT SUB
    END IF

    IF bpp = 4 THEN
        maxColor = 15
        fillColor = ClampInt(fillColor, 0, maxColor)
        fillValue = fillColor
    ELSEIF bpp = 8 THEN
        maxColor = 255
        fillColor = ClampInt(fillColor, 0, maxColor)
        fillValue = fillColor
    ELSE
        maxColor = 255
        fillColor = ClampInt(fillColor, 0, maxColor)
        fillValue = PaletteRgbFromFile(PAL256_FILE, fillColor)
    END IF
    rowSize = ((CLNG(bmpW) * bpp + 31) \ 32) * 4

    targetColor = ReadPixelIndex(dataText, dataOff, rowSize, bmpH, topDown, startX, startY, bpp)
    IF targetColor = fillValue THEN
        WriteStatus "Fill skipped: same color"
        EXIT SUB
    END IF

    head = 0
    tail = 0
    fillQueue(tail) = CLNG(startY) * bmpW + startX
    tail = tail + 1
    WritePixelIndex dataText, dataOff, rowSize, bmpH, topDown, startX, startY, bpp, fillValue

    DO WHILE head < tail
        curIdx = fillQueue(head)
        head = head + 1
        x = CINT(curIdx MOD bmpW)
        y = CINT(curIdx \ bmpW)

        IF x > 0 THEN
            nextIdx = curIdx - 1
            IF ReadPixelIndex(dataText, dataOff, rowSize, bmpH, topDown, x - 1, y, bpp) = targetColor THEN
                WritePixelIndex dataText, dataOff, rowSize, bmpH, topDown, x - 1, y, bpp, fillValue
                fillQueue(tail) = nextIdx
                tail = tail + 1
            END IF
        END IF
        IF x < bmpW - 1 THEN
            nextIdx = curIdx + 1
            IF ReadPixelIndex(dataText, dataOff, rowSize, bmpH, topDown, x + 1, y, bpp) = targetColor THEN
                WritePixelIndex dataText, dataOff, rowSize, bmpH, topDown, x + 1, y, bpp, fillValue
                fillQueue(tail) = nextIdx
                tail = tail + 1
            END IF
        END IF
        IF y > 0 THEN
            nextIdx = curIdx - bmpW
            IF ReadPixelIndex(dataText, dataOff, rowSize, bmpH, topDown, x, y - 1, bpp) = targetColor THEN
                WritePixelIndex dataText, dataOff, rowSize, bmpH, topDown, x, y - 1, bpp, fillValue
                fillQueue(tail) = nextIdx
                tail = tail + 1
            END IF
        END IF
        IF y < bmpH - 1 THEN
            nextIdx = curIdx + bmpW
            IF ReadPixelIndex(dataText, dataOff, rowSize, bmpH, topDown, x, y + 1, bpp) = targetColor THEN
                WritePixelIndex dataText, dataOff, rowSize, bmpH, topDown, x, y + 1, bpp, fillValue
                fillQueue(tail) = nextIdx
                tail = tail + 1
            END IF
        END IF
    LOOP

    f = FREEFILE
    IF OPEN(bmpFile FOR BINARY ACCESS WRITE AS #f) <> 0 THEN
        WriteStatus "Fill failed: write"
        EXIT SUB
    END IF
    PUT #f, 1, dataText
    CLOSE #f

    WriteStatus "Filled " + LTRIM$(STR$(startX)) + "," + LTRIM$(STR$(startY)) + " color " + LTRIM$(STR$(fillColor))
END SUB

' ---------------------------
' Entry point
' ---------------------------

DIM modeText AS STRING

modeText = UCASE$(CleanArg(COMMAND$(1)))

SELECT CASE modeText
CASE "COLOR"
    SavePaletteColorFromPayload CleanArg(COMMAND$(2))
CASE "FILL"
    FloodFillBmp CleanArg(COMMAND$(2)), VALINT(CleanArg(COMMAND$(3))), VALINT(CleanArg(COMMAND$(4))), VALINT(CleanArg(COMMAND$(5)))
CASE ELSE
    WriteStatus "Icon fill helper: bad command"
END SELECT
