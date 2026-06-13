' Runtime support for text editing, caret movement, selection, clipboard shortcuts, undo, and app event routing.
'
' RUNTIME.BAS
' Textbox edit state, clipboard-safe edit helpers, and embedded [EVENTS] support.

CONST ED_MAX_TEXT = 40000
CONST ED_UNDO_NONE = 0
CONST ED_UNDO_TYPING = 1
CONST ED_UNDO_EDIT = 2
CONST ED_UNDO_LEVELS = 20

TYPE EDSTATE
    txt AS STRING
    txtLen AS INTEGER
    curPos AS INTEGER
    selA AS INTEGER
    selB AS INTEGER
    undoTxt01 AS STRING
    undoTxt02 AS STRING
    undoTxt03 AS STRING
    undoTxt04 AS STRING
    undoTxt05 AS STRING
    undoTxt06 AS STRING
    undoTxt07 AS STRING
    undoTxt08 AS STRING
    undoTxt09 AS STRING
    undoTxt10 AS STRING
    undoTxt11 AS STRING
    undoTxt12 AS STRING
    undoTxt13 AS STRING
    undoTxt14 AS STRING
    undoTxt15 AS STRING
    undoTxt16 AS STRING
    undoTxt17 AS STRING
    undoTxt18 AS STRING
    undoTxt19 AS STRING
    undoTxt20 AS STRING
    undoCur(1 TO ED_UNDO_LEVELS) AS INTEGER
    undoSelA(1 TO ED_UNDO_LEVELS) AS INTEGER
    undoSelB(1 TO ED_UNDO_LEVELS) AS INTEGER
    undoCount AS INTEGER
    undoKind AS INTEGER
    insertMode AS INTEGER
END TYPE

DIM SHARED edClipText AS STRING

' ---------------------------
' Small editor math helpers
' ---------------------------

' Returns the smaller of two integers. Used when editor code needs the low end of a caret or selection range.
FUNCTION Ed_MinI(BYVAL a AS INTEGER, BYVAL b AS INTEGER) AS INTEGER
    IF a < b THEN RETURN a
    RETURN b
END FUNCTION

' Returns the larger of two integer values. Editor code uses this when it needs a safe high end of a caret or selection range.
FUNCTION Ed_MaxI(BYVAL a AS INTEGER, BYVAL b AS INTEGER) AS INTEGER
    IF a > b THEN RETURN a
    RETURN b
END FUNCTION

' Limits an integer to a safe low/high range so caret and selection values cannot run outside valid bounds.
FUNCTION Ed_ClampI(BYVAL v AS INTEGER, BYVAL lo AS INTEGER, BYVAL hi AS INTEGER) AS INTEGER
    IF v < lo THEN RETURN lo
    IF v > hi THEN RETURN hi
    RETURN v
END FUNCTION

' ---------------------------
' Undo buffer storage and undo-group setup
' ---------------------------

' Returns the text saved in one undo slot so the editor can restore an earlier text state.
FUNCTION Ed_GetUndoTxt(BYREF ed AS EDSTATE, BYVAL idx AS INTEGER) AS STRING
    SELECT CASE idx
    CASE 1: RETURN ed.undoTxt01
    CASE 2: RETURN ed.undoTxt02
    CASE 3: RETURN ed.undoTxt03
    CASE 4: RETURN ed.undoTxt04
    CASE 5: RETURN ed.undoTxt05
    CASE 6: RETURN ed.undoTxt06
    CASE 7: RETURN ed.undoTxt07
    CASE 8: RETURN ed.undoTxt08
    CASE 9: RETURN ed.undoTxt09
    CASE 10: RETURN ed.undoTxt10
    CASE 11: RETURN ed.undoTxt11
    CASE 12: RETURN ed.undoTxt12
    CASE 13: RETURN ed.undoTxt13
    CASE 14: RETURN ed.undoTxt14
    CASE 15: RETURN ed.undoTxt15
    CASE 16: RETURN ed.undoTxt16
    CASE 17: RETURN ed.undoTxt17
    CASE 18: RETURN ed.undoTxt18
    CASE 19: RETURN ed.undoTxt19
    CASE 20: RETURN ed.undoTxt20
    END SELECT
    RETURN ""
END FUNCTION

' Stores a text snapshot in an undo slot for later undo recovery.
SUB Ed_SetUndoTxt(BYREF ed AS EDSTATE, BYVAL idx AS INTEGER, BYVAL dataText AS STRING)
    SELECT CASE idx
    CASE 1: ed.undoTxt01 = dataText
    CASE 2: ed.undoTxt02 = dataText
    CASE 3: ed.undoTxt03 = dataText
    CASE 4: ed.undoTxt04 = dataText
    CASE 5: ed.undoTxt05 = dataText
    CASE 6: ed.undoTxt06 = dataText
    CASE 7: ed.undoTxt07 = dataText
    CASE 8: ed.undoTxt08 = dataText
    CASE 9: ed.undoTxt09 = dataText
    CASE 10: ed.undoTxt10 = dataText
    CASE 11: ed.undoTxt11 = dataText
    CASE 12: ed.undoTxt12 = dataText
    CASE 13: ed.undoTxt13 = dataText
    CASE 14: ed.undoTxt14 = dataText
    CASE 15: ed.undoTxt15 = dataText
    CASE 16: ed.undoTxt16 = dataText
    CASE 17: ed.undoTxt17 = dataText
    CASE 18: ed.undoTxt18 = dataText
    CASE 19: ed.undoTxt19 = dataText
    CASE 20: ed.undoTxt20 = dataText
    END SELECT
END SUB


' Keeps the caret, selection anchor, and selection end inside the current text length after edits change the buffer.
SUB Ed_Normalize(BYREF ed AS EDSTATE)
    ed.txtLen = LEN(ed.txt)
    ed.curPos = Ed_ClampI(ed.curPos, 0, ed.txtLen)
    ed.selA = Ed_ClampI(ed.selA, 0, ed.txtLen)
    ed.selB = Ed_ClampI(ed.selB, 0, ed.txtLen)
END SUB

' Records the current text before an edit so Ctrl+Z can restore it.
SUB Ed_SaveUndo(BYREF ed AS EDSTATE, BYVAL kind AS INTEGER)
    DIM i AS INTEGER

    IF kind = ED_UNDO_TYPING THEN
        IF ed.undoCount > 0 AND ed.undoKind = ED_UNDO_TYPING THEN EXIT SUB
    END IF

    Ed_Normalize ed

    IF ed.undoCount >= ED_UNDO_LEVELS THEN
        FOR i = 1 TO ED_UNDO_LEVELS - 1
            Ed_SetUndoTxt ed, i, Ed_GetUndoTxt(ed, i + 1)
            ed.undoCur(i) = ed.undoCur(i + 1)
            ed.undoSelA(i) = ed.undoSelA(i + 1)
            ed.undoSelB(i) = ed.undoSelB(i + 1)
        NEXT
        Ed_SetUndoTxt ed, ED_UNDO_LEVELS, ""
        ed.undoCount = ED_UNDO_LEVELS - 1
    END IF

    ed.undoCount = ed.undoCount + 1
    Ed_SetUndoTxt ed, ed.undoCount, ed.txt
    ed.undoCur(ed.undoCount) = ed.curPos
    ed.undoSelA(ed.undoCount) = ed.selA
    ed.undoSelB(ed.undoCount) = ed.selB
    ed.undoKind = kind
