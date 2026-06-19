#lang "fb"

' FLOPDRG.BAS
' Backlash floppy screensaver with side-stable opaque rendering.
' FreeBASIC 1.10.1 compatible.
' Compile: fbc FLOPDRG.BAS

Const SCR_W As Integer = 640
Const SCR_H As Integer = 480
Const MAX_POINTS As Integer = 512
Const MAX_INDEX As Integer = 2048
Const MAX_FACES As Integer = 128
Const MAX_FACE_POINTS As Integer = 32
Const PI_D As Double = 3.1415926535897932384626433832795

Const GROUP_EDGE As Integer = 0
Const GROUP_FRONT As Integer = 1
Const GROUP_BACK As Integer = 2

Type Vec3D
    x As Double
    y As Double
    z As Double
End Type

Dim Shared pt(0 To MAX_POINTS - 1) As Vec3D
Dim Shared pCount As Integer
Dim Shared faceFirst(0 To MAX_FACES - 1) As Integer
Dim Shared faceCount(0 To MAX_FACES - 1) As Integer
Dim Shared faceFill(0 To MAX_FACES - 1) As Integer
Dim Shared faceLine(0 To MAX_FACES - 1) As Integer
Dim Shared faceZAvg(0 To MAX_FACES - 1) As Double
Dim Shared faceOrder(0 To MAX_FACES - 1) As Integer
Dim Shared faceIdx(0 To MAX_INDEX - 1) As Integer
Dim Shared faceGroup(0 To MAX_FACES - 1) As Integer
Dim Shared buildGroup As Integer
Dim Shared fCount As Integer
Dim Shared iCount As Integer
Dim Shared frontFaceID As Integer
Dim Shared backFaceID As Integer
Dim Shared cfgDrawScale As Double

Declare Function AddPoint(ByVal x As Double, ByVal y As Double, ByVal z As Double) As Integer
Declare Sub SetGroup(ByVal g As Integer)
Declare Sub BeginFace(ByVal fillCol As Integer, ByVal lineCol As Integer)
Declare Sub FacePoint(ByVal idx As Integer)
Declare Sub EndFace()
Declare Sub AddQuad(ByVal x1 As Double, ByVal y1 As Double, ByVal z1 As Double, _
                    ByVal x2 As Double, ByVal y2 As Double, ByVal z2 As Double, _
                    ByVal x3 As Double, ByVal y3 As Double, ByVal z3 As Double, _
                    ByVal x4 As Double, ByVal y4 As Double, ByVal z4 As Double, _
                    ByVal fillCol As Integer, ByVal lineCol As Integer)
Declare Sub AddRectZ(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double, _
                     ByVal z As Double, ByVal fillCol As Integer, ByVal lineCol As Integer)
Declare Sub AddRectZFront(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double, _
                          ByVal z As Double, ByVal fillCol As Integer, ByVal lineCol As Integer)
Declare Sub AddRectY(ByVal x1 As Double, ByVal z1 As Double, ByVal x2 As Double, ByVal z2 As Double, _
                     ByVal y As Double, ByVal fillCol As Integer, ByVal lineCol As Integer)
Declare Sub AddCircleZ(ByVal cx As Double, ByVal cy As Double, ByVal z As Double, ByVal r As Double, _
                       ByVal segs As Integer, ByVal fillCol As Integer, ByVal lineCol As Integer)
Declare Sub BuildFloppyModel()
Declare Sub ProjectPoints(ByVal angX As Double, ByVal angY As Double, ByVal centerX As Double, ByVal centerY As Double, _
                          sx() As Integer, sy() As Integer, tz() As Double, _
                          ByRef minX As Integer, ByRef minY As Integer, ByRef maxX As Integer, ByRef maxY As Integer)
