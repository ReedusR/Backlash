' ARCHRUN.BAS
' Shared Archive Manager backend for ZIP, ARJ, RAR, and ACE archives.
' Keeps archive-tool command syntax out of the layout file.

DECLARE FUNCTION TrimAll(ByVal s As String) As String
DECLARE FUNCTION StripOuterQuotes(ByVal s As String) As String
DECLARE FUNCTION UpperText(ByVal s As String) As String
DECLARE FUNCTION ArgValue(ByVal argText As String, ByVal keyName As String) As String
DECLARE FUNCTION Q(ByVal s As String) As String
DECLARE FUNCTION ArchiveExt(ByVal archivePath As String) As String
DECLARE FUNCTION ArchiveDirectory(ByVal archivePath As String) As String
DECLARE FUNCTION TrimTrailingSlash(ByVal pathName As String) As String
DECLARE FUNCTION EnsureTrailingSlash(ByVal pathName As String) As String
DECLARE FUNCTION NeedsDefaultDest(ByVal destPath As String) As Integer
DECLARE FUNCTION FileExists(ByVal pathName As String) As Integer
DECLARE FUNCTION ConfigFlag(ByVal keyName As String, ByVal defaultValue As Integer) As Integer
DECLARE FUNCTION ConfigFlagFromFile(ByVal fileName As String, ByVal keyName As String, ByVal defaultValue As Integer) As Integer
DECLARE FUNCTION IsSafeText(ByVal s As String) As Integer
DECLARE FUNCTION OpenForOutput(ByVal preferredPath As String, ByVal fallbackPath As String, ByRef fh As Integer) As String
DECLARE FUNCTION OpenForAppend(ByVal preferredPath As String, ByVal fallbackPath As String, ByRef fh As Integer) As String
DECLARE FUNCTION CurrentExtractLogPath() As String
DECLARE FUNCTION CurrentTestLogPath() As String
DECLARE FUNCTION ReadU16LE(ByVal fh As Integer, ByVal filePos As Long) As Long
DECLARE FUNCTION ReadU32LE(ByVal fh As Integer, ByVal filePos As Long) As Long
DECLARE FUNCTION FindEndCentralDir(ByVal zipPath As String) As Long
DECLARE FUNCTION ZipHasEncryptedEntries(ByVal zipPath As String) As Integer
DECLARE SUB ClearExtractLog(ByVal titleText As String)
DECLARE SUB AppendExtractLog(ByVal lineText As String)
DECLARE SUB ClearTestLog(ByVal titleText As String)
DECLARE SUB AppendTestLog(ByVal lineText As String)
DECLARE SUB RunExtract(ByVal archivePath As String, ByVal destPath As String, ByVal passText As String)
DECLARE SUB RunTest(ByVal archivePath As String, ByVal passText As String)
DECLARE SUB RunZipExtract(ByVal zipPath As String, ByVal destPath As String, ByVal passText As String)
DECLARE SUB RunZipTest(ByVal zipPath As String, ByVal passText As String)
DECLARE SUB RunArjExtract(ByVal arjPath As String, ByVal destPath As String, ByVal passText As String)
DECLARE SUB RunArjTest(ByVal arjPath As String, ByVal passText As String)
DECLARE SUB RunRarExtract(ByVal rarPath As String, ByVal destPath As String, ByVal passText As String)
DECLARE SUB RunRarTest(ByVal rarPath As String, ByVal passText As String)
DECLARE SUB RunAceExtract(ByVal acePath As String, ByVal destPath As String, ByVal passText As String)
DECLARE SUB RunAceTest(ByVal acePath As String, ByVal passText As String)

CONST XLOG_PREF As String = "APPS\ARCHMGR\ARCXTRCT.LOG"
CONST XLOG_LOCAL As String = "ARCXTRCT.LOG"
CONST TLOG_PREF As String = "APPS\ARCHMGR\ARCTEST.TXT"
CONST TLOG_LOCAL As String = "ARCTEST.TXT"
CONST CFG_PREF As String = "APPS\ARCHMGR\ARCHCFG.CFG"
CONST CFG_LOCAL As String = "ARCHCFG.CFG"

FUNCTION TrimAll(ByVal s As String) As String
    TrimAll = LTrim$(RTrim$(s))
END FUNCTION

FUNCTION StripOuterQuotes(ByVal s As String) As String
    s = TrimAll(s)
    If Len(s) >= 2 Then
        If Left$(s, 1) = Chr$(34) And Right$(s, 1) = Chr$(34) Then
            StripOuterQuotes = Mid$(s, 2, Len(s) - 2)
            Exit Function
        End If
    End If

    StripOuterQuotes = s
END FUNCTION

FUNCTION UpperText(ByVal s As String) As String
    Dim i As Integer
    Dim c As Integer
    Dim outText As String

    outText = s
    For i = 1 To Len(outText)
        c = Asc(Mid$(outText, i, 1))
        If c >= 97 And c <= 122 Then Mid$(outText, i, 1) = Chr$(c - 32)
    Next i

    UpperText = outText
END FUNCTION