END SUB

' Ends the current typing/delete undo group so the next edit starts a new undo step.
SUB Ed_ResetUndoGroup(BYREF ed AS EDSTATE)
    ed.undoKind = ED_UNDO_NONE
END SUB

' ---------------------------
' Selection state and selection ranges
' ---------------------------

' Clears the active text selection and leaves only the caret position.
SUB Ed_SelClr(BYREF ed AS EDSTATE)
    ed.selA = ed.curPos
    ed.selB = ed.curPos
END SUB

' Checks whether the editor currently has a non-empty selection.
FUNCTION Ed_SelHas(BYREF ed AS EDSTATE) AS INTEGER
    Ed_Normalize ed
    IF ed.selA <> ed.selB THEN RETURN -1
    RETURN 0
END FUNCTION

' Orders the two selection endpoints so later code can safely treat them as start and end positions.
SUB Ed_SelNorm(BYREF ed AS EDSTATE, BYREF a AS INTEGER, BYREF b AS INTEGER)
    Ed_Normalize ed
    a = ed.selA
    b = ed.selB
    IF a > b THEN
        DIM t AS INTEGER
        t = a
        a = b
        b = t
    END IF
END SUB

' Sets the editor selection and clamps both endpoints to valid text positions.
SUB Ed_SelSet(BYREF ed AS EDSTATE, BYVAL a AS INTEGER, BYVAL b AS INTEGER)
    Ed_Normalize ed
    ed.selA = Ed_ClampI(a, 0, ed.txtLen)
    ed.selB = Ed_ClampI(b, 0, ed.txtLen)
END SUB

' ---------------------------
' Editor text load/sync helpers
' ---------------------------

' Loads new text into the editor, sets the caret, clears selection, and resets undo state for the new contents.
SUB Ed_LoadTxt(BYREF ed AS EDSTATE, BYVAL dataText AS STRING, BYVAL caretPos AS INTEGER)
    DIM oldTxt AS STRING
    DIM oldSelA AS INTEGER
    DIM oldSelB AS INTEGER

    oldTxt = ed.txt
    oldSelA = ed.selA
    oldSelB = ed.selB

    IF LEN(dataText) > ED_MAX_TEXT THEN
        ed.txt = LEFT$(dataText, ED_MAX_TEXT)
    ELSE
        ed.txt = dataText
    END IF

    ed.txtLen = LEN(ed.txt)
    ed.curPos = Ed_ClampI(caretPos, 0, ed.txtLen)

    IF oldTxt = ed.txt AND oldSelA <> oldSelB THEN
        ed.selA = Ed_ClampI(oldSelA, 0, ed.txtLen)
        ed.selB = Ed_ClampI(oldSelB, 0, ed.txtLen)
    ELSE
        Ed_SelClr ed
    END IF

    Ed_ResetUndoGroup ed
END SUB

' Replaces the textbox text from outside the editor and mirrors the editor caret back to the UI control.
SUB Ed_SetTextGlue(BYREF ed AS EDSTATE, BYVAL dataText AS STRING, BYREF uiText AS STRING, BYREF uiCaret AS INTEGER)
    IF LEN(dataText) > ED_MAX_TEXT THEN
        ed.txt = LEFT$(dataText, ED_MAX_TEXT)
    ELSE
        ed.txt = dataText
    END IF

    ed.txtLen = LEN(ed.txt)
    ed.curPos = 0
    Ed_SelClr ed
    ed.undoCount = 0
    ed.undoKind = ED_UNDO_NONE
    ed.insertMode = 0

    uiText = ed.txt
    uiCaret = ed.curPos
END SUB

' Returns the editor-owned text when available, otherwise falls back to the UI control text.
FUNCTION Ed_GetTextGlue(BYREF ed AS EDSTATE, BYVAL fallbackText AS STRING) AS STRING
    IF ed.txtLen = 0 AND ed.txt = "" THEN RETURN fallbackText
    RETURN ed.txt
END FUNCTION

' Copies editor text and caret state back into the UI control after editor logic changes them.
SUB Ed_SyncGlue(BYREF ed AS EDSTATE, BYREF uiText AS STRING, BYREF uiCaret AS INTEGER)
    Ed_Normalize ed
    uiText = ed.txt
    uiCaret = ed.curPos
END SUB

' ---------------------------
' Text deletion and insertion
' ---------------------------

' Deletes a character range, moves the caret to the start of the removed text, and clears selection.
SUB Ed_DeleteRange(BYREF ed AS EDSTATE, BYVAL a AS INTEGER, BYVAL b AS INTEGER)
    Ed_Normalize ed
    a = Ed_ClampI(a, 0, ed.txtLen)
    b = Ed_ClampI(b, 0, ed.txtLen)
    IF b < a THEN
        DIM t AS INTEGER
        t = a
        a = b
        b = t
    END IF
    IF b <= a THEN EXIT SUB

    ed.txt = LEFT$(ed.txt, a) + MID$(ed.txt, b + 1)
    ed.txtLen = LEN(ed.txt)
    ed.curPos = a
    Ed_SelClr ed
END SUB

' Deletes the current selection when one exists and tells the caller whether anything was removed.
FUNCTION Ed_DeleteSelection(BYREF ed AS EDSTATE) AS INTEGER
    DIM a AS INTEGER
    DIM b AS INTEGER

    IF Ed_SelHas(ed) = 0 THEN RETURN 0
    Ed_SelNorm ed, a, b
    Ed_DeleteRange ed, a, b
    RETURN -1
END FUNCTION

' Inserts typed or pasted text at the current caret position.
SUB Ed_InsertText(BYREF ed AS EDSTATE, BYVAL insText AS STRING, BYVAL maxChars AS INTEGER)
    DIM allowed AS INTEGER

    IF maxChars < 1 THEN maxChars = ED_MAX_TEXT
    IF maxChars > ED_MAX_TEXT THEN maxChars = ED_MAX_TEXT

    IF Ed_SelHas(ed) <> 0 THEN
        Ed_DeleteSelection ed
    END IF

    allowed = maxChars - ed.txtLen
    IF allowed <= 0 THEN EXIT SUB
    IF LEN(insText) > allowed THEN insText = LEFT$(insText, allowed)
    IF insText = "" THEN EXIT SUB

    ed.txt = LEFT$(ed.txt, ed.curPos) + insText + MID$(ed.txt, ed.curPos + 1)
    ed.curPos = ed.curPos + LEN(insText)
    ed.txtLen = LEN(ed.txt)
    Ed_SelClr ed
