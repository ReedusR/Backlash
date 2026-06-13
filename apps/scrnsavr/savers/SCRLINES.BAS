#lang "fb"

' SCRLINES.BAS
' Backlash Rainbow Lines screensaver.
' FreeBASIC 1.10.1 compatible.
' Compile: fbc SCRLINES.BAS

Const SCR_W As Integer = 640
Const SCR_H As Integer = 480
Const MAX_POINTS As Integer = 13
Const MAX_TRAIL_REPS As Integer = 80
Const MAX_LINES_PER_FRAME As Integer = MAX_POINTS * 6
Const MAX_SEGS As Integer = MAX_TRAIL_REPS * MAX_LINES_PER_FRAME
Const CENTER_X As Integer = 320
Const CENTER_Y As Integer = 240
Const COLOR_STEPS As Integer = 96
Const PALETTE_COLORS As Integer = 15
Const COLOR_HOLD As Integer = 2

Type DotState
    x As Double
    y As Double
    vx As Double
    vy As Double
End Type

Type SegmentState
    x1 As Integer
    y1 As Integer
    x2 As Integer
    y2 As Integer
End Type

Dim Shared dots(0 To MAX_POINTS - 1) As DotState
Dim Shared trail(0 To MAX_SEGS - 1) As SegmentState
Dim Shared trailPos As Integer
Dim Shared trailCount As Integer
Dim Shared cycleStep As Integer
Dim Shared cycleTick As Integer
Dim Shared cycleDir As Integer
Dim Shared cfgPointCount As Integer
Dim Shared cfgTrailReps As Integer
Dim Shared cfgMaxSegs As Integer
Dim Shared cfgResetSeconds As Integer

Declare Function ReadCfgValue(ByVal fileName As String, ByVal keyName As String, ByVal defaultValue As String) As String
Declare Function ReadCfgInt(ByVal fileName As String, ByVal keyName As String, ByVal defaultValue As Integer, ByVal minValue As Integer, ByVal maxValue As Integer) As Integer
Declare Function ExitRequested() As Integer
Declare Function ResetLinesWithFade() As Integer
Declare Sub InitDots()
Declare Sub SetPal(ByVal idx As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer, ByVal fadeLevel As Integer)
Declare Sub SetDazzlePalette()
Declare Sub SetDazzlePaletteFade(ByVal fadeLevel As Integer)
Declare Sub AdvanceColorCycle()
Declare Sub ClearTrail()
Declare Sub DrawStoredTrail()
Declare Sub StoreSegment(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer)
Declare Sub StepLineFrame()
Declare Function StepColor(ByVal stepVal As Integer) As Integer
Declare Function AgeColor(ByVal age As Integer) As Integer
Declare Sub DrainKeyboard()

' ---------------------------
' Config reads and screensaver exit input
' ---------------------------

