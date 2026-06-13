#lang "fb"

' LIFESI2.BAS
' Backlash Life Simulator screensaver.
' FreeBASIC 1.10.1 compatible.
' Compile: fbc LIFESI2.BAS
'
' Species:
'   Red    = Predator, T-rex shaped
'   Green  = Herbivore, cow shaped
'   Blue   = Omnivore, human shaped
'   Yellow = Virus, blob shaped
'
' Exit rule:
'   exits only on keypress or mouse click.
'   mouse movement alone does not exit.

Const SCR_W As Integer = 320
Const SCR_H As Integer = 200
Const MAX_CREATURES As Integer = 96

Const TOP_H As Integer = 18
Const MIN_X As Double = 4.0
Const MAX_X As Double = 315.0
Const MIN_Y As Double = 24.0
Const MAX_Y As Double = 195.0

Const SP_PRED As Integer = 0
Const SP_HERB As Integer = 1
Const SP_OMNI As Integer = 2
Const SP_VIRUS As Integer = 3

Const RESET_DELAY_FRAMES As Integer = 267
Const NO_INTERACTION_LIMIT As Integer = 500

Type CreatureState
    active As Integer
    sp As Integer
    x As Double
    y As Double
    vx As Double
    vy As Double
    energy As Double
    age As Integer
    cooldown As Integer
    face As Integer
End Type

Dim Shared cr(0 To MAX_CREATURES - 1) As CreatureState

Dim Shared turnNo As Integer
Dim Shared births As Integer
Dim Shared deaths As Integer
Dim Shared interactions As Integer
Dim Shared noInteractionTurns As Integer
Dim Shared resetPending As Integer
Dim Shared resetCounter As Integer
Dim Shared resetReason As String
Dim Shared tickerX As Integer
Dim Shared resetSerial As Integer
Dim Shared bgCol As Integer
Dim Shared borderCol As Integer

Declare Function Num(ByVal n As Integer) As String
Declare Function ExitRequested() As Integer
Declare Sub DrainKeyboard()
Declare Sub SetDAC(ByVal idx As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer)
Declare Sub SetLifePalette()

Declare Sub InitSimulation()
Declare Function SpawnCreature(ByVal sp As Integer, ByVal px As Double, ByVal py As Double) As Integer
Declare Sub KillCreature(ByVal idx As Integer)
Declare Function CountSpecies(ByVal sp As Integer) As Integer
Declare Function CountLivingSpecies() As Integer
Declare Function TotalLiving() As Integer
Declare Function CountNearbySpecies(ByVal idx As Integer, ByVal sp As Integer, ByVal radius As Double) As Integer
Declare Function ClampD(ByVal v As Double, ByVal lo As Double, ByVal hi As Double) As Double
Declare Function Dist2(ByVal ax As Double, ByVal ay As Double, ByVal bx As Double, ByVal by As Double) As Double

Declare Sub UpdateSimulation()
Declare Sub UpdateMovement()
Declare Sub ApplyMortality()
Declare Sub HandleInteractions()
Declare Sub InteractPair(ByVal a As Integer, ByVal b As Integer)
Declare Sub SameSpecies(ByVal a As Integer, ByVal b As Integer)
Declare Sub VirusTouch(ByVal virusIdx As Integer, ByVal targetIdx As Integer)
Declare Sub PredatorAttack(ByVal predIdx As Integer, ByVal preyIdx As Integer)
Declare Sub OmniAttack(ByVal omniIdx As Integer, ByVal preyIdx As Integer)
Declare Sub HumanPredatorEncounter(ByVal predIdx As Integer, ByVal humanIdx As Integer)

Declare Sub DrawScene()
Declare Sub DrawStats()
Declare Sub DrawCreature(ByVal idx As Integer)
Declare Sub DrawPredator(ByVal x As Integer, ByVal y As Integer, ByVal face As Integer)
Declare Sub DrawHerbivore(ByVal x As Integer, ByVal y As Integer, ByVal face As Integer)
Declare Sub DrawOmnivore(ByVal x As Integer, ByVal y As Integer, ByVal face As Integer)
Declare Sub DrawVirus(ByVal x As Integer, ByVal y As Integer)
Declare Sub FillCircle(ByVal cx As Integer, ByVal cy As Integer, ByVal r As Integer, ByVal c As Integer)
Declare Sub FillTri(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal x3 As Integer, ByVal y3 As Integer, ByVal c As Integer)
Declare Function EdgeX(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal yy As Integer) As Integer
Declare Sub SwapInt(ByRef a As Integer, ByRef b As Integer)

