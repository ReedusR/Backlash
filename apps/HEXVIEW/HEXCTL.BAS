' Hex Viewer helper source. It reads a file page and creates the offset, hex-byte, ASCII, and status output used by the app.
'
' HEXCTL.BAS
' This is viewer-only: it reads bytes, renders offset/hex/ASCII panes, and never writes the opened file.

CONST HEX_OFFSET_FILE = "OFFSET.TMP"
CONST HEX_HEX_FILE = "HEX.TMP"
CONST HEX_ASCII_FILE = "ASCII.TMP"
CONST HEX_STATUS_FILE = "STATUS.TMP"
CONST HEX_PAGE_FILE = "PAGE.TMP"
CONST HEX_PAGE_BYTES = 4096

' ---------------------------
' Basic file and string helpers
' ---------------------------

FUNCTION CleanCommandToken(BYVAL tokenText AS STRING) AS STRING
    tokenText = TRIM$(tokenText)
    IF LEN(tokenText) >= 2 THEN
        IF LEFT$(tokenText, 1) = CHR$(34) AND RIGHT$(tokenText, 1) = CHR$(34) THEN
            tokenText = MID$(tokenText, 2, LEN(tokenText) - 2)
        END IF
    END IF
    RETURN TRIM$(tokenText)
END FUNCTION

FUNCTION FileExists(BYVAL fileName AS STRING) AS INTEGER
    IF TRIM$(fileName) = "" THEN RETURN 0
    IF DIR(fileName) = "" THEN RETURN 0
    RETURN -1
END FUNCTION

FUNCTION SafeLongValue(BYVAL valueText AS STRING) AS LONG
    valueText = CleanCommandToken(valueText)
    IF valueText = "" THEN RETURN 0
    RETURN CLNG(VAL(valueText))
END FUNCTION

