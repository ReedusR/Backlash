#include once "dos/dpmi.bi"
#include once "dos/go32.bi"
#include once "dos/sys/farptr.bi"

' SYSINH.BAS
' Backlash System Info helper.

Const REPORT_FILE As String = "REPORT.TXT"
Const STATUS_FILE As String = "STATUS.TXT"
Const ROOT_REPORT As String = "SYSINFO.TXT"
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

Function ReadCfgValue(ByVal fileName As String, ByVal keyName As String, ByVal defaultValue As String) As String
    Dim fileNum As Integer
    Dim lineText As String
    Dim eqPos As Integer
    Dim leftKey As String
    Dim rightValue As String

    If Dir(fileName) = "" Then Return defaultValue

    fileNum = FreeFile
    Open fileName For Input As #fileNum
    Do Until Eof(fileNum)
        Line Input #fileNum, lineText
        lineText = Trim$(lineText)
        If Len(lineText) > 0 Then
            If Left$(lineText, 1) <> "#" And Left$(lineText, 1) <> ";" Then
                eqPos = InStr(lineText, "=")
                If eqPos > 0 Then
                    leftKey = UCase$(Trim$(Left$(lineText, eqPos - 1)))
                    rightValue = Trim$(Mid$(lineText, eqPos + 1))
                    If leftKey = UCase$(keyName) Then
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