' ---------------------------
' Small helpers, palette setup, and exit input
' ---------------------------

Function Num(ByVal n As Integer) As String
    Num = LTrim(Str(n))
End Function

Sub SetDAC(ByVal idx As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer)
    If idx < 0 Then idx = 0
    If idx > 255 Then idx = 255

    If r < 0 Then r = 0
    If r > 63 Then r = 63
    If g < 0 Then g = 0
    If g > 63 Then g = 63
    If b < 0 Then b = 0
    If b > 63 Then b = 63

    Out &H3C8, idx
    Out &H3C9, r
    Out &H3C9, g
    Out &H3C9, b
End Sub

Sub SetLifePalette()
    Dim i As Integer
    Dim g As Integer

    ' Gray simulation-field backgrounds. Color changes every reset,
    ' but always stays gray.
    For i = 0 To 7
        g = 12 + i * 5
        SetDAC 16 + i, g, g, g
    Next i
End Sub

Sub DrainKeyboard()
    Dim k As String

    Do
        k = InKey$
        If Len(k) = 0 Then Exit Do
    Loop
End Sub

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

Function ClampD(ByVal v As Double, ByVal lo As Double, ByVal hi As Double) As Double
    If v < lo Then v = lo
    If v > hi Then v = hi
    ClampD = v
End Function

Function Dist2(ByVal ax As Double, ByVal ay As Double, ByVal bx As Double, ByVal by As Double) As Double
    Dim dx As Double
    Dim dy As Double

    dx = ax - bx
    dy = ay - by
    Dist2 = dx * dx + dy * dy
End Function

' ---------------------------
' Creature population and counting helpers
' ---------------------------

Function SpawnCreature(ByVal sp As Integer, ByVal px As Double, ByVal py As Double) As Integer
    Dim i As Integer

    For i = 0 To MAX_CREATURES - 1
        If cr(i).active = 0 Then
            cr(i).active = -1
            cr(i).sp = sp
            cr(i).x = ClampD(px, MIN_X + 6.0, MAX_X - 6.0)
            cr(i).y = ClampD(py, MIN_Y + 6.0, MAX_Y - 6.0)
            cr(i).vx = -0.7 + Rnd * 1.4
            cr(i).vy = -0.7 + Rnd * 1.4
            cr(i).age = 0
            cr(i).cooldown = 40 + Int(Rnd * 80)
            cr(i).face = 1
            If Rnd < 0.5 Then cr(i).face = -1

            Select Case sp
                Case SP_PRED
                    cr(i).energy = 115.0 + Rnd * 35.0
                Case SP_HERB
                    cr(i).energy = 95.0 + Rnd * 30.0
                Case SP_OMNI
                    cr(i).energy = 105.0 + Rnd * 35.0
                Case Else
                    cr(i).energy = 75.0 + Rnd * 30.0
                    cr(i).vx *= 0.55
                    cr(i).vy *= 0.55
            End Select

            births += 1
            SpawnCreature = i
            Exit Function
        End If
    Next i

    SpawnCreature = -1
End Function

Sub KillCreature(ByVal idx As Integer)
    If idx < 0 Or idx > MAX_CREATURES - 1 Then Exit Sub
    If cr(idx).active = 0 Then Exit Sub

    cr(idx).active = 0
    deaths += 1
End Sub

Function CountSpecies(ByVal sp As Integer) As Integer
    Dim i As Integer
    Dim n As Integer

    n = 0
    For i = 0 To MAX_CREATURES - 1
        If cr(i).active <> 0 Then
            If cr(i).sp = sp Then n += 1
        End If
    Next i

    CountSpecies = n
End Function

Function TotalLiving() As Integer
    Dim i As Integer
    Dim n As Integer

    n = 0
    For i = 0 To MAX_CREATURES - 1
        If cr(i).active <> 0 Then n += 1
    Next i

    TotalLiving = n
End Function