Declare Function FaceArea(ByVal f As Integer, sx() As Integer, sy() As Integer) As Double
Declare Sub SortFaces(ByRef drawCount As Integer, sx() As Integer, sy() As Integer, tz() As Double)
Declare Sub DrawAllFaces(ByVal drawCount As Integer, sx() As Integer, sy() As Integer)
Declare Sub DrawFace(ByVal f As Integer, sx() As Integer, sy() As Integer)
Declare Sub ProjectOnePoint(ByVal px As Double, ByVal py As Double, ByVal pz As Double, ByVal angX As Double, ByVal angY As Double, ByVal centerX As Double, ByVal centerY As Double, ByRef sx As Integer, ByRef sy As Integer)
Declare Sub DrawHoleOverlay(ByVal angX As Double, ByVal angY As Double, ByVal centerX As Double, ByVal centerY As Double)
Declare Sub FillTri(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal x3 As Integer, ByVal y3 As Integer, ByVal c As Integer)
Declare Function EdgeX(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal yy As Integer) As Integer
Declare Sub SwapInt(ByRef a As Integer, ByRef b As Integer)
Declare Sub DrainKeyboard()
Declare Function ExitRequested() As Integer
Declare Function ReadCfgValue(ByVal fileName As String, ByVal keyName As String, ByVal defaultValue As String) As String
Declare Function ReadCfgInt(ByVal fileName As String, ByVal keyName As String, ByVal defaultValue As Integer, ByVal minValue As Integer, ByVal maxValue As Integer) As Integer

' ---------------------------
' Floppy 3D model builder
' ---------------------------

Function AddPoint(ByVal x As Double, ByVal y As Double, ByVal z As Double) As Integer
    If pCount >= MAX_POINTS Then
        AddPoint = 0
        Exit Function
    End If

    pt(pCount).x = x
    pt(pCount).y = y
    pt(pCount).z = z

    AddPoint = pCount
    pCount += 1
End Function

Sub SetGroup(ByVal g As Integer)
    buildGroup = g
End Sub

Sub BeginFace(ByVal fillCol As Integer, ByVal lineCol As Integer)
    If fCount >= MAX_FACES Then Exit Sub
    If iCount >= MAX_INDEX Then Exit Sub

    faceFirst(fCount) = iCount
    faceCount(fCount) = 0
    faceFill(fCount) = fillCol
    faceLine(fCount) = lineCol
    faceGroup(fCount) = buildGroup
End Sub

Sub FacePoint(ByVal idx As Integer)
    If fCount >= MAX_FACES Then Exit Sub
    If iCount >= MAX_INDEX Then Exit Sub
    If faceCount(fCount) >= MAX_FACE_POINTS Then Exit Sub

    faceIdx(iCount) = idx
    iCount += 1
    faceCount(fCount) += 1
End Sub

Sub EndFace()
    If fCount >= MAX_FACES Then Exit Sub
    If faceCount(fCount) >= 3 Then fCount += 1
End Sub

Sub AddQuad(ByVal x1 As Double, ByVal y1 As Double, ByVal z1 As Double, _
            ByVal x2 As Double, ByVal y2 As Double, ByVal z2 As Double, _
            ByVal x3 As Double, ByVal y3 As Double, ByVal z3 As Double, _
            ByVal x4 As Double, ByVal y4 As Double, ByVal z4 As Double, _
            ByVal fillCol As Integer, ByVal lineCol As Integer)
    Dim p1 As Integer
    Dim p2 As Integer
    Dim p3 As Integer
    Dim p4 As Integer

    p1 = AddPoint(x1, y1, z1)
    p2 = AddPoint(x2, y2, z2)
    p3 = AddPoint(x3, y3, z3)
    p4 = AddPoint(x4, y4, z4)

    BeginFace fillCol, lineCol
    FacePoint p1
    FacePoint p2
    FacePoint p3
    FacePoint p4
    EndFace
End Sub

Sub AddRectZ(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double, _
             ByVal z As Double, ByVal fillCol As Integer, ByVal lineCol As Integer)
    AddQuad x1, y1, z, x2, y1, z, x2, y2, z, x1, y2, z, fillCol, lineCol
End Sub

Sub AddRectZFront(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double, _
                  ByVal z As Double, ByVal fillCol As Integer, ByVal lineCol As Integer)
    AddQuad x1, y1, z, x1, y2, z, x2, y2, z, x2, y1, z, fillCol, lineCol
End Sub

Sub AddRectY(ByVal x1 As Double, ByVal z1 As Double, ByVal x2 As Double, ByVal z2 As Double, _
             ByVal y As Double, ByVal fillCol As Integer, ByVal lineCol As Integer)
    AddQuad x1, y, z1, x2, y, z1, x2, y, z2, x1, y, z2, fillCol, lineCol
End Sub

Sub AddCircleZ(ByVal cx As Double, ByVal cy As Double, ByVal z As Double, ByVal r As Double, _
               ByVal segs As Integer, ByVal fillCol As Integer, ByVal lineCol As Integer)
    Dim i As Integer
    Dim ang As Double
    Dim idx As Integer

    If segs < 3 Then Exit Sub

    BeginFace fillCol, lineCol

    For i = 0 To segs - 1
        ang = (CDbl(i) / CDbl(segs)) * (2.0 * PI_D)
        idx = AddPoint(cx + Cos(ang) * r, cy + Sin(ang) * r, z)
        FacePoint idx
    Next i

    EndFace