FUNCTION WriteBinaryFile(BYVAL fileName AS STRING, BYVAL dataText AS STRING) AS INTEGER
    DIM fileNum AS INTEGER

    WriteBinaryFile = 0
    IF TRIM$(fileName) = "" THEN EXIT FUNCTION

    IF FileExists(fileName) <> 0 THEN KILL fileName

    fileNum = FREEFILE
    IF OPEN(fileName FOR BINARY ACCESS WRITE AS #fileNum) <> 0 THEN EXIT FUNCTION
    IF LEN(dataText) > 0 THEN PUT #fileNum, , dataText
    CLOSE #fileNum

    WriteBinaryFile = -1
END FUNCTION

SUB WriteTextFile(BYVAL fileName AS STRING, BYVAL dataText AS STRING)
    DIM ignored AS INTEGER
    ignored = WriteBinaryFile(fileName, dataText)
END SUB

FUNCTION LineBreak() AS STRING
    RETURN CHR$(13) + CHR$(10)
END FUNCTION

FUNCTION ReadBinaryPage(BYVAL fileName AS STRING, BYVAL startOffset AS LONG, BYVAL byteCount AS LONG, BYREF ok AS INTEGER, BYREF fileSize AS LONG, BYREF actualOffset AS LONG) AS STRING
    DIM fileNum AS INTEGER
    DIM pageLen AS LONG
    DIM dataText AS STRING

    ok = 0
    fileSize = 0
    actualOffset = 0
    ReadBinaryPage = ""
    IF TRIM$(fileName) = "" THEN EXIT FUNCTION

    fileNum = FREEFILE
    IF OPEN(fileName FOR BINARY ACCESS READ AS #fileNum) <> 0 THEN EXIT FUNCTION

    fileSize = LOF(fileNum)

    IF startOffset < 0 THEN startOffset = 0
    IF fileSize <= 0 THEN
        actualOffset = 0
        CLOSE #fileNum
        ok = -1
        EXIT FUNCTION
    END IF

    IF startOffset >= fileSize THEN
        startOffset = ((fileSize - 1) \ HEX_PAGE_BYTES) * HEX_PAGE_BYTES
    END IF

    pageLen = byteCount
    IF pageLen < 1 THEN pageLen = HEX_PAGE_BYTES
    IF startOffset + pageLen > fileSize THEN pageLen = fileSize - startOffset

    IF pageLen > 0 THEN
        dataText = SPACE$(pageLen)
        GET #fileNum, startOffset + 1, dataText
    ELSE
        dataText = ""
    END IF

    CLOSE #fileNum

    actualOffset = startOffset
    ok = -1
    ReadBinaryPage = dataText
END FUNCTION

' ---------------------------
' Byte formatting helpers
' ---------------------------

FUNCTION HexByteText(BYVAL byteVal AS INTEGER) AS STRING
    DIM digits AS STRING
    digits = "0123456789ABCDEF"
    RETURN MID$(digits, (byteVal \ 16) + 1, 1) + MID$(digits, (byteVal MOD 16) + 1, 1)
END FUNCTION

FUNCTION HexLongText8(BYVAL longVal AS LONG) AS STRING
    DIM digits AS STRING
    DIM outText AS STRING
    DIM i AS INTEGER
    DIM nibbleVal AS INTEGER
    DIM workVal AS LONG

    digits = "0123456789ABCDEF"
    outText = ""
    workVal = longVal

    FOR i = 1 TO 8
        nibbleVal = workVal MOD 16
        outText = MID$(digits, nibbleVal + 1, 1) + outText
        workVal = workVal \ 16
    NEXT i

    RETURN outText
END FUNCTION

FUNCTION PrintableByteText(BYVAL byteVal AS INTEGER) AS STRING
    IF byteVal >= 32 AND byteVal <= 126 THEN RETURN CHR$(byteVal)
    RETURN "."
END FUNCTION

FUNCTION LongText(BYVAL valueNum AS LONG) AS STRING
    RETURN LTRIM$(STR$(valueNum))
END FUNCTION

' ---------------------------
' Split-pane rendering
' ---------------------------

SUB BuildSplitViewsFast(BYVAL rawData AS STRING, BYVAL baseOffset AS LONG, BYREF offsetText AS STRING, BYREF hexText AS STRING, BYREF asciiText AS STRING)
    DIM offsetVal AS LONG
    DIM rowLimit AS LONG
    DIM byteIndex AS INTEGER
    DIM dataIndex AS LONG
    DIM byteVal AS INTEGER
    DIM hexLine AS STRING
    DIM asciiLine AS STRING
    DIM eolText AS STRING

    offsetText = ""
    hexText = ""
    asciiText = ""

    eolText = LineBreak()
    rowLimit = LEN(rawData)
    offsetVal = 0

    DO WHILE offsetVal < rowLimit
        hexLine = ""
        asciiLine = ""

        FOR byteIndex = 0 TO 15
            dataIndex = offsetVal + byteIndex
            IF dataIndex < rowLimit THEN
                byteVal = ASC(MID$(rawData, dataIndex + 1, 1))
                IF hexLine <> "" THEN hexLine = hexLine + " "
                hexLine = hexLine + HexByteText(byteVal)
                asciiLine = asciiLine + PrintableByteText(byteVal)
            END IF
        NEXT byteIndex

        IF offsetText <> "" THEN
            offsetText = offsetText + eolText
            hexText = hexText + eolText
            asciiText = asciiText + eolText
        END IF

        offsetText = offsetText + HexLongText8(baseOffset + offsetVal)
        hexText = hexText + hexLine
        asciiText = asciiText + asciiLine

        offsetVal = offsetVal + 16
    LOOP
END SUB

SUB WriteSplitViews(BYVAL rawData AS STRING, BYVAL baseOffset AS LONG)
    DIM offsetText AS STRING
    DIM hexText AS STRING
    DIM asciiText AS STRING

    BuildSplitViewsFast rawData, baseOffset, offsetText, hexText, asciiText
    WriteTextFile HEX_OFFSET_FILE, offsetText
    WriteTextFile HEX_HEX_FILE, hexText
    WriteTextFile HEX_ASCII_FILE, asciiText
END SUB

SUB WriteStatus(BYVAL statusText AS STRING)
    WriteTextFile HEX_STATUS_FILE, statusText
END SUB

SUB WritePageOffset(BYVAL offsetVal AS LONG)
    WriteTextFile HEX_PAGE_FILE, LongText(offsetVal)
END SUB

' ---------------------------
' Action handlers
' ---------------------------

SUB HandlePage(BYVAL pathText AS STRING, BYVAL requestedOffset AS LONG)
    DIM rawData AS STRING
    DIM openOk AS INTEGER
    DIM fileSize AS LONG
    DIM actualOffset AS LONG
    DIM endOffset AS LONG

    pathText = CleanCommandToken(pathText)
    IF pathText = "" THEN
        WriteSplitViews "", 0
        WritePageOffset 0
        WriteStatus "Open failed: no file is selected."
        EXIT SUB
    END IF

    rawData = ReadBinaryPage(pathText, requestedOffset, HEX_PAGE_BYTES, openOk, fileSize, actualOffset)
    IF openOk = 0 THEN
        WriteSplitViews "", 0
        WritePageOffset 0
        WriteStatus "Open failed: " + pathText
        EXIT SUB
    END IF

    WriteSplitViews rawData, actualOffset
    WritePageOffset actualOffset

    IF fileSize <= 0 THEN
        WriteStatus "Viewing " + pathText + "  0 byte(s)."
        EXIT SUB
    END IF

    endOffset = actualOffset + LEN(rawData) - 1
    WriteStatus "Viewing " + pathText + "  bytes " + LongText(actualOffset) + "-" + LongText(endOffset) + " of " + LongText(fileSize) + "."
END SUB

SUB HandleNext(BYVAL pathText AS STRING, BYVAL offsetText AS STRING)
    DIM nextOffset AS LONG
    nextOffset = SafeLongValue(offsetText) + HEX_PAGE_BYTES
    HandlePage pathText, nextOffset
END SUB

SUB HandlePrev(BYVAL pathText AS STRING, BYVAL offsetText AS STRING)
    DIM prevOffset AS LONG
    prevOffset = SafeLongValue(offsetText) - HEX_PAGE_BYTES
    IF prevOffset < 0 THEN prevOffset = 0
    HandlePage pathText, prevOffset
END SUB

' ---------------------------
' Entry point
' ---------------------------

DIM actionText AS STRING
DIM pathText AS STRING
DIM offsetText AS STRING

actionText = UCASE$(CleanCommandToken(COMMAND(1)))
pathText = CleanCommandToken(COMMAND(2))
offsetText = CleanCommandToken(COMMAND(3))

SELECT CASE actionText
CASE "OPEN", "PAGE"
    HandlePage pathText, SafeLongValue(offsetText)
CASE "NEXT"
    HandleNext pathText, offsetText
CASE "PREV"
    HandlePrev pathText, offsetText
CASE ELSE
    WriteSplitViews "", 0
    WritePageOffset 0
    WriteStatus "Hex viewer helper received an unknown action."
END SELECT
