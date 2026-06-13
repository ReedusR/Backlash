' Image Viewer helper source. It prepares image files, slideshow output, or decoded bitmap data for the Image Viewer app.
'
#lang "fb"

CONST TRUE_VALUE AS INTEGER = -1
CONST FALSE_VALUE AS INTEGER = 0

DECLARE FUNCTION UpperText(BYVAL src AS STRING) AS STRING
DECLARE FUNCTION StripQuotes(BYVAL src AS STRING) AS STRING
DECLARE FUNCTION FileExists(BYVAL fileName AS STRING) AS INTEGER
DECLARE FUNCTION FileExtUpper(BYVAL fileName AS STRING) AS STRING
DECLARE FUNCTION FileNameOnly(BYVAL filePath AS STRING) AS STRING
DECLARE FUNCTION ParentPath(BYVAL filePath AS STRING) AS STRING
DECLARE FUNCTION JoinPath(BYVAL dirName AS STRING, BYVAL leafName AS STRING) AS STRING
DECLARE FUNCTION QuoteArg(BYVAL argText AS STRING) AS STRING
DECLARE FUNCTION ImageFileSupported(BYVAL fileName AS STRING) AS INTEGER
DECLARE FUNCTION NextImageInFolder(BYVAL currentPath AS STRING, BYVAL direction AS INTEGER) AS STRING
DECLARE FUNCTION ReadBmpFileInfo(BYVAL fileName AS STRING, BYREF w AS INTEGER, BYREF h AS INTEGER, BYREF bitDepth AS INTEGER, BYREF fileBytes AS UINTEGER) AS INTEGER
DECLARE FUNCTION BuildImageInfoText(BYVAL displayPath AS STRING) AS STRING
DECLARE FUNCTION WriteImageState(BYVAL cfgPath AS STRING, BYVAL originalPath AS STRING, BYVAL displayPath AS STRING, BYVAL nameText AS STRING, BYVAL infoText AS STRING) AS INTEGER
DECLARE FUNCTION ConvertImageSelection(BYVAL sourcePath AS STRING, BYVAL codecPath AS STRING, BYVAL outputBmpPath AS STRING, BYREF displayPath AS STRING) AS INTEGER

' ---------------------------
' String, path, and file helper functions
' ---------------------------

FUNCTION UpperText(BYVAL src AS STRING) AS STRING
    RETURN UCASE$(src)
END FUNCTION

FUNCTION StripQuotes(BYVAL src AS STRING) AS STRING
    src = TRIM$(src)
    IF LEN(src) >= 2 THEN
        IF LEFT$(src, 1) = CHR$(34) AND RIGHT$(src, 1) = CHR$(34) THEN
            RETURN MID$(src, 2, LEN(src) - 2)
        END IF
    END IF
    RETURN src
END FUNCTION

FUNCTION FileExists(BYVAL fileName AS STRING) AS INTEGER
    fileName = StripQuotes(TRIM$(fileName))
    IF fileName = "" THEN RETURN FALSE_VALUE
    IF DIR(fileName) <> "" THEN RETURN TRUE_VALUE
    RETURN FALSE_VALUE
END FUNCTION

FUNCTION FileExtUpper(BYVAL fileName AS STRING) AS STRING
    DIM i AS INTEGER
    DIM ch AS STRING

    fileName = StripQuotes(TRIM$(fileName))

    FOR i = LEN(fileName) TO 1 STEP -1
        ch = MID$(fileName, i, 1)
        IF ch = "." THEN RETURN UpperText(MID$(fileName, i + 1))
        IF ch = CHR$(92) OR ch = ":" THEN EXIT FOR
    NEXT i

    RETURN ""
END FUNCTION

FUNCTION FileNameOnly(BYVAL filePath AS STRING) AS STRING
    DIM i AS INTEGER
    DIM ch AS STRING

    filePath = StripQuotes(TRIM$(filePath))

    FOR i = LEN(filePath) TO 1 STEP -1
        ch = MID$(filePath, i, 1)
        IF ch = CHR$(92) OR ch = ":" THEN RETURN MID$(filePath, i + 1)
    NEXT i

    RETURN filePath
END FUNCTION