Function CountLivingSpecies() As Integer
    Dim n As Integer

    n = 0
    If CountSpecies(SP_PRED) > 0 Then n += 1
    If CountSpecies(SP_HERB) > 0 Then n += 1
    If CountSpecies(SP_OMNI) > 0 Then n += 1
    If CountSpecies(SP_VIRUS) > 0 Then n += 1

    CountLivingSpecies = n
End Function

Function CountNearbySpecies(ByVal idx As Integer, ByVal sp As Integer, ByVal radius As Double) As Integer
    Dim i As Integer
    Dim n As Integer
    Dim r2 As Double

    n = 0
    r2 = radius * radius

    If idx < 0 Or idx > MAX_CREATURES - 1 Then
        CountNearbySpecies = 0
        Exit Function
    End If

    If cr(idx).active = 0 Then
        CountNearbySpecies = 0
        Exit Function
    End If

    For i = 0 To MAX_CREATURES - 1
        If cr(i).active <> 0 Then
            If cr(i).sp = sp Then
                If Dist2(cr(idx).x, cr(idx).y, cr(i).x, cr(i).y) <= r2 Then n += 1
            End If
        End If
    Next i

    CountNearbySpecies = n
End Function

' ---------------------------
' Simulation updates, motion, and interactions
' ---------------------------

Sub InitSimulation()
    Dim i As Integer
    Dim bc As Integer

    For i = 0 To MAX_CREATURES - 1
        cr(i).active = 0
    Next i

    resetSerial += 1

    bgCol = 16 + (resetSerial Mod 8)

    bc = 1 + ((resetSerial * 5) Mod 14)
    If bc = bgCol Then bc = 15
    If bc = 8 Then bc = 11
    borderCol = bc

    turnNo = 0
    births = 0
    deaths = 0
    interactions = 0
    noInteractionTurns = 0
    resetPending = 0
    resetCounter = 0
    resetReason = ""
    tickerX = SCR_W

    For i = 1 To 8
        SpawnCreature SP_PRED, 30.0 + Rnd * 260.0, 38.0 + Rnd * 145.0
    Next i

    For i = 1 To 28
        SpawnCreature SP_HERB, 20.0 + Rnd * 280.0, 38.0 + Rnd * 145.0
    Next i

    For i = 1 To 12
        SpawnCreature SP_OMNI, 20.0 + Rnd * 280.0, 38.0 + Rnd * 145.0
    Next i

    For i = 1 To 6
        SpawnCreature SP_VIRUS, 20.0 + Rnd * 280.0, 38.0 + Rnd * 145.0
    Next i
End Sub

Sub ApplyMortality()
    Dim i As Integer
    Dim lifeSpan As Integer
    Dim drain As Double
    Dim pDeath As Double

    For i = 0 To MAX_CREATURES - 1
        If cr(i).active <> 0 Then
            cr(i).age += 1

            Select Case cr(i).sp
                Case SP_PRED
                    drain = 0.115
                    lifeSpan = 1950
                Case SP_HERB
                    drain = 0.050
                    lifeSpan = 2550
                Case SP_OMNI
                    drain = 0.075
                    lifeSpan = 2300
                Case Else
                    drain = 0.155
                    lifeSpan = 900
            End Select

            cr(i).energy -= drain

            If cr(i).energy <= 0.0 Then
                KillCreature i
            ElseIf cr(i).age > lifeSpan Then
                pDeath = 0.002 + CDbl(cr(i).age - lifeSpan) / 30000.0
                If pDeath > 0.025 Then pDeath = 0.025
                If Rnd < pDeath Then KillCreature i
            End If

            If cr(i).active <> 0 Then
                If cr(i).cooldown > 0 Then cr(i).cooldown -= 1
                If cr(i).energy > 185.0 Then cr(i).energy = 185.0
            End If
        End If
    Next i
End Sub