End Sub

Sub BuildFloppyModel()
    Dim xL As Double
    Dim xR As Double
    Dim yT As Double
    Dim yB As Double
    Dim zF As Double
    Dim zB As Double
    Dim zFD As Double
    Dim zBD As Double

    pCount = 0
    fCount = 0
    iCount = 0
    buildGroup = GROUP_EDGE
    frontFaceID = -1
    backFaceID = -1

    xL = -48.0
    xR =  48.0
    yT = -48.0
    yB =  48.0

    zF = -1.75
    zB =  1.75
    zFD = zF - 0.30
    zBD = zB + 0.30

    ' Main shell.
    SetGroup GROUP_BACK
    backFaceID = fCount
    AddRectZ xL, yT, xR, yB, zB, 8, 4

    SetGroup GROUP_EDGE
    AddRectY xL, zF, xR, zB, yT, 7, 4
    AddQuad xL, yB, zF, xL, yB, zB, xR, yB, zB, xR, yB, zF, 8, 4
    AddQuad xL, yT, zF, xL, yT, zB, xL, yB, zB, xL, yB, zF, 8, 4
    AddQuad xR, yT, zF, xR, yB, zF, xR, yB, zB, xR, yT, zB, 8, 4

    SetGroup GROUP_FRONT
    frontFaceID = fCount
    AddRectZFront xL, yT, xR, yB, zF, 8, 4

    ' Metal shutter / door.
    SetGroup GROUP_FRONT
    AddRectZFront -29.0, -48.0, 29.0, -14.0, zFD, 7, 8

    SetGroup GROUP_EDGE
    AddRectY -29.0, zFD, 29.0, zBD, -48.0, 7, 8

    SetGroup GROUP_BACK
    AddRectZ -29.0, -48.0, 29.0, -35.0, zBD, 7, 8

    ' Front shutter detail.
    SetGroup GROUP_FRONT
    AddRectZFront  14.0, -43.0, 23.0, -18.0, zFD - 0.08, 15, 8

    ' Front label.
    AddRectZFront -28.0, 10.0, 14.0, 37.0, zFD, 15, 4
    AddRectZFront  24.0, 30.0, 38.0, 42.0, zFD, 12, 4
    AddRectZFront -24.0, 16.0, 10.0, 17.0, zFD - 0.05, 8, 1
    AddRectZFront -24.0, 23.0, 10.0, 24.0, zFD - 0.05, 8, 1
    AddRectZFront -24.0, 30.0, 10.0, 31.0, zFD - 0.05, 8, 1

    ' Back-only hub, left back write-protect hole, and right lower corner through-hole.
    SetGroup GROUP_BACK
    AddCircleZ 0.0, -2.0, zBD, 12.0, 28, 7, 8
    AddCircleZ 0.0, -2.0, zBD + 0.05, 5.0, 20, 8, 8
    AddRectZ -2.5, -4.5, 2.5, 0.5, zBD + 0.10, 15, 8

    AddRectZ -40.0, 29.0, -27.0, 42.0, zBD, 0, 4
    AddRectZ -38.0, 31.0, -29.0, 40.0, zBD + 0.05, 8, 4

    ' Through-hole in the opposite lower corner, visible on both back and front.
    SetGroup GROUP_BACK
    AddRectZ 27.0, 29.0, 40.0, 42.0, zBD, 0, 4

    SetGroup GROUP_FRONT
    AddRectZFront 27.0, 29.0, 40.0, 42.0, zF, 0, 4

    SetGroup GROUP_EDGE
    AddRectY 27.0, zF, 40.0, zBD, 29.0, 8, 4
    AddRectY 27.0, zF, 40.0, zBD, 42.0, 8, 4
    AddQuad 27.0, 29.0, zF, 27.0, 42.0, zF, 27.0, 42.0, zBD, 27.0, 29.0, zBD, 8, 4
    AddQuad 40.0, 29.0, zF, 40.0, 29.0, zBD, 40.0, 42.0, zBD, 40.0, 42.0, zF, 8, 4
End Sub

' ---------------------------
' Projection, face ordering, and face drawing
' ---------------------------

