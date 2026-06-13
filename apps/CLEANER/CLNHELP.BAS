' Cleaner helper source. It scans selected cleanup categories, deletes approved targets, and writes the results report.
'
' CLNHELP.BAS
' Backlash Cleaner helper.

CONST CFG_FILE AS STRING = "CLEANER.CFG"
CONST REPORT_FILE AS STRING = "REPORT.TXT"
CONST STATUS_FILE AS STRING = "STATUS.TXT"
CONST MAX_REPORT_LINES AS LONG = 500

TYPE CleanStats
    filesFound AS LONG
    filesDeleted AS LONG
    dirsFound AS LONG
    dirsDeleted AS LONG
    fails AS LONG
    bytesFound AS LONGINT
    bytesDeleted AS LONGINT
END TYPE

DECLARE FUNCTION StripQuotes(BYVAL s AS STRING) AS STRING
DECLARE FUNCTION NormalizePathLocal(BYVAL s AS STRING) AS STRING
DECLARE FUNCTION JoinPathLocal(BYVAL leftPath AS STRING, BYVAL rightName AS STRING) AS STRING
DECLARE FUNCTION ParentPathLocal(BYVAL s AS STRING) AS STRING
DECLARE FUNCTION FileNameOnlyLocal(BYVAL s AS STRING) AS STRING
DECLARE FUNCTION ExtUpper(BYVAL s AS STRING) AS STRING
DECLARE FUNCTION FileExists(BYVAL fileName AS STRING) AS INTEGER
DECLARE FUNCTION DirExists(BYVAL dirName AS STRING) AS INTEGER
DECLARE FUNCTION FileSizeOf(BYVAL fileName AS STRING) AS LONGINT
DECLARE FUNCTION ReadCfgValue(BYVAL fileName AS STRING, BYVAL keyName AS STRING, BYVAL defaultValue AS STRING) AS STRING
DECLARE FUNCTION CfgFlag(BYVAL keyName AS STRING) AS INTEGER
DECLARE FUNCTION FindBacklashRoot() AS STRING
DECLARE FUNCTION IsInsideTrash(BYVAL rootPath AS STRING, BYVAL pathName AS STRING) AS INTEGER
DECLARE FUNCTION ShouldDeleteFile(BYVAL rootPath AS STRING, BYVAL fileName AS STRING, BYVAL optTemp AS INTEGER, BYVAL optLogs AS INTEGER, BYVAL optCache AS INTEGER) AS INTEGER
DECLARE FUNCTION IsTempDirName(BYVAL pathName AS STRING) AS INTEGER
DECLARE FUNCTION IsDirEmpty(BYVAL dirName AS STRING) AS INTEGER
DECLARE SUB AddLine(BYREF reportText AS STRING, BYREF lineCount AS LONG, BYVAL lineText AS STRING)
DECLARE SUB WriteTextFile(BYVAL fileName AS STRING, BYVAL textValue AS STRING)
DECLARE SUB DeleteFileEntry(BYVAL fileName AS STRING, BYVAL doDelete AS INTEGER, BYREF stats AS CleanStats, BYREF reportText AS STRING, BYREF lineCount AS LONG)
DECLARE SUB ScanFolder(BYVAL rootPath AS STRING, BYVAL folderPath AS STRING, BYVAL doDelete AS INTEGER, BYVAL optTemp AS INTEGER, BYVAL optLogs AS INTEGER, BYVAL optCache AS INTEGER, BYVAL optEmpty AS INTEGER, BYREF stats AS CleanStats, BYREF reportText AS STRING, BYREF lineCount AS LONG)
DECLARE SUB HandleExactFile(BYVAL rootPath AS STRING, BYVAL relPath AS STRING, BYVAL doDelete AS INTEGER, BYREF stats AS CleanStats, BYREF reportText AS STRING, BYREF lineCount AS LONG)
DECLARE SUB ClearFileText(BYVAL rootPath AS STRING, BYVAL relPath AS STRING, BYVAL newText AS STRING, BYVAL doDelete AS INTEGER, BYREF stats AS CleanStats, BYREF reportText AS STRING, BYREF lineCount AS LONG)
DECLARE SUB DoCleaner(BYVAL modeText AS STRING)