Sub UpdateMovement()
    Dim i As Integer
    Dim j As Integer
    Dim tx As Double
    Dim ty As Double
    Dim dx As Double
    Dim dy As Double
    Dim d2 As Double
    Dim bestD2 As Double
    Dim found As Integer
    Dim speedMax As Double
    Dim mag As Double
    Dim steer As Double
    Dim flee As Integer
    Dim groupX As Double
    Dim groupY As Double
    Dim groupN As Integer

    For i = 0 To MAX_CREATURES - 1
        If cr(i).active <> 0 Then
            tx = 0.0
            ty = 0.0
            found = 0
            flee = 0
            bestD2 = 100000000.0
            groupX = 0.0
            groupY = 0.0
            groupN = 0

            For j = 0 To MAX_CREATURES - 1
                If j <> i And cr(j).active <> 0 Then
                    dx = cr(j).x - cr(i).x
                    dy = cr(j).y - cr(i).y
                    d2 = dx * dx + dy * dy

                    If cr(i).sp = SP_OMNI Then
                        If cr(j).sp = SP_OMNI And d2 < 8100.0 Then
                            groupX += dx
                            groupY += dy
                            groupN += 1
                        End If
                    End If

                    Select Case cr(i).sp
                        Case SP_PRED
                            If cr(j).sp = SP_HERB Or cr(j).sp = SP_OMNI Then
                                If d2 < bestD2 Then
                                    bestD2 = d2
                                    tx = dx
                                    ty = dy
                                    found = -1
                                    flee = 0
                                End If
                            End If

                        Case SP_HERB
                            If cr(j).sp = SP_PRED Or cr(j).sp = SP_OMNI Then
                                If d2 < bestD2 And d2 < 2500.0 Then
                                    bestD2 = d2
                                    tx = -dx
                                    ty = -dy
                                    found = -1
                                    flee = -1
                                End If
                            End If

                        Case SP_OMNI
                            If cr(j).sp = SP_PRED And d2 < 2600.0 Then
                                If d2 < bestD2 Then
                                    bestD2 = d2
                                    tx = -dx
                                    ty = -dy
                                    found = -1
                                    flee = -1
                                End If
                            ElseIf cr(j).sp = SP_HERB And found = 0 Then
                                If d2 < bestD2 Then
                                    bestD2 = d2
                                    tx = dx
                                    ty = dy
                                    found = -1
                                    flee = 0
                                End If
                            End If

                        Case SP_VIRUS
                            If cr(j).sp <> SP_VIRUS Then
                                If d2 < bestD2 And d2 < 2200.0 Then
                                    bestD2 = d2
                                    tx = dx
                                    ty = dy
                                    found = -1
                                    flee = 0
                                End If
                            End If
                    End Select
                End If
            Next j

            If cr(i).sp = SP_OMNI And groupN > 0 Then
                If flee <> 0 Then
                    ' Humans under threat move toward the group and away from predators.
                    tx = tx * 0.45 + (groupX / CDbl(groupN)) * 1.10
                    ty = ty * 0.45 + (groupY / CDbl(groupN)) * 1.10
                    found = -1
                ElseIf found = 0 Then
                    tx = groupX / CDbl(groupN)
                    ty = groupY / CDbl(groupN)
                    found = -1
                Else
                    ' Even while foraging, humans bias toward grouping.
                    tx = tx * 0.70 + (groupX / CDbl(groupN)) * 0.45
                    ty = ty * 0.70 + (groupY / CDbl(groupN)) * 0.45
                    found = -1
                End If
            End If

            If found <> 0 Then
                mag = Sqr(tx * tx + ty * ty)
                If mag > 0.01 Then
                    Select Case cr(i).sp
                        Case SP_PRED
                            steer = 0.055
                        Case SP_HERB
                            steer = 0.060
                        Case SP_OMNI
                            steer = 0.060
                        Case Else
                            steer = 0.030
                    End Select

                    cr(i).vx += (tx / mag) * steer
                    cr(i).vy += (ty / mag) * steer
                End If
            End If

            If Rnd < 0.055 Then cr(i).vx += -0.12 + Rnd * 0.24
            If Rnd < 0.055 Then cr(i).vy += -0.12 + Rnd * 0.24

            Select Case cr(i).sp
                Case SP_PRED
                    speedMax = 1.12
                Case SP_HERB
                    speedMax = 0.86
                Case SP_OMNI
                    speedMax = 0.94
                Case Else
                    speedMax = 0.58
            End Select

            mag = Sqr(cr(i).vx * cr(i).vx + cr(i).vy * cr(i).vy)
            If mag > speedMax Then
                cr(i).vx = (cr(i).vx / mag) * speedMax
                cr(i).vy = (cr(i).vy / mag) * speedMax
            End If

            cr(i).x += cr(i).vx
            cr(i).y += cr(i).vy

            If cr(i).vx < 0.0 Then cr(i).face = -1
            If cr(i).vx > 0.0 Then cr(i).face = 1

            If cr(i).x < MIN_X Then
                cr(i).x = MIN_X
                cr(i).vx = Abs(cr(i).vx)
            End If

            If cr(i).x > MAX_X Then
                cr(i).x = MAX_X
                cr(i).vx = -Abs(cr(i).vx)
            End If

            If cr(i).y < MIN_Y Then
                cr(i).y = MIN_Y
                cr(i).vy = Abs(cr(i).vy)
            End If

            If cr(i).y > MAX_Y Then
                cr(i).y = MAX_Y
                cr(i).vy = -Abs(cr(i).vy)
            End If
        End If
    Next i