Sub ProjectPoints(ByVal angX As Double, ByVal angY As Double, ByVal centerX As Double, ByVal centerY As Double, _
                  sx() As Integer, sy() As Integer, tz() As Double, _
                  ByRef minX As Integer, ByRef minY As Integer, ByRef maxX As Integer, ByRef maxY As Integer)
    Dim i As Integer
    Dim x1 As Double
    Dim y1 As Double
    Dim z1 As Double
    Dim x2 As Double
    Dim y2 As Double
    Dim z2 As Double
    Dim ca As Double
    Dim sa As Double
    Dim cb As Double
    Dim sb As Double
    Dim dist As Double
    Dim fac As Double
    Dim drawScale As Double

    ca = Cos(angX)
    sa = Sin(angX)
    cb = Cos(angY)
    sb = Sin(angY)
    dist = 290.0
    If cfgDrawScale <= 0.0 Then
        drawScale = 1.92
    Else
        drawScale = cfgDrawScale
    End If

    minX = SCR_W
    minY = SCR_H
    maxX = 0
    maxY = 0

    For i = 0 To pCount - 1
        x1 = pt(i).x
        y1 = pt(i).y * ca - pt(i).z * sa
        z1 = pt(i).y * sa + pt(i).z * ca

        x2 = x1 * cb + z1 * sb
        y2 = y1
        z2 = -x1 * sb + z1 * cb

        tz(i) = z2

        fac = dist / (dist + z2 + 0.001)
        sx(i) = CInt(centerX + x2 * drawScale * fac)
        sy(i) = CInt(centerY + y2 * drawScale * fac)

        If sx(i) < minX Then minX = sx(i)
        If sy(i) < minY Then minY = sy(i)
        If sx(i) > maxX Then maxX = sx(i)
        If sy(i) > maxY Then maxY = sy(i)
    Next i
End Sub

Function FaceArea(ByVal f As Integer, sx() As Integer, sy() As Integer) As Double
    Dim n As Integer
    Dim i As Integer
    Dim j As Integer
    Dim sum As Double
    Dim firstIdx As Integer
    Dim a As Integer
    Dim b As Integer

    n = faceCount(f)
    firstIdx = faceFirst(f)
    sum = 0.0

    For i = 0 To n - 1
        j = i + 1
        If j >= n Then j = 0

        a = faceIdx(firstIdx + i)
        b = faceIdx(firstIdx + j)

        sum += CDbl(sx(a)) * CDbl(sy(b)) - CDbl(sy(a)) * CDbl(sx(b))
    Next i

    FaceArea = sum
End Function

Sub SortFaces(ByRef drawCount As Integer, sx() As Integer, sy() As Integer, tz() As Double)
    Dim f As Integer
    Dim i As Integer
    Dim j As Integer
    Dim n As Integer
    Dim sumZ As Double
    Dim a As Integer
    Dim b As Integer
    Dim t As Integer
    Dim showFront As Integer
    Dim area As Double

    For f = 0 To fCount - 1
        n = faceCount(f)
        sumZ = 0.0

        For i = 0 To n - 1
            sumZ += tz(faceIdx(faceFirst(f) + i))
        Next i

        faceZAvg(f) = sumZ / CDbl(n)
    Next f

    showFront = 0
    If frontFaceID >= 0 And backFaceID >= 0 Then
        If faceZAvg(frontFaceID) < faceZAvg(backFaceID) Then showFront = -1
    End If

    drawCount = 0

    For f = 0 To fCount - 1
        Select Case faceGroup(f)
            Case GROUP_FRONT
                If showFront <> 0 Then
                    faceOrder(drawCount) = f
                    drawCount += 1
                End If

            Case GROUP_BACK
                If showFront = 0 Then
                    faceOrder(drawCount) = f
                    drawCount += 1
                End If

            Case Else
                area = FaceArea(f, sx(), sy())
                If area < -1.0 Then
                    faceOrder(drawCount) = f
                    drawCount += 1
                End If
        End Select
    Next f

    For i = 0 To drawCount - 2
        For j = i + 1 To drawCount - 1
            a = faceOrder(i)
            b = faceOrder(j)

            If faceZAvg(a) < faceZAvg(b) Then
                t = faceOrder(i)
                faceOrder(i) = faceOrder(j)
                faceOrder(j) = t
            End If
        Next j
    Next i
End Sub