FUNCTION ArgValue(ByVal argText As String, ByVal keyName As String) As String
    Dim p As Integer
    Dim k As String

    p = InStr(argText, "=")
    If p <= 0 Then
        ArgValue = ""
        Exit Function
    End If

    k = UpperText(TrimAll(Left$(argText, p - 1)))
    If k <> UpperText(TrimAll(keyName)) Then
        ArgValue = ""
        Exit Function
    End If

    ArgValue = StripOuterQuotes(Mid$(argText, p + 1))
END FUNCTION

FUNCTION Q(ByVal s As String) As String
    s = TrimAll(s)
    If InStr(s, " ") > 0 Then
        Q = Chr$(34) & s & Chr$(34)
    Else
        Q = s
    End If
END FUNCTION

FUNCTION ArchiveExt(ByVal archivePath As String) As String
    Dim i As Integer
    Dim p As Integer
    Dim ch As String

    p = 0
    For i = Len(archivePath) To 1 Step -1
        ch = Mid$(archivePath, i, 1)
        If ch = "." Then
            p = i
            Exit For
        End If
        If ch = "\" Or ch = "/" Then Exit For
    Next i

    If p > 0 Then
        ArchiveExt = UpperText(Mid$(archivePath, p + 1))
    Else
        ArchiveExt = ""
    End If
END FUNCTION

FUNCTION ArchiveDirectory(ByVal archivePath As String) As String
    Dim i As Integer
    Dim p As Integer
    Dim ch As String

    p = 0
    For i = Len(archivePath) To 1 Step -1
        ch = Mid$(archivePath, i, 1)
        If ch = "\" Or ch = "/" Then
            p = i
            Exit For
        End If
    Next i

    If p > 3 Then
        ArchiveDirectory = Left$(archivePath, p - 1)
    ElseIf p > 0 Then
        ArchiveDirectory = Left$(archivePath, p)
    Else
        ArchiveDirectory = "."
    End If
END FUNCTION

FUNCTION TrimTrailingSlash(ByVal pathName As String) As String
    pathName = TrimAll(pathName)
    Do While Len(pathName) > 3
        If Right$(pathName, 1) = "\" Or Right$(pathName, 1) = "/" Then
            pathName = Left$(pathName, Len(pathName) - 1)
        Else
            Exit Do
        End If
    Loop

    TrimTrailingSlash = pathName
END FUNCTION

FUNCTION EnsureTrailingSlash(ByVal pathName As String) As String
    pathName = TrimAll(pathName)
    If Len(pathName) = 0 Then
        EnsureTrailingSlash = pathName
    ElseIf Right$(pathName, 1) = "\" Or Right$(pathName, 1) = "/" Then
        EnsureTrailingSlash = pathName
    Else
        EnsureTrailingSlash = pathName & "\"
    End If
END FUNCTION

FUNCTION NeedsDefaultDest(ByVal destPath As String) As Integer
    Dim d As String

    d = UpperText(TrimAll(destPath))
    If d = "" Or d = "." Or d = ".\" Then
        NeedsDefaultDest = 1
    Else
        NeedsDefaultDest = 0
    End If
END FUNCTION

