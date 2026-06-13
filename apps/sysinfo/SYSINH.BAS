' System Info helper source. It gathers system, disk, memory, video, sound, and configuration information for display.
'
#include once "dos/dpmi.bi"
#include once "dos/go32.bi"
#include once "dos/sys/farptr.bi"

' SYSINH.BAS
' Backlash System Info helper.

Const REPORT_FILE As String = "REPORT.TXT"
Const STATUS_FILE As String = "STATUS.TXT"
Const ROOT_REPORT As String = "SYSINFO.TXT"

Declare Function BacklashDisplayText() As String
Declare Function IsCdromDrive(ByVal driveNumber As Integer) As Integer
Declare Function IsRemoteDrive(ByVal driveNumber As Integer) As Integer

' ---------------------------
' Basic string and file helpers
' ---------------------------

Function CleanLine(ByVal s As String) As String
    s = Trim$(s)
    If Len(s) > 250 Then s = Left$(s, 250)
    Return s
End Function

Sub AddLine(ByRef reportText As String, ByVal lineText As String)
    reportText = reportText + lineText + Chr$(13) + Chr$(10)
End Sub

Sub WriteTextFile(ByVal fileName As String, ByVal textValue As String)
    Dim fileNum As Integer

    fileNum = FreeFile
    Open fileName For Output As #fileNum
    Print #fileNum, textValue;
    Close #fileNum
End Sub