End Sub

Sub SameSpecies(ByVal a As Integer, ByVal b As Integer)
    Dim chance As Double
    Dim needEnergy As Double
    Dim childX As Double
    Dim childY As Double

    If cr(a).sp = SP_VIRUS Then
        If cr(a).energy > 90.0 And cr(b).energy > 90.0 Then
            If Rnd < 0.025 Then
                childX = (cr(a).x + cr(b).x) / 2.0 + (-5.0 + Rnd * 10.0)
                childY = (cr(a).y + cr(b).y) / 2.0 + (-5.0 + Rnd * 10.0)
                If SpawnCreature(SP_VIRUS, childX, childY) >= 0 Then
                    cr(a).energy -= 18.0
                    cr(b).energy -= 18.0
                End If
            End If
        End If
        Exit Sub
    End If

    If cr(a).cooldown > 0 Or cr(b).cooldown > 0 Then Exit Sub

    Select Case cr(a).sp
        Case SP_PRED
            chance = 0.045
            needEnergy = 125.0
        Case SP_HERB
            chance = 0.100
            needEnergy = 95.0
        Case Else
            chance = 0.075
            needEnergy = 110.0
    End Select

    If cr(a).energy >= needEnergy And cr(b).energy >= needEnergy Then
        If Rnd < chance Then
            childX = (cr(a).x + cr(b).x) / 2.0 + (-7.0 + Rnd * 14.0)
            childY = (cr(a).y + cr(b).y) / 2.0 + (-7.0 + Rnd * 14.0)

            If SpawnCreature(cr(a).sp, childX, childY) >= 0 Then
                cr(a).energy -= needEnergy * 0.28
                cr(b).energy -= needEnergy * 0.28
                cr(a).cooldown = 210
                cr(b).cooldown = 210
            End If
        End If
    End If
End Sub

Sub VirusTouch(ByVal virusIdx As Integer, ByVal targetIdx As Integer)
    Dim chance As Double
    Dim tx As Double
    Dim ty As Double

    If cr(virusIdx).active = 0 Or cr(targetIdx).active = 0 Then Exit Sub
    If cr(targetIdx).sp = SP_VIRUS Then Exit Sub

    Select Case cr(targetIdx).sp
        Case SP_PRED
            chance = 0.105
        Case SP_HERB
            chance = 0.185
        Case Else
            chance = 0.145
    End Select

    chance += (cr(virusIdx).energy - cr(targetIdx).energy) * 0.0012
    chance = ClampD(chance, 0.035, 0.360)

    If Rnd < chance Then
        tx = cr(targetIdx).x
        ty = cr(targetIdx).y
        KillCreature targetIdx
        cr(virusIdx).energy += 26.0

        If Rnd < 0.62 Then
            SpawnCreature SP_VIRUS, tx + (-5.0 + Rnd * 10.0), ty + (-5.0 + Rnd * 10.0)
        End If
    Else
        cr(virusIdx).energy -= 2.0
        cr(targetIdx).energy -= 1.0
    End If
End Sub

Sub PredatorAttack(ByVal predIdx As Integer, ByVal preyIdx As Integer)
    Dim chance As Double
    Dim gain As Double

    If cr(predIdx).active = 0 Or cr(preyIdx).active = 0 Then Exit Sub

    If cr(preyIdx).sp = SP_HERB Then
        chance = 0.540
        gain = 58.0
    Else
        chance = 0.330
        gain = 50.0
    End If

    chance += (cr(predIdx).energy - cr(preyIdx).energy) * 0.0028
    chance = ClampD(chance, 0.080, 0.790)

    If Rnd < chance Then
        KillCreature preyIdx
        cr(predIdx).energy += gain
        cr(predIdx).cooldown = 18
    Else
        cr(predIdx).energy -= 11.0
        cr(preyIdx).energy -= 4.0
    End If