Sub DrawFace(ByVal f As Integer, sx() As Integer, sy() As Integer)
    Dim n As Integer
    Dim i As Integer
    Dim firstIdx As Integer
    Dim a As Integer
    Dim b As Integer

    n = faceCount(f)
    If n < 2 Then Exit Sub

    firstIdx = faceFirst(f)

    For i = 0 To n - 1
        a = faceIdx(firstIdx + i)

        If i = n - 1 Then
            b = faceIdx(firstIdx)
        Else
            b = faceIdx(firstIdx + i + 1)
        End If

        Line (sx(a), sy(a))-(sx(b), sy(b)), faceLine(f)
    Next i
End Sub

Sub DrawAllFaces(ByVal drawCount As Integer, sx() As Integer, sy() As Integer)
    Dim i As Integer

    For i = 0 To drawCount - 1
        DrawFace faceOrder(i), sx(), sy()
    Next i
End Sub

' ---------------------------
' Overlay projection used for front-face details
' ---------------------------

Sub ProjectOnePoint(ByVal px As Double, ByVal py As Double, ByVal pz As Double, ByVal angX As Double, ByVal angY As Double, ByVal centerX As Double, ByVal centerY As Double, ByRef sx As Integer, ByRef sy As Integer)
    Dim x1 As Double
    Dim y1 As Double
    Dim z1 As Double
    Dim x2 As Double
    Dim y2 As Double
    Dim z2 As Double
    Dim ca As Double
    Dim sa As Double
    Dim cb As Double
    Dim sb As Double
    Dim dist As Double
    Dim drawScale As Double
    Dim fac As Double

    ca = Cos(angX)
    sa = Sin(angX)
    cb = Cos(angY)
    sb = Sin(angY)
    dist = 290.0
    If cfgDrawScale <= 0.0 Then
        drawScale = 1.92
    Else
        drawScale = cfgDrawScale
    End If

    x1 = px
    y1 = py * ca - pz * sa
    z1 = py * sa + pz * ca

    x2 = x1 * cb + z1 * sb
    y2 = y1
    z2 = -x1 * sb + z1 * cb

    fac = dist / (dist + z2 + 0.001)

    sx = CInt(centerX + x2 * drawScale * fac)
    sy = CInt(centerY + y2 * drawScale * fac)
End Sub

Sub DrawHoleOverlay(ByVal angX As Double, ByVal angY As Double, ByVal centerX As Double, ByVal centerY As Double)
    Dim fx1 As Integer
    Dim fy1 As Integer
    Dim fx2 As Integer
    Dim fy2 As Integer
    Dim fx3 As Integer
    Dim fy3 As Integer
    Dim fx4 As Integer
    Dim fy4 As Integer
    Dim bx1 As Integer
    Dim by1 As Integer
    Dim bx2 As Integer
    Dim by2 As Integer
    Dim bx3 As Integer
    Dim by3 As Integer
    Dim bx4 As Integer
    Dim by4 As Integer

    ' Through-hole lower-right corner.
    ProjectOnePoint 27.0, 29.0, -1.75, angX, angY, centerX, centerY, fx1, fy1
    ProjectOnePoint 40.0, 29.0, -1.75, angX, angY, centerX, centerY, fx2, fy2
    ProjectOnePoint 40.0, 42.0, -1.75, angX, angY, centerX, centerY, fx3, fy3
    ProjectOnePoint 27.0, 42.0, -1.75, angX, angY, centerX, centerY, fx4, fy4

    ProjectOnePoint 27.0, 29.0, 2.05, angX, angY, centerX, centerY, bx1, by1
    ProjectOnePoint 40.0, 29.0, 2.05, angX, angY, centerX, centerY, bx2, by2
    ProjectOnePoint 40.0, 42.0, 2.05, angX, angY, centerX, centerY, bx3, by3
    ProjectOnePoint 27.0, 42.0, 2.05, angX, angY, centerX, centerY, bx4, by4

    ' Front rectangle.
    Line (fx1, fy1)-(fx2, fy2), 4
    Line (fx2, fy2)-(fx3, fy3), 4
    Line (fx3, fy3)-(fx4, fy4), 4
    Line (fx4, fy4)-(fx1, fy1), 4

    ' Back rectangle.
    Line (bx1, by1)-(bx2, by2), 4
    Line (bx2, by2)-(bx3, by3), 4
    Line (bx3, by3)-(bx4, by4), 4
    Line (bx4, by4)-(bx1, by1), 4

    ' Connecting depth edges.
    Line (fx1, fy1)-(bx1, by1), 4
    Line (fx2, fy2)-(bx2, by2), 4
    Line (fx3, fy3)-(bx3, by3), 4
    Line (fx4, fy4)-(bx4, by4), 4
End Sub

