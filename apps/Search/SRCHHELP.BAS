' Archive Manager helper source. It calls archive tools and prepares lists or reports for the app.
'
' SRCHHELP.BAS
' Backlash GUI Search helper
' Compile: FBC -lang fb SRCHHELP.BAS

CONST ATTR_DIRECTORY = 16
CONST ATTR_ANY = 55
CONST MAX_SUBDIRS = 512
CONST MAX_RESULTS = 200

DIM SHARED results(1 TO MAX_RESULTS) AS STRING
DIM SHARED resultCount AS INTEGER
DIM SHARED totalMatches AS LONG
DIM SHARED dirsChecked AS LONG
DIM SHARED filesChecked AS LONG
DIM SHARED truncatedResults AS INTEGER

DECLARE FUNCTION StripOuterQuotes(BYVAL s AS STRING) AS STRING
DECLARE FUNCTION ReadCfgValue(BYVAL fileName AS STRING, BYVAL keyName AS STRING, BYVAL defaultValue AS STRING) AS STRING
DECLARE FUNCTION ConfigValue(BYVAL keyName AS STRING, BYVAL defaultValue AS STRING) AS STRING
DECLARE FUNCTION JoinPath(BYVAL leftPart AS STRING, BYVAL rightPart AS STRING) AS STRING
DECLARE FUNCTION NormalizeDir(BYVAL s AS STRING) AS STRING
DECLARE FUNCTION IsYesValue(BYVAL s AS STRING) AS INTEGER
DECLARE FUNCTION WildMatchAt(BYVAL patternText AS STRING, BYVAL targetText AS STRING, BYVAL pi AS INTEGER, BYVAL ti AS INTEGER) AS INTEGER
DECLARE FUNCTION WildMatch(BYVAL patternText AS STRING, BYVAL targetText AS STRING) AS INTEGER
DECLARE SUB AddResult(BYVAL filePath AS STRING)
DECLARE SUB SearchDirectory(BYVAL baseDir AS STRING, BYVAL maskText AS STRING, BYVAL recurseFlag AS INTEGER)
DECLARE FUNCTION OpenResultsAppFile(BYREF resultName AS STRING) AS INTEGER
DECLARE SUB WriteResultsApp(BYVAL startDir AS STRING, BYVAL maskText AS STRING, BYVAL recurseFlag AS INTEGER)

' ---------------------------
' Config and path helpers
' ---------------------------

FUNCTION StripOuterQuotes(BYVAL s AS STRING) AS STRING
    s = TRIM$(s)
    IF LEN(s) >= 2 THEN
        IF LEFT$(s, 1) = CHR$(34) AND RIGHT$(s, 1) = CHR$(34) THEN
            RETURN MID$(s, 2, LEN(s) - 2)
        END IF
    END IF
    RETURN s
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
                    v = StripOuterQuotes(TRIM$(MID$(lineIn, p + 1)))
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

FUNCTION ConfigValue(BYVAL keyName AS STRING, BYVAL defaultValue AS STRING) AS STRING
    DIM v AS STRING

    v = ReadCfgValue("SYSTEM\SEARCH.CFG", keyName, "")
    IF v <> "" THEN RETURN v

    v = ReadCfgValue("\SYSTEM\SEARCH.CFG", keyName, "")
    IF v <> "" THEN RETURN v

    v = ReadCfgValue("..\..\SYSTEM\SEARCH.CFG", keyName, "")
    IF v <> "" THEN RETURN v

    v = ReadCfgValue("SEARCH.CFG", keyName, "")
    IF v <> "" THEN RETURN v

    RETURN defaultValue
END FUNCTION

FUNCTION JoinPath(BYVAL leftPart AS STRING, BYVAL rightPart AS STRING) AS STRING
    leftPart = TRIM$(leftPart)
    rightPart = TRIM$(rightPart)

    IF leftPart = "" THEN RETURN rightPart
    IF RIGHT$(leftPart, 1) = "\" THEN RETURN leftPart + rightPart
    IF RIGHT$(leftPart, 1) = ":" THEN RETURN leftPart + "\" + rightPart

    RETURN leftPart + "\" + rightPart
END FUNCTION

FUNCTION NormalizeDir(BYVAL s AS STRING) AS STRING
    s = StripOuterQuotes(TRIM$(s))
    IF s = "" THEN s = "."

    DO WHILE LEN(s) > 1 AND RIGHT$(s, 1) = "\"
        IF LEN(s) = 3 AND MID$(s, 2, 1) = ":" THEN EXIT DO
        s = LEFT$(s, LEN(s) - 1)
    LOOP

    RETURN s
END FUNCTION