FUNCTION ParentPath(BYVAL filePath AS STRING) AS STRING
    DIM i AS INTEGER
    DIM ch AS STRING

    filePath = StripQuotes(TRIM$(filePath))

    FOR i = LEN(filePath) TO 1 STEP -1
        ch = MID$(filePath, i, 1)
        IF ch = CHR$(92) THEN
            IF i <= 1 THEN RETURN CHR$(92)
            RETURN LEFT$(filePath, i - 1)
        END IF
    NEXT i

    RETURN "."
END FUNCTION

FUNCTION JoinPath(BYVAL dirName AS STRING, BYVAL leafName AS STRING) AS STRING
    dirName = StripQuotes(TRIM$(dirName))
    leafName = StripQuotes(TRIM$(leafName))

    IF dirName = "" OR dirName = "." THEN RETURN leafName
    IF RIGHT$(dirName, 1) = CHR$(92) THEN RETURN dirName + leafName
    RETURN dirName + CHR$(92) + leafName
END FUNCTION

FUNCTION QuoteArg(BYVAL argText AS STRING) AS STRING
    argText = StripQuotes(TRIM$(argText))
    RETURN CHR$(34) + argText + CHR$(34)
END FUNCTION

' ---------------------------
' Folder image navigation
' ---------------------------

FUNCTION ImageFileSupported(BYVAL fileName AS STRING) AS INTEGER
    DIM extText AS STRING

    extText = FileExtUpper(fileName)
    SELECT CASE extText
    CASE "BMP", "GIF", "JPG", "JPEG"
        RETURN TRUE_VALUE
    END SELECT

    RETURN FALSE_VALUE
END FUNCTION

FUNCTION NextImageInFolder(BYVAL currentPath AS STRING, BYVAL direction AS INTEGER) AS STRING
    DIM dirName AS STRING
    DIM curName AS STRING
    DIM pattern AS STRING
    DIM fileName AS STRING
    DIM fullPath AS STRING
    DIM firstPath AS STRING
    DIM lastPath AS STRING
    DIM bestPath AS STRING
    DIM fileUpper AS STRING
    DIM curUpper AS STRING
    DIM attrBits AS INTEGER

    currentPath = StripQuotes(TRIM$(currentPath))
    IF currentPath <> "" THEN
        dirName = ParentPath(currentPath)
        curName = FileNameOnly(currentPath)
    END IF
    IF dirName = "" THEN dirName = "."
    curUpper = UpperText(curName)

    pattern = dirName
    IF pattern = "." THEN
        pattern = "*.*"
    ELSE
        IF RIGHT$(pattern, 1) <> CHR$(92) THEN pattern = pattern + CHR$(92)
        pattern = pattern + "*.*"
    END IF

    attrBits = 0
    fileName = DIR(pattern, &H37, attrBits)
    DO WHILE fileName <> ""
        fullPath = JoinPath(dirName, fileName)
        IF (attrBits AND &H10) = 0 THEN
            IF ImageFileSupported(fullPath) <> 0 THEN
                fileUpper = UpperText(fileName)
                IF firstPath = "" OR fileUpper < UpperText(FileNameOnly(firstPath)) THEN firstPath = fullPath
                IF lastPath = "" OR fileUpper > UpperText(FileNameOnly(lastPath)) THEN lastPath = fullPath

                IF curUpper = "" THEN
                    IF bestPath = "" THEN bestPath = fullPath
                ELSEIF direction < 0 THEN
                    IF fileUpper < curUpper THEN
                        IF bestPath = "" OR fileUpper > UpperText(FileNameOnly(bestPath)) THEN bestPath = fullPath
                    END IF
                ELSE
                    IF fileUpper > curUpper THEN
                        IF bestPath = "" OR fileUpper < UpperText(FileNameOnly(bestPath)) THEN bestPath = fullPath
                    END IF
                END IF
            END IF
        END IF
        fileName = DIR(attrBits)
    LOOP

    IF bestPath <> "" THEN RETURN bestPath
    IF direction < 0 THEN RETURN lastPath
    RETURN firstPath
END FUNCTION

' ---------------------------
' Image size/depth info text
' ---------------------------