' ---------------------------
' Triangle fill helpers
' ---------------------------

Sub SwapInt(ByRef a As Integer, ByRef b As Integer)
    Dim t As Integer
    t = a
    a = b
    b = t
End Sub

Function EdgeX(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal yy As Integer) As Integer
    If y1 = y2 Then
        EdgeX = x1
    Else
        EdgeX = CInt(CDbl(x1) + (CDbl(yy - y1) * CDbl(x2 - x1)) / CDbl(y2 - y1))
    End If
End Function

Sub FillTri(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal x3 As Integer, ByVal y3 As Integer, ByVal c As Integer)
    Dim y As Integer
    Dim xa As Integer
    Dim xb As Integer

    If y1 > y2 Then
        SwapInt x1, x2
        SwapInt y1, y2
    End If

    If y1 > y3 Then
        SwapInt x1, x3
        SwapInt y1, y3
    End If

    If y2 > y3 Then
        SwapInt x2, x3
        SwapInt y2, y3
    End If

    If y1 = y3 Then Exit Sub

    For y = y1 To y3
        If y < y2 Then
            xa = EdgeX(x1, y1, x2, y2, y)
            xb = EdgeX(x1, y1, x3, y3, y)
        Else
            xa = EdgeX(x2, y2, x3, y3, y)
            xb = EdgeX(x1, y1, x3, y3, y)
        End If

        If xa > xb Then SwapInt xa, xb
        Line (xa, y)-(xb, y), c
    Next y
End Sub

' ---------------------------
' Config reads and screensaver exit input
' ---------------------------

Sub DrainKeyboard()
    Dim k As String

    Do
        k = InKey$
        If Len(k) = 0 Then Exit Do
    Loop
End Sub
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

BuildFloppyModel

Screen 12
Color 15, 0
Cls
DrainKeyboard

Dim sx(0 To MAX_POINTS - 1) As Integer
Dim sy(0 To MAX_POINTS - 1) As Integer
Dim tz(0 To MAX_POINTS - 1) As Double
Dim posX As Double
Dim posY As Double
Dim velX As Double
Dim velY As Double
Dim angX As Double
Dim angY As Double
Dim minX As Integer
Dim minY As Integer
Dim maxX As Integer
Dim maxY As Integer
Dim drawCount As Integer
Dim cfgSpeed As Integer
Dim cfgSize As Integer
Dim speedScale As Double

cfgSpeed = ReadCfgInt("SCRFLOP.CFG", "SPEED", 5, 1, 10)
cfgSize = ReadCfgInt("SCRFLOP.CFG", "SIZE", 5, 1, 10)
speedScale = CDbl(cfgSpeed) / 5.0
cfgDrawScale = 1.12 + (CDbl(cfgSize) * 0.16)

posX = SCR_W / 2.0
posY = SCR_H / 2.0
velX = 2.65 * speedScale
velY = 2.05 * speedScale
angX = 0.0
angY = 0.0

Do
    If ExitRequested() <> 0 Then Exit Do

    angX += 0.043 * speedScale
    angY += 0.031 * speedScale
    posX += velX
    posY += velY

    ProjectPoints angX, angY, posX, posY, sx(), sy(), tz(), minX, minY, maxX, maxY

    If minX < 2 Then
        posX += (2 - minX)
        velX = Abs(velX)
        ProjectPoints angX, angY, posX, posY, sx(), sy(), tz(), minX, minY, maxX, maxY
    End If

    If maxX > SCR_W - 3 Then
        posX -= (maxX - (SCR_W - 3))
        velX = -Abs(velX)
        ProjectPoints angX, angY, posX, posY, sx(), sy(), tz(), minX, minY, maxX, maxY
    End If

    If minY < 2 Then
        posY += (2 - minY)
        velY = Abs(velY)
        ProjectPoints angX, angY, posX, posY, sx(), sy(), tz(), minX, minY, maxX, maxY
    End If

    If maxY > SCR_H - 3 Then
        posY -= (maxY - (SCR_H - 3))
        velY = -Abs(velY)
        ProjectPoints angX, angY, posX, posY, sx(), sy(), tz(), minX, minY, maxX, maxY
    End If

    SortFaces drawCount, sx(), sy(), tz()

    ScreenLock
    Cls
    DrawAllFaces drawCount, sx(), sy()
    DrawHoleOverlay angX, angY, posX, posY
    ScreenUnlock

    Sleep 18, 1
Loop

Screen 0
Width 80, 25
Color 7, 0
Cls
End
