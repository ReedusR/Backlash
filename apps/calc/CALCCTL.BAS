'' CALCCTL.BAS
'' Reads ACTION.TMP and STATE.TMP, writes STATE.TMP and DISPLAY.TMP.
'' DISPLAY.TMP stores the rendered calculator display, including the optional second row.

DECLARE FUNCTION ReadTextFileRaw(BYVAL fileName AS STRING) AS STRING
DECLARE SUB WriteTextFileRaw(BYVAL fileName AS STRING, BYVAL textOut AS STRING)
DECLARE SUB DeleteFileIfPresent(BYVAL fileName AS STRING)
DECLARE FUNCTION IsAbsolutePath(BYVAL fileName AS STRING) AS INTEGER
DECLARE FUNCTION JoinPath(BYVAL leftPath AS STRING, BYVAL rightPath AS STRING) AS STRING
DECLARE FUNCTION AppLocalPath(BYVAL fileName AS STRING) AS STRING
DECLARE FUNCTION StripTrailingLineBreaks(BYVAL textIn AS STRING) AS STRING
DECLARE FUNCTION ReadActionFileToken(BYVAL fileName AS STRING) AS STRING
DECLARE FUNCTION CalcDisplayToExpression(BYVAL displayText AS STRING) AS STRING
DECLARE FUNCTION CalcRightAlignDisplay(BYVAL displayText AS STRING) AS STRING
DECLARE FUNCTION CalcFirstBinaryOperatorPos(BYVAL exprText AS STRING) AS INTEGER
DECLARE FUNCTION CalcDisplayFits(BYVAL exprText AS STRING) AS INTEGER
DECLARE FUNCTION CalcRenderDisplay(BYVAL exprText AS STRING) AS STRING
DECLARE FUNCTION CalcPeek(BYVAL exprText AS STRING, BYVAL scanIdx AS INTEGER) AS STRING
DECLARE SUB CalcSkipSpaces(BYVAL exprText AS STRING, BYREF scanIdx AS INTEGER)
DECLARE FUNCTION CalcParseExpression(BYVAL exprText AS STRING, BYREF scanIdx AS INTEGER, BYREF okFlag AS INTEGER, BYREF errText AS STRING) AS DOUBLE
DECLARE FUNCTION CalcParseTerm(BYVAL exprText AS STRING, BYREF scanIdx AS INTEGER, BYREF okFlag AS INTEGER, BYREF errText AS STRING) AS DOUBLE
DECLARE FUNCTION CalcParsePower(BYVAL exprText AS STRING, BYREF scanIdx AS INTEGER, BYREF okFlag AS INTEGER, BYREF errText AS STRING) AS DOUBLE
DECLARE FUNCTION CalcParseFactor(BYVAL exprText AS STRING, BYREF scanIdx AS INTEGER, BYREF okFlag AS INTEGER, BYREF errText AS STRING) AS DOUBLE
DECLARE FUNCTION CalcEval(BYVAL exprText AS STRING, BYREF resultValue AS DOUBLE, BYREF errText AS STRING) AS INTEGER
DECLARE FUNCTION CalcFormat(BYVAL resultValue AS DOUBLE) AS STRING
DECLARE FUNCTION CalcMapToken(BYVAL tokenText AS STRING) AS STRING
DECLARE FUNCTION CalcApplyFunction(BYVAL funcName AS STRING, BYVAL inputValue AS DOUBLE, BYREF resultValue AS DOUBLE, BYREF errText AS STRING) AS INTEGER
DECLARE SUB CalcAppendToken(BYREF displayText AS STRING, BYVAL tokenText AS STRING)
DECLARE SUB CalcBackspace(BYREF displayText AS STRING)
DECLARE SUB CalcEvaluate(BYREF displayText AS STRING, BYREF statusText AS STRING)
DECLARE SUB CalcApplyDisplayFunction(BYREF displayText AS STRING, BYREF statusText AS STRING, BYVAL funcName AS STRING)
DECLARE SUB CalcSetConstant(BYREF displayText AS STRING, BYREF statusText AS STRING, BYVAL constName AS STRING)
DECLARE SUB CalcProcessAction(BYVAL actionText AS STRING, BYREF displayText AS STRING, BYREF statusText AS STRING, BYREF resultPending AS INTEGER)
DECLARE FUNCTION CalcReadResultPending() AS INTEGER
DECLARE SUB CalcWriteResultPending(BYVAL resultPending AS INTEGER)
DECLARE FUNCTION CalcHistoryListSourceItems(BYVAL historyText AS STRING) AS STRING
DECLARE FUNCTION CalcHistoryListSafeText(BYVAL srcText AS STRING) AS STRING
DECLARE SUB CalcRewriteHistoryApp()
DECLARE SUB CalcAppendHistory(BYVAL exprText AS STRING, BYVAL resultText AS STRING)
DECLARE SUB CalcStoreSwitchState(BYVAL displayText AS STRING, BYVAL resultPending AS INTEGER)
DECLARE SUB CalcRestoreSwitchState(BYREF displayText AS STRING, BYREF resultPending AS INTEGER)
DECLARE FUNCTION CalcSwitchField(BYVAL packedText AS STRING, BYVAL fieldIndex AS INTEGER) AS STRING