END SUB

' ---------------------------
' Line, column, and caret position helpers
' ---------------------------

' Fast text scans use zero-based positions and direct string pointer reads.
' This avoids copying whole textbox strings and avoids MID$ per character.
FUNCTION Ed_CharCodeAt(BYREF s AS STRING, BYVAL charIndex AS INTEGER) AS INTEGER
    DIM textLen AS INTEGER
    DIM textPtr AS UBYTE PTR

    textLen = LEN(s)
    IF charIndex < 0 OR charIndex >= textLen THEN RETURN 0

    textPtr = CAST(UBYTE PTR, STRPTR(s))
    IF textPtr = 0 THEN RETURN 0

    RETURN textPtr[charIndex]
END FUNCTION

' Finds the character position where a textbox line ends.
FUNCTION TbLineEndPos(BYREF s AS STRING, BYVAL startPos AS INTEGER) AS INTEGER
    DIM p AS INTEGER
    DIM textLen AS INTEGER
    DIM textPtr AS UBYTE PTR
    DIM chCode AS INTEGER

    textLen = LEN(s)
    startPos = Ed_ClampI(startPos, 0, textLen)
    IF textLen <= 0 THEN RETURN 0

    textPtr = CAST(UBYTE PTR, STRPTR(s))
    IF textPtr = 0 THEN RETURN textLen

    p = startPos
    DO WHILE p < textLen
        chCode = textPtr[p]
        IF chCode = 13 OR chCode = 10 THEN RETURN p
        p = p + 1
    LOOP

    RETURN textLen
END FUNCTION

' Finds the first character of the next line after a line break.
FUNCTION TbNextLineStart(BYREF s AS STRING, BYVAL endPos AS INTEGER) AS INTEGER
    DIM p AS INTEGER
    DIM textLen AS INTEGER
    DIM textPtr AS UBYTE PTR

    textLen = LEN(s)
    p = Ed_ClampI(endPos, 0, textLen)
    IF textLen <= 0 THEN RETURN 0

    textPtr = CAST(UBYTE PTR, STRPTR(s))
    IF textPtr = 0 THEN RETURN p

    IF p < textLen THEN
        IF textPtr[p] = 13 THEN p = p + 1
        IF p < textLen THEN
            IF textPtr[p] = 10 THEN p = p + 1
        END IF
    END IF

    RETURN p
END FUNCTION

' Finds the character position where a requested textbox line begins.
FUNCTION TbLineStartForLine(BYREF s AS STRING, BYVAL lineNum AS INTEGER) AS INTEGER
    DIM curLine AS INTEGER
    DIM p AS INTEGER
    DIM textLen AS INTEGER
    DIM textPtr AS UBYTE PTR
    DIM chCode AS INTEGER

    textLen = LEN(s)
    IF lineNum <= 0 THEN RETURN 0
    IF textLen <= 0 THEN RETURN 0

    textPtr = CAST(UBYTE PTR, STRPTR(s))
    IF textPtr = 0 THEN RETURN 0

    curLine = 0
    p = 0
    DO WHILE p < textLen
        chCode = textPtr[p]
        IF chCode = 13 OR chCode = 10 THEN
            IF chCode = 13 THEN
                IF p + 1 < textLen THEN
                    IF textPtr[p + 1] = 10 THEN p = p + 1
                END IF
            END IF
            p = p + 1
            curLine = curLine + 1
            IF curLine >= lineNum THEN RETURN p
        ELSE
            p = p + 1
        END IF
    LOOP

    RETURN textLen
END FUNCTION

' Finds which line contains the current caret position in a multiline textbox.
FUNCTION TbCaretLine(BYREF s AS STRING, BYVAL caretPos AS INTEGER) AS INTEGER
    DIM lineNum AS INTEGER
    DIM p AS INTEGER
    DIM textLen AS INTEGER
    DIM textPtr AS UBYTE PTR
    DIM chCode AS INTEGER

    textLen = LEN(s)
    caretPos = Ed_ClampI(caretPos, 0, textLen)
    IF textLen <= 0 THEN RETURN 0

    textPtr = CAST(UBYTE PTR, STRPTR(s))
    IF textPtr = 0 THEN RETURN 0

    lineNum = 0
    p = 0
    DO WHILE p < textLen AND p < caretPos
        chCode = textPtr[p]
        IF chCode = 13 OR chCode = 10 THEN
            IF chCode = 13 THEN
                IF p + 1 < textLen AND p + 1 < caretPos THEN
                    IF textPtr[p + 1] = 10 THEN p = p + 1
                END IF
            END IF
            lineNum = lineNum + 1
        END IF
        p = p + 1
    LOOP

    RETURN lineNum
END FUNCTION

' Calculates the visible column for a caret position inside a line.
FUNCTION TbColumnAtPos(BYREF s AS STRING, BYVAL caretPos AS INTEGER) AS INTEGER
    DIM p AS INTEGER
    DIM lineStart AS INTEGER
    DIM textLen AS INTEGER
    DIM textPtr AS UBYTE PTR
    DIM chCode AS INTEGER

    textLen = LEN(s)
    caretPos = Ed_ClampI(caretPos, 0, textLen)
    IF textLen <= 0 THEN RETURN 0

    textPtr = CAST(UBYTE PTR, STRPTR(s))
    IF textPtr = 0 THEN RETURN caretPos

    p = 0
    lineStart = 0
    DO WHILE p < textLen AND p < caretPos
        chCode = textPtr[p]
        IF chCode = 13 OR chCode = 10 THEN
            IF chCode = 13 THEN
                IF p + 1 < textLen AND p + 1 < caretPos THEN
                    IF textPtr[p + 1] = 10 THEN p = p + 1
                END IF
            END IF
            lineStart = p + 1
        END IF
        p = p + 1
    LOOP

    IF caretPos < lineStart THEN RETURN 0
    RETURN caretPos - lineStart
END FUNCTION

' Converts a line number and column back into a character position in the text.
FUNCTION Ed_PosFromLineCol(BYREF s AS STRING, BYVAL lineNum AS INTEGER, BYVAL colNum AS INTEGER) AS INTEGER
    DIM p AS INTEGER
    DIM e AS INTEGER

    p = TbLineStartForLine(s, lineNum)
    e = TbLineEndPos(s, p)
    IF colNum < 0 THEN colNum = 0
    IF p + colNum > e THEN RETURN e
    RETURN p + colNum