Function FileExists(ByVal fileName As String) As Integer
    Dim fileNum As Integer

    fileNum = FreeFile
    If Open(fileName For Input As #fileNum) = 0 Then
        Close #fileNum
        Return -1
    End If

    Return 0
End Function

Function ReadCfgValue(ByVal fileName As String, ByVal keyName As String, ByVal defaultValue As String) As String
    Dim fileNum As Integer
    Dim lineText As String
    Dim eqPos As Integer
    Dim leftKey As String
    Dim rightValue As String
    Dim keyUpper As String

    keyUpper = UCase$(Trim$(keyName))
    If keyUpper = "" Then Return defaultValue

    fileNum = FreeFile
    If Open(fileName For Input As #fileNum) <> 0 Then Return defaultValue
    Do Until Eof(fileNum)
        Line Input #fileNum, lineText
        lineText = Trim$(lineText)
        If Len(lineText) > 0 Then
            If Left$(lineText, 1) <> "#" And Left$(lineText, 1) <> ";" Then
                eqPos = InStr(lineText, "=")
                If eqPos > 0 Then
                    leftKey = UCase$(Trim$(Left$(lineText, eqPos - 1)))
                    If leftKey = keyUpper Then
                        rightValue = Trim$(Mid$(lineText, eqPos + 1))
                        Close #fileNum
                        Return rightValue
                    End If
                End If
            End If
        End If
    Loop
    Close #fileNum

    Return defaultValue
End Function

Function ReadFirstCfgValue(ByVal fileName As String, ByVal key1 As String, ByVal key2 As String, ByVal key3 As String, ByVal key4 As String, ByVal defaultValue As String) As String
    Dim fileNum As Integer
    Dim lineText As String
    Dim eqPos As Integer
    Dim leftKey As String
    Dim rightValue As String
    Dim key1Upper As String
    Dim key2Upper As String
    Dim key3Upper As String
    Dim key4Upper As String
    Dim value1 As String
    Dim value2 As String
    Dim value3 As String
    Dim value4 As String

    key1Upper = UCase$(Trim$(key1))
    key2Upper = UCase$(Trim$(key2))
    key3Upper = UCase$(Trim$(key3))
    key4Upper = UCase$(Trim$(key4))

    fileNum = FreeFile
    If Open(fileName For Input As #fileNum) <> 0 Then Return defaultValue
    Do Until Eof(fileNum)
        Line Input #fileNum, lineText
        lineText = Trim$(lineText)
        If Len(lineText) > 0 Then
            If Left$(lineText, 1) <> "#" And Left$(lineText, 1) <> ";" Then
                eqPos = InStr(lineText, "=")
                If eqPos > 0 Then
                    leftKey = UCase$(Trim$(Left$(lineText, eqPos - 1)))
                    rightValue = Trim$(Mid$(lineText, eqPos + 1))
                    If value1 = "" And key1Upper <> "" And leftKey = key1Upper Then value1 = rightValue
                    If value2 = "" And key2Upper <> "" And leftKey = key2Upper Then value2 = rightValue
                    If value3 = "" And key3Upper <> "" And leftKey = key3Upper Then value3 = rightValue
                    If value4 = "" And key4Upper <> "" And leftKey = key4Upper Then value4 = rightValue
                End If
            End If
        End If
    Loop
    Close #fileNum

    If value1 <> "" Then Return value1
    If value2 <> "" Then Return value2
    If value3 <> "" Then Return value3
    If value4 <> "" Then Return value4

    Return defaultValue
End Function

Function FirstExistingPath(ByVal path1 As String, ByVal path2 As String, ByVal path3 As String, ByVal path4 As String, ByVal path5 As String, ByVal path6 As String) As String
    If path1 <> "" Then
        If FileExists(path1) <> 0 Then Return path1
    End If
    If path2 <> "" Then
        If FileExists(path2) <> 0 Then Return path2
    End If
    If path3 <> "" Then
        If FileExists(path3) <> 0 Then Return path3
    End If
    If path4 <> "" Then
        If FileExists(path4) <> 0 Then Return path4
    End If
    If path5 <> "" Then
        If FileExists(path5) <> 0 Then Return path5
    End If
    If path6 <> "" Then
        If FileExists(path6) <> 0 Then Return path6
    End If
    Return ""
End Function

Function FindDisplayCfg() As String
    Dim foundPath As String

    foundPath = FirstExistingPath("SYSTEM\DISPLAY.CFG", "..\..\SYSTEM\DISPLAY.CFG", "\SYSTEM\DISPLAY.CFG", "DISPLAY.CFG", "", "")
    If foundPath <> "" Then Return foundPath
    Return "SYSTEM\DISPLAY.CFG"
End Function

Function FindConfigSys() As String
    Return FirstExistingPath("CONFIG.SYS", "..\..\CONFIG.SYS", "\CONFIG.SYS", "", "", "")
End Function

Function FindAutoexecBat() As String
    Return FirstExistingPath("AUTOEXEC.BAT", "..\..\AUTOEXEC.BAT", "\AUTOEXEC.BAT", "", "", "")
End Function

Function FindThemeCfg() As String
    Return FirstExistingPath("SYSTEM\THEME.CFG", "..\..\SYSTEM\THEME.CFG", "\SYSTEM\THEME.CFG", "SYSTEM\THEMES.CFG", "..\..\SYSTEM\THEMES.CFG", "\SYSTEM\THEMES.CFG")
End Function

Function FindWallpaperCfg() As String
    Return FirstExistingPath("SYSTEM\WALLPAPR.CFG", "..\..\SYSTEM\WALLPAPR.CFG", "\SYSTEM\WALLPAPR.CFG", "SYSTEM\WALLPAPER.CFG", "..\..\SYSTEM\WALLPAPER.CFG", "\SYSTEM\WALLPAPER.CFG")
End Function

Function FindScreenSaverCfg() As String
    Return FirstExistingPath("SYSTEM\SCRNSAVR.CFG", "..\..\SYSTEM\SCRNSAVR.CFG", "\SYSTEM\SCRNSAVR.CFG", "SYSTEM\SCREENSAVER.CFG", "..\..\SYSTEM\SCREENSAVER.CFG", "\SYSTEM\SCREENSAVER.CFG")
End Function

Function FindSoundCfg() As String
    Return FirstExistingPath("SYSTEM\SOUND.CFG", "..\..\SYSTEM\SOUND.CFG", "\SYSTEM\SOUND.CFG", "SOUND.CFG", "", "")
End Function

Function FindLaunchMenuCfg() As String
    Return FirstExistingPath("SYSTEM\LAUNCH.INI", "..\..\SYSTEM\LAUNCH.INI", "\SYSTEM\LAUNCH.INI", "SYSTEM\STRTMENU.INI", "..\..\SYSTEM\STRTMENU.INI", "\SYSTEM\STRTMENU.INI")
End Function

Function OneDecimal(ByVal valueNumber As Double) As String
    Dim scaledValue As Integer
    Dim wholePart As Integer
    Dim tenthPart As Integer

    scaledValue = CInt(valueNumber * 10.0 + 0.5)
    wholePart = scaledValue \ 10
    tenthPart = scaledValue Mod 10
    Return LTrim$(Str$(wholePart)) + "." + LTrim$(Str$(tenthPart))
End Function

Function FormatByteSize(ByVal byteCount As Double) As String
    If byteCount < 0.0 Then Return "unknown"
    If byteCount < 1024.0 Then Return LTrim$(Str$(CLng(byteCount))) + " bytes"
    If byteCount < 1048576.0 Then Return LTrim$(Str$(CLng((byteCount / 1024.0) + 0.5))) + " KB"
    If byteCount < 1073741824.0 Then Return OneDecimal(byteCount / 1048576.0) + " MB"
    Return OneDecimal(byteCount / 1073741824.0) + " GB"
End Function

Function DriveLetterText(ByVal driveNumber As Integer) As String
    Return Chr$(Asc("A") + driveNumber - 1) + ":"
End Function

Function HexWordText(ByVal valueNumber As Integer) As String
    Return "&H" + Hex$(valueNumber And &HFFFF, 4)
End Function

Function HexDwordText(ByVal valueNumber As UInteger) As String
    Return "&H" + Hex$(valueNumber, 8)
End Function

Function YesNoText(ByVal trueValue As Integer) As String
    If trueValue <> 0 Then Return "yes"
    Return "no"
End Function

Function EnvValueText(ByVal keyName As String) As String
    Dim valueText As String

    valueText = CleanLine(Environ$(keyName))
    If valueText = "" Then Return "not set"
    Return valueText
End Function

' ---------------------------
' DOS, CPU, and memory probes
' ---------------------------

Function DosVersionText() As String
    Dim regs As __dpmi_regs
    Dim majorVersion As Integer
    Dim minorVersion As Integer

    regs.x.ax = &H3000
    __dpmi_int(&H21, @regs)

    majorVersion = regs.x.ax And &HFF
    minorVersion = (regs.x.ax Shr 8) And &HFF

    Return LTrim$(Str$(majorVersion)) + "." + Right$("00" + LTrim$(Str$(minorVersion)), 2)
End Function

Function CpuClassText() As String
    Dim originalFlags As UInteger
    Dim toggledFlags As UInteger

    originalFlags = 0
    toggledFlags = 0

    Asm
        pushfd
        pop eax
        mov [originalFlags], eax
        xor eax, &H200000
        push eax
        popfd
        pushfd
        pop eax
        mov [toggledFlags], eax
        push dword ptr [originalFlags]
        popfd
    End Asm

    If ((originalFlags Xor toggledFlags) And &H200000) <> 0 Then
        Return "CPUID-capable 486/Pentium+"
    End If

    Return "386 or early 486 class"
End Function

Function FpuText() As String
    Dim regs As __dpmi_regs

    regs.x.ax = 0
    __dpmi_int(&H11, @regs)

    If (regs.x.ax And &H0002) <> 0 Then Return "present"
    Return "not reported by BIOS"
End Function

Function ConventionalMemoryText() As String
    Dim regs As __dpmi_regs
    Dim totalKb As Integer
    Dim largestKb As Double

    regs.x.ax = 0
    __dpmi_int(&H12, @regs)
    totalKb = regs.x.ax And &HFFFF

    regs.x.ax = &H4800
    regs.x.bx = &HFFFF
    __dpmi_int(&H21, @regs)

    If (regs.x.flags And 1) <> 0 Then
        largestKb = CDbl(regs.x.bx) * 16.0 / 1024.0
    Else
        largestKb = 0.0
    End If

    Return LTrim$(Str$(totalKb)) + " KB total, largest free block " + LTrim$(Str$(CLng(largestKb + 0.5))) + " KB"
End Function

Function XmsRealCall(ByVal commandNumber As Integer, ByRef axOut As Integer, ByRef bxOut As Integer, ByRef dxOut As Integer) As Integer
    Dim entryRegs As __dpmi_regs
    Dim callRegs As __dpmi_regs

    entryRegs.x.ax = &H4310
    __dpmi_int(&H2F, @entryRegs)

    If (entryRegs.x.ax And &HFF) <> &H80 Then Return 0
    If (entryRegs.x.es And &HFFFF) = 0 And (entryRegs.x.bx And &HFFFF) = 0 Then Return 0

    callRegs.x.ax = (commandNumber And &HFF) Shl 8
    callRegs.x.bx = 0
    callRegs.x.cx = 0
    callRegs.x.dx = 0
    callRegs.x.si = 0
    callRegs.x.di = 0
    callRegs.x.ds = 0
    callRegs.x.es = 0
    callRegs.x.cs = entryRegs.x.es And &HFFFF
    callRegs.x.ip = entryRegs.x.bx And &HFFFF
    callRegs.x.ss = 0
    callRegs.x.sp = 0

    If __dpmi_simulate_real_mode_procedure_retf(@callRegs) <> 0 Then Return 0

    axOut = callRegs.x.ax And &HFFFF
    bxOut = callRegs.x.bx And &HFFFF
    dxOut = callRegs.x.dx And &HFFFF

    Return -1
End Function

Function XmsText() As String
    Dim regs As __dpmi_regs
    Dim axOut As Integer
    Dim bxOut As Integer
    Dim dxOut As Integer
    Dim versionText As String
    Dim freeText As String
    Dim hmaText As String
    Dim largestKb As Integer
    Dim totalFreeKb As Integer

    regs.x.ax = &H4300
    __dpmi_int(&H2F, @regs)

    If (regs.x.ax And &HFF) <> &H80 Then Return "not detected"

    versionText = "version unavailable"
    freeText = "free memory unavailable"
    hmaText = "HMA unknown"

    If XmsRealCall(&H00, axOut, bxOut, dxOut) <> 0 Then
        versionText = "XMS " + LTrim$(Str$((axOut Shr 8) And &HFF)) + "." + Right$("00" + LTrim$(Str$(axOut And &HFF)), 2)
        hmaText = "HMA " + YesNoText(dxOut <> 0)
    End If

    If XmsRealCall(&H08, axOut, bxOut, dxOut) <> 0 Then
        largestKb = axOut And &HFFFF
        totalFreeKb = dxOut And &HFFFF
        If largestKb <> 0 Or totalFreeKb <> 0 Then
            freeText = LTrim$(Str$(totalFreeKb)) + " KB free, largest free block " + LTrim$(Str$(largestKb)) + " KB"
        End If
    End If

    Return "driver present, " + versionText + ", " + freeText + ", " + hmaText
End Function

Function EmsText() As String
    Dim regs As __dpmi_regs
    Dim statusCode As Integer
    Dim versionByte As Integer
    Dim freePages As Integer
    Dim totalPages As Integer
    Dim freeKb As Integer
    Dim totalKb As Integer
    Dim versionText As String

    regs.x.ax = &H4000
    __dpmi_int(&H67, @regs)
    statusCode = (regs.x.ax Shr 8) And &HFF
    If statusCode <> 0 Then Return "not detected"

    versionText = "version unavailable"
    regs.x.ax = &H4600
    __dpmi_int(&H67, @regs)
    statusCode = (regs.x.ax Shr 8) And &HFF
    If statusCode = 0 Then
        versionByte = regs.x.ax And &HFF
        versionText = "EMS " + LTrim$(Str$((versionByte Shr 4) And &H0F)) + "." + LTrim$(Str$(versionByte And &H0F))
    End If

    regs.x.ax = &H4200
    __dpmi_int(&H67, @regs)
    statusCode = (regs.x.ax Shr 8) And &HFF
    If statusCode <> 0 Then Return "driver present, " + versionText + ", size unavailable"

    freePages = regs.x.bx And &HFFFF
    totalPages = regs.x.dx And &HFFFF
    freeKb = freePages * 16
    totalKb = totalPages * 16

    Return "driver present, " + versionText + ", " + LTrim$(Str$(freeKb)) + " KB free, " + LTrim$(Str$(totalKb)) + " KB total"
End Function

Function UmbText() As String
    Dim regs As __dpmi_regs

    regs.x.ax = &H5802
    __dpmi_int(&H21, @regs)

    If (regs.x.flags And 1) <> 0 Then Return "not reported by DOS"
    If (regs.x.ax And &HFFFF) = 0 Then Return "UMB chain not linked"
    If (regs.x.ax And &HFFFF) = 1 Then Return "UMB chain linked"
    Return "unknown link state " + HexWordText(regs.x.ax And &HFFFF)
End Function

' ---------------------------
' BIOS machine probes
' ---------------------------

Function ReadBiosWord(ByVal memoryAddress As UInteger) As UInteger
    Dim wordBytes(0 To 1) As UByte

    wordBytes(0) = 0
    wordBytes(1) = 0
    dosmemget memoryAddress, 2, @wordBytes(0)

    Return CUInt(wordBytes(0)) + CUInt(wordBytes(1)) * 256
End Function

Function BiosDateText() As String
    Dim dateBytes(0 To 7) As UByte
    Dim i As Integer
    Dim dateText As String

    For i = 0 To 7
        dateBytes(i) = 0
    Next i

    dosmemget &HFFFF5, 8, @dateBytes(0)

    dateText = ""
    For i = 0 To 7
        If dateBytes(i) < 32 Or dateBytes(i) > 126 Then Return "unavailable"
        dateText = dateText + Chr$(dateBytes(i))
    Next i

    dateText = CleanLine(dateText)
    If dateText = "" Then Return "unavailable"
    Return dateText
End Function

Function BiosMachineIdText() As String
    Dim machineByte As UByte

    machineByte = 0
    dosmemget &HFFFFE, 1, @machineByte

    Select Case machineByte
    Case &HFC
        Return "AT / 286-class BIOS ID " + HexWordText(machineByte)
    Case &HFA, &HFB
        Return "PS/2-class BIOS ID " + HexWordText(machineByte)
    Case &HFE
        Return "XT-class BIOS ID " + HexWordText(machineByte)
    Case &HFF
        Return "PC-class BIOS ID " + HexWordText(machineByte)
    End Select

    Return "BIOS ID " + HexWordText(machineByte)
End Function

Function BiosEquipmentFlags() As Integer
    Dim regs As __dpmi_regs

    regs.x.ax = 0
    __dpmi_int(&H11, @regs)

    Return regs.x.ax And &HFFFF
End Function

Function BiosInitialVideoText(ByVal equipmentFlags As Integer) As String
    Dim videoBits As Integer

    videoBits = (equipmentFlags Shr 4) And 3

    Select Case videoBits
    Case 0
        Return "EGA/VGA or none"
    Case 1
        Return "40x25 color"
    Case 2
        Return "80x25 color"
    Case 3
        Return "80x25 monochrome"
    End Select

    Return "unknown"
End Function

Function BiosFloppyCountText(ByVal equipmentFlags As Integer) As String
    Dim floppyCount As Integer

    If (equipmentFlags And 1) = 0 Then Return "not reported"

    floppyCount = ((equipmentFlags Shr 6) And 3) + 1
    Return LTrim$(Str$(floppyCount))
End Function

Function BiosFloppyTypeText(ByVal driveIndex As Integer) As String
    Dim regs As __dpmi_regs
    Dim typeCode As Integer

    regs.x.ax = &H0800
    regs.x.dx = driveIndex And &HFF
    __dpmi_int(&H13, @regs)

    If (regs.x.flags And 1) <> 0 Then Return "unavailable"

    typeCode = regs.x.bx And &HFF

    Select Case typeCode
    Case 1
        Return "360 KB 5.25"
    Case 2
        Return "1.2 MB 5.25"
    Case 3
        Return "720 KB 3.5"
    Case 4
        Return "1.44 MB 3.5"
    Case 5
        Return "2.88 MB 3.5"
    End Select

    Return "type " + LTrim$(Str$(typeCode))
End Function

Function KeyboardTypeText() As String
    Dim regs As __dpmi_regs

    regs.x.ax = &H1200
    __dpmi_int(&H16, @regs)

    If (regs.x.ax And &HFFFF) <> 0 Then Return "enhanced keyboard BIOS query available"
    Return "standard BIOS keyboard query"
End Function

Sub AddMachineReport(ByRef reportText As String)
    Dim equipmentFlags As Integer
    Dim serialPorts As Integer
    Dim parallelPorts As Integer
    Dim hasGamePort As Integer
    Dim floppyCount As Integer

    equipmentFlags = BiosEquipmentFlags()
    serialPorts = (equipmentFlags Shr 9) And 7
    parallelPorts = (equipmentFlags Shr 14) And 3
    hasGamePort = equipmentFlags And &H1000

    AddLine reportText, "BIOS / Machine"
    AddLine reportText, "--------------"
    AddLine reportText, "BIOS date: " + BiosDateText()
    AddLine reportText, "Machine ID: " + BiosMachineIdText()
    AddLine reportText, "Equipment flags: " + HexWordText(equipmentFlags)
    AddLine reportText, "Floppy drives: " + BiosFloppyCountText(equipmentFlags)

    If (equipmentFlags And 1) <> 0 Then
        floppyCount = ((equipmentFlags Shr 6) And 3) + 1
        If floppyCount >= 1 Then AddLine reportText, "Floppy A type: " + BiosFloppyTypeText(0)
        If floppyCount >= 2 Then AddLine reportText, "Floppy B type: " + BiosFloppyTypeText(1)
    End If

    AddLine reportText, "Keyboard: " + KeyboardTypeText()
    AddLine reportText, "Initial video: " + BiosInitialVideoText(equipmentFlags)
    AddLine reportText, "Serial ports: " + LTrim$(Str$(serialPorts))
    AddLine reportText, "Parallel ports: " + LTrim$(Str$(parallelPorts))
    AddLine reportText, "Game port: " + YesNoText(hasGamePort)
    AddLine reportText, ""
End Sub

' ---------------------------
' Port probes
' ---------------------------

Sub AddPortReport(ByRef reportText As String)
    Dim portIndex As Integer
    Dim portAddress As UInteger
    Dim foundPort As Integer

    AddLine reportText, "Ports"
    AddLine reportText, "-----"

    foundPort = 0

    For portIndex = 0 To 3
        portAddress = ReadBiosWord(&H400 + CUInt(portIndex) * 2)
        If portAddress <> 0 Then
            AddLine reportText, "COM" + LTrim$(Str$(portIndex + 1)) + ": " + HexWordText(CInt(portAddress))
            foundPort = -1
        End If
    Next portIndex

    If foundPort = 0 Then AddLine reportText, "COM ports: none reported"

    foundPort = 0

    For portIndex = 0 To 2
        portAddress = ReadBiosWord(&H408 + CUInt(portIndex) * 2)
        If portAddress <> 0 Then
            AddLine reportText, "LPT" + LTrim$(Str$(portIndex + 1)) + ": " + HexWordText(CInt(portAddress))
            foundPort = -1
        End If
    Next portIndex

    If foundPort = 0 Then AddLine reportText, "LPT ports: none reported"

    AddLine reportText, ""
End Sub

' ---------------------------
' DOS config and environment report
' ---------------------------

Function ConfigSettingText(ByVal fileName As String, ByVal keyName As String) As String
    Dim valueText As String

    If fileName = "" Then Return "not found"
    valueText = ReadCfgValue(fileName, keyName, "")
    If valueText = "" Then Return "not set"
    Return valueText
End Function

Function ActiveConfigLine(ByVal sourceText As String) As String
    Dim lineText As String
    Dim upperText As String

    lineText = CleanLine(sourceText)
    If Left$(lineText, 1) = "@" Then lineText = Trim$(Mid$(lineText, 2))
    upperText = UCase$(lineText)

    If lineText = "" Then Return ""
    If Left$(lineText, 1) = ";" Then Return ""
    If Left$(lineText, 1) = "#" Then Return ""
    If Left$(upperText, 3) = "REM" Then
        If Len(upperText) = 3 Or Mid$(upperText, 4, 1) = " " Or Mid$(upperText, 4, 1) = Chr$(9) Then Return ""
    End If
    If Left$(upperText, 2) = "::" Then Return ""

    Return lineText
End Function

Function ConfigLineKey(ByVal lineText As String) As String
    Dim eqPos As Integer

    lineText = ActiveConfigLine(lineText)
    If lineText = "" Then Return ""

    eqPos = InStr(lineText, "=")
    If eqPos <= 0 Then Return ""

    Return UCase$(Trim$(Left$(lineText, eqPos - 1)))
End Function

Function ConfigLineValue(ByVal lineText As String) As String
    Dim eqPos As Integer

    lineText = ActiveConfigLine(lineText)
    If lineText = "" Then Return ""

    eqPos = InStr(lineText, "=")
    If eqPos <= 0 Then Return ""

    Return CleanLine(Mid$(lineText, eqPos + 1))
End Function

Function AutoexecCommandMatches(ByVal lineText As String, ByVal commandName As String) As Integer
    Dim upperText As String
    Dim commandLen As Integer
    Dim nextChar As String

    upperText = UCase$(ActiveConfigLine(lineText))
    commandName = UCase$(commandName)
    commandLen = Len(commandName)

    If upperText = "" Then Return 0
    If Left$(upperText, commandLen) <> commandName Then Return 0
    If Len(upperText) = commandLen Then Return -1

    nextChar = Mid$(upperText, commandLen + 1, 1)
    If nextChar = " " Or nextChar = Chr$(9) Or nextChar = "=" Then Return -1

    Return 0
End Function

Sub AddConfigKeyLines(ByRef reportText As String, ByVal fileName As String, ByVal labelText As String, ByVal keyName As String, ByVal maxLines As Integer)
    Dim fileNum As Integer
    Dim lineText As String
    Dim valueText As String
    Dim matchCount As Integer
    Dim shownCount As Integer

    If fileName = "" Or FileExists(fileName) = 0 Then
        AddLine reportText, labelText + ": not found"
        Exit Sub
    End If

    matchCount = 0
    shownCount = 0
    fileNum = FreeFile
    Open fileName For Input As #fileNum
    Do Until Eof(fileNum)
        Line Input #fileNum, lineText
        If ConfigLineKey(lineText) = UCase$(keyName) Then
            matchCount = matchCount + 1
            If shownCount < maxLines Then
                valueText = ConfigLineValue(lineText)
                If valueText = "" Then valueText = "(blank)"
                AddLine reportText, labelText + " " + LTrim$(Str$(matchCount)) + ": " + valueText
                shownCount = shownCount + 1
            End If
        End If
    Loop
    Close #fileNum

    If matchCount = 0 Then
        AddLine reportText, labelText + ": not set"
    ElseIf matchCount > shownCount Then
        AddLine reportText, labelText + ": " + LTrim$(Str$(matchCount - shownCount)) + " more line(s) not shown"
    End If
End Sub

Sub AddAutoexecCommandLines(ByRef reportText As String, ByVal fileName As String, ByVal labelText As String, ByVal command1 As String, ByVal command2 As String, ByVal maxLines As Integer)
    Dim fileNum As Integer
    Dim lineText As String
    Dim activeText As String
    Dim matchCount As Integer
    Dim shownCount As Integer

    If fileName = "" Or FileExists(fileName) = 0 Then
        AddLine reportText, labelText + ": not found"
        Exit Sub
    End If

    matchCount = 0
    shownCount = 0
    fileNum = FreeFile
    Open fileName For Input As #fileNum
    Do Until Eof(fileNum)
        Line Input #fileNum, lineText
        activeText = ActiveConfigLine(lineText)
        If activeText <> "" Then
            If AutoexecCommandMatches(activeText, command1) <> 0 Or (command2 <> "" And AutoexecCommandMatches(activeText, command2) <> 0) Then
                matchCount = matchCount + 1
                If shownCount < maxLines Then
                    AddLine reportText, labelText + " " + LTrim$(Str$(matchCount)) + ": " + activeText
                    shownCount = shownCount + 1
                End If
            End If
        End If
    Loop
    Close #fileNum

    If matchCount = 0 Then
        AddLine reportText, labelText + ": none"
    ElseIf matchCount > shownCount Then
        AddLine reportText, labelText + ": " + LTrim$(Str$(matchCount - shownCount)) + " more line(s) not shown"
    End If
End Sub

Sub AddAutoexecSummary(ByRef reportText As String, ByVal fileName As String, ByVal maxLines As Integer)
    Dim fileNum As Integer
    Dim lineText As String
    Dim activeText As String
    Dim commandCount As Integer
    Dim shownCount As Integer

    If fileName = "" Or FileExists(fileName) = 0 Then
        AddLine reportText, "AUTOEXEC commands: not found"
        Exit Sub
    End If

    commandCount = 0
    shownCount = 0
    fileNum = FreeFile
    Open fileName For Input As #fileNum
    Do Until Eof(fileNum)
        Line Input #fileNum, lineText
        activeText = ActiveConfigLine(lineText)
        If activeText <> "" Then
            commandCount = commandCount + 1
            If shownCount < maxLines Then
                AddLine reportText, "AUTOEXEC " + LTrim$(Str$(commandCount)) + ": " + activeText
                shownCount = shownCount + 1
            End If
        End If
    Loop
    Close #fileNum

    If commandCount = 0 Then
        AddLine reportText, "AUTOEXEC commands: none"
    ElseIf commandCount > shownCount Then
        AddLine reportText, "AUTOEXEC commands: " + LTrim$(Str$(commandCount - shownCount)) + " more line(s) not shown"
    End If
End Sub

Function FileContainsPattern(ByVal fileName As String, ByVal pattern1 As String, ByVal pattern2 As String, ByVal pattern3 As String, ByVal pattern4 As String) As Integer
    Dim fileNum As Integer
    Dim lineText As String
    Dim upperText As String

    If fileName = "" Or FileExists(fileName) = 0 Then Return 0

    fileNum = FreeFile
    Open fileName For Input As #fileNum
    Do Until Eof(fileNum)
        Line Input #fileNum, lineText
        upperText = UCase$(ActiveConfigLine(lineText))
        If upperText <> "" Then
            If pattern1 <> "" And InStr(upperText, UCase$(pattern1)) > 0 Then
                Close #fileNum
                Return -1
            End If
            If pattern2 <> "" And InStr(upperText, UCase$(pattern2)) > 0 Then
                Close #fileNum
                Return -1
            End If
            If pattern3 <> "" And InStr(upperText, UCase$(pattern3)) > 0 Then
                Close #fileNum
                Return -1
            End If
            If pattern4 <> "" And InStr(upperText, UCase$(pattern4)) > 0 Then
                Close #fileNum
                Return -1
            End If
        End If
    Loop
    Close #fileNum

    Return 0
End Function

Function StartupFilesContain(ByVal pattern1 As String, ByVal pattern2 As String, ByVal pattern3 As String, ByVal pattern4 As String) As Integer
    If FileContainsPattern(FindConfigSys(), pattern1, pattern2, pattern3, pattern4) <> 0 Then Return -1
    If FileContainsPattern(FindAutoexecBat(), pattern1, pattern2, pattern3, pattern4) <> 0 Then Return -1
    Return 0
End Function

Sub AddDriverLine(ByRef reportText As String, ByVal labelText As String, ByVal pattern1 As String, ByVal pattern2 As String, ByVal pattern3 As String, ByVal pattern4 As String)
    AddLine reportText, labelText + ": " + YesNoText(StartupFilesContain(pattern1, pattern2, pattern3, pattern4))
End Sub

Sub AddDosConfigReport(ByRef reportText As String)
    Dim configPath As String
    Dim autoexecPath As String

    configPath = FindConfigSys()
    autoexecPath = FindAutoexecBat()

    AddLine reportText, "DOS Config / Environment"
    AddLine reportText, "------------------------"
    If configPath = "" Then
        AddLine reportText, "CONFIG.SYS: not found"
    Else
        AddLine reportText, "CONFIG.SYS: " + configPath
    End If

    If autoexecPath = "" Then
        AddLine reportText, "AUTOEXEC.BAT: not found"
    Else
        AddLine reportText, "AUTOEXEC.BAT: " + autoexecPath
    End If

    AddLine reportText, "SHELL: " + ConfigSettingText(configPath, "SHELL")
    AddLine reportText, "DOS: " + ConfigSettingText(configPath, "DOS")
    AddLine reportText, "FILES: " + ConfigSettingText(configPath, "FILES")
    AddLine reportText, "BUFFERS: " + ConfigSettingText(configPath, "BUFFERS")
    AddLine reportText, "LASTDRIVE: " + ConfigSettingText(configPath, "LASTDRIVE")
    AddLine reportText, "STACKS: " + ConfigSettingText(configPath, "STACKS")
    AddLine reportText, "FCBS: " + ConfigSettingText(configPath, "FCBS")
    AddLine reportText, "COUNTRY: " + ConfigSettingText(configPath, "COUNTRY")
    AddConfigKeyLines reportText, configPath, "DEVICE", "DEVICE", 16
    AddConfigKeyLines reportText, configPath, "DEVICEHIGH", "DEVICEHIGH", 16
    AddConfigKeyLines reportText, configPath, "INSTALL", "INSTALL", 8
    AddConfigKeyLines reportText, configPath, "INSTALLHIGH", "INSTALLHIGH", 8
    AddAutoexecSummary reportText, autoexecPath, 24
    AddAutoexecCommandLines reportText, autoexecPath, "LOADHIGH/LH", "LH", "LOADHIGH", 16
    AddAutoexecCommandLines reportText, autoexecPath, "SET", "SET", "", 24
    AddLine reportText, "PATH: " + EnvValueText("PATH")
    AddLine reportText, "TEMP: " + EnvValueText("TEMP")
    AddLine reportText, "PROMPT: " + EnvValueText("PROMPT")
    AddLine reportText, "SOUND: " + EnvValueText("SOUND")
    AddLine reportText, "MIDI: " + EnvValueText("MIDI")
    AddLine reportText, "ULTRASND: " + EnvValueText("ULTRASND")
    AddLine reportText, ""
End Sub

Sub AddDriverSummaryReport(ByRef reportText As String)
    AddLine reportText, "Driver Summary"
    AddLine reportText, "--------------"
    AddDriverLine reportText, "HIMEM.SYS referenced", "HIMEM.SYS", "HIMEM.EXE", "", ""
    AddDriverLine reportText, "EMM386.EXE referenced", "EMM386.EXE", "EMM386.SYS", "", ""
    AddDriverLine reportText, "SMARTDRV referenced", "SMARTDRV", "SMARTDRV.EXE", "SMARTDRV.SYS", ""
    AddDriverLine reportText, "MSCDEX referenced", "MSCDEX", "MSCDEX.EXE", "", ""
    AddDriverLine reportText, "Mouse driver referenced", "MOUSE", "CTMOUSE", "LMOUSE", "GMOUSE"
    AddDriverLine reportText, "CD-ROM driver referenced", "CDROM", "CD-ROM", "OAKCDROM", "VIDE-CDD"
    AddDriverLine reportText, "ANSI.SYS referenced", "ANSI.SYS", "NANSI.SYS", "", ""
    AddDriverLine reportText, "SETVER referenced", "SETVER", "SETVER.EXE", "", ""
    AddDriverLine reportText, "SHARE referenced", "SHARE", "SHARE.EXE", "", ""
    AddDriverLine reportText, "DOSKEY referenced", "DOSKEY", "DOSKEY.COM", "DOSKEY.EXE", ""
    AddDriverLine reportText, "RAMDRIVE referenced", "RAMDRIVE", "RAMDRIVE.SYS", "VDISK.SYS", ""
    AddLine reportText, ""
End Sub

Function BootDriveText() As String
    Dim regs As __dpmi_regs
    Dim driveNumber As Integer

    regs.x.ax = &H3305
    regs.x.dx = 0
    __dpmi_int(&H21, @regs)

    If (regs.x.flags And 1) = 0 Then
        driveNumber = regs.x.dx And &HFF
        If driveNumber >= 1 And driveNumber <= 26 Then Return DriveLetterText(driveNumber)
    End If

    If Len(Environ$("COMSPEC")) >= 2 Then
        If Mid$(Environ$("COMSPEC"), 2, 1) = ":" Then Return UCase$(Left$(Environ$("COMSPEC"), 2))
    End If

    Return "unknown"
End Function

Function TwoDigitText(ByVal valueNumber As Integer) As String
    Return Right$("00" + LTrim$(Str$(valueNumber)), 2)
End Function

Function GeneratedDateTimeText() As String
    Dim regs As __dpmi_regs
    Dim yearNumber As Integer
    Dim monthNumber As Integer
    Dim dayNumber As Integer
    Dim hourNumber As Integer
    Dim minuteNumber As Integer
    Dim secondNumber As Integer

    regs.x.ax = &H2A00
    __dpmi_int(&H21, @regs)

    yearNumber = regs.x.cx And &HFFFF
    monthNumber = (regs.x.dx Shr 8) And &HFF
    dayNumber = regs.x.dx And &HFF

    regs.x.ax = &H2C00
    __dpmi_int(&H21, @regs)

    hourNumber = (regs.x.cx Shr 8) And &HFF
    minuteNumber = regs.x.cx And &HFF
    secondNumber = (regs.x.dx Shr 8) And &HFF

    Return LTrim$(Str$(yearNumber)) + "-" + TwoDigitText(monthNumber) + "-" + TwoDigitText(dayNumber) + " " + TwoDigitText(hourNumber) + ":" + TwoDigitText(minuteNumber) + ":" + TwoDigitText(secondNumber)
End Function

Function VerifyStateText() As String
    Dim regs As __dpmi_regs

    regs.x.ax = &H5400
    __dpmi_int(&H21, @regs)

    If (regs.x.ax And &HFF) = 0 Then Return "off"
    Return "on"
End Function

Function BreakStateText() As String
    Dim regs As __dpmi_regs

    regs.x.ax = &H3300
    regs.x.dx = 0
    __dpmi_int(&H21, @regs)

    If (regs.x.flags And 1) <> 0 Then Return "unavailable"
    If (regs.x.dx And &HFF) = 0 Then Return "off"
    Return "on"
End Function

Function CodePageText() As String
    Dim regs As __dpmi_regs

    regs.x.ax = &H6601
    regs.x.bx = 0
    regs.x.dx = 0
    __dpmi_int(&H21, @regs)

    If (regs.x.flags And 1) <> 0 Then Return "not supported"

    Return "active " + LTrim$(Str$(regs.x.bx And &HFFFF)) + ", system " + LTrim$(Str$(regs.x.dx And &HFFFF))
End Function

Function CountryInfoText() As String
    Dim regs As __dpmi_regs
    Dim infoBlock(0 To 63) As UByte
    Dim i As Integer
    Dim countryCode As Integer

    For i = 0 To 63
        infoBlock(i) = 0
    Next i

    dosmemput @infoBlock(0), 64, __tb

    regs.x.ax = &H3800
    regs.x.ds = __tb \ 16
    regs.x.dx = __tb And &H0F
    __dpmi_int(&H21, @regs)

    If (regs.x.flags And 1) <> 0 Then Return "unavailable"

    countryCode = regs.x.bx And &HFFFF
    If countryCode = 0 Then countryCode = regs.x.ax And &HFFFF

    Return "country code " + LTrim$(Str$(countryCode))
End Function

Sub AddDosStateReport(ByRef reportText As String)
    AddLine reportText, "DOS State"
    AddLine reportText, "---------"
    AddLine reportText, "VERIFY: " + VerifyStateText()
    AddLine reportText, "BREAK: " + BreakStateText()
    AddLine reportText, "Code page: " + CodePageText()
    AddLine reportText, "Country: " + CountryInfoText()
    AddLine reportText, ""
End Sub

Function CdromDriveLettersText() As String
    Dim driveNumber As Integer
    Dim lettersText As String

    lettersText = ""
    For driveNumber = 1 To 26
        If IsCdromDrive(driveNumber) <> 0 Then
            If lettersText <> "" Then lettersText = lettersText + " "
            lettersText = lettersText + DriveLetterText(driveNumber)
        End If
    Next driveNumber

    If lettersText = "" Then Return "none detected"
    Return lettersText
End Function

Function CdromDriveCount() As Integer
    Dim driveNumber As Integer
    Dim countValue As Integer

    countValue = 0
    For driveNumber = 1 To 26
        If IsCdromDrive(driveNumber) <> 0 Then countValue = countValue + 1
    Next driveNumber

    Return countValue
End Function

Function MscdexText() As String
    Dim regs As __dpmi_regs
    Dim versionRegs As __dpmi_regs
    Dim driveCount As Integer
    Dim firstDrive As Integer
    Dim versionText As String

    regs.x.ax = &H1500
    regs.x.bx = 0
    regs.x.cx = 0
    __dpmi_int(&H2F, @regs)

    driveCount = regs.x.bx And &HFFFF
    firstDrive = regs.x.cx And &HFFFF

    If driveCount <= 0 Then
        If CdromDriveCount() > 0 Then Return "present, version unavailable"
        Return "not detected"
    End If

    versionText = "version unavailable"
    versionRegs.x.ax = &H150C
    versionRegs.x.bx = 0
    __dpmi_int(&H2F, @versionRegs)
    If (versionRegs.x.bx And &HFFFF) <> 0 Then
        versionText = "version " + LTrim$(Str$((versionRegs.x.bx Shr 8) And &HFF)) + "." + Right$("00" + LTrim$(Str$(versionRegs.x.bx And &HFF)), 2)
    End If

    If firstDrive >= 0 And firstDrive <= 25 Then
        Return "present, " + versionText + ", " + LTrim$(Str$(driveCount)) + " drive(s), first " + DriveLetterText(firstDrive + 1)
    End If

    Return "present, " + versionText + ", " + LTrim$(Str$(driveCount)) + " drive(s)"
End Function

Function NetworkDriveLettersText() As String
    Dim driveNumber As Integer
    Dim lettersText As String

    lettersText = ""
    For driveNumber = 1 To 26
        If IsRemoteDrive(driveNumber) <> 0 Then
            If lettersText <> "" Then lettersText = lettersText + " "
            lettersText = lettersText + DriveLetterText(driveNumber)
        End If
    Next driveNumber

    If lettersText = "" Then Return "none detected"
    Return lettersText
End Function

Function NetworkRedirectorText() As String
    Dim regs As __dpmi_regs
    Dim remoteLetters As String

    remoteLetters = NetworkDriveLettersText()
    If remoteLetters <> "none detected" Then Return "present, remote drives " + remoteLetters

    regs.x.ax = &H1100
    __dpmi_int(&H2F, @regs)

    If (regs.x.ax And &HFF) = &HFF Then Return "redirector present, no remote drives detected"
    Return "not detected"
End Function

Sub AddCdromNetworkReport(ByRef reportText As String)
    AddLine reportText, "CD-ROM / Network"
    AddLine reportText, "----------------"
    AddLine reportText, "MSCDEX: " + MscdexText()
    AddLine reportText, "CD-ROM drive count: " + LTrim$(Str$(CdromDriveCount()))
    AddLine reportText, "CD-ROM drive letters: " + CdromDriveLettersText()
    AddLine reportText, "Network redirector: " + NetworkRedirectorText()
    AddLine reportText, ""
End Sub

Function ApmBiosText() As String
    Dim regs As __dpmi_regs
    Dim versionNumber As Integer
    Dim majorVersion As Integer
    Dim minorVersion As Integer

    regs.x.ax = &H5300
    regs.x.bx = 0
    regs.x.cx = 0
    __dpmi_int(&H15, @regs)

    If (regs.x.flags And 1) <> 0 Then Return "not detected"
    If (regs.x.bx And &HFFFF) <> &H504D Then Return "not detected"

    versionNumber = regs.x.ax And &HFFFF
    majorVersion = (versionNumber Shr 8) And &HFF
    minorVersion = versionNumber And &HFF

    Return "present, version " + LTrim$(Str$(majorVersion)) + "." + Right$("00" + LTrim$(Str$(minorVersion)), 2) + ", flags " + HexWordText(regs.x.cx And &HFFFF)
End Function

Function BiosRomContainsSignature(ByVal signatureText As String) As Integer
    Dim romBlock(0 To 4095) As UByte
    Dim chunkStart As UInteger
    Dim chunkSize As Integer
    Dim i As Integer
    Dim j As Integer
    Dim sigLen As Integer
    Dim matchedValue As Integer

    sigLen = Len(signatureText)
    If sigLen <= 0 Then Return 0

    chunkStart = 0
    Do While chunkStart < &H10000
        chunkSize = 4096
        If chunkStart + CUInt(chunkSize) > &H10000 Then chunkSize = CInt(&H10000 - chunkStart)

        dosmemget &HF0000 + chunkStart, chunkSize, @romBlock(0)

        For i = 0 To chunkSize - sigLen
            matchedValue = -1
            For j = 1 To sigLen
                If romBlock(i + j - 1) <> Asc(Mid$(signatureText, j, 1)) Then
                    matchedValue = 0
                    Exit For
                End If
            Next j
            If matchedValue <> 0 Then Return -1
        Next i

        chunkStart = chunkStart + 4080
    Loop

    Return 0
End Function

Function PciBiosText() As String
    If BiosRomContainsSignature("PCI ") <> 0 Or BiosRomContainsSignature("PCI BIOS") <> 0 Then Return "BIOS ROM signature present"
    Return "not detected"
End Function

Function PnpBiosText() As String
    If BiosRomContainsSignature("$PnP") <> 0 Then Return "BIOS ROM signature present"
    Return "not detected"
End Function

Sub AddBiosExtensionReport(ByRef reportText As String)
    AddLine reportText, "BIOS Extensions"
    AddLine reportText, "---------------"
    AddLine reportText, "APM BIOS: " + ApmBiosText()
    AddLine reportText, "PCI BIOS: " + PciBiosText()
    AddLine reportText, "Plug and Play BIOS: " + PnpBiosText()
    AddLine reportText, ""
End Sub

' ---------------------------
' Sound probes
' ---------------------------

Sub ShortDelay(ByVal loopCount As Integer)
    Dim i As Integer
    Dim wasteValue As Integer

    wasteValue = 0
    For i = 1 To loopCount
        wasteValue = wasteValue Xor i
    Next i
End Sub

Function HexDigitValue(ByVal digitText As String) As Integer
    Dim digitCode As Integer

    If digitText = "" Then Return -1
    digitCode = Asc(UCase$(Left$(digitText, 1)))

    If digitCode >= Asc("0") And digitCode <= Asc("9") Then Return digitCode - Asc("0")
    If digitCode >= Asc("A") And digitCode <= Asc("F") Then Return digitCode - Asc("A") + 10

    Return -1
End Function

Function ParseHexNumber(ByVal sourceText As String) As Integer
    Dim i As Integer
    Dim digitValue As Integer
    Dim resultValue As Integer

    sourceText = UCase$(Trim$(sourceText))
    If Left$(sourceText, 2) = "0X" Then sourceText = Mid$(sourceText, 3)
    If Left$(sourceText, 2) = "&H" Then sourceText = Mid$(sourceText, 3)
    If sourceText = "" Then Return -1

    resultValue = 0
    For i = 1 To Len(sourceText)
        digitValue = HexDigitValue(Mid$(sourceText, i, 1))
        If digitValue < 0 Then Return -1
        resultValue = resultValue * 16 + digitValue
    Next i

    Return resultValue
End Function

Function BlasterToken(ByVal tokenLetter As String) As String
    Dim blasterText As String
    Dim i As Integer
    Dim j As Integer
    Dim tokenText As String
    Dim currentChar As String

    blasterText = UCase$(Environ$("BLASTER"))
    tokenLetter = UCase$(Left$(tokenLetter, 1))

    For i = 1 To Len(blasterText)
        If Mid$(blasterText, i, 1) = tokenLetter Then
            tokenText = ""
            j = i + 1
            Do While j <= Len(blasterText)
                currentChar = Mid$(blasterText, j, 1)
                If currentChar = " " Or currentChar = Chr$(9) Then Exit Do
                tokenText = tokenText + currentChar
                j = j + 1
            Loop
            Return tokenText
        End If
    Next i

    Return ""
End Function

Function BlasterSettingText(ByVal tokenLetter As String) As String
    Dim tokenText As String

    tokenText = BlasterToken(tokenLetter)
    If tokenText = "" Then Return "not set"
    Return tokenText
End Function

Function SbDspReadByte(ByVal sbBase As Integer, ByRef readValue As Integer) As Integer
    Dim waitLoop As Integer

    For waitLoop = 1 To 32767
        If (Inp(sbBase + &HE) And &H80) <> 0 Then
            readValue = Inp(sbBase + &HA) And &HFF
            Return -1
        End If
    Next waitLoop

    Return 0
End Function

Function SbDspWriteByte(ByVal sbBase As Integer, ByVal writeValue As Integer) As Integer
    Dim waitLoop As Integer

    For waitLoop = 1 To 32767
        If (Inp(sbBase + &HC) And &H80) = 0 Then
            Out sbBase + &HC, writeValue And &HFF
            Return -1
        End If
    Next waitLoop

    Return 0
End Function

Function SbDspReset(ByVal sbBase As Integer) As Integer
    Dim readValue As Integer

    Out sbBase + &H6, &H01
    ShortDelay 6000
    Out sbBase + &H6, &H00
    ShortDelay 6000

    If SbDspReadByte(sbBase, readValue) = 0 Then Return 0
    If readValue = &HAA Then Return -1

    Return 0
End Function

Function FindSoundBlasterBase(ByRef detectedBase As Integer) As Integer
    Dim preferredPort As Integer
    Dim candidatePort(0 To 3) As Integer
    Dim portIndex As Integer

    detectedBase = 0
    preferredPort = ParseHexNumber(BlasterToken("A"))

    If preferredPort > 0 Then
        If SbDspReset(preferredPort) <> 0 Then
            detectedBase = preferredPort
            Return -1
        End If
    End If

    candidatePort(0) = &H220
    candidatePort(1) = &H240
    candidatePort(2) = &H260
    candidatePort(3) = &H280

    For portIndex = 0 To 3
        If candidatePort(portIndex) <> preferredPort Then
            If SbDspReset(candidatePort(portIndex)) <> 0 Then
                detectedBase = candidatePort(portIndex)
                Return -1
            End If
        End If
    Next portIndex

    Return 0
End Function

Function SoundBlasterVersionText(ByVal sbBase As Integer) As String
    Dim majorVersion As Integer
    Dim minorVersion As Integer

    If SbDspReset(sbBase) = 0 Then Return "DSP version unavailable"
    If SbDspWriteByte(sbBase, &HE1) = 0 Then Return "DSP version unavailable"
    If SbDspReadByte(sbBase, majorVersion) = 0 Then Return "DSP version unavailable"
    If SbDspReadByte(sbBase, minorVersion) = 0 Then Return "DSP version unavailable"

    Return "DSP " + LTrim$(Str$(majorVersion)) + "." + Right$("00" + LTrim$(Str$(minorVersion)), 2)
End Function

Sub OplWriteReg(ByVal registerNumber As Integer, ByVal registerValue As Integer)
    Out &H388, registerNumber And &HFF
    ShortDelay 120
    Out &H389, registerValue And &HFF
    ShortDelay 120
End Sub

Sub Opl3WriteReg(ByVal registerNumber As Integer, ByVal registerValue As Integer)
    Out &H38A, registerNumber And &HFF
    ShortDelay 120
    Out &H38B, registerValue And &HFF
    ShortDelay 120
End Sub

Function Opl2Detected() As Integer
    Dim statusBefore As Integer
    Dim statusAfter As Integer

    OplWriteReg &H04, &H60
    OplWriteReg &H04, &H80
    statusBefore = Inp(&H388) And &HFF

    OplWriteReg &H02, &HFF
    OplWriteReg &H04, &H21
    ShortDelay 30000
    statusAfter = Inp(&H388) And &HFF

    OplWriteReg &H04, &H60
    OplWriteReg &H04, &H80

    If ((statusBefore And &HE0) = 0) And ((statusAfter And &HC0) = &HC0) Then Return -1
    Return 0
End Function

Function Opl2Text() As String
    If Opl2Detected() <> 0 Then Return "detected at &H388"
    Return "not detected"
End Function

Function Opl3Text() As String
    Dim statusBefore As Integer
    Dim statusAfter As Integer

    If Opl2Detected() = 0 Then Return "not detected"

    Opl3WriteReg &H05, &H01
    ShortDelay 120
    statusBefore = Inp(&H388) And &HFF
    Opl3WriteReg &H05, &H00
    ShortDelay 120
    statusAfter = Inp(&H388) And &HFF

    If (statusBefore And &H06) = 0 And (statusAfter And &H06) = 0 Then Return "possible OPL3 at &H388/&H38A"
    Return "not detected"
End Function

Function MpuAckReceived(ByVal mpuBase As Integer) As Integer
    Dim waitLoop As Integer
    Dim statusValue As Integer
    Dim dataValue As Integer

    Out mpuBase + 1, &HFF

    For waitLoop = 1 To 8192
        statusValue = Inp(mpuBase + 1) And &HFF
        If (statusValue And &H80) = 0 Then
            dataValue = Inp(mpuBase) And &HFF
            If dataValue = &HFE Then Return -1
        End If
    Next waitLoop

    Return 0
End Function

Function Mpu401Text() As String
    Dim preferredPort As Integer
    Dim candidatePort(0 To 2) As Integer
    Dim portIndex As Integer

    preferredPort = ParseHexNumber(BlasterToken("P"))
    If preferredPort > 0 Then
        If MpuAckReceived(preferredPort) <> 0 Then Return "detected at " + HexWordText(preferredPort)
    End If

    candidatePort(0) = &H330
    candidatePort(1) = &H300
    candidatePort(2) = &H332

    For portIndex = 0 To 2
        If candidatePort(portIndex) <> preferredPort Then
            If MpuAckReceived(candidatePort(portIndex)) <> 0 Then Return "detected at " + HexWordText(candidatePort(portIndex))
        End If
    Next portIndex

    Return "not detected"
End Function

Sub AddSoundReport(ByRef reportText As String)
    Dim detectedBase As Integer
    Dim blasterText As String
    Dim soundCfg As String

    blasterText = CleanLine(Environ$("BLASTER"))
    If blasterText = "" Then blasterText = "not set"

    AddLine reportText, "Sound"
    AddLine reportText, "-----"
    AddLine reportText, "BLASTER: " + blasterText

    If FindSoundBlasterBase(detectedBase) <> 0 Then
        AddLine reportText, "Sound Blaster DSP: detected at " + HexWordText(detectedBase) + ", " + SoundBlasterVersionText(detectedBase)
    Else
        AddLine reportText, "Sound Blaster DSP: not detected"
    End If

    AddLine reportText, "Sound Blaster IRQ: " + BlasterSettingText("I")
    AddLine reportText, "Sound Blaster DMA: " + BlasterSettingText("D")
    AddLine reportText, "Sound Blaster high DMA: " + BlasterSettingText("H")
    AddLine reportText, "AdLib / OPL2: " + Opl2Text()
    AddLine reportText, "OPL3: " + Opl3Text()
    AddLine reportText, "MPU-401: " + Mpu401Text()

    soundCfg = FindSoundCfg()
    If soundCfg = "" Then
        AddLine reportText, "Backlash sound config: not found"
    Else
        AddLine reportText, "Backlash sound config: " + soundCfg
        AddLine reportText, "Configured device: " + ReadFirstCfgValue(soundCfg, "device", "card", "sound", "type", "not set")
        AddLine reportText, "Configured port: " + ReadFirstCfgValue(soundCfg, "port", "base", "address", "sbport", "not set")
        AddLine reportText, "Configured IRQ: " + ReadFirstCfgValue(soundCfg, "irq", "sbirq", "", "", "not set")
        AddLine reportText, "Configured DMA: " + ReadFirstCfgValue(soundCfg, "dma", "sbdma", "", "", "not set")
        AddLine reportText, "Startup WAV: " + ReadFirstCfgValue(soundCfg, "startup", "startup_wav", "startupwav", "startup_sound", "not set")
        AddLine reportText, "Click WAV: " + ReadFirstCfgValue(soundCfg, "click", "click_wav", "clickwav", "click_sound", "not set")
        AddLine reportText, "Shutdown WAV: " + ReadFirstCfgValue(soundCfg, "shutdown", "shutdown_wav", "shutdownwav", "shutdown_sound", "not set")
    End If

    AddLine reportText, ""
End Sub

' ---------------------------
' Drive probes
' ---------------------------

Function IsCdromDrive(ByVal driveNumber As Integer) As Integer
    Dim regs As __dpmi_regs

    regs.x.ax = &H150B
    regs.x.cx = driveNumber - 1
    __dpmi_int(&H2F, @regs)

    If (regs.x.bx And &HFFFF) = &HADAD Then Return -1
    Return 0
End Function

Function IsRemoteDrive(ByVal driveNumber As Integer) As Integer
    Dim regs As __dpmi_regs

    regs.x.ax = &H4409
    regs.x.bx = driveNumber
    regs.x.dx = 0
    __dpmi_int(&H21, @regs)

    If (regs.x.flags And 1) <> 0 Then Return 0
    If (regs.x.dx And &H1000) <> 0 Then Return -1
    Return 0
End Function

Function IoctlDriveType(ByVal driveNumber As Integer) As String
    Dim regs As __dpmi_regs

    regs.x.ax = &H4408
    regs.x.bx = driveNumber
    regs.x.dx = driveNumber
    __dpmi_int(&H21, @regs)

    If (regs.x.flags And 1) <> 0 Then Return ""
    If (regs.x.ax And &HFFFF) = 0 Then Return "removable"
    If (regs.x.ax And &HFFFF) = 1 Then Return "fixed"
    Return "unknown"
End Function

Function FatEstimateText(ByVal totalClusters As Double) As String
    If totalClusters <= 0.0 Then Return "FAT type unknown"
    If totalClusters < 4085.0 Then Return "FAT12 estimate"
    If totalClusters < 65525.0 Then Return "FAT16 estimate"
    Return "FAT32 or large FAT estimate"
End Function

Function GetDiskSpaceText(ByVal driveNumber As Integer) As String
    Dim regs As __dpmi_regs
    Dim sectorsPerCluster As Double
    Dim availableClusters As Double
    Dim bytesPerSector As Double
    Dim totalClusters As Double
    Dim freeBytes As Double
    Dim totalBytes As Double
    Dim usedBytes As Double

    regs.x.ax = &H3600
    regs.x.dx = driveNumber
    __dpmi_int(&H21, @regs)

    If (regs.x.ax And &HFFFF) = &HFFFF Then Return "space unavailable"

    sectorsPerCluster = CDbl(regs.x.ax And &HFFFF)
    availableClusters = CDbl(regs.x.bx And &HFFFF)
    bytesPerSector = CDbl(regs.x.cx And &HFFFF)
    totalClusters = CDbl(regs.x.dx And &HFFFF)

    freeBytes = availableClusters * sectorsPerCluster * bytesPerSector
    totalBytes = totalClusters * sectorsPerCluster * bytesPerSector
    usedBytes = totalBytes - freeBytes
    If usedBytes < 0.0 Then usedBytes = 0.0

    Return FormatByteSize(totalBytes) + " total, " + FormatByteSize(freeBytes) + " free, " + FormatByteSize(usedBytes) + " used"
End Function

Function GetDiskGeometryText(ByVal driveNumber As Integer) As String
    Dim regs As __dpmi_regs
    Dim sectorsPerCluster As Double
    Dim availableClusters As Double
    Dim bytesPerSector As Double
    Dim totalClusters As Double
    Dim clusterSize As Double

    regs.x.ax = &H3600
    regs.x.dx = driveNumber
    __dpmi_int(&H21, @regs)

    If (regs.x.ax And &HFFFF) = &HFFFF Then Return "details unavailable"

    sectorsPerCluster = CDbl(regs.x.ax And &HFFFF)
    availableClusters = CDbl(regs.x.bx And &HFFFF)
    bytesPerSector = CDbl(regs.x.cx And &HFFFF)
    totalClusters = CDbl(regs.x.dx And &HFFFF)
    clusterSize = sectorsPerCluster * bytesPerSector

    Return LTrim$(Str$(CLng(bytesPerSector))) + " bytes/sector, " + LTrim$(Str$(CLng(sectorsPerCluster))) + " sectors/cluster, " + FormatByteSize(clusterSize) + " cluster size"
End Function

Function GetDiskClusterText(ByVal driveNumber As Integer) As String
    Dim regs As __dpmi_regs
    Dim availableClusters As Double
    Dim totalClusters As Double

    regs.x.ax = &H3600
    regs.x.dx = driveNumber
    __dpmi_int(&H21, @regs)

    If (regs.x.ax And &HFFFF) = &HFFFF Then Return "clusters unavailable"

    availableClusters = CDbl(regs.x.bx And &HFFFF)
    totalClusters = CDbl(regs.x.dx And &HFFFF)

    Return LTrim$(Str$(CLng(totalClusters))) + " total, " + LTrim$(Str$(CLng(availableClusters))) + " free, " + FatEstimateText(totalClusters)
End Function

Function MediaLabelText(ByVal mediaBlock As UByte Ptr) As String
    Dim i As Integer
    Dim labelText As String

    labelText = ""
    For i = 6 To 16
        If mediaBlock[i] >= 32 And mediaBlock[i] <= 126 Then labelText = labelText + Chr$(mediaBlock[i])
    Next i

    labelText = Trim$(labelText)
    If labelText = "" Then Return "none"
    Return labelText
End Function

Function MediaFileSystemText(ByVal mediaBlock As UByte Ptr) As String
    Dim i As Integer
    Dim fsText As String

    fsText = ""
    For i = 17 To 24
        If mediaBlock[i] >= 32 And mediaBlock[i] <= 126 Then fsText = fsText + Chr$(mediaBlock[i])
    Next i

    fsText = Trim$(fsText)
    If fsText = "" Then Return "unknown"
    Return fsText
End Function

Function GetDriveMediaText(ByVal driveNumber As Integer) As String
    Dim regs As __dpmi_regs
    Dim mediaBlock(0 To 31) As UByte
    Dim i As Integer
    Dim serialNumber As UInteger

    For i = 0 To 31
        mediaBlock(i) = 0
    Next i

    dosmemput @mediaBlock(0), 32, __tb

    regs.x.ax = &H6900
    regs.x.bx = driveNumber And &HFF
    regs.x.ds = __tb \ 16
    regs.x.dx = __tb And &H0F
    __dpmi_int(&H21, @regs)

    If (regs.x.flags And 1) <> 0 Then Return "media ID unavailable"

    dosmemget __tb, 32, @mediaBlock(0)

    serialNumber = CUInt(mediaBlock(2)) + CUInt(mediaBlock(3)) * 256 + CUInt(mediaBlock(4)) * 65536 + CUInt(mediaBlock(5)) * 16777216

    Return "label " + MediaLabelText(@mediaBlock(0)) + ", serial " + HexDwordText(serialNumber) + ", file system " + MediaFileSystemText(@mediaBlock(0))
End Function

Sub AddDriveReport(ByRef reportText As String)
    Dim driveNumber As Integer
    Dim typeText As String
    Dim spaceText As String
    Dim seenDrive As Integer

    AddLine reportText, "Drives"
    AddLine reportText, "------"

    For driveNumber = 1 To 26
        seenDrive = 0
        typeText = IoctlDriveType(driveNumber)

        If IsCdromDrive(driveNumber) <> 0 Then
            typeText = "CD-ROM"
            seenDrive = -1
        ElseIf IsRemoteDrive(driveNumber) <> 0 Then
            typeText = "network"
            seenDrive = -1
        ElseIf typeText <> "" Then
            seenDrive = -1
        End If

        If driveNumber >= 3 Then
            spaceText = GetDiskSpaceText(driveNumber)
            If spaceText <> "space unavailable" Then seenDrive = -1
        Else
            spaceText = "space not checked for removable drive"
        End If

        If seenDrive <> 0 Then
            If typeText = "" Then typeText = "unknown"
            AddLine reportText, DriveLetterText(driveNumber) + "  " + typeText + "  " + spaceText
            If driveNumber >= 3 And spaceText <> "space unavailable" Then
                AddLine reportText, "   Media: " + GetDriveMediaText(driveNumber)
                AddLine reportText, "   Geometry: " + GetDiskGeometryText(driveNumber)
                AddLine reportText, "   Clusters: " + GetDiskClusterText(driveNumber)
            End If
        End If
    Next driveNumber

    AddLine reportText, ""
End Sub

' ---------------------------
' Video and mouse probes
' ---------------------------

Function CurrentVideoModeText() As String
    Dim modeByte As UByte

    modeByte = 0
    dosmemget &H449, 1, @modeByte
    Return "BIOS mode " + LTrim$(Str$(modeByte)) + " / &H" + Hex$(modeByte, 2)
End Function

Function LoadVesaInfo(ByVal blockData As UByte Ptr) As Integer
    Dim regs As __dpmi_regs
    Dim i As Integer
    Dim signatureText As String

    For i = 0 To 511
        blockData[i] = 0
    Next i
    blockData[0] = Asc("V")
    blockData[1] = Asc("B")
    blockData[2] = Asc("E")
    blockData[3] = Asc("2")

    dosmemput blockData, 512, __tb

    regs.x.ax = &H4F00
    regs.x.es = __tb \ 16
    regs.x.di = __tb And &H0F
    __dpmi_int(&H10, @regs)

    If (regs.x.ax And &HFFFF) <> &H004F Then Return 0

    dosmemget __tb, 512, blockData

    signatureText = Chr$(blockData[0]) + Chr$(blockData[1]) + Chr$(blockData[2]) + Chr$(blockData[3])
    If Left$(signatureText, 4) <> "VESA" Then Return 0

    Return -1
End Function

Function VesaOemText(ByVal blockData As UByte Ptr) As String
    Dim stringBytes(0 To 79) As UByte
    Dim i As Integer
    Dim oemOffset As UInteger
    Dim oemSegment As UInteger
    Dim oemAddress As UInteger
    Dim oemText As String

    oemOffset = CUInt(blockData[6]) + CUInt(blockData[7]) * 256
    oemSegment = CUInt(blockData[8]) + CUInt(blockData[9]) * 256
    oemAddress = oemSegment * 16 + oemOffset
    oemText = ""

    If oemAddress <> 0 Then
        For i = 0 To 79
            stringBytes(i) = 0
        Next i
        dosmemget oemAddress, 80, @stringBytes(0)
        For i = 0 To 79
            If stringBytes(i) = 0 Then Exit For
            If stringBytes(i) >= 32 And stringBytes(i) <= 126 Then oemText = oemText + Chr$(stringBytes(i))
        Next i
    End If

    oemText = CleanLine(oemText)
    If oemText = "" Then oemText = "OEM string unavailable"
    Return oemText
End Function

Function VesaSummaryText() As String
    Dim block(0 To 511) As UByte
    Dim versionNumber As Integer
    Dim versionMajor As Integer
    Dim versionMinor As Integer

    If LoadVesaInfo(@block(0)) = 0 Then Return "not detected"

    versionNumber = CInt(block(4)) + CInt(block(5)) * 256
    versionMajor = (versionNumber Shr 8) And &HFF
    versionMinor = versionNumber And &HFF

    Return "VESA " + LTrim$(Str$(versionMajor)) + "." + Right$("00" + LTrim$(Str$(versionMinor)), 2) + " - " + VesaOemText(@block(0))
End Function

Function VesaMemoryText() As String
    Dim block(0 To 511) As UByte
    Dim memoryBlocks As Integer

    If LoadVesaInfo(@block(0)) = 0 Then Return "not detected"

    memoryBlocks = CInt(block(18)) + CInt(block(19)) * 256
    If memoryBlocks <= 0 Then Return "not reported"

    Return FormatByteSize(CDbl(memoryBlocks) * 65536.0)
End Function

Function VesaModesText() As String
    Dim block(0 To 511) As UByte
    Dim modeBytes(0 To 127) As UByte
    Dim modeOffset As UInteger
    Dim modeSegment As UInteger
    Dim modeAddress As UInteger
    Dim i As Integer
    Dim modeValue As Integer
    Dim modesText As String
    Dim modeCount As Integer

    If LoadVesaInfo(@block(0)) = 0 Then Return "not detected"

    modeOffset = CUInt(block(14)) + CUInt(block(15)) * 256
    modeSegment = CUInt(block(16)) + CUInt(block(17)) * 256
    modeAddress = modeSegment * 16 + modeOffset

    If modeAddress = 0 Then Return "not reported"

    For i = 0 To 127
        modeBytes(i) = 0
    Next i

    dosmemget modeAddress, 128, @modeBytes(0)

    modesText = ""
    modeCount = 0
    For i = 0 To 62 Step 2
        modeValue = CInt(modeBytes(i)) + CInt(modeBytes(i + 1)) * 256
        If modeValue = &HFFFF Then Exit For
        If modesText <> "" Then modesText = modesText + " "
        modesText = modesText + HexWordText(modeValue)
        modeCount = modeCount + 1
        If modeCount >= 32 Then Exit For
    Next i

    If modesText = "" Then Return "not reported"
    If modeCount >= 32 Then modesText = modesText + " ..."
    Return modesText
End Function

Sub AddVideoReport(ByRef reportText As String)
    AddLine reportText, "Video"
    AddLine reportText, "-----"
    AddLine reportText, "Current mode: " + CurrentVideoModeText()
    AddLine reportText, "VESA BIOS: " + VesaSummaryText()
    AddLine reportText, "VESA memory: " + VesaMemoryText()
    AddLine reportText, "VESA modes: " + VesaModesText()
    AddLine reportText, "Backlash display: " + BacklashDisplayText()
    AddLine reportText, ""
End Sub

Function MouseText() As String
    Dim regs As __dpmi_regs
    Dim majorVersion As Integer
    Dim minorVersion As Integer
    Dim mouseType As Integer
    Dim irqNumber As Integer

    regs.x.ax = &H0024
    __dpmi_int(&H33, @regs)

    If (regs.x.ax And &HFFFF) <> &HFFFF Then Return "not detected or driver does not support version query"

    majorVersion = (regs.x.bx Shr 8) And &HFF
    minorVersion = regs.x.bx And &HFF
    mouseType = (regs.x.cx Shr 8) And &HFF
    irqNumber = regs.x.cx And &HFF

    Return "driver " + LTrim$(Str$(majorVersion)) + "." + Right$("00" + LTrim$(Str$(minorVersion)), 2) + ", type " + LTrim$(Str$(mouseType)) + ", IRQ " + LTrim$(Str$(irqNumber))
End Function

' ---------------------------
' Backlash settings report
' ---------------------------

Function BacklashDisplayText() As String
    Dim resolutionValue As String
    Dim depthValue As String
    Dim resolutionText As String
    Dim depthText As String

    resolutionValue = ReadCfgValue(FindDisplayCfg(), "resolution", "not set")
    depthValue = ReadCfgValue(FindDisplayCfg(), "colordepth", "not set")

    Select Case resolutionValue
    Case "1"
        resolutionText = "640x480"
    Case "2"
        resolutionText = "800x600"
    Case "3"
        resolutionText = "1024x768"
    Case Else
        resolutionText = resolutionValue
    End Select

    Select Case depthValue
    Case "4"
        depthText = "16 color"
    Case "8"
        depthText = "256 color"
    Case "16"
        depthText = "High Color"
    Case Else
        depthText = depthValue
    End Select

    Return "resolution " + resolutionText + ", color depth " + depthText
End Function

Sub AddBacklashConfigReport(ByRef reportText As String)
    Dim themeCfg As String
    Dim wallpaperCfg As String
    Dim saverCfg As String
    Dim launchCfg As String

    themeCfg = FindThemeCfg()
    wallpaperCfg = FindWallpaperCfg()
    saverCfg = FindScreenSaverCfg()
    launchCfg = FindLaunchMenuCfg()

    AddLine reportText, "Backlash Config"
    AddLine reportText, "---------------"
    AddLine reportText, "Display config: " + FindDisplayCfg()
    AddLine reportText, "Display: " + BacklashDisplayText()

    If themeCfg = "" Then
        AddLine reportText, "Theme config: not found"
    Else
        AddLine reportText, "Theme config: " + themeCfg
    End If

    If wallpaperCfg = "" Then
        AddLine reportText, "Wallpaper config: not found"
    Else
        AddLine reportText, "Wallpaper config: " + wallpaperCfg
        AddLine reportText, "Wallpaper: " + ReadFirstCfgValue(wallpaperCfg, "wallpaper", "file", "path", "image", "not set")
        AddLine reportText, "Wallpaper mode: " + ReadFirstCfgValue(wallpaperCfg, "mode", "style", "layout", "", "not set")
    End If

    If saverCfg = "" Then
        AddLine reportText, "Screensaver config: not found"
    Else
        AddLine reportText, "Screensaver config: " + saverCfg
        AddLine reportText, "Screensaver enabled: " + ReadFirstCfgValue(saverCfg, "enabled", "active", "screensaver", "", "not set")
        AddLine reportText, "Screensaver: " + ReadFirstCfgValue(saverCfg, "saver", "file", "path", "screen_saver", "not set")
        AddLine reportText, "Screensaver timer: " + ReadFirstCfgValue(saverCfg, "timer", "timeout", "minutes", "delay", "not set")
    End If

    If launchCfg = "" Then
        AddLine reportText, "Launch menu config: not found"
    Else
        AddLine reportText, "Launch menu config: " + launchCfg
    End If

    AddLine reportText, ""
End Sub

' ---------------------------
' Report builder
' ---------------------------

Function BuildReportText() As String
    Dim reportText As String

    reportText = ""

    AddLine reportText, "Backlash System Information"
    AddLine reportText, "Generated by SYSINH.EXE"
    AddLine reportText, ""

    AddLine reportText, "System"
    AddLine reportText, "------"
    AddLine reportText, "Generated: " + GeneratedDateTimeText()
    AddLine reportText, "DOS version: " + DosVersionText()
    AddLine reportText, "Boot drive: " + BootDriveText()
    AddLine reportText, "Current directory: " + CurDir()
    AddLine reportText, "COMSPEC: " + EnvValueText("COMSPEC")
    AddLine reportText, ""

    AddDosConfigReport reportText
    AddDriverSummaryReport reportText
    AddDosStateReport reportText
    AddMachineReport reportText
    AddPortReport reportText
    AddCdromNetworkReport reportText
    AddBiosExtensionReport reportText

    AddLine reportText, "Processor"
    AddLine reportText, "---------"
    AddLine reportText, "CPU class: " + CpuClassText()
    AddLine reportText, "FPU: " + FpuText()
    AddLine reportText, ""

    AddLine reportText, "Memory"
    AddLine reportText, "------"
    AddLine reportText, "Conventional: " + ConventionalMemoryText()
    AddLine reportText, "XMS: " + XmsText()
    AddLine reportText, "EMS: " + EmsText()
    AddLine reportText, "UMB: " + UmbText()
    AddLine reportText, ""

    AddDriveReport reportText
    AddVideoReport reportText

    AddLine reportText, "Mouse"
    AddLine reportText, "-----"
    AddLine reportText, "Mouse: " + MouseText()
    AddLine reportText, ""

    AddSoundReport reportText
    AddBacklashConfigReport reportText

    Return reportText
End Function

' ---------------------------
' Program entry
' ---------------------------

Dim modeText As String
Dim reportOutput As String

modeText = UCase$(Trim$(Command(1)))
reportOutput = BuildReportText()

WriteTextFile REPORT_FILE, reportOutput

If modeText = "SAVE" Then
    WriteTextFile ROOT_REPORT, reportOutput
    WriteTextFile STATUS_FILE, "Report saved to SYSINFO.TXT."
Else
    WriteTextFile STATUS_FILE, "System information refreshed."
End If