FUNCTION StripQuotes(BYVAL s AS STRING) AS STRING
    s = TRIM$(s)
    IF LEN(s) >= 2 THEN
        IF LEFT$(s, 1) = CHR$(34) AND RIGHT$(s, 1) = CHR$(34) THEN
            s = MID$(s, 2, LEN(s) - 2)
        END IF
    END IF
    RETURN s
END FUNCTION

FUNCTION NormalizePathLocal(BYVAL s AS STRING) AS STRING
    DIM i AS INTEGER
    DIM ch AS STRING
    DIM outText AS STRING

    s = TRIM$(StripQuotes(s))
    FOR i = 1 TO LEN(s)
        ch = MID$(s, i, 1)
        IF ch = "/" THEN ch = "\"
        outText = outText + ch
    NEXT

    DO WHILE LEN(outText) > 1 AND RIGHT$(outText, 1) = "\"
        IF LEN(outText) = 3 AND MID$(outText, 2, 1) = ":" THEN EXIT DO
        outText = LEFT$(outText, LEN(outText) - 1)
    LOOP

    RETURN outText
END FUNCTION

FUNCTION JoinPathLocal(BYVAL leftPath AS STRING, BYVAL rightName AS STRING) AS STRING
    leftPath = NormalizePathLocal(leftPath)
    rightName = NormalizePathLocal(rightName)
    IF leftPath = "" THEN RETURN rightName
    IF rightName = "" THEN RETURN leftPath
    IF RIGHT$(leftPath, 1) = "\" THEN RETURN leftPath + rightName
    RETURN leftPath + "\" + rightName
END FUNCTION

FUNCTION ParentPathLocal(BYVAL s AS STRING) AS STRING
    DIM i AS INTEGER

    s = NormalizePathLocal(s)
    FOR i = LEN(s) TO 1 STEP -1
        IF MID$(s, i, 1) = "\" THEN
            IF i <= 3 AND MID$(s, 2, 1) = ":" THEN RETURN LEFT$(s, i)
            RETURN LEFT$(s, i - 1)
        END IF
    NEXT
    RETURN ""
END FUNCTION

FUNCTION FileNameOnlyLocal(BYVAL s AS STRING) AS STRING
    DIM i AS INTEGER

    s = NormalizePathLocal(s)
    FOR i = LEN(s) TO 1 STEP -1
        IF MID$(s, i, 1) = "\" THEN RETURN MID$(s, i + 1)
    NEXT
    RETURN s
END FUNCTION

FUNCTION ExtUpper(BYVAL s AS STRING) AS STRING
    DIM nameOnly AS STRING
    DIM i AS INTEGER

    nameOnly = FileNameOnlyLocal(s)
    FOR i = LEN(nameOnly) TO 1 STEP -1
        IF MID$(nameOnly, i, 1) = "." THEN RETURN UCASE$(MID$(nameOnly, i))
    NEXT
    RETURN ""
END FUNCTION