END FUNCTION

' ---------------------------
' Mouse hit testing for caret placement and selection
' ---------------------------

' Converts a mouse click inside a textbox into the nearest text caret position.
FUNCTION Ed_MouseClickPos(BYREF s AS STRING, BYVAL curPos AS INTEGER, BYVAL cols AS INTEGER, BYVAL rows AS INTEGER, BYVAL multiline AS INTEGER, BYVAL px AS INTEGER, BYVAL py AS INTEGER) AS INTEGER
    DIM colNum AS INTEGER
    DIM rowNum AS INTEGER
    DIM caretLine AS INTEGER
    DIM firstLine AS INTEGER
    DIM targetLine AS INTEGER
    DIM textLen AS INTEGER

    textLen = LEN(s)
    IF cols < 1 THEN cols = 1
    IF rows < 1 THEN rows = 1

    colNum = px \ 8
    rowNum = py \ 8
    IF colNum < 0 THEN colNum = 0
    IF rowNum < 0 THEN rowNum = 0
    IF colNum > cols THEN colNum = cols
    IF rowNum >= rows THEN rowNum = rows - 1

    IF multiline = 0 THEN
        IF colNum > textLen THEN colNum = textLen
        RETURN colNum
    END IF

    caretLine = TbCaretLine(s, curPos)
    firstLine = caretLine - rows + 1
    IF firstLine < 0 THEN firstLine = 0

    targetLine = firstLine + rowNum
    RETURN Ed_PosFromLineCol(s, targetLine, colNum)
END FUNCTION

' Converts a mouse drag position into a text position for extending selection.
FUNCTION Ed_MouseDragPos(BYREF s AS STRING, BYVAL anchorPos AS INTEGER, BYVAL cols AS INTEGER, BYVAL rows AS INTEGER, BYVAL multiline AS INTEGER, BYVAL px AS INTEGER, BYVAL py AS INTEGER) AS INTEGER
    RETURN Ed_MouseClickPos(s, anchorPos, cols, rows, multiline, px, py)
END FUNCTION

' ---------------------------
' Word and line selection helpers
' ---------------------------

' Classifies character codes that count as part of a word for word selection and word movement.
FUNCTION Ed_IsWordCode(BYVAL c AS INTEGER) AS INTEGER
    IF c >= ASC("A") AND c <= ASC("Z") THEN RETURN -1
    IF c >= ASC("a") AND c <= ASC("z") THEN RETURN -1
    IF c >= ASC("0") AND c <= ASC("9") THEN RETURN -1
    IF c = ASC("_") THEN RETURN -1
    RETURN 0
END FUNCTION

' Checks whether a one-character string should be treated as part of a word.
FUNCTION Ed_IsWordChar(BYVAL ch AS STRING) AS INTEGER
    IF ch = "" THEN RETURN 0
    RETURN Ed_IsWordCode(ASC(ch))
END FUNCTION

' Expands the current caret position to select the whole word under the caret.
SUB Ed_SelectWordAt(BYREF ed AS EDSTATE)
    DIM p AS INTEGER
    DIM a AS INTEGER
    DIM b AS INTEGER

    Ed_Normalize ed
    IF ed.txtLen <= 0 THEN
        ed.curPos = 0
        Ed_SelClr ed
        EXIT SUB
    END IF

    p = ed.curPos
    IF p >= ed.txtLen THEN p = ed.txtLen - 1

    IF Ed_IsWordCode(Ed_CharCodeAt(ed.txt, p)) = 0 THEN
        IF p > 0 THEN
            IF Ed_IsWordCode(Ed_CharCodeAt(ed.txt, p - 1)) <> 0 THEN p = p - 1
        END IF
    END IF

    IF Ed_IsWordCode(Ed_CharCodeAt(ed.txt, p)) = 0 THEN
        ed.selA = p
        ed.selB = p + 1
        ed.curPos = ed.selB
        EXIT SUB
    END IF

    a = p
    DO WHILE a > 0
        IF Ed_IsWordCode(Ed_CharCodeAt(ed.txt, a - 1)) = 0 THEN EXIT DO
        a = a - 1
    LOOP

    b = p + 1
    DO WHILE b < ed.txtLen
        IF Ed_IsWordCode(Ed_CharCodeAt(ed.txt, b)) = 0 THEN EXIT DO
        b = b + 1
    LOOP

    ed.selA = a
    ed.selB = b
    ed.curPos = b
END SUB

' Expands the current caret position to select the entire line.
SUB Ed_SelectLineAt(BYREF ed AS EDSTATE)
    DIM lineNum AS INTEGER
    DIM a AS INTEGER
    DIM b AS INTEGER

    Ed_Normalize ed
    lineNum = TbCaretLine(ed.txt, ed.curPos)
    a = TbLineStartForLine(ed.txt, lineNum)
    b = TbLineEndPos(ed.txt, a)

    ed.selA = a
    ed.selB = b
    ed.curPos = b
END SUB

' ---------------------------
' Caret movement, undo restore, and clipboard key handling
' ---------------------------

' Moves the caret, optionally extending selection when Shift is held.
SUB Ed_MoveCaret(BYREF ed AS EDSTATE, BYVAL newPos AS INTEGER, BYVAL shiftDown AS INTEGER)
    DIM oldPos AS INTEGER
    DIM a AS INTEGER
    DIM b AS INTEGER

    Ed_Normalize ed
    oldPos = ed.curPos
    newPos = Ed_ClampI(newPos, 0, ed.txtLen)

    IF shiftDown <> 0 THEN
        IF ed.selA <> ed.selB THEN
            Ed_SelNorm ed, a, b
            IF oldPos = a THEN
                ed.selA = b
                ed.selB = newPos
            ELSE
                ed.selA = a
                ed.selB = newPos
            END IF
        ELSE
            ed.selA = oldPos
            ed.selB = newPos
        END IF
    ELSE
        ed.selA = newPos
        ed.selB = newPos
    END IF

    ed.curPos = newPos
    Ed_ResetUndoGroup ed
END SUB

' Restores the most recent saved text state and moves the undo stack back one step.
SUB Ed_RestoreUndo(BYREF ed AS EDSTATE)
    IF ed.undoCount <= 0 THEN EXIT SUB

    ed.txt = Ed_GetUndoTxt(ed, ed.undoCount)
    ed.txtLen = LEN(ed.txt)
    ed.curPos = Ed_ClampI(ed.undoCur(ed.undoCount), 0, ed.txtLen)
    ed.selA = Ed_ClampI(ed.undoSelA(ed.undoCount), 0, ed.txtLen)
    ed.selB = Ed_ClampI(ed.undoSelB(ed.undoCount), 0, ed.txtLen)

    Ed_SetUndoTxt ed, ed.undoCount, ""
    ed.undoCur(ed.undoCount) = 0
    ed.undoSelA(ed.undoCount) = 0
    ed.undoSelB(ed.undoCount) = 0
    ed.undoCount = ed.undoCount - 1
    ed.undoKind = ED_UNDO_NONE
