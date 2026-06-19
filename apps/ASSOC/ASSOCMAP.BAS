' ASSOCM03.BAS
' Builds and imports Backlash file associations using a program-to-extensions map.
' The helper keeps ASSOC.CFG in the shell's existing EXT=ACTION format.

CONST MAX_ASSOC = 1024
CONST MAX_GROUPS = 512

DIM SHARED assocKey(1 TO MAX_ASSOC) AS STRING
DIM SHARED assocValue(1 TO MAX_ASSOC) AS STRING
DIM SHARED assocCount AS INTEGER
DIM SHARED groupMode(1 TO MAX_GROUPS) AS INTEGER
DIM SHARED groupAction(1 TO MAX_GROUPS) AS STRING
DIM SHARED groupExts(1 TO MAX_GROUPS) AS STRING
DIM SHARED groupCount AS INTEGER
DIM SHARED cfgPath AS STRING
DIM SHARED mapPath AS STRING
DIM SHARED modePath AS STRING
DIM SHARED statusPath AS STRING

FUNCTION TrimText(BYVAL s AS STRING) AS STRING
    TrimText = LTRIM$(RTRIM$(s))
END FUNCTION

FUNCTION FileExists(BYVAL fileName AS STRING) AS INTEGER
    IF LEN(DIR(fileName)) > 0 THEN
        FileExists = -1
    ELSE
        FileExists = 0
    END IF
END FUNCTION

SUB ResolveAssocPaths()
    DIM appPrefix AS STRING

    ' Try the normal shell root first, then app/system subfolder launch cases.
    cfgPath = ""
    appPrefix = "APPS\ASSOC\"

    IF FileExists("SYSTEM\ASSOC.CFG") <> 0 THEN
        cfgPath = "SYSTEM\ASSOC.CFG"
        appPrefix = "APPS\ASSOC\"
    ELSEIF FileExists("..\..\SYSTEM\ASSOC.CFG") <> 0 THEN
        cfgPath = "..\..\SYSTEM\ASSOC.CFG"
        appPrefix = "..\..\APPS\ASSOC\"
    ELSEIF FileExists("..\ASSOC.CFG") <> 0 THEN
        cfgPath = "..\ASSOC.CFG"
        appPrefix = "..\..\APPS\ASSOC\"
    ELSEIF FileExists("ASSOC.CFG") <> 0 THEN
        cfgPath = "ASSOC.CFG"
        appPrefix = "..\APPS\ASSOC\"
    END IF

    mapPath = appPrefix + "ASSOCMAP.TXT"
    modePath = appPrefix + "ASSOCCMD.TXT"
    statusPath = appPrefix + "ASSOCSTS.TXT"
END SUB

FUNCTION ReadFirstLine(BYVAL fileName AS STRING) AS STRING
    DIM f AS INTEGER
    DIM s AS STRING

    ReadFirstLine = ""
    IF FileExists(fileName) = 0 THEN EXIT FUNCTION

    f = FREEFILE
    OPEN fileName FOR INPUT AS #f
    IF EOF(f) = 0 THEN LINE INPUT #f, s
    CLOSE #f

    ReadFirstLine = TrimText(s)
END FUNCTION

SUB WriteStatus(BYVAL msgText AS STRING)
    DIM f AS INTEGER

    f = FREEFILE
    OPEN statusPath FOR OUTPUT AS #f
    PRINT #f, msgText
    CLOSE #f
END SUB

FUNCTION IsWholeLineComment(BYVAL s AS STRING) AS INTEGER
    DIM t AS STRING
    DIM c AS STRING

    t = TrimText(s)
    IF t = "" THEN
        IsWholeLineComment = -1
        EXIT FUNCTION
    END IF

    c = LEFT$(t, 1)
    IF c = "#" OR c = ";" OR c = "'" THEN
        IsWholeLineComment = -1
    ELSE
        IsWholeLineComment = 0
    END IF
END FUNCTION

FUNCTION NormalizedExt(BYVAL rawExt AS STRING) AS STRING
    DIM s AS STRING
    DIM i AS INTEGER
    DIM ch AS STRING

    s = UCASE$(TrimText(rawExt))
    IF LEFT$(s, 2) = "*." THEN s = MID$(s, 3)

    DO WHILE LEFT$(s, 1) = "."
        s = MID$(s, 2)
    LOOP

    IF s = "" THEN
        NormalizedExt = ""
        EXIT FUNCTION
    END IF

    FOR i = 1 TO LEN(s)
        ch = MID$(s, i, 1)
        IF ASC(ch) <= 32 OR ch = "|" OR ch = "=" THEN
            NormalizedExt = ""
            EXIT FUNCTION
        END IF
    NEXT

    NormalizedExt = s
END FUNCTION