FUNCTION FileExists(BYVAL fileName AS STRING) AS INTEGER
    DIM f AS INTEGER

    f = FREEFILE
    IF OPEN(fileName FOR BINARY ACCESS READ AS #f) = 0 THEN
        CLOSE #f
        RETURN -1
    END IF
    RETURN 0
END FUNCTION

FUNCTION DirExists(BYVAL dirName AS STRING) AS INTEGER
    DIM attrBits AS INTEGER
    DIM nameText AS STRING

    dirName = NormalizePathLocal(dirName)
    IF dirName = "" THEN RETURN 0
    nameText = DIR(dirName, &H10, attrBits)
    IF nameText <> "" THEN
        IF (attrBits AND &H10) <> 0 THEN RETURN -1
    END IF
    RETURN 0
END FUNCTION

FUNCTION FileSizeOf(BYVAL fileName AS STRING) AS LONGINT
    DIM f AS INTEGER
    DIM sizeValue AS LONGINT

    sizeValue = 0
    f = FREEFILE
    IF OPEN(fileName FOR BINARY ACCESS READ AS #f) = 0 THEN
        sizeValue = LOF(f)
        CLOSE #f
    END IF
    RETURN sizeValue
END FUNCTION

FUNCTION ReadCfgValue(BYVAL fileName AS STRING, BYVAL keyName AS STRING, BYVAL defaultValue AS STRING) AS STRING
    DIM f AS INTEGER
    DIM lineText AS STRING
    DIM eqPos AS INTEGER
    DIM leftKey AS STRING
    DIM keyUpper AS STRING

    keyUpper = UCASE$(TRIM$(keyName))
    f = FREEFILE
    IF OPEN(fileName FOR INPUT AS #f) <> 0 THEN RETURN defaultValue
    DO WHILE NOT EOF(f)
        LINE INPUT #f, lineText
        lineText = TRIM$(lineText)
        IF lineText <> "" THEN
            IF LEFT$(lineText, 1) <> ";" AND LEFT$(lineText, 1) <> "#" THEN
                eqPos = INSTR(lineText, "=")
                IF eqPos > 0 THEN
                    leftKey = UCASE$(TRIM$(LEFT$(lineText, eqPos - 1)))
                    IF leftKey = keyUpper THEN
                        CLOSE #f
                        RETURN TRIM$(MID$(lineText, eqPos + 1))
                    END IF
                END IF
            END IF
        END IF
    LOOP
    CLOSE #f
    RETURN defaultValue
END FUNCTION

FUNCTION CfgFlag(BYVAL keyName AS STRING) AS INTEGER
    DIM v AS STRING

    v = UCASE$(TRIM$(ReadCfgValue(CFG_FILE, keyName, "0")))
    IF v = "1" OR v = "Y" OR v = "YES" OR v = "TRUE" OR v = "ON" THEN RETURN -1
    RETURN 0
END FUNCTION

FUNCTION FindBacklashRoot() AS STRING
    DIM curPath AS STRING
    DIM probe AS STRING
    DIM i AS INTEGER

    curPath = NormalizePathLocal(CURDIR)
    probe = curPath

    FOR i = 1 TO 8
        IF FileExists(JoinPathLocal(probe, "BACKLASH.EXE")) <> 0 THEN RETURN probe
        IF FileExists(JoinPathLocal(probe, "SYSTEM\LAUNCH.INI")) <> 0 THEN RETURN probe
        probe = ParentPathLocal(probe)
        IF probe = "" THEN EXIT FOR
    NEXT

    probe = ParentPathLocal(ParentPathLocal(curPath))
    IF probe <> "" THEN RETURN probe
    RETURN curPath
END FUNCTION

FUNCTION IsInsideTrash(BYVAL rootPath AS STRING, BYVAL pathName AS STRING) AS INTEGER
    DIM trashPath AS STRING
    DIM pathUpper AS STRING

    trashPath = UCASE$(NormalizePathLocal(JoinPathLocal(rootPath, "SYSTEM\TRASH")))
    pathUpper = UCASE$(NormalizePathLocal(pathName))
    IF pathUpper = trashPath THEN RETURN -1
    IF LEFT$(pathUpper, LEN(trashPath) + 1) = trashPath + "\" THEN RETURN -1
    RETURN 0
END FUNCTION

FUNCTION ShouldDeleteFile(BYVAL rootPath AS STRING, BYVAL fileName AS STRING, BYVAL optTemp AS INTEGER, BYVAL optLogs AS INTEGER, BYVAL optCache AS INTEGER) AS INTEGER
    DIM extText AS STRING

    IF IsInsideTrash(rootPath, fileName) <> 0 THEN RETURN 0
    extText = ExtUpper(fileName)

    IF optTemp <> 0 AND extText = ".TMP" THEN RETURN -1
    IF optLogs <> 0 AND extText = ".LOG" THEN RETURN -1
    IF optCache <> 0 AND extText = ".CCH" THEN RETURN -1

    RETURN 0
END FUNCTION

FUNCTION IsTempDirName(BYVAL pathName AS STRING) AS INTEGER
    DIM n AS STRING

    n = UCASE$(FileNameOnlyLocal(pathName))
    IF n = "TEMP" OR n = "TMP" THEN RETURN -1
    RETURN 0
END FUNCTION

FUNCTION IsDirEmpty(BYVAL dirName AS STRING) AS INTEGER
    DIM attrBits AS INTEGER
    DIM entryName AS STRING

    entryName = DIR(JoinPathLocal(dirName, "*.*"), &H37, attrBits)
    DO WHILE entryName <> ""
        IF entryName <> "." AND entryName <> ".." THEN RETURN 0
        entryName = DIR(attrBits)
    LOOP
    RETURN -1
END FUNCTION

SUB AddLine(BYREF reportText AS STRING, BYREF lineCount AS LONG, BYVAL lineText AS STRING)
    IF lineCount < MAX_REPORT_LINES THEN
        reportText = reportText + lineText + CHR$(13) + CHR$(10)
    ELSEIF lineCount = MAX_REPORT_LINES THEN
        reportText = reportText + "...additional lines omitted..." + CHR$(13) + CHR$(10)
    END IF
    lineCount = lineCount + 1
END SUB

SUB WriteTextFile(BYVAL fileName AS STRING, BYVAL textValue AS STRING)
    DIM f AS INTEGER

    f = FREEFILE
    OPEN fileName FOR OUTPUT AS #f
    PRINT #f, textValue;
    CLOSE #f
END SUB

SUB DeleteFileEntry(BYVAL fileName AS STRING, BYVAL doDelete AS INTEGER, BYREF stats AS CleanStats, BYREF reportText AS STRING, BYREF lineCount AS LONG)
    DIM sizeValue AS LONGINT

    IF FileExists(fileName) = 0 THEN EXIT SUB

    sizeValue = FileSizeOf(fileName)
    stats.filesFound = stats.filesFound + 1
    stats.bytesFound = stats.bytesFound + sizeValue

    IF doDelete <> 0 THEN
        KILL fileName
        IF FileExists(fileName) = 0 THEN
            stats.filesDeleted = stats.filesDeleted + 1
            stats.bytesDeleted = stats.bytesDeleted + sizeValue
            AddLine reportText, lineCount, "Deleted: " + fileName
        ELSE
            stats.fails = stats.fails + 1
            AddLine reportText, lineCount, "FAILED: " + fileName
        END IF
    ELSE
        AddLine reportText, lineCount, "Found: " + fileName
    END IF
END SUB

SUB ScanFolder(BYVAL rootPath AS STRING, BYVAL folderPath AS STRING, BYVAL doDelete AS INTEGER, BYVAL optTemp AS INTEGER, BYVAL optLogs AS INTEGER, BYVAL optCache AS INTEGER, BYVAL optEmpty AS INTEGER, BYREF stats AS CleanStats, BYREF reportText AS STRING, BYREF lineCount AS LONG)
    DIM attrBits AS INTEGER
    DIM entryName AS STRING
    DIM fullName AS STRING
    DIM dirCount AS INTEGER
    DIM dirCap AS INTEGER
    DIM i AS INTEGER
    REDIM dirList(1 TO 32) AS STRING

    IF IsInsideTrash(rootPath, folderPath) <> 0 THEN EXIT SUB

    dirCap = 32
    entryName = DIR(JoinPathLocal(folderPath, "*.*"), &H37, attrBits)
    DO WHILE entryName <> ""
        IF entryName <> "." AND entryName <> ".." THEN
            fullName = JoinPathLocal(folderPath, entryName)
            IF (attrBits AND &H10) <> 0 THEN
                IF IsInsideTrash(rootPath, fullName) = 0 THEN
                    dirCount = dirCount + 1
                    IF dirCount > dirCap THEN
                        dirCap = dirCap + 32
                        REDIM PRESERVE dirList(1 TO dirCap) AS STRING
                    END IF
                    dirList(dirCount) = fullName
                END IF
            ELSE
                IF ShouldDeleteFile(rootPath, fullName, optTemp, optLogs, optCache) <> 0 THEN
                    DeleteFileEntry fullName, doDelete, stats, reportText, lineCount
                END IF
            END IF
        END IF
        entryName = DIR(attrBits)
    LOOP

    FOR i = 1 TO dirCount
        ScanFolder rootPath, dirList(i), doDelete, optTemp, optLogs, optCache, optEmpty, stats, reportText, lineCount
    NEXT

    IF optEmpty <> 0 THEN
        IF IsTempDirName(folderPath) <> 0 THEN
            IF UCASE$(NormalizePathLocal(folderPath)) <> UCASE$(NormalizePathLocal(rootPath)) THEN
                IF IsDirEmpty(folderPath) <> 0 THEN
                    stats.dirsFound = stats.dirsFound + 1
                    IF doDelete <> 0 THEN
                        RMDIR folderPath
                        IF DirExists(folderPath) = 0 THEN
                            stats.dirsDeleted = stats.dirsDeleted + 1
                            AddLine reportText, lineCount, "Removed empty folder: " + folderPath
                        ELSE
                            stats.fails = stats.fails + 1
                            AddLine reportText, lineCount, "FAILED folder: " + folderPath
                        END IF
                    ELSE
                        AddLine reportText, lineCount, "Empty temp folder: " + folderPath
                    END IF
                END IF
            END IF
        END IF
    END IF
END SUB

SUB HandleExactFile(BYVAL rootPath AS STRING, BYVAL relPath AS STRING, BYVAL doDelete AS INTEGER, BYREF stats AS CleanStats, BYREF reportText AS STRING, BYREF lineCount AS LONG)
    DIM fullPath AS STRING

    fullPath = JoinPathLocal(rootPath, relPath)
    IF IsInsideTrash(rootPath, fullPath) <> 0 THEN EXIT SUB
    DeleteFileEntry fullPath, doDelete, stats, reportText, lineCount
END SUB

SUB ClearFileText(BYVAL rootPath AS STRING, BYVAL relPath AS STRING, BYVAL newText AS STRING, BYVAL doDelete AS INTEGER, BYREF stats AS CleanStats, BYREF reportText AS STRING, BYREF lineCount AS LONG)
    DIM fullPath AS STRING
    DIM oldSize AS LONGINT

    fullPath = JoinPathLocal(rootPath, relPath)
    IF IsInsideTrash(rootPath, fullPath) <> 0 THEN EXIT SUB

    oldSize = FileSizeOf(fullPath)
    stats.filesFound = stats.filesFound + 1
    stats.bytesFound = stats.bytesFound + oldSize

    IF doDelete <> 0 THEN
        WriteTextFile fullPath, newText
        stats.filesDeleted = stats.filesDeleted + 1
        stats.bytesDeleted = stats.bytesDeleted + oldSize
        AddLine reportText, lineCount, "Cleared: " + fullPath
    ELSE
        AddLine reportText, lineCount, "Would clear: " + fullPath
    END IF
END SUB

SUB DoCleaner(BYVAL modeText AS STRING)
    DIM rootPath AS STRING
    DIM doDelete AS INTEGER
    DIM optTemp AS INTEGER
    DIM optHistory AS INTEGER
    DIM optAppTemp AS INTEGER
    DIM optLogs AS INTEGER
    DIM optCache AS INTEGER
    DIM optRunSearch AS INTEGER
    DIM optEmpty AS INTEGER
    DIM stats AS CleanStats
    DIM reportText AS STRING
    DIM lineCount AS LONG
    DIM statusText AS STRING
    DIM reportOutFile AS STRING
    DIM statusOutFile AS STRING

    reportOutFile = TRIM$(StripQuotes(COMMAND(2)))
    statusOutFile = TRIM$(StripQuotes(COMMAND(3)))
    IF reportOutFile = "" THEN reportOutFile = REPORT_FILE
    IF statusOutFile = "" THEN statusOutFile = STATUS_FILE

    modeText = UCASE$(TRIM$(StripQuotes(modeText)))
    doDelete = 0
    IF modeText = "DELETE" OR modeText = "CLEAN" THEN doDelete = -1

    rootPath = FindBacklashRoot()

    optTemp = CfgFlag("del_temp")
    optHistory = CfgFlag("del_history")
    optAppTemp = CfgFlag("del_app_temp")
    optLogs = CfgFlag("del_logs")
    optCache = CfgFlag("clear_cache")
    optRunSearch = CfgFlag("clear_runsearch")
    optEmpty = CfgFlag("clean_empty")

    IF doDelete <> 0 THEN
        reportText = "Cleaner delete report" + CHR$(13) + CHR$(10)
    ELSE
        reportText = "Cleaner scan report" + CHR$(13) + CHR$(10)
    END IF
    reportText = reportText + "Root: " + rootPath + CHR$(13) + CHR$(10) + CHR$(13) + CHR$(10)

    IF optTemp = 0 AND optHistory = 0 AND optAppTemp = 0 AND optLogs = 0 AND optCache = 0 AND optRunSearch = 0 AND optEmpty = 0 THEN
        AddLine reportText, lineCount, "No cleanup items are checked."
    ELSE
        IF optTemp <> 0 OR optLogs <> 0 OR optCache <> 0 OR optEmpty <> 0 THEN
            ScanFolder rootPath, rootPath, doDelete, optTemp, optLogs, optCache, optEmpty, stats, reportText, lineCount
        END IF

        IF optHistory <> 0 THEN
            ClearFileText rootPath, "SYSTEM\RECENT.DAT", "", doDelete, stats, reportText, lineCount
        END IF

        IF optRunSearch <> 0 THEN
            ClearFileText rootPath, "SYSTEM\RUN.CFG", "COMMAND=" + CHR$(13) + CHR$(10), doDelete, stats, reportText, lineCount
            ClearFileText rootPath, "SYSTEM\SEARCH.CFG", "MASK=*.*" + CHR$(13) + CHR$(10) + "STARTDIR=." + CHR$(13) + CHR$(10) + "RECURSE=Y" + CHR$(13) + CHR$(10), doDelete, stats, reportText, lineCount
            HandleExactFile rootPath, "SYSTEM\SEARCH.TXT", doDelete, stats, reportText, lineCount
        END IF

        IF optAppTemp <> 0 THEN
            HandleExactFile rootPath, "APPS\SYSINFO\REPORT.TXT", doDelete, stats, reportText, lineCount
            HandleExactFile rootPath, "APPS\SYSINFO\STATUS.TXT", doDelete, stats, reportText, lineCount
            HandleExactFile rootPath, "APPS\ICONEDIT\FILLCOL.TXT", doDelete, stats, reportText, lineCount
            HandleExactFile rootPath, "APPS\ICONEDIT\FILLSTAT.TXT", doDelete, stats, reportText, lineCount
        END IF
    END IF

    reportText = reportText + CHR$(13) + CHR$(10)
    reportText = reportText + "Files found: " + STR$(stats.filesFound) + CHR$(13) + CHR$(10)
    IF doDelete <> 0 THEN reportText = reportText + "Files deleted/cleared: " + STR$(stats.filesDeleted) + CHR$(13) + CHR$(10)
    reportText = reportText + "Empty temp folders found: " + STR$(stats.dirsFound) + CHR$(13) + CHR$(10)
    IF doDelete <> 0 THEN reportText = reportText + "Empty temp folders removed: " + STR$(stats.dirsDeleted) + CHR$(13) + CHR$(10)
    reportText = reportText + "Failures: " + STR$(stats.fails) + CHR$(13) + CHR$(10)

    IF doDelete <> 0 THEN
        statusText = "Deleted/cleared " + LTRIM$(STR$(stats.filesDeleted)) + " file entries; failures " + LTRIM$(STR$(stats.fails)) + "."
    ELSE
        statusText = "Scan found " + LTRIM$(STR$(stats.filesFound)) + " file entries; failures " + LTRIM$(STR$(stats.fails)) + "."
    END IF

    WriteTextFile reportOutFile, reportText
    WriteTextFile statusOutFile, statusText
END SUB

DoCleaner COMMAND(1)