END SUB

' Processes clipboard shortcuts such as copy, cut, paste, and select-all before normal key handling continues.
SUB Ed_ClipKey(BYREF ed AS EDSTATE, BYVAL keyIn AS STRING, BYVAL maxChars AS INTEGER, BYREF prefCol AS INTEGER, BYREF clipHandled AS INTEGER)
    DIM c AS INTEGER
    DIM a AS INTEGER
    DIM b AS INTEGER

    clipHandled = 0
    IF LEN(keyIn) <> 1 THEN EXIT SUB

    c = ASC(keyIn)

    SELECT CASE c
    CASE 1
        Ed_Normalize ed
        ed.selA = 0
        ed.selB = ed.txtLen
        ed.curPos = ed.txtLen
        Ed_ResetUndoGroup ed
        clipHandled = -1

    CASE 3
        IF Ed_SelHas(ed) <> 0 THEN
            Ed_SelNorm ed, a, b
            edClipText = MID$(ed.txt, a + 1, b - a)
        END IF
        Ed_ResetUndoGroup ed
        clipHandled = -1

    CASE 22
        IF edClipText <> "" THEN
            Ed_SaveUndo ed, ED_UNDO_EDIT
            Ed_InsertText ed, edClipText, maxChars
        END IF
        Ed_ResetUndoGroup ed
        clipHandled = -1

    CASE 24
        IF Ed_SelHas(ed) <> 0 THEN
            Ed_SelNorm ed, a, b
            edClipText = MID$(ed.txt, a + 1, b - a)
            Ed_SaveUndo ed, ED_UNDO_EDIT
            Ed_DeleteRange ed, a, b
        END IF
        Ed_ResetUndoGroup ed
        clipHandled = -1

    CASE 26
        Ed_RestoreUndo ed
        clipHandled = -1
    END SELECT
END SUB

' ---------------------------
' Keyboard editing path
' ---------------------------

' Routes textbox keyboard input for typing, deletion, caret movement, selection, clipboard shortcuts, and undo.
SUB Ed_KeyInputGlue(BYREF ed AS EDSTATE, BYVAL keyIn AS STRING, BYVAL multiline AS INTEGER, BYVAL maxChars AS INTEGER, BYREF prefCol AS INTEGER, BYVAL shiftDown AS INTEGER, BYVAL ctrlDown AS INTEGER)
    DIM c AS INTEGER
    DIM ext AS INTEGER
    DIM oldCol AS INTEGER
    DIM lineNum AS INTEGER
    DIM newPos AS INTEGER
    DIM a AS INTEGER
    DIM b AS INTEGER
    DIM ch AS STRING

    IF maxChars < 1 THEN maxChars = ED_MAX_TEXT
    IF maxChars > ED_MAX_TEXT THEN maxChars = ED_MAX_TEXT

    Ed_Normalize ed
    IF LEN(keyIn) = 0 THEN EXIT SUB

    IF LEN(keyIn) = 1 THEN
        c = ASC(keyIn)

        SELECT CASE c
        CASE 8
            Ed_SaveUndo ed, ED_UNDO_EDIT
            IF Ed_DeleteSelection(ed) = 0 THEN
                IF ed.curPos > 0 THEN Ed_DeleteRange ed, ed.curPos - 1, ed.curPos
            END IF
            Ed_ResetUndoGroup ed
            EXIT SUB

        CASE 127
            Ed_SaveUndo ed, ED_UNDO_EDIT
            IF Ed_DeleteSelection(ed) = 0 THEN
                IF ed.curPos < ed.txtLen THEN Ed_DeleteRange ed, ed.curPos, ed.curPos + 1
            END IF
            Ed_ResetUndoGroup ed
            EXIT SUB

        CASE 9
            IF multiline <> 0 THEN
                Ed_SaveUndo ed, ED_UNDO_TYPING
                Ed_InsertText ed, "    ", maxChars
            END IF
            EXIT SUB

        CASE 13
            IF multiline <> 0 THEN
                Ed_SaveUndo ed, ED_UNDO_EDIT
                Ed_InsertText ed, CHR$(13) + CHR$(10), maxChars
            END IF
            Ed_ResetUndoGroup ed
            EXIT SUB

        CASE 32 TO 255
            IF c >= 32 THEN
                ch = CHR$(c)
                Ed_SaveUndo ed, ED_UNDO_TYPING
                IF ed.insertMode <> 0 AND Ed_SelHas(ed) = 0 AND ed.curPos < ed.txtLen THEN
                    ed.txt = LEFT$(ed.txt, ed.curPos) + ch + MID$(ed.txt, ed.curPos + 2)
                    ed.curPos = ed.curPos + 1
                    ed.txtLen = LEN(ed.txt)
                    Ed_SelClr ed
                ELSE
                    Ed_InsertText ed, ch, maxChars
                END IF
                EXIT SUB
            END IF
        END SELECT

        EXIT SUB
    END IF

    IF LEN(keyIn) >= 2 THEN
        ext = ASC(RIGHT$(keyIn, 1))

        SELECT CASE ext
        CASE 14
            Ed_SaveUndo ed, ED_UNDO_EDIT
            IF Ed_DeleteSelection(ed) = 0 THEN
                IF ed.curPos > 0 THEN Ed_DeleteRange ed, ed.curPos - 1, ed.curPos
            END IF
            Ed_ResetUndoGroup ed

        CASE ASC("K")
            Ed_MoveCaret ed, ed.curPos - 1, shiftDown

        CASE ASC("M")
            Ed_MoveCaret ed, ed.curPos + 1, shiftDown

        CASE ASC("G")
            IF ctrlDown <> 0 THEN
                newPos = 0
            ELSEIF multiline <> 0 THEN
                lineNum = TbCaretLine(ed.txt, ed.curPos)
                newPos = TbLineStartForLine(ed.txt, lineNum)
            ELSE
                newPos = 0
            END IF
            Ed_MoveCaret ed, newPos, shiftDown

        CASE ASC("O")
            IF ctrlDown <> 0 THEN
                newPos = ed.txtLen
            ELSEIF multiline <> 0 THEN
                lineNum = TbCaretLine(ed.txt, ed.curPos)
                newPos = TbLineEndPos(ed.txt, TbLineStartForLine(ed.txt, lineNum))
            ELSE
                newPos = ed.txtLen
            END IF
            Ed_MoveCaret ed, newPos, shiftDown

        CASE 119
            Ed_MoveCaret ed, 0, shiftDown

        CASE 117
            Ed_MoveCaret ed, ed.txtLen, shiftDown

        CASE ASC("H")
            IF multiline <> 0 THEN
                oldCol = TbColumnAtPos(ed.txt, ed.curPos)
                IF prefCol >= 0 THEN oldCol = prefCol
                prefCol = oldCol
                lineNum = TbCaretLine(ed.txt, ed.curPos)
                IF lineNum > 0 THEN
                    newPos = Ed_PosFromLineCol(ed.txt, lineNum - 1, oldCol)
                    Ed_MoveCaret ed, newPos, shiftDown
                END IF
            END IF

        CASE ASC("P")
            IF multiline <> 0 THEN
                oldCol = TbColumnAtPos(ed.txt, ed.curPos)
                IF prefCol >= 0 THEN oldCol = prefCol
                prefCol = oldCol
                lineNum = TbCaretLine(ed.txt, ed.curPos)
                newPos = Ed_PosFromLineCol(ed.txt, lineNum + 1, oldCol)
                Ed_MoveCaret ed, newPos, shiftDown
            END IF

        CASE ASC("R")
            IF ed.insertMode = 0 THEN
                ed.insertMode = -1
            ELSE
                ed.insertMode = 0
            END IF
            Ed_ResetUndoGroup ed

        CASE ASC("S")
            Ed_SaveUndo ed, ED_UNDO_EDIT
            IF Ed_DeleteSelection(ed) = 0 THEN
                IF ed.curPos < ed.txtLen THEN Ed_DeleteRange ed, ed.curPos, ed.curPos + 1
            END IF
            Ed_ResetUndoGroup ed
        END SELECT
    END IF