Function ReadCfgValue(ByVal fileName As String, ByVal keyName As String, ByVal defaultValue As String) As String
    Dim f As Integer
    Dim lineIn As String
    Dim p As Integer
    Dim k As String
    Dim v As String

    keyName = UCase$(Trim$(keyName))
    If keyName = "" Then
        ReadCfgValue = defaultValue
        Exit Function
    End If

    f = FreeFile
    If Open(fileName For Input As #f) <> 0 Then
        ReadCfgValue = defaultValue
        Exit Function
    End If

    Do While Not Eof(f)
        Line Input #f, lineIn
        lineIn = Trim$(lineIn)

        If lineIn <> "" Then
            If Left$(lineIn, 1) <> ";" And Left$(lineIn, 1) <> "#" Then
                p = InStr(lineIn, "=")
                If p > 0 Then
                    k = UCase$(Trim$(Left$(lineIn, p - 1)))
                    v = Trim$(Mid$(lineIn, p + 1))
                    If k = keyName Then
                        Close #f
                        ReadCfgValue = v
                        Exit Function
                    End If
                End If
            End If
        End If
    Loop

    Close #f
    ReadCfgValue = defaultValue
End Function

Function ReadCfgInt(ByVal fileName As String, ByVal keyName As String, ByVal defaultValue As Integer, ByVal minValue As Integer, ByVal maxValue As Integer) As Integer
    Dim v As Integer

    v = Val(ReadCfgValue(fileName, keyName, LTrim$(Str$(defaultValue))))
    If v < minValue Then v = minValue
    If v > maxValue Then v = maxValue

    ReadCfgInt = v
End Function

Function ExitRequested() As Integer
    Dim k As String
    Dim mx As Integer
    Dim my As Integer
    Dim mw As Integer
    Dim mb As Integer

    k = InKey$
    If Len(k) > 0 Then
        ExitRequested = -1
        Exit Function
    End If

    If GetMouse(mx, my, mw, mb) = 0 Then
        If mb <> 0 Then
            ExitRequested = -1
            Exit Function
        End If
    End If

    ExitRequested = 0
End Function

Sub DrainKeyboard()
    Dim k As String

    Do
        k = InKey$
        If Len(k) = 0 Then Exit Do
    Loop
End Sub

' ---------------------------
' Line endpoint setup
' ---------------------------

Sub InitDots()
    Dim n As Integer

    If cfgPointCount < 3 Then cfgPointCount = 8
    If cfgPointCount > MAX_POINTS Then cfgPointCount = MAX_POINTS

    For n = 0 To cfgPointCount - 1
        dots(n).x = 70.0 + Rnd * CDbl(SCR_W - 140)
        dots(n).y = 60.0 + Rnd * CDbl(SCR_H - 120)

        dots(n).vx = 1.2 + Rnd * 3.0
        dots(n).vy = 1.0 + Rnd * 2.7

        If Rnd < 0.5 Then dots(n).vx = -dots(n).vx
        If Rnd < 0.5 Then dots(n).vy = -dots(n).vy
    Next n
End Sub

' ---------------------------
' Palette cycling and fade colors
' ---------------------------

Sub SetPal(ByVal idx As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer, ByVal fadeLevel As Integer)
    If fadeLevel < 0 Then fadeLevel = 0
    If fadeLevel > 64 Then fadeLevel = 64

    Palette idx, RGB((r * fadeLevel) \ 64, (g * fadeLevel) \ 64, (b * fadeLevel) \ 64)
End Sub

Sub SetDazzlePalette()
    SetDazzlePaletteFade 64
End Sub

Sub SetDazzlePaletteFade(ByVal fadeLevel As Integer)
    ' Smooth VGA-style color wheel.
    ' Newest line color depends on cycleStep, which starts randomly.
    SetPal 1, 255,   0,   0, fadeLevel
    SetPal 2, 255,  64,   0, fadeLevel
    SetPal 3, 255, 128,   0, fadeLevel
    SetPal 4, 255, 192,   0, fadeLevel
    SetPal 5, 255, 255,   0, fadeLevel
    SetPal 6, 128, 255,   0, fadeLevel
    SetPal 7,   0, 255,   0, fadeLevel
    SetPal 8,   0, 255, 128, fadeLevel
    SetPal 9,   0, 255, 255, fadeLevel
    SetPal 10,  0, 128, 255, fadeLevel
    SetPal 11,  0,   0, 255, fadeLevel
    SetPal 12, 96,   0, 255, fadeLevel
    SetPal 13,192,   0, 255, fadeLevel
    SetPal 14,255,   0, 192, fadeLevel
    SetPal 15,255,   0,  96, fadeLevel
End Sub

Sub AdvanceColorCycle()
    cycleTick += 1

    If cycleTick >= COLOR_HOLD Then
        cycleTick = 0
        cycleStep += cycleDir

        If cycleStep >= COLOR_STEPS Then cycleStep = 0
        If cycleStep < 0 Then cycleStep = COLOR_STEPS - 1
    End If
End Sub

Function StepColor(ByVal stepVal As Integer) As Integer
    Dim s As Integer
    Dim c As Integer

    s = stepVal Mod COLOR_STEPS
    If s < 0 Then s += COLOR_STEPS

    c = ((s * PALETTE_COLORS) \ COLOR_STEPS) + 1

    If c < 1 Then c = 1
    If c > PALETTE_COLORS Then c = PALETTE_COLORS

    StepColor = c
End Function

Function AgeColor(ByVal age As Integer) As Integer
    Dim ageStep As Integer
    Dim activeMax As Integer

    activeMax = cfgMaxSegs
    If activeMax < 1 Then activeMax = MAX_SEGS

    If age < 0 Then age = 0
    If age >= activeMax Then age = activeMax - 1

    ageStep = (age * COLOR_STEPS) \ activeMax

    AgeColor = StepColor(cycleStep - (ageStep * cycleDir))
End Function

' ---------------------------
' Trail storage and trail redraw
' ---------------------------

Sub StoreSegment(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer)
    Dim activeMax As Integer

    activeMax = cfgMaxSegs
    If activeMax < 1 Then activeMax = MAX_SEGS
    If activeMax > MAX_SEGS Then activeMax = MAX_SEGS

    trail(trailPos).x1 = x1
    trail(trailPos).y1 = y1
    trail(trailPos).x2 = x2
    trail(trailPos).y2 = y2

    trailPos += 1
    If trailPos >= activeMax Then trailPos = 0

    If trailCount < activeMax Then trailCount += 1
End Sub

Sub ClearTrail()
    trailPos = 0
    trailCount = 0
End Sub

Sub DrawStoredTrail()
    Dim n As Integer
    Dim idx As Integer
    Dim age As Integer
    Dim activeMax As Integer

    activeMax = cfgMaxSegs
    If activeMax < 1 Then activeMax = MAX_SEGS
    If activeMax > MAX_SEGS Then activeMax = MAX_SEGS

    Cls

    If trailCount <= 0 Then Exit Sub

    For n = trailCount - 1 To 0 Step -1
        idx = trailPos - 1 - n
        Do While idx < 0
            idx += activeMax
        Loop

        age = n
        Line (trail(idx).x1, trail(idx).y1)-(trail(idx).x2, trail(idx).y2), AgeColor(age)
    Next n
End Sub

' ---------------------------
' Per-frame line motion
' ---------------------------

Sub StepLineFrame()
    Dim i As Integer
    Dim j As Integer

    For i = 0 To cfgPointCount - 1
        dots(i).x += dots(i).vx
        dots(i).y += dots(i).vy

        If dots(i).x < 8.0 Then
            dots(i).x = 8.0
            dots(i).vx = Abs(dots(i).vx)
        End If

        If dots(i).x > CDbl(SCR_W - 9) Then
            dots(i).x = CDbl(SCR_W - 9)
            dots(i).vx = -Abs(dots(i).vx)
        End If

        If dots(i).y < 8.0 Then
            dots(i).y = 8.0
            dots(i).vy = Abs(dots(i).vy)
        End If

        If dots(i).y > CDbl(SCR_H - 9) Then
            dots(i).y = CDbl(SCR_H - 9)
            dots(i).vy = -Abs(dots(i).vy)
        End If
    Next i

    AdvanceColorCycle

    For i = 0 To cfgPointCount - 1
        j = i + 1
        If j >= cfgPointCount Then j = 0

        StoreSegment CInt(dots(i).x), CInt(dots(i).y), CInt(dots(j).x), CInt(dots(j).y)
        StoreSegment SCR_W - 1 - CInt(dots(i).x), CInt(dots(i).y), SCR_W - 1 - CInt(dots(j).x), CInt(dots(j).y)
        StoreSegment CInt(dots(i).x), SCR_H - 1 - CInt(dots(i).y), CInt(dots(j).x), SCR_H - 1 - CInt(dots(j).y)
        StoreSegment SCR_W - 1 - CInt(dots(i).x), SCR_H - 1 - CInt(dots(i).y), SCR_W - 1 - CInt(dots(j).x), SCR_H - 1 - CInt(dots(j).y)

        StoreSegment CENTER_X - (CInt(dots(i).y) - CENTER_Y), CENTER_Y + (CInt(dots(i).x) - CENTER_X), CENTER_X - (CInt(dots(j).y) - CENTER_Y), CENTER_Y + (CInt(dots(j).x) - CENTER_X)
        StoreSegment CENTER_X + (CInt(dots(i).y) - CENTER_Y), CENTER_Y - (CInt(dots(i).x) - CENTER_X), CENTER_X + (CInt(dots(j).y) - CENTER_Y), CENTER_Y - (CInt(dots(j).x) - CENTER_X)
    Next i
End Sub

' ---------------------------
' Fade reset
' ---------------------------

Function ResetLinesWithFade() As Integer
    Dim f As Integer

    For f = 64 To 0 Step -4
        SetDazzlePaletteFade f
        Sleep 10, 1
        If ExitRequested() <> 0 Then
            ResetLinesWithFade = -1
            Exit Function
        End If
    Next f

    ScreenLock
    Cls
    ScreenUnlock

    ClearTrail
    InitDots
    cycleStep = Int(Rnd * CDbl(COLOR_STEPS))
    cycleTick = 0
    cycleDir = 1
    If Rnd < 0.5 Then cycleDir = -1

    For f = 0 To 64 Step 4
        SetDazzlePaletteFade f
        StepLineFrame
        ScreenLock
        DrawStoredTrail
        ScreenUnlock
        Sleep 15, 1
        If ExitRequested() <> 0 Then
            ResetLinesWithFade = -1
            Exit Function
        End If
    Next f

    SetDazzlePalette
    ResetLinesWithFade = 0
End Function

Randomize Timer

Dim cfgDensity As Integer
Dim lastResetTime As Double
Dim nowTime As Double

cfgTrailReps = ReadCfgInt("SCRLINES.CFG", "TRAIL_LENGTH", 24, 5, 80)
cfgResetSeconds = ReadCfgInt("SCRLINES.CFG", "RESET_SECONDS", 30, 5, 120)
cfgDensity = ReadCfgInt("SCRLINES.CFG", "LINE_DENSITY", 5, 1, 10)
cfgPointCount = cfgDensity + 3
If cfgPointCount < 3 Then cfgPointCount = 3
If cfgPointCount > MAX_POINTS Then cfgPointCount = MAX_POINTS

cfgMaxSegs = cfgTrailReps * (cfgPointCount * 6)
If cfgMaxSegs < 1 Then cfgMaxSegs = MAX_LINES_PER_FRAME
If cfgMaxSegs > MAX_SEGS Then cfgMaxSegs = MAX_SEGS

Screen 12
Color 15, 0
Cls
DrainKeyboard
SetDazzlePalette

Dim i As Integer
Dim keyText As String

InitDots

trailPos = 0
trailCount = 0
cycleStep = Int(Rnd * CDbl(COLOR_STEPS))
cycleTick = 0
cycleDir = 1
If Rnd < 0.5 Then cycleDir = -1

For i = 0 To MAX_SEGS - 1
    trail(i).x1 = 0
    trail(i).y1 = 0
    trail(i).x2 = 0
    trail(i).y2 = 0
Next i

lastResetTime = Timer

Do
    If ExitRequested() <> 0 Then Exit Do

    nowTime = Timer
    If nowTime < lastResetTime Then lastResetTime = nowTime

    If nowTime - lastResetTime >= CDbl(cfgResetSeconds) Then
        If ResetLinesWithFade() <> 0 Then Exit Do
        lastResetTime = Timer
    End If

    StepLineFrame

    ScreenLock
    DrawStoredTrail
    ScreenUnlock

    Sleep 15, 1
Loop

Screen 0
Width 80, 25
Color 7, 0
Cls
End