FUNCTION IsYesValue(BYVAL s AS STRING) AS INTEGER
    s = UCASE$(TRIM$(StripOuterQuotes(s)))
    IF s = "Y" THEN RETURN -1
    IF s = "YES" THEN RETURN -1
    IF s = "1" THEN RETURN -1
    IF s = "TRUE" THEN RETURN -1
    IF s = "ON" THEN RETURN -1
    RETURN 0
END FUNCTION

' ---------------------------
' Wildcard matching
' ---------------------------

FUNCTION WildMatchAt(BYVAL patternText AS STRING, BYVAL targetText AS STRING, BYVAL pi AS INTEGER, BYVAL ti AS INTEGER) AS INTEGER
    DIM pc AS STRING
    DIM tc AS STRING
    DIM k AS INTEGER

    DO
        IF pi > LEN(patternText) THEN
            IF ti > LEN(targetText) THEN RETURN -1
            RETURN 0
        END IF

        pc = MID$(patternText, pi, 1)

        IF pc = "*" THEN
            DO WHILE pi <= LEN(patternText) AND MID$(patternText, pi, 1) = "*"
                pi = pi + 1
            LOOP

            IF pi > LEN(patternText) THEN RETURN -1

            FOR k = ti TO LEN(targetText) + 1
                IF WildMatchAt(patternText, targetText, pi, k) <> 0 THEN RETURN -1
            NEXT k

            RETURN 0
        ELSEIF pc = "?" THEN
            IF ti > LEN(targetText) THEN RETURN 0
            pi = pi + 1
            ti = ti + 1
        ELSE
            IF ti > LEN(targetText) THEN RETURN 0
            tc = MID$(targetText, ti, 1)
            IF pc <> tc THEN RETURN 0
            pi = pi + 1
            ti = ti + 1
        END IF
    LOOP
END FUNCTION

FUNCTION WildMatch(BYVAL patternText AS STRING, BYVAL targetText AS STRING) AS INTEGER
    patternText = UCASE$(TRIM$(patternText))
    targetText = UCASE$(TRIM$(targetText))

    IF patternText = "" THEN patternText = "*.*"
    RETURN WildMatchAt(patternText, targetText, 1, 1)
END FUNCTION

' ---------------------------
' Result collection and recursive search
' ---------------------------

SUB AddResult(BYVAL filePath AS STRING)
    totalMatches = totalMatches + 1

    IF resultCount < MAX_RESULTS THEN
        resultCount = resultCount + 1
        results(resultCount) = filePath
    ELSE
        truncatedResults = -1
    END IF
END SUB

SUB SearchDirectory(BYVAL baseDir AS STRING, BYVAL maskText AS STRING, BYVAL recurseFlag AS INTEGER)
    DIM entryName AS STRING
    DIM fullName AS STRING
    DIM attrVal AS INTEGER
    DIM subDirs(1 TO MAX_SUBDIRS) AS STRING
    DIM subCount AS INTEGER
    DIM i AS INTEGER

    baseDir = NormalizeDir(baseDir)
    dirsChecked = dirsChecked + 1
    subCount = 0

    entryName = DIR(JoinPath(baseDir, "*.*"), ATTR_ANY, attrVal)

    DO WHILE entryName <> ""
        IF entryName <> "." AND entryName <> ".." THEN
            fullName = JoinPath(baseDir, entryName)
            IF (attrVal AND ATTR_DIRECTORY) <> 0 THEN
                IF recurseFlag <> 0 THEN
                    IF subCount < MAX_SUBDIRS THEN
                        subCount = subCount + 1
                        subDirs(subCount) = fullName
                    END IF
                END IF
            ELSE
                filesChecked = filesChecked + 1
                IF WildMatch(maskText, entryName) <> 0 THEN
                    AddResult fullName
                END IF
            END IF
        END IF

        entryName = DIR(attrVal)
    LOOP

    IF recurseFlag <> 0 THEN
        FOR i = 1 TO subCount
            SearchDirectory subDirs(i), maskText, recurseFlag
        NEXT i
    END IF
END SUB

' ---------------------------
' Result APP file generation
' ---------------------------