END SUB

' embedded [EVENTS] support inside .APP files
' caches and pre-parses event blocks per open window
' keeps fallback behavior through HostAppAction

DIM SHARED rtAppFile(1 TO 12) AS STRING * 260
DIM SHARED rtEvCnt(1 TO 12) AS INTEGER
DIM SHARED rtEvLine(1 TO 12, 1 TO 256) AS STRING

' Pre-parsed event table.  Raw [EVENTS] rows are retained only for reload/clear safety.
' Dispatch uses these rows instead of trimming/uppercasing/scanning every script line per event.
DIM SHARED rtEvBlkCnt(1 TO 12) AS INTEGER
DIM SHARED rtEvBlkType(1 TO 12, 1 TO 256) AS INTEGER
DIM SHARED rtEvBlkCtl(1 TO 12, 1 TO 256) AS STRING
DIM SHARED rtEvBlkAct(1 TO 12, 1 TO 256) AS STRING
DIM SHARED rtEvBlkFirstCmd(1 TO 12, 1 TO 256) AS INTEGER
DIM SHARED rtEvBlkCmdCnt(1 TO 12, 1 TO 256) AS INTEGER
DIM SHARED rtEvBlkEnded(1 TO 12, 1 TO 256) AS INTEGER
DIM SHARED rtEvCmdCnt(1 TO 12) AS INTEGER
DIM SHARED rtEvCmdType(1 TO 12, 1 TO 256) AS INTEGER
DIM SHARED rtEvCmdArg(1 TO 12, 1 TO 256) AS STRING

CONST RT_EVT_INIT = 1
CONST RT_EVT_CLICK = 2
CONST RT_EVT_DBLCLICK = 3
CONST RT_EVT_CHANGE = 4
CONST RT_EVT_ACTION = 5

CONST RT_CMD_HOST = 1
CONST RT_CMD_PRINT = 2

' The layout parser already reads the full APP/SYS file.
' Keep its [EVENTS] rows here until the just-created window runtime is initialized.
DIM SHARED rtPendingEvCnt AS INTEGER
DIM SHARED rtPendingEvLine(1 TO 256) AS STRING

' ---------------------------
' APP runtime parsing helpers
' ---------------------------

' Trims a string and uppercases it for runtime event comparisons.
FUNCTION RtTrimUp(BYVAL s AS STRING) AS STRING
    RETURN UCASE$(LTRIM$(RTRIM$(s)))
END FUNCTION

' Checks whether one uppercase runtime string starts with a specific command prefix.
FUNCTION RtStarts(BYVAL s AS STRING, BYVAL pfx AS STRING) AS INTEGER
    IF LEN(s) < LEN(pfx) THEN RETURN 0
    IF LEFT$(s, LEN(pfx)) = pfx THEN RETURN -1
    RETURN 0
END FUNCTION

' Returns the text that follows a known runtime command prefix.
FUNCTION RtTail(BYVAL s AS STRING, BYVAL pfx AS STRING) AS STRING
    RETURN LTRIM$(MID$(s, LEN(pfx) + 1))
END FUNCTION

' Converts an event name such as ACTION or CHANGE into the runtime event type number.
FUNCTION RtEventTypeFromText(BYREF evUp AS STRING) AS INTEGER
    IF evUp = "INIT" THEN RETURN RT_EVT_INIT
    IF evUp = "CLICK" THEN RETURN RT_EVT_CLICK
    IF evUp = "DBLCLICK" THEN RETURN RT_EVT_DBLCLICK
    IF evUp = "CHANGE" THEN RETURN RT_EVT_CHANGE
    RETURN 0
END FUNCTION

' Parses an event block header and extracts the event type, control name, and action name.
FUNCTION RtParseEventHead(BYREF lineUp AS STRING, BYREF blkType AS INTEGER, BYREF blkCtl AS STRING, BYREF blkAct AS STRING) AS INTEGER
    blkType = 0
    blkCtl = ""
    blkAct = ""

    IF lineUp = "ON INIT" THEN
        blkType = RT_EVT_INIT
        RETURN -1
    END IF

    IF RtStarts(lineUp, "ON CLICK ") THEN
        blkType = RT_EVT_CLICK
        blkCtl = RtTail(lineUp, "ON CLICK ")
        RETURN -1
    END IF

    IF RtStarts(lineUp, "ON DBLCLICK ") THEN
        blkType = RT_EVT_DBLCLICK
        blkCtl = RtTail(lineUp, "ON DBLCLICK ")
        RETURN -1
    END IF

    IF RtStarts(lineUp, "ON CHANGE ") THEN
        blkType = RT_EVT_CHANGE
        blkCtl = RtTail(lineUp, "ON CHANGE ")
        RETURN -1
    END IF

    IF RtStarts(lineUp, "ON ACTION ") THEN
        blkType = RT_EVT_ACTION
        blkAct = RtTail(lineUp, "ON ACTION ")
        RETURN -1
    END IF

    RETURN 0
END FUNCTION