End Sub

Sub HumanPredatorEncounter(ByVal predIdx As Integer, ByVal humanIdx As Integer)
    Dim groupN As Integer
    Dim humanWin As Double
    Dim predWin As Double
    Dim i As Integer
    Dim r2 As Double

    If cr(predIdx).active = 0 Or cr(humanIdx).active = 0 Then Exit Sub

    groupN = CountNearbySpecies(humanIdx, SP_OMNI, 34.0)
    If groupN < 1 Then groupN = 1

    ' Group math:
    ' 1 isolated human is vulnerable.
    ' 2 humans have a realistic defensive chance.
    ' 3+ humans sharply reduce predator success.
    humanWin = 0.060 + CDbl(groupN) * 0.125
    If groupN >= 4 Then humanWin += 0.100
    humanWin += (cr(humanIdx).energy - cr(predIdx).energy) * 0.0010
    humanWin = ClampD(humanWin, 0.070, 0.780)

    predWin = 0.410 - CDbl(groupN - 1) * 0.070
    predWin += (cr(predIdx).energy - cr(humanIdx).energy) * 0.0018
    predWin = ClampD(predWin, 0.050, 0.520)

    If Rnd < humanWin Then
        KillCreature predIdx

        r2 = 34.0 * 34.0
        For i = 0 To MAX_CREATURES - 1
            If cr(i).active <> 0 Then
                If cr(i).sp = SP_OMNI Then
                    If Dist2(cr(i).x, cr(i).y, cr(humanIdx).x, cr(humanIdx).y) <= r2 Then
                        cr(i).energy += 8.0
                        If cr(i).energy > 185.0 Then cr(i).energy = 185.0
                    End If
                End If
            End If
        Next i
    ElseIf Rnd < predWin Then
        KillCreature humanIdx
        cr(predIdx).energy += 45.0
    Else
        cr(predIdx).energy -= 9.0
        cr(humanIdx).energy -= 3.0
    End If
End Sub

Sub OmniAttack(ByVal omniIdx As Integer, ByVal preyIdx As Integer)
    Dim chance As Double

    If cr(omniIdx).active = 0 Or cr(preyIdx).active = 0 Then Exit Sub
    If cr(preyIdx).sp <> SP_HERB Then Exit Sub

    chance = 0.235 + (cr(omniIdx).energy - cr(preyIdx).energy) * 0.0018
    chance = ClampD(chance, 0.040, 0.520)

    If Rnd < chance Then
        KillCreature preyIdx
        cr(omniIdx).energy += 34.0
    Else
        cr(omniIdx).energy -= 5.0
        cr(preyIdx).energy -= 2.0
    End If
End Sub

Sub InteractPair(ByVal a As Integer, ByVal b As Integer)
    Dim sa As Integer
    Dim sb As Integer

    If cr(a).active = 0 Or cr(b).active = 0 Then Exit Sub

    sa = cr(a).sp
    sb = cr(b).sp

    If sa = sb Then
        SameSpecies a, b
        Exit Sub
    End If

    If sa = SP_VIRUS Then
        VirusTouch a, b
        Exit Sub
    End If

    If sb = SP_VIRUS Then
        VirusTouch b, a
        Exit Sub
    End If

    If sa = SP_PRED And sb = SP_OMNI Then
        HumanPredatorEncounter a, b
        Exit Sub
    End If

    If sb = SP_PRED And sa = SP_OMNI Then
        HumanPredatorEncounter b, a
        Exit Sub
    End If

    If sa = SP_PRED Then
        PredatorAttack a, b
        Exit Sub
    End If

    If sb = SP_PRED Then
        PredatorAttack b, a
        Exit Sub
    End If

    If sa = SP_OMNI And sb = SP_HERB Then
        OmniAttack a, b
        Exit Sub
    End If

    If sb = SP_OMNI And sa = SP_HERB Then
        OmniAttack b, a
        Exit Sub
    End If