FUNCTION OpenResultsAppFile(BYREF resultName AS STRING) AS INTEGER
    DIM f AS INTEGER

    f = FREEFILE
    resultName = "APPS\SEARCH\SRCHRES.APP"
    IF OPEN(resultName FOR OUTPUT AS #f) = 0 THEN RETURN f

    f = FREEFILE
    resultName = "\APPS\SEARCH\SRCHRES.APP"
    IF OPEN(resultName FOR OUTPUT AS #f) = 0 THEN RETURN f

    f = FREEFILE
    resultName = "SRCHRES.APP"
    IF OPEN(resultName FOR OUTPUT AS #f) = 0 THEN RETURN f

    RETURN 0
END FUNCTION

SUB WriteResultsApp(BYVAL startDir AS STRING, BYVAL maskText AS STRING, BYVAL recurseFlag AS INTEGER)
    DIM f AS INTEGER
    DIM appPath AS STRING
    DIM i AS INTEGER
    DIM labelText AS STRING
    DIM itemText AS STRING

    f = OpenResultsAppFile(appPath)
    IF f = 0 THEN EXIT SUB

    labelText = LTRIM$(STR$(totalMatches)) + " match(es) for " + maskText + " in " + startDir
    IF truncatedResults <> 0 THEN
        labelText = labelText + " - showing first " + LTRIM$(STR$(MAX_RESULTS))
    END IF

    PRINT #f, "title=Search Results"
    PRINT #f, "ui=LAYOUT"
    PRINT #f, "single_instance=0"
    PRINT #f, "resizable=1"
    PRINT #f, "CONTEXT_OPEN_TEXT=Open"
    PRINT #f, "CONTEXT_EDIT_TEXT=Edit"
    PRINT #f, "CONTEXT_CUT_TEXT=Cut"
    PRINT #f, "CONTEXT_CUT_ACTION=EXPLORER_FILE_CUT"
    PRINT #f, "CONTEXT_COPY_TEXT=Copy"
    PRINT #f, "CONTEXT_COPY_ACTION=EXPLORER_FILE_COPY"
    PRINT #f, "CONTEXT_PASTE_TEXT=Paste"
    PRINT #f, "CONTEXT_PASTE_ACTION=EXPLORER_FILE_PASTE DEST_PATH STATUS_BOX"
    PRINT #f, ""
    PRINT #f, "[WINDOW]"
    PRINT #f, "X=70"
    PRINT #f, "Y=60"
    PRINT #f, "W=620"
    PRINT #f, "H=390"
    PRINT #f, ""
    PRINT #f, "[LABEL]"
    PRINT #f, "TEXT=" + labelText
    PRINT #f, "X=8"
    PRINT #f, "Y=8"
    PRINT #f, ""
    PRINT #f, "[LISTBOX]"
    PRINT #f, "NAME=FILE_VIEW"
    PRINT #f, "X=8"
    PRINT #f, "Y=28"
    PRINT #f, "W=604"
    PRINT #f, "H=260"
    PRINT #f, "MULTISELECT=1"
    PRINT #f, "ACTION=EXPLORER_FILE_SELECT FILE_VIEW STATUS_BOX"
    PRINT #f, "CONTEXT_ITEMS=Open=EXPLORER_FILE_OPEN FILE_VIEW STATUS_BOX|Edit=EXPLORER_FILE_EDIT FILE_VIEW STATUS_BOX|Cut=EXPLORER_FILE_CUT FILE_VIEW STATUS_BOX|Copy=EXPLORER_FILE_COPY FILE_VIEW STATUS_BOX|Paste=EXPLORER_FILE_PASTE DEST_PATH STATUS_BOX"
    PRINT #f, "SOURCE_ITEMS=";
    FOR i = 1 TO resultCount
        IF i > 1 THEN PRINT #f, "|";
        itemText = results(i)
        PRINT #f, itemText + "=F:" + itemText;
    NEXT i
    PRINT #f, ""
    PRINT #f, ""
    PRINT #f, "[LABEL]"
    PRINT #f, "TEXT=Paste to:"
    PRINT #f, "X=8"
    PRINT #f, "Y=302"
    PRINT #f, ""
    PRINT #f, "[TEXTBOX]"
    PRINT #f, "NAME=DEST_PATH"
    PRINT #f, "X=72"
    PRINT #f, "Y=298"
    PRINT #f, "W=312"
    PRINT #f, "H=22"
    PRINT #f, "TEXT=" + startDir
    PRINT #f, ""
    PRINT #f, "[BUTTON]"
    PRINT #f, "NAME=OPEN_BTN"
    PRINT #f, "TEXT=Open"
    PRINT #f, "X=8"
    PRINT #f, "Y=330"
    PRINT #f, "W=64"
    PRINT #f, "H=22"
    PRINT #f, "ACTION=EXPLORER_FILE_OPEN FILE_VIEW STATUS_BOX"
    PRINT #f, ""
    PRINT #f, "[BUTTON]"
    PRINT #f, "NAME=EDIT_BTN"
    PRINT #f, "TEXT=Edit"
    PRINT #f, "X=78"
    PRINT #f, "Y=330"
    PRINT #f, "W=64"
    PRINT #f, "H=22"
    PRINT #f, "ACTION=EXPLORER_FILE_EDIT FILE_VIEW STATUS_BOX"
    PRINT #f, ""
    PRINT #f, "[BUTTON]"
    PRINT #f, "NAME=CUT_BTN"
    PRINT #f, "TEXT=Cut"
    PRINT #f, "X=148"
    PRINT #f, "Y=330"
    PRINT #f, "W=64"
    PRINT #f, "H=22"
    PRINT #f, "ACTION=EXPLORER_FILE_CUT FILE_VIEW STATUS_BOX"
    PRINT #f, ""
    PRINT #f, "[BUTTON]"
    PRINT #f, "NAME=COPY_BTN"
    PRINT #f, "TEXT=Copy"
    PRINT #f, "X=218"
    PRINT #f, "Y=330"
    PRINT #f, "W=64"
    PRINT #f, "H=22"
    PRINT #f, "ACTION=EXPLORER_FILE_COPY FILE_VIEW STATUS_BOX"
    PRINT #f, ""
    PRINT #f, "[BUTTON]"
    PRINT #f, "NAME=PASTE_BTN"
    PRINT #f, "TEXT=Paste"
    PRINT #f, "X=288"
    PRINT #f, "Y=330"
    PRINT #f, "W=64"
    PRINT #f, "H=22"
    PRINT #f, "ACTION=EXPLORER_FILE_PASTE DEST_PATH STATUS_BOX"
    PRINT #f, ""
    PRINT #f, "[BUTTON]"
    PRINT #f, "NAME=CLOSE_BTN"
    PRINT #f, "TEXT=Close"
    PRINT #f, "X=540"
    PRINT #f, "Y=330"
    PRINT #f, "W=72"
    PRINT #f, "H=22"
    PRINT #f, "ACTION=CLOSE_WINDOW"
    PRINT #f, ""
    PRINT #f, "[TEXTBOX]"
    PRINT #f, "NAME=STATUS_BOX"
    PRINT #f, "X=8"
    PRINT #f, "Y=360"
    PRINT #f, "W=604"
    PRINT #f, "H=22"
    PRINT #f, "TEXT=Directories: " + LTRIM$(STR$(dirsChecked)) + "  Files: " + LTRIM$(STR$(filesChecked)) + "  Matches: " + LTRIM$(STR$(totalMatches))
    PRINT #f, "READONLY=1"
    PRINT #f, ""
    PRINT #f, "[EVENTS]"
    PRINT #f, "ON CHANGE FILE_VIEW"
    PRINT #f, "    HOST EXPLORER_FILE_SELECT FILE_VIEW STATUS_BOX"
    PRINT #f, "END"
    PRINT #f, ""
    PRINT #f, "ON DBLCLICK FILE_VIEW"
    PRINT #f, "    HOST EXPLORER_FILE_OPEN FILE_VIEW STATUS_BOX"
    PRINT #f, "END"
    PRINT #f, ""
    PRINT #f, "ON ACTION EXPLORER_FILE_OPEN FILE_VIEW STATUS_BOX"
    PRINT #f, "    HOST EXPLORER_FILE_OPEN FILE_VIEW STATUS_BOX"
    PRINT #f, "END"
    PRINT #f, ""
    PRINT #f, "ON ACTION EXPLORER_FILE_EDIT FILE_VIEW STATUS_BOX"
    PRINT #f, "    HOST EXPLORER_FILE_EDIT FILE_VIEW STATUS_BOX"
    PRINT #f, "END"
    PRINT #f, ""
    PRINT #f, "ON ACTION EXPLORER_FILE_CUT FILE_VIEW STATUS_BOX"
    PRINT #f, "    HOST EXPLORER_FILE_CUT FILE_VIEW STATUS_BOX"
    PRINT #f, "END"
    PRINT #f, ""
    PRINT #f, "ON ACTION EXPLORER_FILE_COPY FILE_VIEW STATUS_BOX"
    PRINT #f, "    HOST EXPLORER_FILE_COPY FILE_VIEW STATUS_BOX"
    PRINT #f, "END"
    PRINT #f, ""
    PRINT #f, "ON ACTION EXPLORER_FILE_PASTE DEST_PATH STATUS_BOX"
    PRINT #f, "    HOST EXPLORER_FILE_PASTE DEST_PATH STATUS_BOX"
    PRINT #f, "END"
    PRINT #f, ""
    PRINT #f, "ON ACTION CLOSE_WINDOW"
    PRINT #f, "    HOST CLOSE_WINDOW"
    PRINT #f, "END"

    CLOSE #f
END SUB

DIM startDir AS STRING
DIM maskText AS STRING
DIM recurseText AS STRING
DIM recurseFlag AS INTEGER

resultCount = 0
totalMatches = 0
dirsChecked = 0
filesChecked = 0
truncatedResults = 0

maskText = StripOuterQuotes(TRIM$(ConfigValue("MASK", "*.*")))
startDir = NormalizeDir(ConfigValue("STARTDIR", "."))
recurseText = ConfigValue("RECURSE", "Y")

IF maskText = "" THEN maskText = "*.*"
IF recurseText = "" THEN recurseText = "Y"
recurseFlag = IsYesValue(recurseText)

SearchDirectory startDir, maskText, recurseFlag
WriteResultsApp startDir, maskText, recurseFlag

END 0