' Checks whether a compiled event block applies to the current window event.
FUNCTION RtEventBlockMatches(BYVAL winIdx AS INTEGER, BYVAL blkIdx AS INTEGER, BYVAL evTypeId AS INTEGER, BYREF ctlUp AS STRING, BYREF actUp AS STRING) AS INTEGER
    DIM blkType AS INTEGER

    blkType = rtEvBlkType(winIdx, blkIdx)

    IF blkType = RT_EVT_ACTION THEN
        IF actUp <> "" AND rtEvBlkAct(winIdx, blkIdx) = actUp THEN RETURN -1
        RETURN 0
    END IF

    IF blkType <> evTypeId THEN RETURN 0

    SELECT CASE blkType
    CASE RT_EVT_INIT
        RETURN -1
    CASE RT_EVT_CLICK, RT_EVT_DBLCLICK, RT_EVT_CHANGE
        IF rtEvBlkCtl(winIdx, blkIdx) = ctlUp THEN RETURN -1
    END SELECT

    RETURN 0
END FUNCTION

' Adds one parsed runtime command to the compiled event table for a window.
SUB RtAddCompiledCommand(BYVAL winIdx AS INTEGER, BYVAL blkIdx AS INTEGER, BYVAL cmdType AS INTEGER, BYVAL cmdArg AS STRING)
    DIM cmdIdx AS INTEGER

    IF rtEvCmdCnt(winIdx) >= 256 THEN EXIT SUB

    rtEvCmdCnt(winIdx) = rtEvCmdCnt(winIdx) + 1
    cmdIdx = rtEvCmdCnt(winIdx)

    rtEvCmdType(winIdx, cmdIdx) = cmdType
    rtEvCmdArg(winIdx, cmdIdx) = cmdArg

    IF rtEvBlkFirstCmd(winIdx, blkIdx) = 0 THEN rtEvBlkFirstCmd(winIdx, blkIdx) = cmdIdx
    rtEvBlkCmdCnt(winIdx, blkIdx) = rtEvBlkCmdCnt(winIdx, blkIdx) + 1
END SUB

' Clears all compiled runtime event commands for one window before reloading them.
SUB RtClearCompiledWinEvents(BYVAL winIdx AS INTEGER)
    DIM i AS INTEGER
    DIM clearBlocks AS INTEGER
    DIM clearCmds AS INTEGER

    IF winIdx < LBOUND(rtEvCnt) OR winIdx > UBOUND(rtEvCnt) THEN EXIT SUB

    clearBlocks = rtEvBlkCnt(winIdx)
    IF clearBlocks < 0 THEN clearBlocks = 0
    IF clearBlocks > 256 THEN clearBlocks = 256

    clearCmds = rtEvCmdCnt(winIdx)
    IF clearCmds < 0 THEN clearCmds = 0
    IF clearCmds > 256 THEN clearCmds = 256

    FOR i = 1 TO clearBlocks
        rtEvBlkType(winIdx, i) = 0
        rtEvBlkCtl(winIdx, i) = ""
        rtEvBlkAct(winIdx, i) = ""
        rtEvBlkFirstCmd(winIdx, i) = 0
        rtEvBlkCmdCnt(winIdx, i) = 0
        rtEvBlkEnded(winIdx, i) = 0
    NEXT i

    FOR i = 1 TO clearCmds
        rtEvCmdType(winIdx, i) = 0
        rtEvCmdArg(winIdx, i) = ""
    NEXT i

    rtEvBlkCnt(winIdx) = 0
    rtEvCmdCnt(winIdx) = 0
END SUB

' Parses pending event text into compiled event blocks so runtime events can run faster.
SUB RtCompileWinEvents(BYVAL winIdx AS INTEGER)
    DIM i AS INTEGER
    DIM lineIn AS STRING
    DIM lineUp AS STRING
    DIM blkIdx AS INTEGER
    DIM parsedType AS INTEGER
    DIM parsedCtl AS STRING
    DIM parsedAct AS STRING

    IF winIdx < LBOUND(rtEvCnt) OR winIdx > UBOUND(rtEvCnt) THEN EXIT SUB

    RtClearCompiledWinEvents winIdx

    blkIdx = 0

    FOR i = 1 TO rtEvCnt(winIdx)
        lineIn = LTRIM$(RTRIM$(rtEvLine(winIdx, i)))
        IF lineIn = "" OR LEFT$(lineIn, 1) = "#" OR LEFT$(lineIn, 1) = ";" THEN
        ELSE
            lineUp = UCASE$(lineIn)

            IF RtStarts(lineUp, "ON ") THEN
                IF rtEvBlkCnt(winIdx) < 256 THEN
                    IF RtParseEventHead(lineUp, parsedType, parsedCtl, parsedAct) <> 0 THEN
                        rtEvBlkCnt(winIdx) = rtEvBlkCnt(winIdx) + 1
                        blkIdx = rtEvBlkCnt(winIdx)
                        rtEvBlkType(winIdx, blkIdx) = parsedType
                        rtEvBlkCtl(winIdx, blkIdx) = parsedCtl
                        rtEvBlkAct(winIdx, blkIdx) = parsedAct
                        rtEvBlkFirstCmd(winIdx, blkIdx) = 0
                        rtEvBlkCmdCnt(winIdx, blkIdx) = 0
                        rtEvBlkEnded(winIdx, blkIdx) = 0
                    ELSE
                        blkIdx = 0
                    END IF
                ELSE
                    blkIdx = 0
                END IF
            ELSEIF lineUp = "END" THEN
                IF blkIdx > 0 THEN
                    rtEvBlkEnded(winIdx, blkIdx) = -1
                    blkIdx = 0
                END IF
            ELSEIF blkIdx > 0 THEN
                IF RtStarts(lineUp, "HOST ") THEN
                    RtAddCompiledCommand winIdx, blkIdx, RT_CMD_HOST, RtTail(lineIn, "HOST ")
                ELSEIF RtStarts(lineUp, "PRINT ") THEN
                    RtAddCompiledCommand winIdx, blkIdx, RT_CMD_PRINT, RtTail(lineIn, "PRINT ")
                END IF
            END IF
        END IF
    NEXT i
END SUB

' ---------------------------
' Per-window runtime event tables
' ---------------------------

' Clears the temporary event text collected while an app layout is being loaded.
SUB RtClearPendingAppEvents()
    DIM i AS INTEGER
    DIM clearCount AS INTEGER

    clearCount = rtPendingEvCnt
    IF clearCount < 0 THEN clearCount = 0
    IF clearCount > 256 THEN clearCount = 256

    FOR i = 1 TO clearCount
        rtPendingEvLine(i) = ""
    NEXT i
    rtPendingEvCnt = 0
END SUB

' Adds one app event line to the pending event buffer during layout loading.
SUB RtAppendPendingAppEventLine(BYVAL lineIn AS STRING)
    IF rtPendingEvCnt >= 256 THEN EXIT SUB
    rtPendingEvCnt = rtPendingEvCnt + 1
    rtPendingEvLine(rtPendingEvCnt) = lineIn