Function FileExists(ByVal fileName As String) As Integer
    Dim fileNum As Integer

    fileNum = FreeFile
    If Open(fileName For Input As #fileNum) = 0 Then
        Close #fileNum
        Return -1
    End If

    Return 0
End Function

Function FindDisplayCfg() As String
    If FileExists("SYSTEM\DISPLAY.CFG") <> 0 Then Return "SYSTEM\DISPLAY.CFG"
    If FileExists("..\..\SYSTEM\DISPLAY.CFG") <> 0 Then Return "..\..\SYSTEM\DISPLAY.CFG"
    If FileExists("\SYSTEM\DISPLAY.CFG") <> 0 Then Return "\SYSTEM\DISPLAY.CFG"
    Return "SYSTEM\DISPLAY.CFG"
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

Function XmsText() As String
    Dim regs As __dpmi_regs
    Dim lowByte As Integer

    regs.x.ax = &H4300
    __dpmi_int(&H2F, @regs)
    lowByte = regs.x.ax And &HFF

    If lowByte = &H80 Then Return "driver present"
    Return "not detected"
End Function

Function EmsText() As String
    Dim regs As __dpmi_regs
    Dim statusCode As Integer
    Dim freePages As Integer
    Dim totalPages As Integer
    Dim freeKb As Integer
    Dim totalKb As Integer

    regs.x.ax = &H4000
    __dpmi_int(&H67, @regs)
    statusCode = (regs.x.ax Shr 8) And &HFF
    If statusCode <> 0 Then Return "not detected"

    regs.x.ax = &H4200
    __dpmi_int(&H67, @regs)
    statusCode = (regs.x.ax Shr 8) And &HFF
    If statusCode <> 0 Then Return "driver present, size unavailable"

    freePages = regs.x.bx And &HFFFF
    totalPages = regs.x.dx And &HFFFF
    freeKb = freePages * 16
    totalKb = totalPages * 16

    Return LTrim$(Str$(freeKb)) + " KB free, " + LTrim$(Str$(totalKb)) + " KB total"
End Function

Function HexWordText(ByVal valueNumber As Integer) As String
    Return "&H" + Hex$(valueNumber And &HFFFF, 4)
End Function

Function YesNoText(ByVal trueValue As Integer) As String
    If trueValue <> 0 Then Return "yes"
    Return "no"
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

Sub AddMachineReport(ByRef reportText As String)
    Dim equipmentFlags As Integer
    Dim serialPorts As Integer
    Dim parallelPorts As Integer
    Dim hasGamePort As Integer

    equipmentFlags = BiosEquipmentFlags()
    serialPorts = (equipmentFlags Shr 9) And 7
    parallelPorts = (equipmentFlags Shr 14) And 3
    hasGamePort = equipmentFlags And &H1000

    AddLine reportText, "BIOS / Machine"
    AddLine reportText, "--------------"
    AddLine reportText, "BIOS date: " + BiosDateText()
    AddLine reportText, "Equipment flags: " + HexWordText(equipmentFlags)
    AddLine reportText, "Floppy drives: " + BiosFloppyCountText(equipmentFlags)
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

Function Opl2Text() As String
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

    If ((statusBefore And &HE0) = 0) And ((statusAfter And &HC0) = &HC0) Then
        Return "detected at &H388"
    End If

    Return "not detected"
End Function

Sub AddSoundReport(ByRef reportText As String)
    Dim detectedBase As Integer
    Dim blasterText As String

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
        End If
    Next driveNumber

    AddLine reportText, ""
End Sub

' ---------------------------
' Video, mouse, and Backlash settings
' ---------------------------

Function CurrentVideoModeText() As String
    Dim modeByte As UByte

    modeByte = 0
    dosmemget &H449, 1, @modeByte
    Return "BIOS mode " + LTrim$(Str$(modeByte)) + " / &H" + Hex$(modeByte, 2)
End Function

Function VesaText() As String
    Dim regs As __dpmi_regs
    Dim block(0 To 511) As UByte
    Dim stringBytes(0 To 79) As UByte
    Dim i As Integer
    Dim signatureText As String
    Dim versionNumber As Integer
    Dim versionMajor As Integer
    Dim versionMinor As Integer
    Dim oemOffset As UInteger
    Dim oemSegment As UInteger
    Dim oemAddress As UInteger
    Dim oemText As String

    For i = 0 To 511
        block(i) = 0
    Next i
    block(0) = Asc("V")
    block(1) = Asc("B")
    block(2) = Asc("E")
    block(3) = Asc("2")

    dosmemput @block(0), 512, __tb

    regs.x.ax = &H4F00
    regs.x.es = __tb \ 16
    regs.x.di = __tb And &H0F
    __dpmi_int(&H10, @regs)

    If (regs.x.ax And &HFFFF) <> &H004F Then Return "not detected"

    dosmemget __tb, 512, @block(0)

    signatureText = Chr$(block(0)) + Chr$(block(1)) + Chr$(block(2)) + Chr$(block(3))
    If Left$(signatureText, 4) <> "VESA" Then Return "not detected"

    versionNumber = CInt(block(4)) + CInt(block(5)) * 256
    versionMajor = (versionNumber Shr 8) And &HFF
    versionMinor = versionNumber And &HFF

    oemOffset = CUInt(block(6)) + CUInt(block(7)) * 256
    oemSegment = CUInt(block(8)) + CUInt(block(9)) * 256
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

    Return "VESA " + LTrim$(Str$(versionMajor)) + "." + Right$("00" + LTrim$(Str$(versionMinor)), 2) + " - " + oemText
End Function

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
    AddLine reportText, "DOS version: " + DosVersionText()
    AddLine reportText, "Current directory: " + CurDir()
    AddLine reportText, "COMSPEC: " + Environ$("COMSPEC")
    AddLine reportText, ""

    AddMachineReport reportText
    AddPortReport reportText

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
    AddLine reportText, ""

    AddDriveReport reportText

    AddLine reportText, "Video"
    AddLine reportText, "-----"
    AddLine reportText, "Current mode: " + CurrentVideoModeText()
    AddLine reportText, "VESA BIOS: " + VesaText()
    AddLine reportText, "Backlash display: " + BacklashDisplayText()
    AddLine reportText, ""

    AddLine reportText, "Mouse"
    AddLine reportText, "-----"
    AddLine reportText, "Mouse: " + MouseText()
    AddLine reportText, ""

    AddSoundReport reportText

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