End Sub

Sub HandleInteractions()
    Dim i As Integer
    Dim j As Integer
    Dim d As Double
    Dim touchDist As Double
    Dim hadInteraction As Integer

    hadInteraction = 0

    For i = 0 To MAX_CREATURES - 2
        If cr(i).active <> 0 Then
            For j = i + 1 To MAX_CREATURES - 1
                If cr(j).active <> 0 Then
                    touchDist = 6.5

                    If cr(i).sp = SP_VIRUS Or cr(j).sp = SP_VIRUS Then
                        touchDist = 5.5
                    End If

                    d = Dist2(cr(i).x, cr(i).y, cr(j).x, cr(j).y)

                    If d <= touchDist * touchDist Then
                        interactions += 1
                        hadInteraction = -1
                        InteractPair i, j
                    End If
                End If
            Next j
        End If
    Next i

    If hadInteraction <> 0 Then
        noInteractionTurns = 0
    Else
        noInteractionTurns += 1
    End If
End Sub

Sub UpdateSimulation()
    Dim livingKinds As Integer

    turnNo += 1

    ApplyMortality
    UpdateMovement
    HandleInteractions

    livingKinds = CountLivingSpecies()

    If TotalLiving() <= 0 Then
        InitSimulation
        Exit Sub
    End If

    If noInteractionTurns >= NO_INTERACTION_LIMIT Then
        InitSimulation
        Exit Sub
    End If

    If livingKinds <= 1 Then
        If resetPending = 0 Then
            resetPending = -1
            resetCounter = RESET_DELAY_FRAMES
            resetReason = "ONLY ONE SPECIES SURVIVED"
        End If
    Else
        resetPending = 0
        resetCounter = 0
        resetReason = ""
    End If

    If resetPending <> 0 Then
        resetCounter -= 1
        If resetCounter <= 0 Then
            InitSimulation
            Exit Sub
        End If
    End If
End Sub

' ---------------------------
' Triangle/circle drawing helpers
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

Sub FillCircle(ByVal cx As Integer, ByVal cy As Integer, ByVal r As Integer, ByVal c As Integer)
    Dim y As Integer
    Dim span As Integer
    Dim v As Double

    If r < 1 Then Exit Sub

    For y = -r To r
        v = 1.0 - (CDbl(y * y) / CDbl(r * r))
        If v < 0.0 Then v = 0.0
        span = CInt(Sqr(v) * CDbl(r))
        Line (cx - span, cy + y)-(cx + span, cy + y), c
    Next y
End Sub

' ---------------------------
' Creature drawing
' ---------------------------

Sub DrawPredator(ByVal x As Integer, ByVal y As Integer, ByVal face As Integer)
    ' Smaller T-rex silhouette.
    Line (x - face * 4, y - 2)-(x + face * 3, y + 2), 4, BF
    Line (x + face * 3, y - 5)-(x + face * 8, y - 2), 4, BF
    Line (x + face * 6, y - 2)-(x + face * 10, y), 4
    PSet (x + face * 7, y - 4), 15

    FillTri x - face * 4, y - 1, x - face * 10, y - 5, x - face * 5, y + 1, 4

    Line (x - face * 1, y + 2)-(x - face * 3, y + 6), 4
    Line (x + face * 3, y + 2)-(x + face * 4, y + 6), 4
    Line (x + face * 1, y - 1)-(x + face * 5, y), 12
End Sub

Sub DrawHerbivore(ByVal x As Integer, ByVal y As Integer, ByVal face As Integer)
    ' Smaller cow-like block shape.
    Line (x - 5, y - 3)-(x + 5, y + 3), 2, BF
    Line (x + face * 4, y - 4)-(x + face * 9, y - 1), 2, BF

    Line (x - 4, y + 3)-(x - 4, y + 6), 2
    Line (x - 1, y + 3)-(x - 1, y + 6), 2
    Line (x + 2, y + 3)-(x + 2, y + 6), 2
    Line (x + 5, y + 3)-(x + 5, y + 6), 2

    PSet (x + face * 8, y - 3), 15
    PSet (x + face * 10, y - 4), 15
    PSet (x + face * 7, y - 2), 0

    Line (x - face * 5, y - 1)-(x - face * 9, y - 3), 10
    Line (x - 2, y - 2)-(x + 2, y - 2), 10