FUNCTION ReadBmpFileInfo(BYVAL fileName AS STRING, BYREF w AS INTEGER, BYREF h AS INTEGER, BYREF bitDepth AS INTEGER, BYREF fileBytes AS UINTEGER) AS INTEGER
    DIM f AS INTEGER
    DIM sig AS USHORT
    DIM reserved1 AS USHORT
    DIM reserved2 AS USHORT
    DIM dataOffset AS UINTEGER
    DIM infoSize AS UINTEGER
    DIM bmpW AS INTEGER
    DIM bmpH AS INTEGER
    DIM planes AS USHORT
    DIM bitCount AS USHORT
    DIM coreW AS USHORT
    DIM coreH AS USHORT
    DIM corePlanes AS USHORT
    DIM coreBitCount AS USHORT

    w = 0
    h = 0
    bitDepth = 0
    fileBytes = 0
    fileName = StripQuotes(TRIM$(fileName))

    f = FREEFILE
    IF OPEN(fileName FOR BINARY ACCESS READ AS #f) <> 0 THEN RETURN FALSE_VALUE
    fileBytes = LOF(f)
    IF fileBytes < 26 THEN
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    GET #f, , sig
    GET #f, , fileBytes
    GET #f, , reserved1
    GET #f, , reserved2
    GET #f, , dataOffset
    GET #f, , infoSize

    IF sig <> &H4D42 THEN
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    IF infoSize = 12 THEN
        GET #f, , coreW
        GET #f, , coreH
        GET #f, , corePlanes
        GET #f, , coreBitCount
        bmpW = coreW
        bmpH = coreH
        planes = corePlanes
        bitCount = coreBitCount
    ELSEIF infoSize >= 40 THEN
        GET #f, , bmpW
        GET #f, , bmpH
        GET #f, , planes
        GET #f, , bitCount
    ELSE
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    CLOSE #f

    IF planes <> 1 THEN RETURN FALSE_VALUE
    IF bitCount <> 1 AND bitCount <> 4 AND bitCount <> 8 AND bitCount <> 16 AND bitCount <> 24 AND bitCount <> 32 THEN RETURN FALSE_VALUE
    IF bmpW <= 0 OR bmpH = 0 THEN RETURN FALSE_VALUE

    w = bmpW
    IF bmpH < 0 THEN
        h = -bmpH
    ELSE
        h = bmpH
    END IF
    bitDepth = bitCount

    RETURN TRUE_VALUE
END FUNCTION

FUNCTION BuildImageInfoText(BYVAL displayPath AS STRING) AS STRING
    DIM bmpW AS INTEGER
    DIM bmpH AS INTEGER
    DIM bitDepth AS INTEGER
    DIM fileBytes AS UINTEGER
    DIM kbText AS STRING

    displayPath = StripQuotes(TRIM$(displayPath))
    IF displayPath = "" THEN RETURN "No image loaded"

    IF ReadBmpFileInfo(displayPath, bmpW, bmpH, bitDepth, fileBytes) = 0 THEN
        RETURN "Image info unavailable"
    END IF

    kbText = LTRIM$(STR$((fileBytes + 1023) \ 1024))
    RETURN "Size: " + LTRIM$(STR$(bmpW)) + "x" + LTRIM$(STR$(bmpH)) + _
           "   Color depth: " + LTRIM$(STR$(bitDepth)) + "-bit" + _
           "   File size: " + kbText + " KB"
END FUNCTION

' ---------------------------
' Viewer state file output
' ---------------------------

FUNCTION WriteImageState(BYVAL cfgPath AS STRING, BYVAL originalPath AS STRING, BYVAL displayPath AS STRING, BYVAL nameText AS STRING, BYVAL infoText AS STRING) AS INTEGER
    DIM f AS INTEGER

    cfgPath = StripQuotes(TRIM$(cfgPath))
    IF cfgPath = "" THEN RETURN FALSE_VALUE

    f = FREEFILE
    IF OPEN(cfgPath FOR OUTPUT AS #f) <> 0 THEN RETURN FALSE_VALUE
    PRINT #f, "PATH=" + originalPath
    PRINT #f, "DISPLAY=" + displayPath
    PRINT #f, "NAME_TEXT=" + nameText
    PRINT #f, "INFO_TEXT=" + infoText
    CLOSE #f

    RETURN TRUE_VALUE
END FUNCTION

' ---------------------------
' Codec dispatch for the normal Image Viewer path
' ---------------------------

FUNCTION ConvertImageSelection(BYVAL sourcePath AS STRING, BYVAL codecPath AS STRING, BYVAL outputBmpPath AS STRING, BYREF displayPath AS STRING) AS INTEGER
    DIM extText AS STRING
    DIM cmdText AS STRING
    DIM bmpW AS INTEGER
    DIM bmpH AS INTEGER
    DIM bitDepth AS INTEGER
    DIM fileBytes AS UINTEGER

    sourcePath = StripQuotes(TRIM$(sourcePath))
    codecPath = StripQuotes(TRIM$(codecPath))
    outputBmpPath = StripQuotes(TRIM$(outputBmpPath))
    displayPath = ""

    IF sourcePath = "" THEN RETURN FALSE_VALUE
    IF FileExists(sourcePath) = 0 THEN RETURN FALSE_VALUE
    IF ImageFileSupported(sourcePath) = 0 THEN RETURN FALSE_VALUE

    extText = FileExtUpper(sourcePath)
    displayPath = sourcePath

    IF codecPath <> "" AND outputBmpPath <> "" THEN
        IF FileExists(outputBmpPath) <> 0 THEN KILL outputBmpPath

        IF FileExists(codecPath) <> 0 THEN
            cmdText = QuoteArg(codecPath) + " " + QuoteArg(sourcePath) + " " + QuoteArg(outputBmpPath) + " >NUL"
            SHELL cmdText

            IF FileExists(outputBmpPath) <> 0 THEN
                IF ReadBmpFileInfo(outputBmpPath, bmpW, bmpH, bitDepth, fileBytes) <> 0 THEN
                    displayPath = outputBmpPath
                ELSE
                    KILL outputBmpPath
                    IF extText <> "BMP" THEN RETURN FALSE_VALUE
                END IF
            ELSEIF extText <> "BMP" THEN
                RETURN FALSE_VALUE
            END IF
        ELSEIF extText <> "BMP" THEN
            RETURN FALSE_VALUE
        END IF
    ELSEIF extText <> "BMP" THEN
        RETURN FALSE_VALUE
    END IF

    RETURN TRUE_VALUE
END FUNCTION

DIM modeText AS STRING
DIM tokenText AS STRING
DIM sourcePath AS STRING
DIM codecPath AS STRING
DIM outputBmpPath AS STRING
DIM cfgPath AS STRING
DIM selectedPath AS STRING
DIM displayPath AS STRING
DIM infoText AS STRING
DIM direction AS INTEGER

modeText = UpperText(StripQuotes(TRIM$(COMMAND(1))))

SELECT CASE modeText
CASE "CLEAR"
    cfgPath = StripQuotes(TRIM$(COMMAND(2)))
    WriteImageState cfgPath, "", "", "", ""

CASE "LOAD"
    sourcePath = StripQuotes(TRIM$(COMMAND(2)))
    codecPath = StripQuotes(TRIM$(COMMAND(3)))
    outputBmpPath = StripQuotes(TRIM$(COMMAND(4)))
    cfgPath = StripQuotes(TRIM$(COMMAND(5)))

    selectedPath = sourcePath
    IF ConvertImageSelection(selectedPath, codecPath, outputBmpPath, displayPath) <> 0 THEN
        infoText = BuildImageInfoText(displayPath)
        WriteImageState cfgPath, selectedPath, displayPath, "Image: " + selectedPath, infoText
    END IF

CASE "KEY"
    tokenText = UpperText(StripQuotes(TRIM$(COMMAND(2))))
    sourcePath = StripQuotes(TRIM$(COMMAND(3)))
    codecPath = StripQuotes(TRIM$(COMMAND(4)))
    outputBmpPath = StripQuotes(TRIM$(COMMAND(5)))
    cfgPath = StripQuotes(TRIM$(COMMAND(6)))

    direction = 0
    IF tokenText = "SPACE" THEN direction = 1
    IF tokenText = "CTRL_SPACE" THEN direction = -1

    IF direction <> 0 THEN
        selectedPath = NextImageInFolder(sourcePath, direction)
        IF selectedPath <> "" THEN
            IF ConvertImageSelection(selectedPath, codecPath, outputBmpPath, displayPath) <> 0 THEN
                infoText = BuildImageInfoText(displayPath)
                WriteImageState cfgPath, selectedPath, displayPath, "Image: " + selectedPath, infoText
            END IF
        END IF
    END IF
END SELECT