END SUB

' Clears runtime event state for one window slot.
SUB RtClearWin(BYVAL winIdx AS INTEGER)
    DIM i AS INTEGER
    DIM clearCount AS INTEGER

    IF winIdx < LBOUND(rtEvCnt) OR winIdx > UBOUND(rtEvCnt) THEN EXIT SUB

    RtClearCompiledWinEvents winIdx

    clearCount = rtEvCnt(winIdx)
    IF clearCount < 0 THEN clearCount = 0
    IF clearCount > 256 THEN clearCount = 256

    rtAppFile(winIdx) = ""
    rtEvCnt(winIdx) = 0
    FOR i = 1 TO clearCount
        rtEvLine(winIdx, i) = ""
    NEXT i
END SUB

' Compiles the pending event lines into the runtime event table for one loaded app window.
SUB RtLoadPendingEventsIntoWin(BYVAL winIdx AS INTEGER, BYVAL appFile AS STRING)
    DIM i AS INTEGER
    DIM copyCount AS INTEGER

    IF winIdx < LBOUND(rtEvCnt) OR winIdx > UBOUND(rtEvCnt) THEN EXIT SUB

    RtClearWin winIdx
    rtAppFile(winIdx) = appFile

    copyCount = rtPendingEvCnt
    IF copyCount < 0 THEN copyCount = 0
    IF copyCount > 256 THEN copyCount = 256

    rtEvCnt(winIdx) = copyCount
    FOR i = 1 TO copyCount
        rtEvLine(winIdx, i) = rtPendingEvLine(i)
    NEXT i

    RtCompileWinEvents winIdx
END SUB

' ---------------------------
' APP event loading
' ---------------------------

' Loads and compiles the runtime event section for an app file.
SUB RtLoadApp(BYVAL winIdx AS INTEGER, BYVAL appFile AS STRING)
    DIM f AS INTEGER
    DIM lineIn AS STRING
    DIM lineUp AS STRING
    DIM inEv AS INTEGER

    RtClearWin winIdx
    IF appFile = "" THEN EXIT SUB

    rtAppFile(winIdx) = appFile

    f = FREEFILE
    IF OPEN(appFile FOR INPUT AS #f) <> 0 THEN EXIT SUB

    inEv = 0
    DO WHILE NOT EOF(f)
        LINE INPUT #f, lineIn
        lineIn = RTRIM$(lineIn)
        lineUp = UCASE$(LTRIM$(RTRIM$(lineIn)))

        IF LEFT$(lineUp, 1) = "[" AND RIGHT$(lineUp, 1) = "]" THEN
            IF lineUp = "[EVENTS]" THEN
                inEv = -1
            ELSEIF inEv <> 0 THEN
                EXIT DO
            END IF
        ELSEIF inEv <> 0 THEN
            IF rtEvCnt(winIdx) < 256 THEN
                rtEvCnt(winIdx) = rtEvCnt(winIdx) + 1
                rtEvLine(winIdx, rtEvCnt(winIdx)) = lineIn
            END IF
        END IF
    LOOP

    CLOSE #f
    RtCompileWinEvents winIdx
END SUB

' ---------------------------
' APP event matching and host action dispatch
' ---------------------------

' Runs all compiled event commands that match the current window event.
FUNCTION RtRunWinEvent(BYVAL winIdx AS INTEGER, BYVAL evType AS STRING, BYVAL ctlName AS STRING, BYVAL valTxt AS STRING, BYVAL actTxt AS STRING) AS INTEGER
    DIM i AS INTEGER
    DIM c AS INTEGER
    DIM cmdIdx AS INTEGER
    DIM firstCmd AS INTEGER
    DIM evTypeId AS INTEGER
    DIM evUp AS STRING
    DIM ctlUp AS STRING
    DIM actUp AS STRING

    IF winIdx < LBOUND(rtEvCnt) OR winIdx > UBOUND(rtEvCnt) THEN RETURN 0
    IF rtEvBlkCnt(winIdx) <= 0 THEN RETURN 0

    evUp = RtTrimUp(evType)
    ctlUp = RtTrimUp(ctlName)
    actUp = RtTrimUp(actTxt)
    evTypeId = RtEventTypeFromText(evUp)

    FOR i = 1 TO rtEvBlkCnt(winIdx)
        IF RtEventBlockMatches(winIdx, i, evTypeId, ctlUp, actUp) <> 0 THEN
            firstCmd = rtEvBlkFirstCmd(winIdx, i)
            IF firstCmd > 0 THEN
                FOR c = 0 TO rtEvBlkCmdCnt(winIdx, i) - 1
                    cmdIdx = firstCmd + c
                    SELECT CASE rtEvCmdType(winIdx, cmdIdx)
                    CASE RT_CMD_HOST
                        HostAppAction winIdx, rtEvCmdArg(winIdx, cmdIdx)
                    CASE RT_CMD_PRINT
                        PRINT rtEvCmdArg(winIdx, cmdIdx)
                    END SELECT
                NEXT c
            END IF

            IF rtEvBlkEnded(winIdx, i) <> 0 THEN RETURN -1
            RETURN 0
        END IF
    NEXT i

    RETURN 0
END FUNCTION

' ---------------------------
' Runtime entry points used by the shell
' ---------------------------

' Initializes runtime event storage for an app window.
SUB AppRuntime_Init(BYVAL winIdx AS INTEGER, BYVAL appFile AS STRING)
    RtLoadApp winIdx, LTRIM$(RTRIM$(appFile))
    RtRunWinEvent winIdx, "INIT", "", "", ""
END SUB

' Initializes runtime event storage after the app loader has already collected event lines.
SUB AppRuntime_InitLoadedEvents(BYVAL winIdx AS INTEGER, BYVAL appFile AS STRING)
    ' The shell parser already copied [EVENTS] rows out of this APP/SYS file.
    ' Load those rows directly instead of reopening and rescanning the same file.
    RtLoadPendingEventsIntoWin winIdx, LTRIM$(RTRIM$(appFile))
    RtClearPendingAppEvents
    RtRunWinEvent winIdx, "INIT", "", "", ""
END SUB

' Entry point used by the shell to run runtime events for one app window.
SUB AppRuntime_HandleEvent(BYVAL winIdx AS INTEGER, BYVAL evType AS STRING, BYVAL ctlName AS STRING, BYVAL valTxt AS STRING, BYVAL actTxt AS STRING)
    IF RtRunWinEvent(winIdx, evType, ctlName, valTxt, actTxt) = 0 THEN
        IF RtTrimUp(evType) <> "DBLCLICK" THEN
            HostAppAction winIdx, actTxt
        END IF
    END IF
END SUB