SUB AddAssoc(BYVAL keyName AS STRING, BYVAL actionText AS STRING)
    DIM i AS INTEGER
    DIM k AS STRING
    DIM v AS STRING

    k = UCASE$(TrimText(keyName))
    v = TrimText(actionText)
    IF k = "" OR v = "" THEN EXIT SUB

    FOR i = 1 TO assocCount
        IF assocKey(i) = k THEN
            assocValue(i) = v
            EXIT SUB
        END IF
    NEXT

    IF assocCount >= MAX_ASSOC THEN EXIT SUB
    assocCount = assocCount + 1
    assocKey(assocCount) = k
    assocValue(assocCount) = v
END SUB

SUB AddExtList(BYVAL actionText AS STRING, BYVAL extText AS STRING, BYVAL editMode AS INTEGER, BYREF addedCount AS INTEGER)
    DIM i AS INTEGER
    DIM ch AS STRING
    DIM token AS STRING
    DIM extName AS STRING
    DIM keyName AS STRING

    token = ""
    FOR i = 1 TO LEN(extText) + 1
        ch = " "
        IF i <= LEN(extText) THEN ch = MID$(extText, i, 1)

        IF ch = " " OR ch = CHR$(9) OR ch = "," THEN
            extName = NormalizedExt(token)
            IF extName <> "" THEN
                keyName = extName
                IF editMode <> 0 THEN keyName = keyName + "_EDIT"
                AddAssoc keyName, actionText
                addedCount = addedCount + 1
            END IF
            token = ""
        ELSE
            token = token + ch
        END IF
    NEXT
END SUB

SUB ParseMapLine(BYVAL srcLine AS STRING, BYREF addedCount AS INTEGER, BYREF errorCount AS INTEGER)
    DIM s AS STRING
    DIM u AS STRING
    DIM p AS INTEGER
    DIM actionText AS STRING
    DIM extText AS STRING
    DIM editMode AS INTEGER

    IF IsWholeLineComment(srcLine) <> 0 THEN EXIT SUB

    s = TrimText(srcLine)
    u = UCASE$(s)
    editMode = 0

    IF LEFT$(u, 5) = "EDIT " THEN
        editMode = -1
        s = TrimText(MID$(s, 6))
    ELSEIF LEFT$(u, 5) = "OPEN " THEN
        s = TrimText(MID$(s, 6))
    END IF

    p = INSTR(s, "|")
    IF p = 0 THEN p = INSTR(s, "=")

    IF p <= 1 THEN
        errorCount = errorCount + 1
        EXIT SUB
    END IF

    actionText = TrimText(LEFT$(s, p - 1))
    extText = TrimText(MID$(s, p + 1))

    IF actionText = "" OR extText = "" THEN
        errorCount = errorCount + 1
        EXIT SUB
    END IF

    AddExtList actionText, extText, editMode, addedCount
END SUB

FUNCTION MapHasContent() AS INTEGER
    DIM f AS INTEGER
    DIM s AS STRING

    IF FileExists(mapPath) = 0 THEN
        MapHasContent = 0
        EXIT FUNCTION
    END IF

    f = FREEFILE
    OPEN mapPath FOR INPUT AS #f
    DO WHILE EOF(f) = 0
        LINE INPUT #f, s
        IF IsWholeLineComment(s) = 0 THEN
            IF TrimText(s) <> "" THEN
                CLOSE #f
                MapHasContent = -1
                EXIT FUNCTION
            END IF
        END IF
    LOOP
    CLOSE #f

    MapHasContent = 0
END FUNCTION

SUB BuildCfgFromMap()
    DIM f AS INTEGER
    DIM o AS INTEGER
    DIM s AS STRING
    DIM addedCount AS INTEGER
    DIM errorCount AS INTEGER
    DIM i AS INTEGER

    assocCount = 0
    addedCount = 0
    errorCount = 0

    IF cfgPath = "" THEN
        WriteStatus "SYSTEM\ASSOC.CFG was not found. Build did not run."
        EXIT SUB
    END IF

    IF MapHasContent() = 0 THEN
        WriteStatus "No map entries found. Import first. " + cfgPath + " was not changed."
        EXIT SUB
    END IF

    f = FREEFILE
    OPEN mapPath FOR INPUT AS #f
    DO WHILE EOF(f) = 0
        LINE INPUT #f, s
        ParseMapLine s, addedCount, errorCount
    LOOP
    CLOSE #f

    IF errorCount > 0 THEN
        WriteStatus STR$(errorCount) + " bad map line(s). " + cfgPath + " was not changed."
        EXIT SUB
    END IF

    IF assocCount = 0 THEN
        WriteStatus "No valid associations. " + cfgPath + " was not changed."
        EXIT SUB
    END IF

    o = FREEFILE
    OPEN cfgPath FOR OUTPUT AS #o
    PRINT #o, "# Backlash / DOSWIN file associations"
    PRINT #o, "# Generated from ASSOCMAP.TXT"
    PRINT #o, "# Format required by shell:"
    PRINT #o, "# EXT=ACTION"
    PRINT #o, "# EXT_EDIT=ACTION"
    PRINT #o, ""
    PRINT #o, "# Open actions."
    FOR i = 1 TO assocCount
        IF RIGHT$(assocKey(i), 5) <> "_EDIT" THEN
            PRINT #o, assocKey(i) + "=" + assocValue(i)
        END IF
    NEXT
    PRINT #o, ""
    PRINT #o, "# Right-click Edit actions."
    FOR i = 1 TO assocCount
        IF RIGHT$(assocKey(i), 5) = "_EDIT" THEN
            PRINT #o, assocKey(i) + "=" + assocValue(i)
        END IF
    NEXT
    CLOSE #o

    WriteStatus STR$(assocCount) + " association key(s) written to " + cfgPath + "."
