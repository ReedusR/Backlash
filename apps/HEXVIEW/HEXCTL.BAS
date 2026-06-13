' Hex Viewer helper source. It reads a file and creates the offset, hex-byte, ASCII, and status output used by the app.
'
' HEXCTL.BAS
' This is viewer-only: it reads bytes, renders offset/hex/ASCII panes, and never writes the opened file.

CONST HEX_OFFSET_FILE = "OFFSET.TMP"
CONST HEX_HEX_FILE = "HEX.TMP"
CONST HEX_ASCII_FILE = "ASCII.TMP"
CONST HEX_STATUS_FILE = "STATUS.TMP"

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

FUNCTION ReadBinaryFile(BYVAL fileName AS STRING, BYREF ok AS INTEGER) AS STRING
    DIM fileNum AS INTEGER
    DIM fileLen AS LONG
    DIM dataText AS STRING

    ok = 0
    ReadBinaryFile = ""
    IF TRIM$(fileName) = "" THEN EXIT FUNCTION

    fileNum = FREEFILE
    IF OPEN(fileName FOR BINARY ACCESS READ AS #fileNum) <> 0 THEN EXIT FUNCTION

    fileLen = LOF(fileNum)
    IF fileLen > 0 THEN
        dataText = SPACE$(fileLen)
        GET #fileNum, , dataText
    ELSE
        dataText = ""
    END IF

    CLOSE #fileNum
    ok = -1
    ReadBinaryFile = dataText
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

' ---------------------------
' Split-pane rendering
' ---------------------------

SUB BuildSplitViewsFast(BYVAL rawData AS STRING, BYREF offsetText AS STRING, BYREF hexText AS STRING, BYREF asciiText AS STRING)
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

        offsetText = offsetText + HexLongText8(offsetVal)
        hexText = hexText + hexLine
        asciiText = asciiText + asciiLine

        offsetVal = offsetVal + 16
    LOOP
END SUB

SUB WriteSplitViews(BYVAL rawData AS STRING)
    DIM offsetText AS STRING
    DIM hexText AS STRING
    DIM asciiText AS STRING

    BuildSplitViewsFast rawData, offsetText, hexText, asciiText
    WriteTextFile HEX_OFFSET_FILE, offsetText
    WriteTextFile HEX_HEX_FILE, hexText
    WriteTextFile HEX_ASCII_FILE, asciiText
END SUB

SUB WriteStatus(BYVAL statusText AS STRING)
    WriteTextFile HEX_STATUS_FILE, statusText
END SUB

' ---------------------------
' Action handlers
' ---------------------------

SUB HandleOpen(BYVAL pathText AS STRING)
    DIM rawData AS STRING
    DIM openOk AS INTEGER

    pathText = CleanCommandToken(pathText)
    IF pathText = "" THEN
        WriteSplitViews ""
        WriteStatus "Open failed: no file is selected."
        EXIT SUB
    END IF

    rawData = ReadBinaryFile(pathText, openOk)
    IF openOk = 0 THEN
        WriteSplitViews ""
        WriteStatus "Open failed: " + pathText
        EXIT SUB
    END IF

    WriteSplitViews rawData
    WriteStatus "Viewing " + pathText + "  " + LTRIM$(STR$(LEN(rawData))) + " byte(s)."
END SUB

' ---------------------------
' Entry point
' ---------------------------

DIM actionText AS STRING
DIM pathText AS STRING

actionText = UCASE$(CleanCommandToken(COMMAND(1)))
pathText = CleanCommandToken(COMMAND(2))

SELECT CASE actionText
CASE "OPEN"
    HandleOpen pathText
CASE ELSE
    WriteSplitViews ""
    WriteStatus "Hex viewer helper received an unknown action."
END SELECT