CONST ACTION_FILE  = "ACTION.TMP"
CONST DISPLAY_FILE = "DISPLAY.TMP"
CONST STATE_FILE   = "STATE.TMP"
CONST HISTORY_FILE = "HISTORY.TMP"
CONST HISTORY_APP  = "CALCHIST.APP"
CONST RESULT_FILE  = "RESULT.TMP"
CONST SWITCH_FILE  = "SWITCH.TMP"
CONST MAX_DISPLAY_CHARS = 16

FUNCTION IsAbsolutePath(BYVAL fileName AS STRING) AS INTEGER
    DIM cleanName AS STRING

    cleanName = TRIM$(fileName)
    IF cleanName = "" THEN RETURN 0
    IF INSTR(cleanName, ":") > 0 THEN RETURN -1
    IF LEFT$(cleanName, 1) = CHR$(92) THEN RETURN -1
    IF LEFT$(cleanName, 1) = "/" THEN RETURN -1
    RETURN 0
END FUNCTION

FUNCTION JoinPath(BYVAL leftPath AS STRING, BYVAL rightPath AS STRING) AS STRING
    DIM cleanLeft AS STRING
    DIM cleanRight AS STRING

    cleanLeft = TRIM$(leftPath)
    cleanRight = TRIM$(rightPath)
    IF cleanLeft = "" THEN RETURN cleanRight
    IF cleanRight = "" THEN RETURN cleanLeft

    IF RIGHT$(cleanLeft, 1) = CHR$(92) OR RIGHT$(cleanLeft, 1) = "/" THEN
        RETURN cleanLeft + cleanRight
    END IF

    RETURN cleanLeft + CHR$(92) + cleanRight
END FUNCTION

FUNCTION AppLocalPath(BYVAL fileName AS STRING) AS STRING
    DIM cleanName AS STRING
    DIM appDir AS STRING

    cleanName = TRIM$(fileName)
    IF cleanName = "" THEN RETURN ""
    IF IsAbsolutePath(cleanName) <> 0 THEN RETURN cleanName

    ' Keep calculator temp/history files beside CALCCTL.EXE.
    appDir = TRIM$(EXEPATH)
    IF appDir <> "" THEN RETURN JoinPath(appDir, cleanName)
    RETURN cleanName
END FUNCTION

