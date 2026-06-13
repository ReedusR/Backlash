' RUNHELP.BAS
' Backlash RUN helper
' Compile: FBC -lang fb RUNHELP.BAS

DECLARE FUNCTION StripOuterQuotes(BYVAL s AS STRING) AS STRING
DECLARE FUNCTION ReadCfgValue(BYVAL fileName AS STRING, BYVAL keyName AS STRING, BYVAL defaultValue AS STRING) AS STRING

' ---------------------------
' Command text cleanup
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

' ---------------------------
' RUN helper config loading
' ---------------------------

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

DIM cmdText AS STRING

cmdText = ReadCfgValue("SYSTEM\RUN.CFG", "COMMAND", "")
IF cmdText = "" THEN cmdText = ReadCfgValue("\SYSTEM\RUN.CFG", "COMMAND", "")
IF cmdText = "" THEN cmdText = ReadCfgValue("..\..\SYSTEM\RUN.CFG", "COMMAND", "")

cmdText = TRIM$(cmdText)
IF cmdText <> "" THEN
    SHELL cmdText
END IF

END 0