End Sub

Sub DrawOmnivore(ByVal x As Integer, ByVal y As Integer, ByVal face As Integer)
    ' Smaller human-like figure.
    FillCircle x, y - 4, 2, 1
    PSet (x + face, y - 5), 15

    Line (x, y - 2)-(x, y + 4), 1
    Line (x - 3, y)-(x + 3, y), 1
    Line (x, y + 4)-(x - 3, y + 8), 1
    Line (x, y + 4)-(x + 3, y + 8), 1
    Line (x + face * 1, y - 1)-(x + face * 5, y - 3), 9
End Sub

Sub DrawVirus(ByVal x As Integer, ByVal y As Integer)
    Dim r As Integer

    r = 3

    FillCircle x, y, r, 14

    Line (x - 5, y)-(x - 3, y), 14
    Line (x + 3, y)-(x + 5, y), 14
    Line (x, y - 5)-(x, y - 3), 14
    Line (x, y + 3)-(x, y + 5), 14
    PSet (x - 4, y - 4), 14
    PSet (x + 4, y - 4), 14
    PSet (x - 4, y + 4), 14
    PSet (x + 4, y + 4), 14

    PSet (x - 1, y - 1), 15
    PSet (x + 1, y + 1), 6
End Sub

Sub DrawCreature(ByVal idx As Integer)
    Dim x As Integer
    Dim y As Integer

    If cr(idx).active = 0 Then Exit Sub

    x = CInt(cr(idx).x)
    y = CInt(cr(idx).y)

    Select Case cr(idx).sp
        Case SP_PRED
            DrawPredator x, y, cr(idx).face
        Case SP_HERB
            DrawHerbivore x, y, cr(idx).face
        Case SP_OMNI
            DrawOmnivore x, y, cr(idx).face
        Case Else
            DrawVirus x, y
    End Select
End Sub

Sub DrawStats()
    Dim s As String
    Dim w As Integer
    Dim resetText As String

    resetText = ""
    If resetPending <> 0 Then
        resetText = " | RESET: " & resetReason & " IN " & Num(resetCounter \ 33) & " SEC"
    End If

    s = "TURN " & Num(turnNo) & _
        " | RED PREDATORS " & Num(CountSpecies(SP_PRED)) & _
        " | GREEN HERBIVORES " & Num(CountSpecies(SP_HERB)) & _
        " | BLUE HUMANS " & Num(CountSpecies(SP_OMNI)) & _
        " | YELLOW VIRUS " & Num(CountSpecies(SP_VIRUS)) & _
        " | BIRTHS " & Num(births) & _
        " | DEATHS " & Num(deaths) & _
        " | INTERACTIONS " & Num(interactions) & _
        " | QUIET " & Num(noInteractionTurns) & "/" & Num(NO_INTERACTION_LIMIT) & _
        resetText & "     "

    w = Len(s) * 8

    Line (0, 0)-(SCR_W - 1, TOP_H - 1), 0, BF
    Line (0, TOP_H - 1)-(SCR_W - 1, TOP_H - 1), 8

    Draw String (tickerX, 5), s, 15
    Draw String (tickerX + w + 32, 5), s, 15

    tickerX -= 2
    If tickerX < -w - 32 Then tickerX = 0
End Sub

' ---------------------------
' Scene drawing and status text
' ---------------------------

Sub DrawScene()
    Dim i As Integer

    Line (0, 0)-(SCR_W - 1, SCR_H - 1), 0, BF

    ' Simulation field.
    Line (0, TOP_H)-(SCR_W - 1, SCR_H - 1), bgCol, BF
    Line (2, TOP_H + 2)-(SCR_W - 3, SCR_H - 3), borderCol, B

    For i = 0 To MAX_CREATURES - 1
        DrawCreature i
    Next i

    DrawStats
End Sub

Randomize Timer

Screen 13
Color 15, 0
Cls
DrainKeyboard
SetLifePalette

resetSerial = -1
InitSimulation

Do
    If ExitRequested() <> 0 Then Exit Do

    UpdateSimulation

    ScreenLock
    DrawScene
    ScreenUnlock

    Sleep 30, 1
Loop

Screen 0
Width 80, 25
Color 7, 0
Cls
End