FUNCTION ReadTextFileRaw(BYVAL fileName AS STRING) AS STRING
    DIM fileNum AS INTEGER
    DIM textIn AS STRING

    fileName = AppLocalPath(fileName)
    IF TRIM$(fileName) = "" THEN RETURN ""
    fileNum = FREEFILE
    IF OPEN(fileName FOR BINARY ACCESS READ AS #fileNum) <> 0 THEN RETURN ""

    IF LOF(fileNum) > 0 THEN
        textIn = STRING(LOF(fileNum), 0)
        GET #fileNum, , textIn
    ELSE
        textIn = ""
    END IF

    CLOSE #fileNum
    RETURN StripTrailingLineBreaks(textIn)
END FUNCTION

SUB WriteTextFileRaw(BYVAL fileName AS STRING, BYVAL textOut AS STRING)
    DIM fileNum AS INTEGER

    fileName = AppLocalPath(fileName)
    IF TRIM$(fileName) = "" THEN EXIT SUB
    DeleteFileIfPresent fileName
    fileNum = FREEFILE
    IF OPEN(fileName FOR BINARY ACCESS WRITE AS #fileNum) <> 0 THEN EXIT SUB
    IF LEN(textOut) > 0 THEN PUT #fileNum, , textOut
    CLOSE #fileNum
END SUB

SUB DeleteFileIfPresent(BYVAL fileName AS STRING)
    fileName = AppLocalPath(fileName)
    IF TRIM$(fileName) = "" THEN EXIT SUB
    IF DIR(fileName) <> "" THEN KILL fileName
END SUB

FUNCTION StripTrailingLineBreaks(BYVAL textIn AS STRING) AS STRING
    DO WHILE LEN(textIn) > 0
        IF RIGHT$(textIn, 1) = CHR$(13) OR RIGHT$(textIn, 1) = CHR$(10) THEN
            textIn = LEFT$(textIn, LEN(textIn) - 1)
        ELSE
            EXIT DO
        END IF
    LOOP
    RETURN textIn
END FUNCTION

FUNCTION ReadActionFileToken(BYVAL fileName AS STRING) AS STRING
    DIM rawText AS STRING
    DIM sepPos AS INTEGER

    rawText = ReadTextFileRaw(fileName)
    sepPos = INSTR(rawText, "|")
    IF sepPos > 0 THEN rawText = LEFT$(rawText, sepPos - 1)
    RETURN TRIM$(rawText)
END FUNCTION

FUNCTION CalcDisplayToExpression(BYVAL displayText AS STRING) AS STRING
    DIM i AS INTEGER
    DIM ch AS STRING
    DIM rawText AS STRING

    rawText = ""
    FOR i = 1 TO LEN(displayText)
        ch = MID$(displayText, i, 1)
        IF ch <> " " AND ch <> CHR$(13) AND ch <> CHR$(10) THEN rawText = rawText + ch
    NEXT

    RETURN rawText
END FUNCTION

FUNCTION CalcRightAlignDisplay(BYVAL displayText AS STRING) AS STRING
    IF LEN(displayText) >= MAX_DISPLAY_CHARS THEN RETURN displayText
    RETURN SPACE$(MAX_DISPLAY_CHARS - LEN(displayText)) + displayText
END FUNCTION

FUNCTION CalcFirstBinaryOperatorPos(BYVAL exprText AS STRING) AS INTEGER
    DIM i AS INTEGER
    DIM ch AS STRING
    DIM prevCh AS STRING
    DIM depth AS INTEGER

    depth = 0
    FOR i = 1 TO LEN(exprText)
        ch = MID$(exprText, i, 1)

        IF ch = "(" THEN
            depth = depth + 1
        ELSEIF ch = ")" THEN
            IF depth > 0 THEN depth = depth - 1
        ELSEIF depth = 0 THEN
            IF ch = "+" OR ch = "*" OR ch = "/" THEN RETURN i
            IF ch = "-" AND i > 1 THEN
                prevCh = MID$(exprText, i - 1, 1)
                IF prevCh <> "+" AND prevCh <> "-" AND prevCh <> "*" AND prevCh <> "/" AND prevCh <> "(" AND prevCh <> "^" THEN RETURN i
            END IF
        END IF
    NEXT

    RETURN 0
END FUNCTION

FUNCTION CalcDisplayFits(BYVAL exprText AS STRING) AS INTEGER
    DIM splitPos AS INTEGER
    DIM topText AS STRING
    DIM bottomText AS STRING

    splitPos = CalcFirstBinaryOperatorPos(exprText)
    IF splitPos <= 0 THEN
        IF LEN(exprText) <= MAX_DISPLAY_CHARS THEN RETURN -1
        RETURN 0
    END IF

    topText = LEFT$(exprText, splitPos - 1)
    bottomText = MID$(exprText, splitPos)

    IF LEN(topText) <= MAX_DISPLAY_CHARS AND LEN(bottomText) <= MAX_DISPLAY_CHARS THEN RETURN -1
    RETURN 0
END FUNCTION

FUNCTION CalcRenderDisplay(BYVAL exprText AS STRING) AS STRING
    DIM splitPos AS INTEGER
    DIM topText AS STRING
    DIM bottomText AS STRING

    splitPos = CalcFirstBinaryOperatorPos(exprText)
    IF splitPos <= 0 THEN RETURN CalcRightAlignDisplay(exprText)

    topText = LEFT$(exprText, splitPos - 1)
    bottomText = MID$(exprText, splitPos)
    RETURN CalcRightAlignDisplay(topText) + CHR$(13) + CHR$(10) + CalcRightAlignDisplay(bottomText)
END FUNCTION

FUNCTION CalcPeek(BYVAL exprText AS STRING, BYVAL scanIdx AS INTEGER) AS STRING
    IF scanIdx < 1 OR scanIdx > LEN(exprText) THEN RETURN ""
    RETURN MID$(exprText, scanIdx, 1)
END FUNCTION

SUB CalcSkipSpaces(BYVAL exprText AS STRING, BYREF scanIdx AS INTEGER)
    DO WHILE scanIdx <= LEN(exprText)
        IF MID$(exprText, scanIdx, 1) <> " " THEN EXIT DO
        scanIdx = scanIdx + 1
    LOOP
END SUB

FUNCTION CalcParseExpression(BYVAL exprText AS STRING, BYREF scanIdx AS INTEGER, BYREF okFlag AS INTEGER, BYREF errText AS STRING) AS DOUBLE
    DIM valueLeft AS DOUBLE
    DIM valueRight AS DOUBLE
    DIM opText AS STRING

    valueLeft = CalcParseTerm(exprText, scanIdx, okFlag, errText)
    DO WHILE okFlag <> 0
        CalcSkipSpaces exprText, scanIdx
        opText = CalcPeek(exprText, scanIdx)
        IF opText <> "+" AND opText <> "-" THEN EXIT DO
        scanIdx = scanIdx + 1
        valueRight = CalcParseTerm(exprText, scanIdx, okFlag, errText)
        IF okFlag = 0 THEN EXIT DO
        IF opText = "+" THEN
            valueLeft = valueLeft + valueRight
        ELSE
            valueLeft = valueLeft - valueRight
        END IF
    LOOP

    RETURN valueLeft
END FUNCTION

FUNCTION CalcParseTerm(BYVAL exprText AS STRING, BYREF scanIdx AS INTEGER, BYREF okFlag AS INTEGER, BYREF errText AS STRING) AS DOUBLE
    DIM valueLeft AS DOUBLE
    DIM valueRight AS DOUBLE
    DIM opText AS STRING

    valueLeft = CalcParsePower(exprText, scanIdx, okFlag, errText)
    DO WHILE okFlag <> 0
        CalcSkipSpaces exprText, scanIdx
        opText = CalcPeek(exprText, scanIdx)
        IF opText <> "*" AND opText <> "/" THEN EXIT DO
        scanIdx = scanIdx + 1
        valueRight = CalcParsePower(exprText, scanIdx, okFlag, errText)
        IF okFlag = 0 THEN EXIT DO
        IF opText = "*" THEN
            valueLeft = valueLeft * valueRight
        ELSE
            IF valueRight = 0 THEN
                okFlag = 0
                errText = "Divide by zero"
            ELSE
                valueLeft = valueLeft / valueRight
            END IF
        END IF
    LOOP

    RETURN valueLeft
END FUNCTION

FUNCTION CalcParsePower(BYVAL exprText AS STRING, BYREF scanIdx AS INTEGER, BYREF okFlag AS INTEGER, BYREF errText AS STRING) AS DOUBLE
    DIM valueLeft AS DOUBLE
    DIM valueRight AS DOUBLE

    valueLeft = CalcParseFactor(exprText, scanIdx, okFlag, errText)
    IF okFlag <> 0 THEN
        CalcSkipSpaces exprText, scanIdx
        IF CalcPeek(exprText, scanIdx) = "^" THEN
            scanIdx = scanIdx + 1
            valueRight = CalcParsePower(exprText, scanIdx, okFlag, errText)
            IF okFlag <> 0 THEN valueLeft = valueLeft ^ valueRight
        END IF
    END IF

    RETURN valueLeft
END FUNCTION

FUNCTION CalcParseFactor(BYVAL exprText AS STRING, BYREF scanIdx AS INTEGER, BYREF okFlag AS INTEGER, BYREF errText AS STRING) AS DOUBLE
    DIM ch AS STRING
    DIM startIdx AS INTEGER
    DIM wordText AS STRING
    DIM numText AS STRING
    DIM innerValue AS DOUBLE
    DIM resultValue AS DOUBLE

    CalcSkipSpaces exprText, scanIdx
    ch = CalcPeek(exprText, scanIdx)

    IF ch = "" THEN
        okFlag = 0
        errText = "Missing number"
        RETURN 0
    END IF

    IF ch = "+" THEN
        scanIdx = scanIdx + 1
        RETURN CalcParseFactor(exprText, scanIdx, okFlag, errText)
    END IF

    IF ch = "-" THEN
        scanIdx = scanIdx + 1
        RETURN -CalcParseFactor(exprText, scanIdx, okFlag, errText)
    END IF

    IF ch = "(" THEN
        scanIdx = scanIdx + 1
        innerValue = CalcParseExpression(exprText, scanIdx, okFlag, errText)
        IF okFlag = 0 THEN RETURN 0

        CalcSkipSpaces exprText, scanIdx
        IF CalcPeek(exprText, scanIdx) <> ")" THEN
            okFlag = 0
            errText = "Missing )"
            RETURN 0
        END IF

        scanIdx = scanIdx + 1
        RETURN innerValue
    END IF

    IF (UCASE$(ch) >= "A" AND UCASE$(ch) <= "Z") THEN
        startIdx = scanIdx
        DO WHILE scanIdx <= LEN(exprText)
            ch = UCASE$(CalcPeek(exprText, scanIdx))
            IF ch < "A" OR ch > "Z" THEN EXIT DO
            scanIdx = scanIdx + 1
        LOOP

        wordText = UCASE$(MID$(exprText, startIdx, scanIdx - startIdx))
        IF wordText = "PI" THEN RETURN ATN(1) * 4
        IF wordText = "E" THEN RETURN EXP(1)

        CalcSkipSpaces exprText, scanIdx
        IF CalcPeek(exprText, scanIdx) = "(" THEN
            scanIdx = scanIdx + 1
            innerValue = CalcParseExpression(exprText, scanIdx, okFlag, errText)
            IF okFlag = 0 THEN RETURN 0

            CalcSkipSpaces exprText, scanIdx
            IF CalcPeek(exprText, scanIdx) <> ")" THEN
                okFlag = 0
                errText = "Missing )"
                RETURN 0
            END IF

            scanIdx = scanIdx + 1
            IF CalcApplyFunction(wordText, innerValue, resultValue, errText) = 0 THEN
                okFlag = 0
                RETURN 0
            END IF

            RETURN resultValue
        END IF

        okFlag = 0
        errText = "Unknown name"
        RETURN 0
    END IF

    IF (ch >= "0" AND ch <= "9") OR ch = "." THEN
        startIdx = scanIdx
        DO WHILE scanIdx <= LEN(exprText)
            ch = CalcPeek(exprText, scanIdx)
            IF (ch >= "0" AND ch <= "9") OR ch = "." THEN
                scanIdx = scanIdx + 1
            ELSE
                EXIT DO
            END IF
        LOOP

        numText = MID$(exprText, startIdx, scanIdx - startIdx)
        RETURN VAL(numText)
    END IF

    okFlag = 0
    errText = "Bad character"
    RETURN 0
END FUNCTION

FUNCTION CalcEval(BYVAL exprText AS STRING, BYREF resultValue AS DOUBLE, BYREF errText AS STRING) AS INTEGER
    DIM scanIdx AS INTEGER
    DIM okFlag AS INTEGER

    exprText = TRIM$(exprText)
    IF exprText = "" THEN
        resultValue = 0
        errText = ""
        RETURN -1
    END IF

    scanIdx = 1
    okFlag = -1
    errText = ""
    resultValue = CalcParseExpression(exprText, scanIdx, okFlag, errText)
    IF okFlag = 0 THEN RETURN 0

    CalcSkipSpaces exprText, scanIdx
    IF scanIdx <= LEN(exprText) THEN
        errText = "Extra input"
        RETURN 0
    END IF

    RETURN -1
END FUNCTION

FUNCTION CalcFormat(BYVAL resultValue AS DOUBLE) AS STRING
    DIM textOut AS STRING

    textOut = LTRIM$(STR$(resultValue))
    IF textOut = "-0" THEN textOut = "0"
    RETURN textOut
END FUNCTION

FUNCTION CalcMapToken(BYVAL tokenText AS STRING) AS STRING
    tokenText = UCASE$(TRIM$(tokenText))

    SELECT CASE tokenText
    CASE "PLUS"
        RETURN "+"
    CASE "MINUS"
        RETURN "-"
    CASE "STAR", "ASTERISK", "MULTIPLY"
        RETURN "*"
    CASE "SLASH", "DIVIDE"
        RETURN "/"
    CASE "DOT", "DECIMAL"
        RETURN "."
    CASE "LPAREN"
        RETURN "("
    CASE "RPAREN"
        RETURN ")"
    CASE "POW"
        RETURN "^"
    CASE ELSE
        RETURN TRIM$(tokenText)
    END SELECT
END FUNCTION

FUNCTION CalcApplyFunction(BYVAL funcName AS STRING, BYVAL inputValue AS DOUBLE, BYREF resultValue AS DOUBLE, BYREF errText AS STRING) AS INTEGER
    DIM piValue AS DOUBLE

    funcName = UCASE$(TRIM$(funcName))
    piValue = ATN(1) * 4
    errText = ""

    SELECT CASE funcName
    CASE "SIN"
        resultValue = SIN(inputValue * piValue / 180)
    CASE "COS"
        resultValue = COS(inputValue * piValue / 180)
    CASE "TAN"
        resultValue = TAN(inputValue * piValue / 180)
    CASE "SQRT", "SQR"
        IF inputValue < 0 THEN
            errText = "Invalid input"
            RETURN 0
        END IF
        resultValue = SQR(inputValue)
    CASE "SQUARE", "X2"
        resultValue = inputValue * inputValue
    CASE "RECIP", "INV"
        IF inputValue = 0 THEN
            errText = "Divide by zero"
            RETURN 0
        END IF
        resultValue = 1 / inputValue
    CASE "LOG"
        IF inputValue <= 0 THEN
            errText = "Invalid input"
            RETURN 0
        END IF
        resultValue = LOG(inputValue) / LOG(10)
    CASE "LN"
        IF inputValue <= 0 THEN
            errText = "Invalid input"
            RETURN 0
        END IF
        resultValue = LOG(inputValue)
    CASE "NEG"
        resultValue = -inputValue
    CASE ELSE
        errText = "Unknown function"
        RETURN 0
    END SELECT

    RETURN -1
END FUNCTION

SUB CalcAppendToken(BYREF displayText AS STRING, BYVAL tokenText AS STRING)
    DIM appendText AS STRING
    DIM nextText AS STRING

    appendText = CalcMapToken(tokenText)
    IF appendText = "" THEN EXIT SUB

    nextText = displayText
    IF nextText = "0" THEN
        IF appendText >= "0" AND appendText <= "9" THEN nextText = ""
    END IF

    nextText = nextText + appendText
    IF CalcDisplayFits(nextText) = 0 THEN EXIT SUB

    displayText = nextText
END SUB

SUB CalcBackspace(BYREF displayText AS STRING)
    IF LEN(displayText) > 0 THEN
        displayText = LEFT$(displayText, LEN(displayText) - 1)
    END IF
END SUB

SUB CalcEvaluate(BYREF displayText AS STRING, BYREF statusText AS STRING)
    DIM resultValue AS DOUBLE
    DIM errText AS STRING
    DIM sourceText AS STRING
    DIM resultText AS STRING

    sourceText = displayText
    IF CalcEval(sourceText, resultValue, errText) <> 0 THEN
        resultText = CalcFormat(resultValue)
        CalcAppendHistory sourceText, resultText
        displayText = resultText
        statusText = ""
    ELSE
        displayText = sourceText
        statusText = errText
    END IF
END SUB

SUB CalcApplyDisplayFunction(BYREF displayText AS STRING, BYREF statusText AS STRING, BYVAL funcName AS STRING)
    DIM inputValue AS DOUBLE
    DIM resultValue AS DOUBLE
    DIM errText AS STRING
    DIM sourceText AS STRING

    sourceText = displayText
    IF CalcEval(sourceText, inputValue, errText) = 0 THEN
        displayText = sourceText
        statusText = errText
        EXIT SUB
    END IF

    IF CalcApplyFunction(funcName, inputValue, resultValue, errText) <> 0 THEN
        displayText = CalcFormat(resultValue)
        statusText = ""
    ELSE
        displayText = sourceText
        statusText = errText
    END IF
END SUB

SUB CalcSetConstant(BYREF displayText AS STRING, BYREF statusText AS STRING, BYVAL constName AS STRING)
    constName = UCASE$(TRIM$(constName))

    SELECT CASE constName
    CASE "PI"
        displayText = CalcFormat(ATN(1) * 4)
        statusText = ""
    CASE "E"
        displayText = CalcFormat(EXP(1))
        statusText = ""
    END SELECT
END SUB

FUNCTION CalcReadResultPending() AS INTEGER
    IF ReadTextFileRaw(RESULT_FILE) = "1" THEN RETURN -1
    RETURN 0
END FUNCTION

SUB CalcWriteResultPending(BYVAL resultPending AS INTEGER)
    IF resultPending <> 0 THEN
        WriteTextFileRaw RESULT_FILE, "1"
    ELSE
        DeleteFileIfPresent RESULT_FILE
    END IF
END SUB

FUNCTION CalcHistoryListSafeText(BYVAL srcText AS STRING) AS STRING
    DIM i AS INTEGER
    DIM ch AS STRING
    DIM outText AS STRING

    outText = ""
    FOR i = 1 TO LEN(srcText)
        ch = MID$(srcText, i, 1)
        IF ch = "|" OR ch = CHR$(1) OR ch = CHR$(13) OR ch = CHR$(10) THEN
            outText = outText + " "
        ELSE
            outText = outText + ch
        END IF
    NEXT

    RETURN TRIM$(outText)
END FUNCTION

FUNCTION CalcHistoryListSourceItems(BYVAL historyText AS STRING) AS STRING
    DIM outText AS STRING
    DIM scanPos AS INTEGER
    DIM lineEnd AS INTEGER
    DIM rawLine AS STRING
    DIM itemText AS STRING
    DIM sepPos AS INTEGER

    outText = ""
    scanPos = 1

    DO WHILE scanPos <= LEN(historyText)
        lineEnd = scanPos
        DO WHILE lineEnd <= LEN(historyText)
            IF MID$(historyText, lineEnd, 1) = CHR$(13) OR MID$(historyText, lineEnd, 1) = CHR$(10) THEN EXIT DO
            lineEnd = lineEnd + 1
        LOOP

        rawLine = MID$(historyText, scanPos, lineEnd - scanPos)
        sepPos = INSTR(rawLine, "|")
        IF sepPos > 0 THEN rawLine = LEFT$(rawLine, sepPos - 1)
        itemText = CalcHistoryListSafeText(rawLine)

        IF itemText <> "" THEN
            IF outText <> "" THEN outText = outText + "|"
            outText = outText + itemText + CHR$(1) + itemText
        END IF

        scanPos = lineEnd
        DO WHILE scanPos <= LEN(historyText)
            IF MID$(historyText, scanPos, 1) <> CHR$(13) AND MID$(historyText, scanPos, 1) <> CHR$(10) THEN EXIT DO
            scanPos = scanPos + 1
        LOOP
    LOOP

    RETURN outText
END FUNCTION

SUB CalcRewriteHistoryApp()
    DIM appText AS STRING
    DIM sourceItems AS STRING

    sourceItems = CalcHistoryListSourceItems(ReadTextFileRaw(HISTORY_FILE))

    appText = "title=Calculator History" + CHR$(13) + CHR$(10)
    appText = appText + "ui=LAYOUT" + CHR$(13) + CHR$(10)
    appText = appText + "single_instance=1" + CHR$(13) + CHR$(10)
    appText = appText + "resizable=0" + CHR$(13) + CHR$(10) + CHR$(13) + CHR$(10)
    appText = appText + "[WINDOW]" + CHR$(13) + CHR$(10)
    appText = appText + "X=460" + CHR$(13) + CHR$(10)
    appText = appText + "Y=70" + CHR$(13) + CHR$(10)
    appText = appText + "W=320" + CHR$(13) + CHR$(10)
    appText = appText + "H=228" + CHR$(13) + CHR$(10) + CHR$(13) + CHR$(10)
    appText = appText + "[LISTBOX]" + CHR$(13) + CHR$(10)
    appText = appText + "NAME=CALC_HISTORY" + CHR$(13) + CHR$(10)
    appText = appText + "X=12" + CHR$(13) + CHR$(10)
    appText = appText + "Y=12" + CHR$(13) + CHR$(10)
    appText = appText + "W=296" + CHR$(13) + CHR$(10)
    appText = appText + "H=180" + CHR$(13) + CHR$(10)
    appText = appText + "SOURCE_ITEMS=" + sourceItems + CHR$(13) + CHR$(10)

    WriteTextFileRaw HISTORY_APP, appText
END SUB

SUB CalcAppendHistory(BYVAL exprText AS STRING, BYVAL resultText AS STRING)
    DIM historyText AS STRING
    DIM lineText AS STRING

    exprText = TRIM$(exprText)
    resultText = TRIM$(resultText)
    IF exprText = "" THEN exprText = "0"
    IF resultText = "" THEN EXIT SUB

    historyText = ReadTextFileRaw(HISTORY_FILE)
    lineText = exprText + " = " + resultText

    IF historyText <> "" THEN historyText = historyText + CHR$(13) + CHR$(10)
    historyText = historyText + lineText + "|" + lineText
    WriteTextFileRaw HISTORY_FILE, historyText
    CalcRewriteHistoryApp
END SUB

FUNCTION CalcSwitchField(BYVAL packedText AS STRING, BYVAL fieldIndex AS INTEGER) AS STRING
    DIM curField AS INTEGER
    DIM startPos AS INTEGER
    DIM sepPos AS INTEGER
    DIM sepText AS STRING

    IF fieldIndex < 1 THEN RETURN ""

    sepText = CHR$(30)
    startPos = 1

    FOR curField = 1 TO fieldIndex
        sepPos = INSTR(startPos, packedText, sepText)
        IF curField = fieldIndex THEN
            IF sepPos <= 0 THEN RETURN MID$(packedText, startPos)
            RETURN MID$(packedText, startPos, sepPos - startPos)
        END IF

        IF sepPos <= 0 THEN RETURN ""
        startPos = sepPos + LEN(sepText)
    NEXT

    RETURN ""
END FUNCTION

SUB CalcStoreSwitchState(BYVAL displayText AS STRING, BYVAL resultPending AS INTEGER)
    DIM packedText AS STRING
    DIM sepText AS STRING
    DIM pendingText AS STRING

    sepText = CHR$(30)
    IF resultPending <> 0 THEN
        pendingText = "1"
    ELSE
        pendingText = "0"
    END IF

    packedText = displayText + sepText + ReadTextFileRaw(HISTORY_FILE) + sepText + pendingText
    WriteTextFileRaw SWITCH_FILE, packedText
END SUB

SUB CalcRestoreSwitchState(BYREF displayText AS STRING, BYREF resultPending AS INTEGER)
    DIM packedText AS STRING
    DIM historyText AS STRING
    DIM pendingText AS STRING

    packedText = ReadTextFileRaw(SWITCH_FILE)
    IF packedText = "" THEN EXIT SUB

    displayText = CalcSwitchField(packedText, 1)
    historyText = CalcSwitchField(packedText, 2)
    pendingText = CalcSwitchField(packedText, 3)

    IF historyText <> "" THEN
        WriteTextFileRaw HISTORY_FILE, historyText
    ELSE
        DeleteFileIfPresent HISTORY_FILE
    END IF

    IF pendingText = "1" THEN
        resultPending = -1
    ELSE
        resultPending = 0
    END IF

    DeleteFileIfPresent SWITCH_FILE
END SUB

SUB CalcProcessAction(BYVAL actionText AS STRING, BYREF displayText AS STRING, BYREF statusText AS STRING, BYREF resultPending AS INTEGER)
    actionText = UCASE$(TRIM$(actionText))

    SELECT CASE actionText
    CASE "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", _
         "DOT", "PLUS", "MINUS", "STAR", "SLASH", "LPAREN", "RPAREN"
        IF resultPending <> 0 THEN
            SELECT CASE actionText
            CASE "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "DOT", "LPAREN"
                displayText = ""
            END SELECT
        END IF
        CalcAppendToken displayText, actionText
        resultPending = 0
        statusText = ""

    CASE "BACK"
        CalcBackspace displayText
        resultPending = 0
        statusText = ""

    CASE "CLEAR"
        displayText = ""
        resultPending = 0
        statusText = ""

    CASE "EQUALS"
        CalcEvaluate displayText, statusText
        IF statusText = "" THEN
            resultPending = -1
        ELSE
            resultPending = 0
        END IF

    CASE "SIN", "COS", "TAN", "SQRT", "SQUARE", "RECIP", "LOG", "LN", "NEG"
        CalcApplyDisplayFunction displayText, statusText, actionText

    CASE "PI", "E"
        CalcSetConstant displayText, statusText, actionText

    CASE "HISTAPP"
        CalcRewriteHistoryApp
        statusText = ""

    CASE "SWITCH_OUT"
        CalcStoreSwitchState displayText, resultPending
        statusText = ""

    CASE "SWITCH_IN"
        CalcRestoreSwitchState displayText, resultPending
        statusText = ""

    CASE "SYNC"
        statusText = ""

    CASE ELSE
        statusText = "Unknown action"
    END SELECT
END SUB

DIM actionText AS STRING
DIM displayText AS STRING
DIM statusText AS STRING
DIM resultPending AS INTEGER

DeleteFileIfPresent "ACTION.TXT"
DeleteFileIfPresent "DISPLAY.TXT"
DeleteFileIfPresent "STATUS.TXT"

actionText = ReadActionFileToken(ACTION_FILE)
IF UCASE$(TRIM$(actionText)) <> "SWITCH_OUT" AND UCASE$(TRIM$(actionText)) <> "SWITCH_IN" THEN DeleteFileIfPresent SWITCH_FILE
IF DIR(AppLocalPath(STATE_FILE)) <> "" THEN
    displayText = ReadTextFileRaw(STATE_FILE)
ELSE
    displayText = CalcDisplayToExpression(ReadTextFileRaw(DISPLAY_FILE))
END IF
statusText = ""
resultPending = CalcReadResultPending()

CalcProcessAction actionText, displayText, statusText, resultPending

WriteTextFileRaw STATE_FILE, displayText
WriteTextFileRaw DISPLAY_FILE, CalcRenderDisplay(displayText)
CalcWriteResultPending resultPending