END SUB

SUB AddGroupExt(BYVAL editMode AS INTEGER, BYVAL actionText AS STRING, BYVAL extName AS STRING)
    DIM i AS INTEGER
    DIM searchText AS STRING

    IF actionText = "" OR extName = "" THEN EXIT SUB

    FOR i = 1 TO groupCount
        IF groupMode(i) = editMode AND groupAction(i) = actionText THEN
            searchText = " " + UCASE$(groupExts(i)) + " "
            IF INSTR(searchText, " " + UCASE$(extName) + " ") = 0 THEN
                groupExts(i) = groupExts(i) + " " + extName
            END IF
            EXIT SUB
        END IF
    NEXT

    IF groupCount >= MAX_GROUPS THEN EXIT SUB
    groupCount = groupCount + 1
    groupMode(groupCount) = editMode
    groupAction(groupCount) = actionText
    groupExts(groupCount) = extName
END SUB

SUB ImportCfgToMap()
    DIM f AS INTEGER
    DIM o AS INTEGER
    DIM s AS STRING
    DIM p AS INTEGER
    DIM keyName AS STRING
    DIM actionText AS STRING
    DIM extName AS STRING
    DIM editMode AS INTEGER
    DIM importedCount AS INTEGER
    DIM i AS INTEGER

    IF cfgPath = "" THEN
        WriteStatus "SYSTEM\ASSOC.CFG was not found. Import did not run."
        EXIT SUB
    END IF

    groupCount = 0
    importedCount = 0

    f = FREEFILE
    OPEN cfgPath FOR INPUT AS #f
    DO WHILE EOF(f) = 0
        LINE INPUT #f, s
        IF IsWholeLineComment(s) = 0 THEN
            p = INSTR(s, "=")
            IF p > 1 THEN
                keyName = UCASE$(TrimText(LEFT$(s, p - 1)))
                actionText = TrimText(MID$(s, p + 1))
                IF keyName <> "" AND actionText <> "" THEN
                    editMode = 0
                    extName = keyName
                    IF LEN(keyName) > 5 THEN
                        IF RIGHT$(keyName, 5) = "_EDIT" THEN
                            editMode = -1
                            extName = LEFT$(keyName, LEN(keyName) - 5)
                        END IF
                    END IF
                    extName = NormalizedExt(extName)
                    IF extName <> "" THEN
                        AddGroupExt editMode, actionText, extName
                        importedCount = importedCount + 1
                    END IF
                END IF
            END IF
        END IF
    LOOP
    CLOSE #f

    IF importedCount = 0 THEN
        WriteStatus "No association keys were found in " + cfgPath + "."
        EXIT SUB
    END IF

    o = FREEFILE
    OPEN mapPath FOR OUTPUT AS #o
    PRINT #o, "# ASSOCMAP.TXT"
    PRINT #o, "# Format: ACTION|EXT EXT EXT"
    PRINT #o, "# Edit-menu format: EDIT ACTION|EXT EXT EXT"
    PRINT #o, ""
    PRINT #o, "# Open actions."
    FOR i = 1 TO groupCount
        IF groupMode(i) = 0 THEN PRINT #o, groupAction(i) + "|" + groupExts(i)
    NEXT
    PRINT #o, ""
    PRINT #o, "# Right-click Edit actions."
    FOR i = 1 TO groupCount
        IF groupMode(i) <> 0 THEN PRINT #o, "EDIT " + groupAction(i) + "|" + groupExts(i)
    NEXT
    CLOSE #o

    WriteStatus STR$(importedCount) + " key(s) imported from " + cfgPath + " into " + mapPath + "."
END SUB

DIM modeText AS STRING

ResolveAssocPaths
modeText = UCASE$(ReadFirstLine(modePath))
IF modeText = "" THEN
    IF MapHasContent() = 0 THEN
        modeText = "IMPORT"
    ELSE
        modeText = "BUILD"
    END IF
END IF

IF modeText = "IMPORT" THEN
    ImportCfgToMap
ELSE
    BuildCfgFromMap
END IF