FUNCTION FileExists(ByVal pathName As String) As Integer
    Dim f As Integer

    If Len(TrimAll(pathName)) = 0 Then
        FileExists = 0
        Exit Function
    End If

    f = FreeFile
    If Open(pathName For Binary Access Read As #f) <> 0 Then
        FileExists = 0
    Else
        Close #f
        FileExists = 1
    End If
END FUNCTION

FUNCTION ConfigFlagFromFile(ByVal fileName As String, ByVal keyName As String, ByVal defaultValue As Integer) As Integer
    Dim f As Integer
    Dim lineText As String
    Dim p As Integer
    Dim k As String
    Dim v As String
    Dim keyUpper As String

    ConfigFlagFromFile = defaultValue
    If FileExists(fileName) = 0 Then Exit Function

    keyUpper = UpperText(TrimAll(keyName))
    f = FreeFile
    If Open(fileName For Input As #f) <> 0 Then Exit Function

    Do While Not EOF(f)
        Line Input #f, lineText
        p = InStr(lineText, "=")
        If p > 0 Then
            k = UpperText(TrimAll(Left$(lineText, p - 1)))
            v = UpperText(TrimAll(Mid$(lineText, p + 1)))
            If k = keyUpper Then
                If v = "1" Or v = "Y" Or v = "YES" Or v = "ON" Or v = "TRUE" Then
                    ConfigFlagFromFile = 1
                Else
                    ConfigFlagFromFile = 0
                End If
                Close #f
                Exit Function
            End If
        End If
    Loop

    Close #f
END FUNCTION

FUNCTION ConfigFlag(ByVal keyName As String, ByVal defaultValue As Integer) As Integer
    Dim v As Integer

    v = ConfigFlagFromFile(CFG_PREF, keyName, defaultValue)
    If v <> defaultValue Then
        ConfigFlag = v
        Exit Function
    End If

    ConfigFlag = ConfigFlagFromFile(CFG_LOCAL, keyName, v)
END FUNCTION

FUNCTION IsSafeText(ByVal s As String) As Integer
    Dim i As Integer
    Dim c As String

    IsSafeText = 1
    For i = 1 To Len(s)
        c = Mid$(s, i, 1)
        If c = Chr$(34) Or c = ">" Or c = "<" Or c = "|" Then
            IsSafeText = 0
            Exit Function
        End If
    Next i
END FUNCTION

FUNCTION OpenForOutput(ByVal preferredPath As String, ByVal fallbackPath As String, ByRef fh As Integer) As String
    fh = FreeFile
    If Open(preferredPath For Output As #fh) = 0 Then
        OpenForOutput = preferredPath
        Exit Function
    End If

    fh = FreeFile
    If Open(fallbackPath For Output As #fh) = 0 Then
        OpenForOutput = fallbackPath
    Else
        OpenForOutput = ""
    End If
END FUNCTION

FUNCTION OpenForAppend(ByVal preferredPath As String, ByVal fallbackPath As String, ByRef fh As Integer) As String
    fh = FreeFile
    If Open(preferredPath For Append As #fh) = 0 Then
        OpenForAppend = preferredPath
        Exit Function
    End If

    fh = FreeFile
    If Open(fallbackPath For Append As #fh) = 0 Then
        OpenForAppend = fallbackPath
    Else
        OpenForAppend = ""
    End If
END FUNCTION

FUNCTION CurrentExtractLogPath() As String
    If FileExists(XLOG_PREF) <> 0 Then
        CurrentExtractLogPath = XLOG_PREF
    ElseIf FileExists(XLOG_LOCAL) <> 0 Then
        CurrentExtractLogPath = XLOG_LOCAL
    Else
        CurrentExtractLogPath = XLOG_PREF
    End If
END FUNCTION

FUNCTION CurrentTestLogPath() As String
    If FileExists(TLOG_PREF) <> 0 Then
        CurrentTestLogPath = TLOG_PREF
    ElseIf FileExists(TLOG_LOCAL) <> 0 Then
        CurrentTestLogPath = TLOG_LOCAL
    Else
        CurrentTestLogPath = TLOG_PREF
    End If
END FUNCTION

FUNCTION ReadU16LE(ByVal fh As Integer, ByVal filePos As Long) As Long
    Dim b1 As UByte
    Dim b2 As UByte

    If filePos < 1 Or filePos + 1 > LOF(fh) Then
        ReadU16LE = -1
        Exit Function
    End If

    Get #fh, filePos, b1
    Get #fh, filePos + 1, b2
    ReadU16LE = CLng(b1) + CLng(b2) * 256
END FUNCTION

FUNCTION ReadU32LE(ByVal fh As Integer, ByVal filePos As Long) As Long
    Dim b1 As UByte
    Dim b2 As UByte
    Dim b3 As UByte
    Dim b4 As UByte

    If filePos < 1 Or filePos + 3 > LOF(fh) Then
        ReadU32LE = -1
        Exit Function
    End If

    Get #fh, filePos, b1
    Get #fh, filePos + 1, b2
    Get #fh, filePos + 2, b3
    Get #fh, filePos + 3, b4
    ReadU32LE = CLng(b1) + CLng(b2) * 256 + CLng(b3) * 65536 + CLng(b4) * 16777216
END FUNCTION

FUNCTION FindEndCentralDir(ByVal zipPath As String) As Long
    Dim fh As Integer
    Dim fileLen As Long
    Dim startPos As Long
    Dim p As Long

    FindEndCentralDir = 0
    fh = FreeFile
    If Open(zipPath For Binary Access Read As #fh) <> 0 Then Exit Function

    fileLen = LOF(fh)
    If fileLen < 22 Then
        Close #fh
        Exit Function
    End If

    startPos = fileLen - 65557
    If startPos < 1 Then startPos = 1

    For p = fileLen - 21 To startPos Step -1
        If ReadU32LE(fh, p) = &H06054B50 Then
            FindEndCentralDir = p
            Exit For
        End If
    Next p

    Close #fh
END FUNCTION

FUNCTION ZipHasEncryptedEntries(ByVal zipPath As String) As Integer
    Dim fh As Integer
    Dim eocdPos As Long
    Dim fileLen As Long
    Dim centralPos As Long
    Dim entryCount As Long
    Dim entryIndex As Long
    Dim p As Long
    Dim flagBits As Long
    Dim nameLen As Long
    Dim extraLen As Long
    Dim commentLen As Long
    Dim compSize As Long
    Dim nextPos As Long

    ZipHasEncryptedEntries = 0
    eocdPos = FindEndCentralDir(zipPath)

    fh = FreeFile
    If Open(zipPath For Binary Access Read As #fh) <> 0 Then Exit Function
    fileLen = LOF(fh)

    If eocdPos > 0 Then
        entryCount = ReadU16LE(fh, eocdPos + 10)
        centralPos = ReadU32LE(fh, eocdPos + 16) + 1

        p = centralPos
        For entryIndex = 1 To entryCount
            If p < 1 Or p + 45 > fileLen Then Exit For
            If ReadU32LE(fh, p) <> &H02014B50 Then Exit For

            flagBits = ReadU16LE(fh, p + 8)
            If (flagBits And 1) <> 0 Then
                ZipHasEncryptedEntries = 1
                Close #fh
                Exit Function
            End If

            nameLen = ReadU16LE(fh, p + 28)
            extraLen = ReadU16LE(fh, p + 30)
            commentLen = ReadU16LE(fh, p + 32)
            p = p + 46 + nameLen + extraLen + commentLen
        Next entryIndex

        Close #fh
        Exit Function
    End If

    p = 1
    Do While p + 29 <= fileLen
        If ReadU32LE(fh, p) = &H04034B50 Then
            flagBits = ReadU16LE(fh, p + 6)
            If (flagBits And 1) <> 0 Then
                ZipHasEncryptedEntries = 1
                Close #fh
                Exit Function
            End If

            compSize = ReadU32LE(fh, p + 18)
            nameLen = ReadU16LE(fh, p + 26)
            extraLen = ReadU16LE(fh, p + 28)
            nextPos = p + 30 + nameLen + extraLen + compSize
            If nextPos <= p Then
                p = p + 1
            Else
                p = nextPos
            End If
        Else
            p = p + 1
        End If
    Loop

    Close #fh
END FUNCTION

SUB ClearExtractLog(ByVal titleText As String)
    Dim f As Integer
    Dim usedPath As String

    usedPath = OpenForOutput(XLOG_PREF, XLOG_LOCAL, f)
    If Len(usedPath) > 0 Then
        Print #f, titleText
        Print #f, "Log path: " & usedPath
        Close #f
    End If
END SUB

SUB AppendExtractLog(ByVal lineText As String)
    Dim f As Integer
    Dim usedPath As String

    usedPath = OpenForAppend(XLOG_PREF, XLOG_LOCAL, f)
    If Len(usedPath) > 0 Then
        Print #f, lineText
        Close #f
    End If
END SUB

SUB ClearTestLog(ByVal titleText As String)
    Dim f As Integer
    Dim usedPath As String

    usedPath = OpenForOutput(TLOG_PREF, TLOG_LOCAL, f)
    If Len(usedPath) > 0 Then
        Print #f, titleText
        Print #f, "Log path: " & usedPath
        Close #f
    End If
END SUB

SUB AppendTestLog(ByVal lineText As String)
    Dim f As Integer
    Dim usedPath As String

    usedPath = OpenForAppend(TLOG_PREF, TLOG_LOCAL, f)
    If Len(usedPath) > 0 Then
        Print #f, lineText
        Close #f
    End If
END SUB

SUB RunZipExtract(ByVal zipPath As String, ByVal destPath As String, ByVal passText As String)
    Dim useDirs As Integer
    Dim useOverwrite As Integer
    Dim useFreshen As Integer
    Dim useNewer As Integer
    Dim useVol As Integer
    Dim switches As String
    Dim logLine As String
    Dim cmdLine As String
    Dim exitCode As Integer
    Dim encryptedFlag As Integer
    Dim passwordWasBlank As Integer

    ClearExtractLog "Archive Manager ZIP extraction log"

    zipPath = StripOuterQuotes(zipPath)
    destPath = StripOuterQuotes(destPath)
    passText = StripOuterQuotes(passText)
    passwordWasBlank = 0
    If Len(passText) = 0 Then passwordWasBlank = 1

    If NeedsDefaultDest(destPath) <> 0 Then
        destPath = ArchiveDirectory(zipPath)
        AppendExtractLog "Destination defaulted to archive folder: " & destPath
    Else
        destPath = TrimTrailingSlash(destPath)
    End If

    If FileExists(zipPath) = 0 Then
        AppendExtractLog "ZIP file not found: " & zipPath
        Exit Sub
    End If

    If IsSafeText(zipPath) = 0 Or IsSafeText(destPath) = 0 Or IsSafeText(passText) = 0 Then
        AppendExtractLog "Unsafe archive, destination, or password text. Extraction stopped."
        Exit Sub
    End If

    encryptedFlag = ZipHasEncryptedEntries(zipPath)
    If encryptedFlag <> 0 And passwordWasBlank <> 0 Then
        AppendExtractLog "Password required: this archive contains encrypted files."
        AppendExtractLog "Extraction stopped before PKUNZIP was run."
        AppendExtractLog "Enter the password in Archive Manager and click Extract again."
        Exit Sub
    End If

    useDirs = ConfigFlag("OPT_DIRS", 1)
    useOverwrite = ConfigFlag("OPT_OVERWRITE", 1)
    useFreshen = ConfigFlag("OPT_FRESHEN", 0)
    useNewer = ConfigFlag("OPT_NEWER", 0)
    useVol = ConfigFlag("OPT_VOL", 0)

    switches = ""
    If useDirs <> 0 Then switches = switches & " -d"
    If useOverwrite <> 0 Then switches = switches & " -o"
    If useFreshen <> 0 Then switches = switches & " -f"
    If useNewer <> 0 Then switches = switches & " -n"
    If useVol <> 0 Then switches = switches & " -$"

    If useOverwrite = 0 And useFreshen = 0 And useNewer = 0 Then
        switches = switches & " -n"
        AppendExtractLog "No overwrite mode was selected; added -n to avoid prompts."
    End If

    logLine = switches
    If passwordWasBlank = 0 Then
        switches = switches & " -s" & passText
        logLine = logLine & " -s*****"
        AppendExtractLog "Password: supplied"
    Else
        AppendExtractLog "Password: not supplied"
        AppendExtractLog "No ZIP password switch was added."
    End If

    cmdLine = "COMMAND.COM /C PKUNZIP" & switches & " " & Q(zipPath) & " " & Q(destPath) & " >> " & CurrentExtractLogPath() & " < NUL"
    AppendExtractLog "Tool: PKUNZIP"
    AppendExtractLog "Switches: " & TrimAll(logLine)
    AppendExtractLog "Archive: " & zipPath
    AppendExtractLog "Destination: " & destPath
    AppendExtractLog "Command: COMMAND.COM /C PKUNZIP " & TrimAll(logLine) & " " & Q(zipPath) & " " & Q(destPath) & " >> " & CurrentExtractLogPath() & " < NUL"

    exitCode = Shell(cmdLine)
    AppendExtractLog "Exit code: " & Str$(exitCode)
END SUB

SUB RunZipTest(ByVal zipPath As String, ByVal passText As String)
    Dim switches As String
    Dim logLine As String
    Dim cmdLine As String
    Dim exitCode As Integer
    Dim encryptedFlag As Integer

    ClearTestLog "Archive Manager ZIP test log"

    zipPath = StripOuterQuotes(zipPath)
    passText = StripOuterQuotes(passText)

    If FileExists(zipPath) = 0 Then
        AppendTestLog "ZIP file not found: " & zipPath
        Exit Sub
    End If

    If IsSafeText(zipPath) = 0 Or IsSafeText(passText) = 0 Then
        AppendTestLog "Unsafe archive or password text. Test stopped."
        Exit Sub
    End If

    switches = "-t"
    logLine = "-t"
    encryptedFlag = ZipHasEncryptedEntries(zipPath)
    If encryptedFlag <> 0 And Len(passText) = 0 Then
        AppendTestLog "Password required: this archive contains encrypted files."
        AppendTestLog "Test stopped before PKUNZIP was run."
        Exit Sub
    End If

    If Len(passText) > 0 Then
        switches = switches & " -s" & passText
        logLine = logLine & " -s*****"
        AppendTestLog "Password: supplied"
    Else
        AppendTestLog "Password: not supplied"
        AppendTestLog "No ZIP password switch was added."
    End If

    cmdLine = "COMMAND.COM /C PKUNZIP " & switches & " " & Q(zipPath) & " > " & CurrentTestLogPath() & " < NUL"
    AppendTestLog "Tool: PKUNZIP"
    AppendTestLog "Switches: " & logLine
    AppendTestLog "Archive: " & zipPath
    AppendTestLog "Command: COMMAND.COM /C PKUNZIP " & logLine & " " & Q(zipPath) & " > " & CurrentTestLogPath() & " < NUL"

    exitCode = Shell(cmdLine)
    AppendTestLog "Exit code: " & Str$(exitCode)
END SUB

SUB RunArjExtract(ByVal arjPath As String, ByVal destPath As String, ByVal passText As String)
    Dim useDirs As Integer
    Dim useOverwrite As Integer
    Dim useFreshen As Integer
    Dim useNewer As Integer
    Dim cmdName As String
    Dim switches As String
    Dim logSwitches As String
    Dim cmdLine As String
    Dim exitCode As Integer
    Dim destForRun As String

    ClearExtractLog "Archive Manager ARJ extraction log"

    arjPath = StripOuterQuotes(arjPath)
    destPath = StripOuterQuotes(destPath)
    passText = StripOuterQuotes(passText)

    If NeedsDefaultDest(destPath) <> 0 Then
        destPath = ArchiveDirectory(arjPath)
        AppendExtractLog "Destination defaulted to archive folder: " & destPath
    Else
        destPath = TrimTrailingSlash(destPath)
    End If

    If FileExists(arjPath) = 0 Then
        AppendExtractLog "ARJ file not found: " & arjPath
        Exit Sub
    End If

    If IsSafeText(arjPath) = 0 Or IsSafeText(destPath) = 0 Or IsSafeText(passText) = 0 Then
        AppendExtractLog "Unsafe archive, destination, or password text. Extraction stopped."
        Exit Sub
    End If

    useDirs = ConfigFlag("OPT_DIRS", 1)
    useOverwrite = ConfigFlag("OPT_OVERWRITE", 1)
    useFreshen = ConfigFlag("OPT_FRESHEN", 0)
    useNewer = ConfigFlag("OPT_NEWER", 0)

    If useDirs <> 0 Then
        cmdName = "x"
    Else
        cmdName = "e"
    End If

    switches = " -i -y"
    logSwitches = " -i -y"

    If useOverwrite = 0 And useFreshen = 0 And useNewer = 0 Then
        switches = switches & " -n"
        logSwitches = logSwitches & " -n"
        AppendExtractLog "No overwrite mode was selected; added -n to avoid replacing existing files."
    End If

    If useFreshen <> 0 Then
        switches = switches & " -f"
        logSwitches = logSwitches & " -f"
    End If

    If useNewer <> 0 Then
        switches = switches & " -u"
        logSwitches = logSwitches & " -u"
    End If

    If Len(passText) > 0 Then
        switches = switches & " -g" & passText
        logSwitches = logSwitches & " -g*****"
        AppendExtractLog "Password: supplied"
    Else
        AppendExtractLog "Password: not supplied"
        AppendExtractLog "No ARJ password switch was added."
    End If

    destForRun = EnsureTrailingSlash(destPath)
    cmdLine = "COMMAND.COM /C ARJ " & cmdName & switches & " " & Q(arjPath) & " " & Q(destForRun) & " *.* > " & CurrentExtractLogPath() & " < NUL"
    AppendExtractLog "Tool: ARJ"
    AppendExtractLog "ARJ command: " & cmdName
    AppendExtractLog "Switches: " & TrimAll(logSwitches)
    AppendExtractLog "Archive: " & arjPath
    AppendExtractLog "Destination: " & destPath
    AppendExtractLog "Destination argument: " & destForRun
    AppendExtractLog "Command: COMMAND.COM /C ARJ " & cmdName & " " & TrimAll(logSwitches) & " " & Q(arjPath) & " " & Q(destForRun) & " *.* > " & CurrentExtractLogPath() & " < NUL"

    exitCode = Shell(cmdLine)
    AppendExtractLog "Exit code: " & Str$(exitCode)
END SUB

SUB RunArjTest(ByVal arjPath As String, ByVal passText As String)
    Dim switches As String
    Dim logSwitches As String
    Dim cmdLine As String
    Dim exitCode As Integer

    ClearTestLog "Archive Manager ARJ test log"

    arjPath = StripOuterQuotes(arjPath)
    passText = StripOuterQuotes(passText)

    If FileExists(arjPath) = 0 Then
        AppendTestLog "ARJ file not found: " & arjPath
        Exit Sub
    End If

    If IsSafeText(arjPath) = 0 Or IsSafeText(passText) = 0 Then
        AppendTestLog "Unsafe archive or password text. Test stopped."
        Exit Sub
    End If

    switches = " -i"
    logSwitches = " -i"

    If Len(passText) > 0 Then
        switches = switches & " -g" & passText
        logSwitches = logSwitches & " -g*****"
        AppendTestLog "Password: supplied"
    Else
        AppendTestLog "Password: not supplied"
        AppendTestLog "No ARJ password switch was added."
    End If

    cmdLine = "COMMAND.COM /C ARJ t" & switches & " " & Q(arjPath) & " > " & CurrentTestLogPath() & " < NUL"
    AppendTestLog "Tool: ARJ"
    AppendTestLog "Switches: " & TrimAll(logSwitches)
    AppendTestLog "Archive: " & arjPath
    AppendTestLog "Command: COMMAND.COM /C ARJ t " & TrimAll(logSwitches) & " " & Q(arjPath) & " > " & CurrentTestLogPath() & " < NUL"

    exitCode = Shell(cmdLine)
    AppendTestLog "Exit code: " & Str$(exitCode)
END SUB

SUB RunRarExtract(ByVal rarPath As String, ByVal destPath As String, ByVal passText As String)
    Dim useDirs As Integer
    Dim useOverwrite As Integer
    Dim useFreshen As Integer
    Dim useNewer As Integer
    Dim cmdName As String
    Dim switches As String
    Dim logSwitches As String
    Dim cmdLine As String
    Dim exitCode As Integer
    Dim destForRun As String

    ClearExtractLog "Archive Manager RAR extraction log"

    rarPath = StripOuterQuotes(rarPath)
    destPath = StripOuterQuotes(destPath)
    passText = StripOuterQuotes(passText)

    If NeedsDefaultDest(destPath) <> 0 Then
        destPath = ArchiveDirectory(rarPath)
        AppendExtractLog "Destination defaulted to archive folder: " & destPath
    Else
        destPath = TrimTrailingSlash(destPath)
    End If

    If FileExists(rarPath) = 0 Then
        AppendExtractLog "RAR file not found: " & rarPath
        Exit Sub
    End If

    If IsSafeText(rarPath) = 0 Or IsSafeText(destPath) = 0 Or IsSafeText(passText) = 0 Then
        AppendExtractLog "Unsafe archive, destination, or password text. Extraction stopped."
        Exit Sub
    End If

    useDirs = ConfigFlag("OPT_DIRS", 1)
    useOverwrite = ConfigFlag("OPT_OVERWRITE", 1)
    useFreshen = ConfigFlag("OPT_FRESHEN", 0)
    useNewer = ConfigFlag("OPT_NEWER", 0)

    If useDirs <> 0 Then
        cmdName = "x"
    Else
        cmdName = "e"
    End If

    switches = " -y"
    logSwitches = " -y"

    If useOverwrite <> 0 Then
        switches = switches & " -o+"
        logSwitches = logSwitches & " -o+"
    Else
        switches = switches & " -o-"
        logSwitches = logSwitches & " -o-"
        AppendExtractLog "No overwrite mode was selected; added -o- to avoid replacing existing files."
    End If

    If useFreshen <> 0 Then
        switches = switches & " -f"
        logSwitches = logSwitches & " -f"
    End If

    If useNewer <> 0 Then
        switches = switches & " -u"
        logSwitches = logSwitches & " -u"
    End If

    If Len(passText) > 0 Then
        switches = switches & " -p" & passText
        logSwitches = logSwitches & " -p*****"
        AppendExtractLog "Password: supplied"
    Else
        AppendExtractLog "Password: not supplied"
        AppendExtractLog "No RAR password switch was added."
    End If

    destForRun = EnsureTrailingSlash(destPath)
    cmdLine = "COMMAND.COM /C UNRAR " & cmdName & switches & " " & Q(rarPath) & " *.* " & Q(destForRun) & " > " & CurrentExtractLogPath() & " < NUL"
    AppendExtractLog "Tool: UNRAR"
    AppendExtractLog "UNRAR command: " & cmdName
    AppendExtractLog "Switches: " & TrimAll(logSwitches)
    AppendExtractLog "Archive: " & rarPath
    AppendExtractLog "Destination: " & destPath
    AppendExtractLog "Destination argument: " & destForRun
    AppendExtractLog "Command: COMMAND.COM /C UNRAR " & cmdName & " " & TrimAll(logSwitches) & " " & Q(rarPath) & " *.* " & Q(destForRun) & " > " & CurrentExtractLogPath() & " < NUL"

    exitCode = Shell(cmdLine)
    AppendExtractLog "Exit code: " & Str$(exitCode)
END SUB

SUB RunRarTest(ByVal rarPath As String, ByVal passText As String)
    Dim switches As String
    Dim logSwitches As String
    Dim cmdLine As String
    Dim exitCode As Integer

    ClearTestLog "Archive Manager RAR test log"

    rarPath = StripOuterQuotes(rarPath)
    passText = StripOuterQuotes(passText)

    If FileExists(rarPath) = 0 Then
        AppendTestLog "RAR file not found: " & rarPath
        Exit Sub
    End If

    If IsSafeText(rarPath) = 0 Or IsSafeText(passText) = 0 Then
        AppendTestLog "Unsafe archive or password text. Test stopped."
        Exit Sub
    End If

    switches = " -y"
    logSwitches = " -y"

    If Len(passText) > 0 Then
        switches = switches & " -p" & passText
        logSwitches = logSwitches & " -p*****"
        AppendTestLog "Password: supplied"
    Else
        AppendTestLog "Password: not supplied"
        AppendTestLog "No RAR password switch was added."
    End If

    cmdLine = "COMMAND.COM /C UNRAR t" & switches & " " & Q(rarPath) & " > " & CurrentTestLogPath() & " < NUL"
    AppendTestLog "Tool: UNRAR"
    AppendTestLog "Switches: " & TrimAll(logSwitches)
    AppendTestLog "Archive: " & rarPath
    AppendTestLog "Command: COMMAND.COM /C UNRAR t " & TrimAll(logSwitches) & " " & Q(rarPath) & " > " & CurrentTestLogPath() & " < NUL"

    exitCode = Shell(cmdLine)
    AppendTestLog "Exit code: " & Str$(exitCode)
END SUB


SUB RunAceExtract(ByVal acePath As String, ByVal destPath As String, ByVal passText As String)
    Dim useDirs As Integer
    Dim cmdName As String
    Dim cmdLine As String
    Dim exitCode As Integer
    Dim destForRun As String

    ClearExtractLog "Archive Manager ACE extraction log"

    acePath = StripOuterQuotes(acePath)
    destPath = StripOuterQuotes(destPath)
    passText = StripOuterQuotes(passText)

    If NeedsDefaultDest(destPath) <> 0 Then
        destPath = ArchiveDirectory(acePath)
        AppendExtractLog "Destination defaulted to archive folder: " & destPath
    Else
        destPath = TrimTrailingSlash(destPath)
    End If

    If FileExists(acePath) = 0 Then
        AppendExtractLog "ACE file not found: " & acePath
        Exit Sub
    End If

    If IsSafeText(acePath) = 0 Or IsSafeText(destPath) = 0 Or IsSafeText(passText) = 0 Then
        AppendExtractLog "Unsafe archive, destination, or password text. Extraction stopped."
        Exit Sub
    End If

    useDirs = ConfigFlag("OPT_DIRS", 1)

    If useDirs <> 0 Then
        cmdName = "x"
    Else
        cmdName = "e"
    End If

    If Len(passText) > 0 Then
        AppendExtractLog "Password: supplied, but UNACE 1.1b help lists no password switch. No password switch was added."
    Else
        AppendExtractLog "Password: not supplied"
        AppendExtractLog "No ACE password switch was added."
    End If

    destForRun = EnsureTrailingSlash(destPath)
    cmdLine = "COMMAND.COM /C UNACE " & cmdName & " " & Q(acePath) & " " & Q(destForRun) & " > " & CurrentExtractLogPath() & " < NUL"
    AppendExtractLog "Tool: UNACE"
    AppendExtractLog "UNACE command: " & cmdName
    AppendExtractLog "Archive: " & acePath
    AppendExtractLog "Destination: " & destPath
    AppendExtractLog "Destination argument: " & destForRun
    AppendExtractLog "Command: COMMAND.COM /C UNACE " & cmdName & " " & Q(acePath) & " " & Q(destForRun) & " > " & CurrentExtractLogPath() & " < NUL"

    exitCode = Shell(cmdLine)
    AppendExtractLog "Exit code: " & Str$(exitCode)
END SUB

SUB RunAceTest(ByVal acePath As String, ByVal passText As String)
    Dim cmdLine As String
    Dim exitCode As Integer

    ClearTestLog "Archive Manager ACE test log"

    acePath = StripOuterQuotes(acePath)
    passText = StripOuterQuotes(passText)

    If FileExists(acePath) = 0 Then
        AppendTestLog "ACE file not found: " & acePath
        Exit Sub
    End If

    If IsSafeText(acePath) = 0 Or IsSafeText(passText) = 0 Then
        AppendTestLog "Unsafe archive or password text. Test stopped."
        Exit Sub
    End If

    If Len(passText) > 0 Then
        AppendTestLog "Password: supplied, but UNACE 1.1b help lists no password switch. No password switch was added."
    Else
        AppendTestLog "Password: not supplied"
        AppendTestLog "No ACE password switch was added."
    End If

    cmdLine = "COMMAND.COM /C UNACE t " & Q(acePath) & " > " & CurrentTestLogPath() & " < NUL"
    AppendTestLog "Tool: UNACE"
    AppendTestLog "Archive: " & acePath
    AppendTestLog "Command: COMMAND.COM /C UNACE t " & Q(acePath) & " > " & CurrentTestLogPath() & " < NUL"

    exitCode = Shell(cmdLine)
    AppendTestLog "Exit code: " & Str$(exitCode)
END SUB

SUB RunExtract(ByVal archivePath As String, ByVal destPath As String, ByVal passText As String)
    Dim extName As String

    archivePath = StripOuterQuotes(archivePath)
    extName = ArchiveExt(archivePath)

    If extName = "ZIP" Then
        RunZipExtract archivePath, destPath, passText
    ElseIf extName = "ARJ" Then
        RunArjExtract archivePath, destPath, passText
    ElseIf extName = "RAR" Then
        RunRarExtract archivePath, destPath, passText
    ElseIf extName = "ACE" Then
        RunAceExtract archivePath, destPath, passText
    Else
        ClearExtractLog "Archive Manager extraction log"
        AppendExtractLog "Unsupported archive type: " & extName
        AppendExtractLog "Archive: " & archivePath
    End If
END SUB

SUB RunTest(ByVal archivePath As String, ByVal passText As String)
    Dim extName As String

    archivePath = StripOuterQuotes(archivePath)
    extName = ArchiveExt(archivePath)

    If extName = "ZIP" Then
        RunZipTest archivePath, passText
    ElseIf extName = "ARJ" Then
        RunArjTest archivePath, passText
    ElseIf extName = "RAR" Then
        RunRarTest archivePath, passText
    ElseIf extName = "ACE" Then
        RunAceTest archivePath, passText
    Else
        ClearTestLog "Archive Manager test log"
        AppendTestLog "Unsupported archive type: " & extName
        AppendTestLog "Archive: " & archivePath
    End If
END SUB

Dim modeText As String
Dim arcArg As String
Dim destArg As String
Dim passArg As String

modeText = UpperText(TrimAll(Command$(1)))
If modeText = "EXTRACT" Then
    If InStr(Command$(2), "=") > 0 Then
        arcArg = ArgValue(Command$(2), "ARC")
        destArg = ArgValue(Command$(3), "DEST")
        passArg = ArgValue(Command$(4), "PASS")
        RunExtract arcArg, destArg, passArg
    Else
        RunExtract Command$(2), Command$(3), Command$(4)
    End If
ElseIf modeText = "TEST" Then
    If InStr(Command$(2), "=") > 0 Then
        arcArg = ArgValue(Command$(2), "ARC")
        passArg = ArgValue(Command$(3), "PASS")
        RunTest arcArg, passArg
    Else
        RunTest Command$(2), Command$(3)
    End If
Else
    ClearExtractLog "Archive Manager backend log"
    AppendExtractLog "Usage: ARCHRUN EXTRACT ARC=archive DEST=destdir PASS=password"
    AppendExtractLog "Usage: ARCHRUN TEST ARC=archive PASS=password"
End If
