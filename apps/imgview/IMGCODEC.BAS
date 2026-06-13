' Image Viewer helper source. It prepares image files, slideshow output, or decoded bitmap data for the Image Viewer app.
'
' IMGCODEC.BAS
' External Backlash Image Viewer converter.
' Converts image files to BMP outside BACKLASH.BAS.
' Supports BMP passthrough, GIF87a/GIF89a first frame, and baseline JPEG.

#lang "fb"

CONST TRUE_VALUE AS INTEGER = -1
CONST FALSE_VALUE AS INTEGER = 0

TYPE JPG_BITSTREAM
    bytes AS UBYTE PTR
    size AS LONG
    byteIndex AS LONG
    bitBuffer AS UINTEGER
    bitCount AS INTEGER
END TYPE


DIM SHARED jpgZigZag(0 TO 63) AS INTEGER
DIM SHARED jpgCosTable(0 TO 7, 0 TO 7) AS DOUBLE
DIM SHARED jpgCScale(0 TO 7) AS DOUBLE
DIM SHARED jpgTablesReady AS INTEGER
DIM SHARED jpgQuant(0 TO 3, 0 TO 63) AS INTEGER
DIM SHARED jpgQuantValid(0 TO 3) AS INTEGER
DIM SHARED jpgHuffCount(0 TO 1, 0 TO 3) AS INTEGER
DIM SHARED jpgHuffCode(0 TO 1, 0 TO 3, 0 TO 255) AS INTEGER
DIM SHARED jpgHuffSize(0 TO 1, 0 TO 3, 0 TO 255) AS INTEGER
DIM SHARED jpgHuffSymbol(0 TO 1, 0 TO 3, 0 TO 255) AS INTEGER
DIM SHARED jpgHuffMinCode(0 TO 1, 0 TO 3, 1 TO 16) AS INTEGER
DIM SHARED jpgHuffMaxCode(0 TO 1, 0 TO 3, 1 TO 16) AS INTEGER
DIM SHARED jpgHuffValIndex(0 TO 1, 0 TO 3, 1 TO 16) AS INTEGER
DIM SHARED jpgWidth AS INTEGER
DIM SHARED jpgHeight AS INTEGER
DIM SHARED jpgCompCount AS INTEGER
DIM SHARED jpgCompId(0 TO 3) AS INTEGER
DIM SHARED jpgCompH(0 TO 3) AS INTEGER
DIM SHARED jpgCompV(0 TO 3) AS INTEGER
DIM SHARED jpgCompQ(0 TO 3) AS INTEGER
DIM SHARED jpgCompDc(0 TO 3) AS INTEGER
DIM SHARED jpgCompAc(0 TO 3) AS INTEGER
DIM SHARED jpgCompPrevDc(0 TO 3) AS INTEGER
DIM SHARED jpgScanCompCount AS INTEGER
DIM SHARED jpgScanCompIndex(0 TO 3) AS INTEGER
DIM SHARED jpgRestartInterval AS INTEGER

' ---------------------------
' File names, extensions, and basic binary file helpers
' ---------------------------

FUNCTION UpperText(BYVAL s AS STRING) AS STRING
    DIM i AS INTEGER
    DIM c AS INTEGER
    DIM t AS STRING

    t = s
    FOR i = 1 TO LEN(t)
        c = ASC(MID$(t, i, 1))
        IF c >= ASC("a") AND c <= ASC("z") THEN
            MID$(t, i, 1) = CHR$(c - 32)
        END IF
    NEXT
    RETURN t
END FUNCTION

FUNCTION FileExtUpper(BYVAL fileName AS STRING) AS STRING
    DIM i AS INTEGER
    DIM ch AS STRING

    FOR i = LEN(fileName) TO 1 STEP -1
        ch = MID$(fileName, i, 1)
        IF ch = "." THEN RETURN UpperText(MID$(fileName, i + 1))
        IF ch = CHR$(92) OR ch = ":" THEN EXIT FOR
    NEXT
    RETURN ""
END FUNCTION

FUNCTION CopyBinaryFile(BYVAL inputFile AS STRING, BYVAL outputFile AS STRING) AS INTEGER
    CONST COPY_BLOCK_SIZE AS LONG = 8192

    DIM inNum AS INTEGER
    DIM outNum AS INTEGER
    DIM fileLen AS LONG
    DIM copiedBytes AS LONG
    DIM bytesLeft AS LONG
    DIM bytesThisPass AS LONG
    DIM blockData AS STRING

    inNum = FREEFILE
    IF OPEN(inputFile FOR BINARY ACCESS READ AS #inNum) <> 0 THEN RETURN FALSE_VALUE

    IF DIR(outputFile) <> "" THEN KILL outputFile

    outNum = FREEFILE
    IF OPEN(outputFile FOR BINARY ACCESS WRITE AS #outNum) <> 0 THEN
        CLOSE #inNum
        RETURN FALSE_VALUE
    END IF

    fileLen = LOF(inNum)
    copiedBytes = 0

    DO WHILE copiedBytes < fileLen
        bytesLeft = fileLen - copiedBytes
        IF bytesLeft > COPY_BLOCK_SIZE THEN
            bytesThisPass = COPY_BLOCK_SIZE
        ELSE
            bytesThisPass = bytesLeft
        END IF

        blockData = SPACE$(bytesThisPass)
        GET #inNum, copiedBytes + 1, blockData
        PUT #outNum, copiedBytes + 1, blockData
        copiedBytes = copiedBytes + bytesThisPass
    LOOP

    CLOSE #outNum
    CLOSE #inNum
    RETURN TRUE_VALUE
END FUNCTION

' ---------------------------
' Low-level binary reads and GIF sub-block reads
' ---------------------------

FUNCTION ReadByte(BYVAL f AS INTEGER, BYREF b AS UBYTE) AS INTEGER
    IF EOF(f) THEN RETURN FALSE_VALUE
    GET #f, , b
    RETURN TRUE_VALUE
END FUNCTION

FUNCTION ReadUShort(BYVAL f AS INTEGER, BYREF v AS USHORT) AS INTEGER
    IF EOF(f) THEN RETURN FALSE_VALUE
    GET #f, , v
    RETURN TRUE_VALUE
END FUNCTION

FUNCTION ReadUShortBE(BYVAL f AS INTEGER, BYREF v AS USHORT) AS INTEGER
    DIM hi AS UBYTE
    DIM lo AS UBYTE

    IF ReadByte(f, hi) = FALSE_VALUE THEN RETURN FALSE_VALUE
    IF ReadByte(f, lo) = FALSE_VALUE THEN RETURN FALSE_VALUE
    v = (CUINT(hi) SHL 8) OR CUINT(lo)
    RETURN TRUE_VALUE
END FUNCTION

FUNCTION SkipSubBlocks(BYVAL f AS INTEGER) AS INTEGER
    DIM blockSize AS UBYTE
    DIM blockText AS STRING

    DO
        IF ReadByte(f, blockSize) = FALSE_VALUE THEN RETURN FALSE_VALUE
        IF blockSize = 0 THEN EXIT DO
        blockText = SPACE$(blockSize)
        IF EOF(f) THEN RETURN FALSE_VALUE
        GET #f, , blockText
    LOOP

    RETURN TRUE_VALUE
END FUNCTION

FUNCTION ReadSubBlocks(BYVAL f AS INTEGER, BYREF blockData AS UBYTE PTR, BYREF blockSizeTotal AS LONG) AS INTEGER
    DIM blockSize AS UBYTE
    DIM i AS INTEGER
    DIM newPtr AS UBYTE PTR
    DIM blockText AS STRING

    blockData = 0
    blockSizeTotal = 0

    DO
        IF ReadByte(f, blockSize) = FALSE_VALUE THEN RETURN FALSE_VALUE
        IF blockSize = 0 THEN EXIT DO

        blockText = SPACE$(blockSize)
        IF EOF(f) THEN
            IF blockData <> 0 THEN DEALLOCATE blockData
            blockData = 0
            blockSizeTotal = 0
            RETURN FALSE_VALUE
        END IF
        GET #f, , blockText

        newPtr = REALLOCATE(blockData, blockSizeTotal + blockSize)
        IF newPtr = 0 THEN
            IF blockData <> 0 THEN DEALLOCATE blockData
            blockData = 0
            blockSizeTotal = 0
            RETURN FALSE_VALUE
        END IF
        blockData = newPtr

        FOR i = 0 TO blockSize - 1
            blockData[blockSizeTotal + i] = ASC(MID$(blockText, i + 1, 1))
        NEXT
        blockSizeTotal = blockSizeTotal + blockSize
    LOOP

    RETURN TRUE_VALUE
END FUNCTION

' ---------------------------
' BMP output and BMP-to-24-bit conversion
' ---------------------------

FUNCTION WriteBmp24(BYVAL fileName AS STRING, BYVAL pix AS UINTEGER PTR, BYVAL w AS INTEGER, BYVAL h AS INTEGER) AS INTEGER
    DIM f AS INTEGER
    DIM sig AS USHORT
    DIM fileSize AS UINTEGER
    DIM reserved1 AS USHORT
    DIM reserved2 AS USHORT
    DIM dataOffset AS UINTEGER
    DIM infoSize AS UINTEGER
    DIM planes AS USHORT
    DIM bitCount AS USHORT
    DIM compression AS UINTEGER
    DIM imageSize AS UINTEGER
    DIM xppm AS INTEGER
    DIM yppm AS INTEGER
    DIM clrUsed AS UINTEGER
    DIM clrImportant AS UINTEGER
    DIM rowSize AS INTEGER
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM p AS UINTEGER
    DIM rowData AS STRING
    DIM rowPtr AS UBYTE PTR
    DIM rowOfs AS INTEGER
    DIM bmpW AS INTEGER
    DIM bmpH AS INTEGER

    IF pix = 0 OR w <= 0 OR h <= 0 THEN RETURN FALSE_VALUE

    rowSize = ((w * 3 + 3) \ 4) * 4
    imageSize = rowSize * h
    fileSize = 14 + 40 + imageSize

    sig = &H4D42
    reserved1 = 0
    reserved2 = 0
    dataOffset = 54
    infoSize = 40
    bmpW = w
    bmpH = h
    planes = 1
    bitCount = 24
    compression = 0
    xppm = 2835
    yppm = 2835
    clrUsed = 0
    clrImportant = 0

    IF DIR(fileName) <> "" THEN KILL fileName

    f = FREEFILE
    IF OPEN(fileName FOR BINARY ACCESS WRITE AS #f) <> 0 THEN RETURN FALSE_VALUE

    PUT #f, , sig
    PUT #f, , fileSize
    PUT #f, , reserved1
    PUT #f, , reserved2
    PUT #f, , dataOffset
    PUT #f, , infoSize
    PUT #f, , bmpW
    PUT #f, , bmpH
    PUT #f, , planes
    PUT #f, , bitCount
    PUT #f, , compression
    PUT #f, , imageSize
    PUT #f, , xppm
    PUT #f, , yppm
    PUT #f, , clrUsed
    PUT #f, , clrImportant

    rowData = SPACE$(rowSize)
    rowPtr = CAST(UBYTE PTR, STRPTR(rowData))

    FOR y = h - 1 TO 0 STEP -1
        FOR x = 0 TO w - 1
            p = pix[CLNG(y) * w + x]
            rowOfs = x * 3
            rowPtr[rowOfs] = p AND 255
            rowPtr[rowOfs + 1] = (p SHR 8) AND 255
            rowPtr[rowOfs + 2] = (p SHR 16) AND 255
        NEXT
        PUT #f, , rowData
    NEXT

    CLOSE #f
    RETURN TRUE_VALUE
END FUNCTION

FUNCTION BmpCodecMaskShift(BYVAL maskValue AS UINTEGER) AS INTEGER
    DIM shiftCount AS INTEGER

    shiftCount = 0
    IF maskValue = 0 THEN RETURN 0
    DO WHILE (maskValue AND 1) = 0
        maskValue = maskValue SHR 1
        shiftCount = shiftCount + 1
    LOOP
    RETURN shiftCount
END FUNCTION

FUNCTION BmpCodecMaskBits(BYVAL maskValue AS UINTEGER) AS INTEGER
    DIM bitCount AS INTEGER

    bitCount = 0
    IF maskValue = 0 THEN RETURN 0
    DO WHILE (maskValue AND 1) = 0
        maskValue = maskValue SHR 1
    LOOP
    DO WHILE (maskValue AND 1) <> 0
        bitCount = bitCount + 1
        maskValue = maskValue SHR 1
    LOOP
    RETURN bitCount
END FUNCTION

FUNCTION BmpCodecExpandMask(BYVAL pixelValue AS UINTEGER, BYVAL maskValue AS UINTEGER) AS INTEGER
    DIM shiftCount AS INTEGER
    DIM bitCount AS INTEGER
    DIM rawValue AS UINTEGER
    DIM maxValue AS UINTEGER

    IF maskValue = 0 THEN RETURN 0
    shiftCount = BmpCodecMaskShift(maskValue)
    bitCount = BmpCodecMaskBits(maskValue)
    IF bitCount <= 0 THEN RETURN 0

    rawValue = (pixelValue AND maskValue) SHR shiftCount
    maxValue = (CUINT(1) SHL bitCount) - 1
    IF maxValue = 0 THEN RETURN 0

    RETURN CINT((rawValue * 255 + (maxValue \ 2)) \ maxValue)
END FUNCTION

FUNCTION ConvertBmpToBmp24(BYVAL inputFile AS STRING, BYVAL outputFile AS STRING) AS INTEGER
    DIM f AS INTEGER
    DIM sig AS USHORT
    DIM fileSize AS UINTEGER
    DIM reserved1 AS USHORT
    DIM reserved2 AS USHORT
    DIM dataOffset AS UINTEGER
    DIM infoSize AS UINTEGER
    DIM bmpW AS INTEGER
    DIM bmpH AS INTEGER
    DIM planes AS USHORT
    DIM bitCount AS USHORT
    DIM compression AS UINTEGER
    DIM sizeImage AS UINTEGER
    DIM xppm AS INTEGER
    DIM yppm AS INTEGER
    DIM clrUsed AS UINTEGER
    DIM clrImportant AS UINTEGER
    DIM coreW AS USHORT
    DIM coreH AS USHORT
    DIM corePlanes AS USHORT
    DIM coreBitCount AS USHORT
    DIM isCoreBmp AS INTEGER
    DIM palCount AS INTEGER
    DIM palIdx AS INTEGER
    DIM palR(0 TO 255) AS INTEGER
    DIM palG(0 TO 255) AS INTEGER
    DIM palB(0 TO 255) AS INTEGER
    DIM ub AS UBYTE
    DIM ug AS UBYTE
    DIM ur AS UBYTE
    DIM ua AS UBYTE
    DIM srcW AS INTEGER
    DIM srcH AS INTEGER
    DIM rowSize AS INTEGER
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM srcY AS INTEGER
    DIM idx AS LONG
    DIM rowData AS STRING
    DIM rowPtr AS UBYTE PTR
    DIM rowOfs AS INTEGER
    DIM pix AS UINTEGER PTR
    DIM palColor AS INTEGER
    DIM bitIdx AS INTEGER
    DIM nibble AS INTEGER
    DIM c16 AS USHORT
    DIM c32 AS UINTEGER
    DIM redMask AS UINTEGER
    DIM greenMask AS UINTEGER
    DIM blueMask AS UINTEGER
    DIM ok AS INTEGER

    f = FREEFILE
    IF OPEN(inputFile FOR BINARY ACCESS READ AS #f) <> 0 THEN RETURN FALSE_VALUE
    IF LOF(f) < 26 THEN
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    GET #f, , sig
    GET #f, , fileSize
    GET #f, , reserved1
    GET #f, , reserved2
    GET #f, , dataOffset

    IF sig <> &H4D42 THEN
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    GET #f, , infoSize
    isCoreBmp = FALSE_VALUE
    compression = 0
    sizeImage = 0
    xppm = 0
    yppm = 0
    clrUsed = 0
    clrImportant = 0

    IF infoSize = 12 THEN
        GET #f, , coreW
        GET #f, , coreH
        GET #f, , corePlanes
        GET #f, , coreBitCount
        bmpW = coreW
        bmpH = coreH
        planes = corePlanes
        bitCount = coreBitCount
        isCoreBmp = TRUE_VALUE
    ELSEIF infoSize >= 40 THEN
        GET #f, , bmpW
        GET #f, , bmpH
        GET #f, , planes
        GET #f, , bitCount
        GET #f, , compression
        GET #f, , sizeImage
        GET #f, , xppm
        GET #f, , yppm
        GET #f, , clrUsed
        GET #f, , clrImportant
    ELSE
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    IF planes <> 1 THEN
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    IF bitCount <> 1 AND bitCount <> 4 AND bitCount <> 8 AND bitCount <> 16 AND bitCount <> 24 AND bitCount <> 32 THEN
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    IF bitCount = 16 OR bitCount = 32 THEN
        IF compression <> 0 AND compression <> 3 THEN
            CLOSE #f
            RETURN FALSE_VALUE
        END IF
    ELSE
        IF compression <> 0 THEN
            CLOSE #f
            RETURN FALSE_VALUE
        END IF
    END IF

    IF bmpW <= 0 OR bmpH = 0 THEN
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    srcW = bmpW
    IF bmpH < 0 THEN
        srcH = -bmpH
    ELSE
        srcH = bmpH
    END IF

    redMask = 0
    greenMask = 0
    blueMask = 0
    IF (bitCount = 16 OR bitCount = 32) AND compression = 3 THEN
        GET #f, , redMask
        GET #f, , greenMask
        GET #f, , blueMask
    ELSEIF bitCount = 16 THEN
        redMask = &H7C00
        greenMask = &H03E0
        blueMask = &H001F
    ELSEIF bitCount = 32 THEN
        redMask = &H00FF0000
        greenMask = &H0000FF00
        blueMask = &H000000FF
    END IF

    IF bitCount = 1 OR bitCount = 4 OR bitCount = 8 THEN
        IF bitCount = 1 THEN
            IF clrUsed > 0 AND clrUsed <= 2 THEN
                palCount = CINT(clrUsed)
            ELSE
                palCount = 2
            END IF
        ELSEIF bitCount = 4 THEN
            IF clrUsed > 0 AND clrUsed <= 16 THEN
                palCount = CINT(clrUsed)
            ELSE
                palCount = 16
            END IF
        ELSE
            IF clrUsed > 0 AND clrUsed <= 256 THEN
                palCount = CINT(clrUsed)
            ELSE
                palCount = 256
            END IF
        END IF

        SEEK #f, CLNG(14) + CLNG(infoSize) + 1
        FOR palIdx = 0 TO palCount - 1
            GET #f, , ub
            GET #f, , ug
            GET #f, , ur
            IF isCoreBmp = FALSE_VALUE THEN GET #f, , ua
            palB(palIdx) = ub
            palG(palIdx) = ug
            palR(palIdx) = ur
        NEXT
    END IF

    SELECT CASE bitCount
    CASE 1
        rowSize = ((srcW + 31) \ 32) * 4
    CASE 4
        rowSize = ((srcW * 4 + 31) \ 32) * 4
    CASE 8
        rowSize = ((srcW * 8 + 31) \ 32) * 4
    CASE ELSE
        rowSize = ((srcW * (bitCount \ 8) + 3) \ 4) * 4
    END SELECT

    pix = CALLocate(srcW * srcH, SIZEOF(UINTEGER))
    IF pix = 0 THEN
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    rowData = SPACE$(rowSize)

    FOR y = 0 TO srcH - 1
        IF bmpH > 0 THEN
            srcY = srcH - 1 - y
        ELSE
            srcY = y
        END IF

        SEEK #f, CLNG(dataOffset) + CLNG(srcY) * rowSize + 1
        GET #f, , rowData
        rowPtr = CAST(UBYTE PTR, STRPTR(rowData))

        FOR x = 0 TO srcW - 1
            idx = CLNG(y) * srcW + x
            SELECT CASE bitCount
            CASE 1
                rowOfs = x \ 8
                bitIdx = 7 - (x AND 7)
                palColor = (rowPtr[rowOfs] SHR bitIdx) AND 1
                pix[idx] = (CUINT(palR(palColor)) SHL 16) OR (CUINT(palG(palColor)) SHL 8) OR CUINT(palB(palColor))

            CASE 4
                rowOfs = x \ 2
                IF (x AND 1) = 0 THEN
                    nibble = (rowPtr[rowOfs] SHR 4) AND 15
                ELSE
                    nibble = rowPtr[rowOfs] AND 15
                END IF
                pix[idx] = (CUINT(palR(nibble)) SHL 16) OR (CUINT(palG(nibble)) SHL 8) OR CUINT(palB(nibble))

            CASE 8
                palColor = rowPtr[x]
                pix[idx] = (CUINT(palR(palColor)) SHL 16) OR (CUINT(palG(palColor)) SHL 8) OR CUINT(palB(palColor))

            CASE 16
                rowOfs = x * 2
                c16 = CAST(USHORT, rowPtr[rowOfs]) OR (CAST(USHORT, rowPtr[rowOfs + 1]) SHL 8)
                c32 = c16
                pix[idx] = (CUINT(BmpCodecExpandMask(c32, redMask)) SHL 16) OR _
                           (CUINT(BmpCodecExpandMask(c32, greenMask)) SHL 8) OR _
                           CUINT(BmpCodecExpandMask(c32, blueMask))

            CASE 24
                rowOfs = x * 3
                pix[idx] = (CUINT(rowPtr[rowOfs + 2]) SHL 16) OR _
                           (CUINT(rowPtr[rowOfs + 1]) SHL 8) OR _
                           CUINT(rowPtr[rowOfs])

            CASE 32
                rowOfs = x * 4
                IF compression = 3 THEN
                    c32 = CUINT(rowPtr[rowOfs]) OR _
                          (CUINT(rowPtr[rowOfs + 1]) SHL 8) OR _
                          (CUINT(rowPtr[rowOfs + 2]) SHL 16) OR _
                          (CUINT(rowPtr[rowOfs + 3]) SHL 24)
                    pix[idx] = (CUINT(BmpCodecExpandMask(c32, redMask)) SHL 16) OR _
                               (CUINT(BmpCodecExpandMask(c32, greenMask)) SHL 8) OR _
                               CUINT(BmpCodecExpandMask(c32, blueMask))
                ELSE
                    pix[idx] = (CUINT(rowPtr[rowOfs + 2]) SHL 16) OR _
                               (CUINT(rowPtr[rowOfs + 1]) SHL 8) OR _
                               CUINT(rowPtr[rowOfs])
                END IF
            END SELECT
        NEXT
    NEXT

    CLOSE #f

    ok = WriteBmp24(outputFile, pix, srcW, srcH)
    DEALLOCATE pix
    RETURN ok
END FUNCTION

' ---------------------------
' Buffered BMP output used by the decoders
' ---------------------------

FUNCTION BeginBmp24Write( _
    BYVAL fileName AS STRING, _
    BYVAL w AS INTEGER, _
    BYVAL h AS INTEGER, _
    BYREF f AS INTEGER, _
    BYREF rowSize AS LONG) AS INTEGER
    DIM sig AS USHORT
    DIM fileSize AS UINTEGER
    DIM reserved1 AS USHORT
    DIM reserved2 AS USHORT
    DIM dataOffset AS UINTEGER
    DIM infoSize AS UINTEGER
    DIM planes AS USHORT
    DIM bitCount AS USHORT
    DIM compression AS UINTEGER
    DIM imageSize AS UINTEGER
    DIM xppm AS INTEGER
    DIM yppm AS INTEGER
    DIM clrUsed AS UINTEGER
    DIM clrImportant AS UINTEGER
    DIM bmpW AS INTEGER
    DIM bmpH AS INTEGER

    IF w <= 0 OR h <= 0 THEN RETURN FALSE_VALUE

    rowSize = ((CLNG(w) * 3 + 3) \ 4) * 4
    imageSize = CUINT(rowSize * h)
    fileSize = 14 + 40 + imageSize

    sig = &H4D42
    reserved1 = 0
    reserved2 = 0
    dataOffset = 54
    infoSize = 40
    bmpW = w
    bmpH = h
    planes = 1
    bitCount = 24
    compression = 0
    xppm = 2835
    yppm = 2835
    clrUsed = 0
    clrImportant = 0

    IF DIR(fileName) <> "" THEN KILL fileName

    f = FREEFILE
    IF OPEN(fileName FOR BINARY ACCESS WRITE AS #f) <> 0 THEN RETURN FALSE_VALUE

    PUT #f, , sig
    PUT #f, , fileSize
    PUT #f, , reserved1
    PUT #f, , reserved2
    PUT #f, , dataOffset
    PUT #f, , infoSize
    PUT #f, , bmpW
    PUT #f, , bmpH
    PUT #f, , planes
    PUT #f, , bitCount
    PUT #f, , compression
    PUT #f, , imageSize
    PUT #f, , xppm
    PUT #f, , yppm
    PUT #f, , clrUsed
    PUT #f, , clrImportant

    RETURN TRUE_VALUE
END FUNCTION

SUB ClearByteBuffer(BYVAL buf AS UBYTE PTR, BYVAL byteCount AS LONG)
    DIM i AS LONG

    IF buf = 0 THEN EXIT SUB
    IF byteCount <= 0 THEN EXIT SUB

    FOR i = 0 TO byteCount - 1
        buf[i] = 0
    NEXT
END SUB

SUB PutBandPixel( _
    BYVAL band AS UBYTE PTR, _
    BYVAL rowSize AS LONG, _
    BYVAL localY AS INTEGER, _
    BYVAL x AS INTEGER, _
    BYVAL rgbVal AS UINTEGER)
    DIM bandPos AS LONG

    IF band = 0 THEN EXIT SUB
    IF rowSize <= 0 THEN EXIT SUB
    IF localY < 0 OR x < 0 THEN EXIT SUB

    bandPos = CLNG(localY) * rowSize + CLNG(x) * 3
    band[bandPos] = rgbVal AND 255
    band[bandPos + 1] = (rgbVal SHR 8) AND 255
    band[bandPos + 2] = (rgbVal SHR 16) AND 255
END SUB

FUNCTION WriteBmpBand( _
    BYVAL f AS INTEGER, _
    BYVAL band AS UBYTE PTR, _
    BYVAL rowSize AS LONG, _
    BYVAL bandRows AS INTEGER, _
    BYVAL startY AS INTEGER, _
    BYVAL imageH AS INTEGER) AS INTEGER
    DIM py AS INTEGER
    DIM outY AS INTEGER
    DIM j AS INTEGER
    DIM filePos AS LONG
    DIM rowBase AS LONG
    DIM rowData AS STRING

    IF f <= 0 THEN RETURN FALSE_VALUE
    IF band = 0 THEN RETURN FALSE_VALUE
    IF rowSize <= 0 THEN RETURN FALSE_VALUE
    IF rowSize > 32760 THEN RETURN FALSE_VALUE
    IF bandRows <= 0 THEN RETURN FALSE_VALUE

    rowData = SPACE$(rowSize)

    FOR py = 0 TO bandRows - 1
        outY = startY + py
        IF outY >= 0 AND outY < imageH THEN
            rowBase = CLNG(py) * rowSize
            FOR j = 0 TO CINT(rowSize - 1)
                MID$(rowData, j + 1, 1) = CHR$(band[rowBase + j])
            NEXT
            filePos = 55 + CLNG(imageH - 1 - outY) * rowSize
            PUT #f, filePos, rowData
        END IF
    NEXT

    RETURN TRUE_VALUE
END FUNCTION


FUNCTION JpegScaledWidth(BYVAL srcW AS INTEGER, BYVAL srcH AS INTEGER) AS INTEGER
    DIM outW AS INTEGER
    DIM outH AS INTEGER
    DIM maxW AS INTEGER
    DIM maxH AS INTEGER

    maxW = 800
    maxH = 600
    IF srcW <= 0 OR srcH <= 0 THEN RETURN 0

    outW = srcW
    outH = srcH
    IF outW > maxW OR outH > maxH THEN
        IF CLNGINT(srcW) * maxH > CLNGINT(srcH) * maxW THEN
            outW = maxW
            outH = CINT((CLNGINT(srcH) * maxW + (srcW \ 2)) \ srcW)
        ELSE
            outH = maxH
            outW = CINT((CLNGINT(srcW) * maxH + (srcH \ 2)) \ srcH)
        END IF
    END IF

    IF outW < 1 THEN outW = 1
    RETURN outW
END FUNCTION

FUNCTION JpegScaledHeight(BYVAL srcW AS INTEGER, BYVAL srcH AS INTEGER) AS INTEGER
    DIM outW AS INTEGER
    DIM outH AS INTEGER
    DIM maxW AS INTEGER
    DIM maxH AS INTEGER

    maxW = 800
    maxH = 600
    IF srcW <= 0 OR srcH <= 0 THEN RETURN 0

    outW = srcW
    outH = srcH
    IF outW > maxW OR outH > maxH THEN
        IF CLNGINT(srcW) * maxH > CLNGINT(srcH) * maxW THEN
            outW = maxW
            outH = CINT((CLNGINT(srcH) * maxW + (srcW \ 2)) \ srcW)
        ELSE
            outH = maxH
            outW = CINT((CLNGINT(srcW) * maxH + (srcH \ 2)) \ srcH)
        END IF
    END IF

    IF outH < 1 THEN outH = 1
    RETURN outH
END FUNCTION

SUB PutOutputPixel( _
    BYVAL imgBuf AS UBYTE PTR, _
    BYVAL rowSize AS LONG, _
    BYVAL x AS INTEGER, _
    BYVAL y AS INTEGER, _
    BYVAL rgbVal AS UINTEGER)
    DIM bufPos AS LONG

    IF imgBuf = 0 THEN EXIT SUB
    IF rowSize <= 0 THEN EXIT SUB
    IF x < 0 OR y < 0 THEN EXIT SUB

    bufPos = CLNG(y) * rowSize + CLNG(x) * 3
    imgBuf[bufPos] = rgbVal AND 255
    imgBuf[bufPos + 1] = (rgbVal SHR 8) AND 255
    imgBuf[bufPos + 2] = (rgbVal SHR 16) AND 255
END SUB

FUNCTION WriteBmpBuffer24( _
    BYVAL fileName AS STRING, _
    BYVAL imgBuf AS UBYTE PTR, _
    BYVAL imgW AS INTEGER, _
    BYVAL imgH AS INTEGER, _
    BYVAL rowSize AS LONG) AS INTEGER
    DIM outNum AS INTEGER
    DIM headerRowSize AS LONG
    DIM y AS INTEGER
    DIM i AS LONG
    DIM offsetVal AS LONG
    DIM rowData AS STRING
    DIM rowPtr AS UBYTE PTR

    IF imgBuf = 0 THEN RETURN FALSE_VALUE
    IF imgW <= 0 OR imgH <= 0 THEN RETURN FALSE_VALUE
    IF rowSize <= 0 THEN RETURN FALSE_VALUE
    IF rowSize > 32760 THEN RETURN FALSE_VALUE

    IF BeginBmp24Write(fileName, imgW, imgH, outNum, headerRowSize) = FALSE_VALUE THEN RETURN FALSE_VALUE
    IF headerRowSize <> rowSize THEN
        CLOSE #outNum
        IF DIR(fileName) <> "" THEN KILL fileName
        RETURN FALSE_VALUE
    END IF

    rowData = SPACE$(rowSize)
    rowPtr = CAST(UBYTE PTR, STRPTR(rowData))

    FOR y = imgH - 1 TO 0 STEP -1
        offsetVal = CLNG(y) * rowSize
        FOR i = 0 TO rowSize - 1
            rowPtr[i] = imgBuf[offsetVal + i]
        NEXT
        PUT #outNum, , rowData
    NEXT

    CLOSE #outNum
    RETURN TRUE_VALUE
END FUNCTION

' ---------------------------
' GIF LZW decode path
' ---------------------------

FUNCTION LzwGetCode(BYVAL blockData AS UBYTE PTR, BYVAL blockSizeTotal AS LONG, BYREF bitPos AS LONG, BYVAL codeSize AS INTEGER) AS INTEGER
    DIM i AS INTEGER
    DIM bytePos AS LONG
    DIM bitMask AS INTEGER
    DIM result AS INTEGER

    IF blockData = 0 THEN RETURN -1
    IF codeSize < 1 OR codeSize > 12 THEN RETURN -1

    result = 0
    FOR i = 0 TO codeSize - 1
        bytePos = (bitPos + i) \ 8
        IF bytePos < 0 OR bytePos >= blockSizeTotal THEN RETURN -1
        bitMask = 1 SHL ((bitPos + i) AND 7)
        IF (blockData[bytePos] AND bitMask) <> 0 THEN result = result OR (1 SHL i)
    NEXT

    bitPos = bitPos + codeSize
    RETURN result
END FUNCTION

FUNCTION DecodeGifImage( _
    BYVAL compBytes AS UBYTE PTR, _
    BYVAL compSize AS LONG, _
    BYVAL minCodeSize AS INTEGER, _
    BYVAL leftPos AS INTEGER, _
    BYVAL topPos AS INTEGER, _
    BYVAL imageW AS INTEGER, _
    BYVAL imageH AS INTEGER, _
    BYVAL interlace AS INTEGER, _
    BYVAL transparentFlag AS INTEGER, _
    BYVAL transparentIndex AS INTEGER, _
    BYVAL palR AS UBYTE PTR, _
    BYVAL palG AS UBYTE PTR, _
    BYVAL palB AS UBYTE PTR, _
    BYVAL canvas AS UINTEGER PTR, _
    BYVAL canvasW AS INTEGER, _
    BYVAL canvasH AS INTEGER, _
    BYVAL backColor AS UINTEGER) AS INTEGER
    DIM prefix(0 TO 4095) AS INTEGER
    DIM suffix(0 TO 4095) AS UBYTE
    DIM stack(0 TO 4095) AS UBYTE
    DIM bitPos AS LONG
    DIM clearCode AS INTEGER
    DIM endCode AS INTEGER
    DIM nextCode AS INTEGER
    DIM codeSize AS INTEGER
    DIM codeLimit AS INTEGER
    DIM code AS INTEGER
    DIM oldCode AS INTEGER
    DIM inCode AS INTEGER
    DIM firstChar AS UBYTE
    DIM stackTop AS INTEGER
    DIM outCount AS LONG
    DIM totalPixels AS LONG
    DIM rowNum AS INTEGER
    DIM colNum AS INTEGER
    DIM destX AS INTEGER
    DIM destY AS INTEGER
    DIM passNum AS INTEGER
    DIM rowInPass AS INTEGER
    DIM idx AS INTEGER
    DIM c AS UINTEGER
    DIM i AS INTEGER

    IF compBytes = 0 OR compSize <= 0 THEN RETURN FALSE_VALUE
    IF canvas = 0 OR canvasW <= 0 OR canvasH <= 0 THEN RETURN FALSE_VALUE
    IF imageW <= 0 OR imageH <= 0 THEN RETURN FALSE_VALUE
    IF minCodeSize < 2 OR minCodeSize > 8 THEN RETURN FALSE_VALUE

    clearCode = 1 SHL minCodeSize
    endCode = clearCode + 1
    codeSize = minCodeSize + 1
    codeLimit = 1 SHL codeSize
    nextCode = endCode + 1

    FOR i = 0 TO clearCode - 1
        prefix(i) = 0
        suffix(i) = i
    NEXT

    bitPos = 0
    oldCode = -1
    firstChar = 0
    totalPixels = CLNG(imageW) * imageH
    outCount = 0
    passNum = 0
    rowInPass = 0

    DO WHILE outCount < totalPixels
        code = LzwGetCode(compBytes, compSize, bitPos, codeSize)
        IF code < 0 THEN EXIT DO

        IF code = clearCode THEN
            codeSize = minCodeSize + 1
            codeLimit = 1 SHL codeSize
            nextCode = endCode + 1
            oldCode = -1
            CONTINUE DO
        END IF

        IF code = endCode THEN EXIT DO
        IF code > 4095 THEN RETURN FALSE_VALUE

        IF oldCode = -1 THEN
            IF code >= clearCode THEN RETURN FALSE_VALUE
            firstChar = suffix(code)
            stackTop = 0
            stack(stackTop) = firstChar
        ELSE
            inCode = code
            stackTop = 0

            IF code >= nextCode THEN
                stack(stackTop) = firstChar
                stackTop = stackTop + 1
                code = oldCode
            END IF

            DO WHILE code >= clearCode
                IF code < 0 OR code > 4095 THEN RETURN FALSE_VALUE
                IF stackTop > 4094 THEN RETURN FALSE_VALUE
                stack(stackTop) = suffix(code)
                stackTop = stackTop + 1
                code = prefix(code)
            LOOP

            IF code < 0 OR code >= clearCode THEN RETURN FALSE_VALUE
            firstChar = suffix(code)
            IF stackTop > 4094 THEN RETURN FALSE_VALUE
            stack(stackTop) = firstChar

            IF nextCode <= 4095 THEN
                prefix(nextCode) = oldCode
                suffix(nextCode) = firstChar
                nextCode = nextCode + 1
                IF nextCode >= codeLimit AND codeSize < 12 THEN
                    codeSize = codeSize + 1
                    codeLimit = 1 SHL codeSize
                END IF
            END IF

            code = inCode
        END IF

        FOR i = stackTop TO 0 STEP -1
            idx = stack(i)

            IF interlace = FALSE_VALUE THEN
                rowNum = outCount \ imageW
            ELSE
                SELECT CASE passNum
                CASE 0
                    rowNum = rowInPass * 8
                CASE 1
                    rowNum = rowInPass * 8 + 4
                CASE 2
                    rowNum = rowInPass * 4 + 2
                CASE ELSE
                    rowNum = rowInPass * 2 + 1
                END SELECT
            END IF

            colNum = outCount MOD imageW
            destX = leftPos + colNum
            destY = topPos + rowNum

            IF destX >= 0 AND destX < canvasW AND destY >= 0 AND destY < canvasH THEN
                IF transparentFlag <> 0 AND idx = transparentIndex THEN
                    c = backColor
                ELSE
                    c = (CUINT(palR[idx]) SHL 16) OR (CUINT(palG[idx]) SHL 8) OR CUINT(palB[idx])
                END IF
                canvas[CLNG(destY) * canvasW + destX] = c
            END IF

            outCount = outCount + 1
            IF outCount >= totalPixels THEN EXIT FOR

            IF interlace <> FALSE_VALUE AND colNum = imageW - 1 THEN
                rowInPass = rowInPass + 1
                DO
                    SELECT CASE passNum
                    CASE 0
                        rowNum = rowInPass * 8
                        IF rowNum < imageH THEN EXIT DO
                        passNum = 1
                        rowInPass = 0
                    CASE 1
                        rowNum = rowInPass * 8 + 4
                        IF rowNum < imageH THEN EXIT DO
                        passNum = 2
                        rowInPass = 0
                    CASE 2
                        rowNum = rowInPass * 4 + 2
                        IF rowNum < imageH THEN EXIT DO
                        passNum = 3
                        rowInPass = 0
                    CASE ELSE
                        rowNum = rowInPass * 2 + 1
                        IF rowNum < imageH THEN EXIT DO
                        EXIT DO
                    END SELECT
                LOOP
            END IF
        NEXT

        oldCode = code
    LOOP

    IF outCount <= 0 THEN RETURN FALSE_VALUE
    RETURN TRUE_VALUE
END FUNCTION

FUNCTION ConvertGifToBmp(BYVAL inputFile AS STRING, BYVAL outputFile AS STRING, BYVAL backColor AS UINTEGER) AS INTEGER
    DIM f AS INTEGER
    DIM i AS INTEGER
    DIM b AS UBYTE
    DIM header AS STRING
    DIM screenW AS USHORT
    DIM screenH AS USHORT
    DIM packed AS UBYTE
    DIM bgIndex AS UBYTE
    DIM aspectByte AS UBYTE
    DIM gctFlag AS INTEGER
    DIM gctSize AS INTEGER
    DIM sep AS UBYTE
    DIM label AS UBYTE
    DIM blockSize AS UBYTE
    DIM gfxPacked AS UBYTE
    DIM delayTime AS USHORT
    DIM transparentIndexByte AS UBYTE
    DIM termByte AS UBYTE
    DIM transparentFlag AS INTEGER
    DIM transparentIndex AS INTEGER
    DIM leftPos AS USHORT
    DIM topPos AS USHORT
    DIM imageW AS USHORT
    DIM imageH AS USHORT
    DIM imagePacked AS UBYTE
    DIM lctFlag AS INTEGER
    DIM interlace AS INTEGER
    DIM lctSize AS INTEGER
    DIM palR(0 TO 255) AS UBYTE
    DIM palG(0 TO 255) AS UBYTE
    DIM palB(0 TO 255) AS UBYTE
    DIM useR AS UBYTE PTR
    DIM useG AS UBYTE PTR
    DIM useB AS UBYTE PTR
    DIM compBytes AS UBYTE PTR
    DIM compSize AS LONG
    DIM lzwMin AS UBYTE
    DIM canvas AS UINTEGER PTR
    DIM ok AS INTEGER

    f = FREEFILE
    IF OPEN(inputFile FOR BINARY ACCESS READ AS #f) <> 0 THEN RETURN FALSE_VALUE

    header = ""
    FOR i = 1 TO 6
        IF ReadByte(f, b) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE
        header = header + CHR$(b)
    NEXT

    IF header <> "GIF87a" AND header <> "GIF89a" THEN
        CLOSE #f
        RETURN FALSE_VALUE
    END IF

    IF ReadUShort(f, screenW) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE
    IF ReadUShort(f, screenH) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE
    IF ReadByte(f, packed) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE
    IF ReadByte(f, bgIndex) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE
    IF ReadByte(f, aspectByte) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE

    IF screenW = 0 OR screenH = 0 THEN CLOSE #f : RETURN FALSE_VALUE

    gctFlag = 0
    IF (packed AND &H80) <> 0 THEN gctFlag = TRUE_VALUE
    gctSize = 1 SHL ((packed AND 7) + 1)

    FOR i = 0 TO 255
        palR(i) = 255
        palG(i) = 255
        palB(i) = 255
    NEXT

    IF gctFlag <> 0 THEN
        FOR i = 0 TO gctSize - 1
            IF ReadByte(f, palR(i)) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE
            IF ReadByte(f, palG(i)) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE
            IF ReadByte(f, palB(i)) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE
        NEXT
    END IF

    canvas = CALLOCATE(CLNG(screenW) * screenH, SIZEOF(UINTEGER))
    IF canvas = 0 THEN CLOSE #f : RETURN FALSE_VALUE

    FOR i = 0 TO CLNG(screenW) * screenH - 1
        canvas[i] = backColor
    NEXT

    transparentFlag = 0
    transparentIndex = -1
    ok = FALSE_VALUE

    DO
        IF ReadByte(f, sep) = FALSE_VALUE THEN EXIT DO

        SELECT CASE sep
        CASE &H21
            IF ReadByte(f, label) = FALSE_VALUE THEN EXIT DO
            IF label = &HF9 THEN
                IF ReadByte(f, blockSize) = FALSE_VALUE THEN EXIT DO
                IF blockSize <> 4 THEN
                    IF SkipSubBlocks(f) = FALSE_VALUE THEN EXIT DO
                ELSE
                    IF ReadByte(f, gfxPacked) = FALSE_VALUE THEN EXIT DO
                    IF ReadUShort(f, delayTime) = FALSE_VALUE THEN EXIT DO
                    IF ReadByte(f, transparentIndexByte) = FALSE_VALUE THEN EXIT DO
                    IF ReadByte(f, termByte) = FALSE_VALUE THEN EXIT DO
                    transparentFlag = 0
                    IF (gfxPacked AND 1) <> 0 THEN transparentFlag = TRUE_VALUE
                    transparentIndex = transparentIndexByte
                END IF
            ELSE
                IF SkipSubBlocks(f) = FALSE_VALUE THEN EXIT DO
            END IF

        CASE &H2C
            IF ReadUShort(f, leftPos) = FALSE_VALUE THEN EXIT DO
            IF ReadUShort(f, topPos) = FALSE_VALUE THEN EXIT DO
            IF ReadUShort(f, imageW) = FALSE_VALUE THEN EXIT DO
            IF ReadUShort(f, imageH) = FALSE_VALUE THEN EXIT DO
            IF ReadByte(f, imagePacked) = FALSE_VALUE THEN EXIT DO

            lctFlag = 0
            IF (imagePacked AND &H80) <> 0 THEN lctFlag = TRUE_VALUE
            interlace = 0
            IF (imagePacked AND &H40) <> 0 THEN interlace = TRUE_VALUE
            lctSize = 1 SHL ((imagePacked AND 7) + 1)

            IF lctFlag <> 0 THEN
                FOR i = 0 TO 255
                    palR(i) = 255
                    palG(i) = 255
                    palB(i) = 255
                NEXT
                FOR i = 0 TO lctSize - 1
                    IF ReadByte(f, palR(i)) = FALSE_VALUE THEN EXIT DO
                    IF ReadByte(f, palG(i)) = FALSE_VALUE THEN EXIT DO
                    IF ReadByte(f, palB(i)) = FALSE_VALUE THEN EXIT DO
                NEXT
            END IF

            IF ReadByte(f, lzwMin) = FALSE_VALUE THEN EXIT DO
            compBytes = 0
            compSize = 0
            IF ReadSubBlocks(f, compBytes, compSize) = FALSE_VALUE THEN EXIT DO

            useR = @palR(0)
            useG = @palG(0)
            useB = @palB(0)

            ok = DecodeGifImage(compBytes, compSize, lzwMin, leftPos, topPos, imageW, imageH, interlace, transparentFlag, transparentIndex, useR, useG, useB, canvas, screenW, screenH, backColor)
            IF compBytes <> 0 THEN DEALLOCATE compBytes
            compBytes = 0
            compSize = 0
            EXIT DO

        CASE &H3B
            EXIT DO

        CASE ELSE
            EXIT DO
        END SELECT
    LOOP

    CLOSE #f

    IF ok <> FALSE_VALUE THEN
        ok = WriteBmp24(outputFile, canvas, screenW, screenH)
    END IF

    IF canvas <> 0 THEN DEALLOCATE canvas
    RETURN ok
END FUNCTION

' ---------------------------
' Codec option parsing and small color helpers
' ---------------------------

FUNCTION ParseBgColor(BYVAL spec AS STRING, BYREF backColor AS UINTEGER) AS INTEGER
    DIM s AS STRING
    DIM p1 AS INTEGER
    DIM p2 AS INTEGER
    DIM r AS INTEGER
    DIM g AS INTEGER
    DIM b AS INTEGER

    s = UpperText(TRIM$(spec))
    IF LEFT$(s, 3) = "BG=" THEN s = MID$(s, 4)
    IF s = "" THEN RETURN FALSE_VALUE

    p1 = INSTR(s, ",")
    IF p1 <= 0 THEN RETURN FALSE_VALUE
    p2 = INSTR(p1 + 1, s, ",")
    IF p2 <= 0 THEN RETURN FALSE_VALUE

    r = VAL(LEFT$(s, p1 - 1))
    g = VAL(MID$(s, p1 + 1, p2 - p1 - 1))
    b = VAL(MID$(s, p2 + 1))

    IF r < 0 THEN r = 0
    IF r > 255 THEN r = 255
    IF g < 0 THEN g = 0
    IF g > 255 THEN g = 255
    IF b < 0 THEN b = 0
    IF b > 255 THEN b = 255

    backColor = (CUINT(r) SHL 16) OR (CUINT(g) SHL 8) OR CUINT(b)
    RETURN TRUE_VALUE
END FUNCTION

FUNCTION ClampByte(BYVAL v AS INTEGER) AS UBYTE
    IF v < 0 THEN RETURN 0
    IF v > 255 THEN RETURN 255
    RETURN v
END FUNCTION

' ---------------------------
' JPEG tables, marker parsing, and frame headers
' ---------------------------

SUB InitJpegTables()
    DIM i AS INTEGER
    DIM x AS INTEGER
    DIM u AS INTEGER

    IF jpgTablesReady <> 0 THEN EXIT SUB

    jpgZigZag(0) = 0
    jpgZigZag(1) = 1
    jpgZigZag(2) = 8
    jpgZigZag(3) = 16
    jpgZigZag(4) = 9
    jpgZigZag(5) = 2
    jpgZigZag(6) = 3
    jpgZigZag(7) = 10
    jpgZigZag(8) = 17
    jpgZigZag(9) = 24
    jpgZigZag(10) = 32
    jpgZigZag(11) = 25
    jpgZigZag(12) = 18
    jpgZigZag(13) = 11
    jpgZigZag(14) = 4
    jpgZigZag(15) = 5
    jpgZigZag(16) = 12
    jpgZigZag(17) = 19
    jpgZigZag(18) = 26
    jpgZigZag(19) = 33
    jpgZigZag(20) = 40
    jpgZigZag(21) = 48
    jpgZigZag(22) = 41
    jpgZigZag(23) = 34
    jpgZigZag(24) = 27
    jpgZigZag(25) = 20
    jpgZigZag(26) = 13
    jpgZigZag(27) = 6
    jpgZigZag(28) = 7
    jpgZigZag(29) = 14
    jpgZigZag(30) = 21
    jpgZigZag(31) = 28
    jpgZigZag(32) = 35
    jpgZigZag(33) = 42
    jpgZigZag(34) = 49
    jpgZigZag(35) = 56
    jpgZigZag(36) = 57
    jpgZigZag(37) = 50
    jpgZigZag(38) = 43
    jpgZigZag(39) = 36
    jpgZigZag(40) = 29
    jpgZigZag(41) = 22
    jpgZigZag(42) = 15
    jpgZigZag(43) = 23
    jpgZigZag(44) = 30
    jpgZigZag(45) = 37
    jpgZigZag(46) = 44
    jpgZigZag(47) = 51
    jpgZigZag(48) = 58
    jpgZigZag(49) = 59
    jpgZigZag(50) = 52
    jpgZigZag(51) = 45
    jpgZigZag(52) = 38
    jpgZigZag(53) = 31
    jpgZigZag(54) = 39
    jpgZigZag(55) = 46
    jpgZigZag(56) = 53
    jpgZigZag(57) = 60
    jpgZigZag(58) = 61
    jpgZigZag(59) = 54
    jpgZigZag(60) = 47
    jpgZigZag(61) = 55
    jpgZigZag(62) = 62
    jpgZigZag(63) = 63

    FOR i = 0 TO 3
        jpgQuantValid(i) = 0
        jpgCompPrevDc(i) = 0
    NEXT

    jpgCScale(0) = 0.7071067811865476
    FOR i = 1 TO 7
        jpgCScale(i) = 1.0
    NEXT

    FOR x = 0 TO 7
        FOR u = 0 TO 7
            jpgCosTable(x, u) = COS((2.0 * x + 1.0) * u * 3.141592653589793 / 16.0)
        NEXT
    NEXT

    jpgTablesReady = TRUE_VALUE
END SUB

FUNCTION ReadJpegMarker(BYVAL f AS INTEGER, BYREF markerValue AS UBYTE) AS INTEGER
    DIM b AS UBYTE

    DO
        IF ReadByte(f, b) = FALSE_VALUE THEN RETURN FALSE_VALUE
    LOOP WHILE b <> &HFF

    DO
        IF ReadByte(f, b) = FALSE_VALUE THEN RETURN FALSE_VALUE
    LOOP WHILE b = &HFF

    markerValue = b
    RETURN TRUE_VALUE
END FUNCTION

FUNCTION SkipJpegSegment(BYVAL f AS INTEGER, BYVAL segLen AS USHORT) AS INTEGER
    DIM i AS INTEGER
    DIM b AS UBYTE

    IF segLen < 2 THEN RETURN FALSE_VALUE
    FOR i = 1 TO segLen - 2
        IF ReadByte(f, b) = FALSE_VALUE THEN RETURN FALSE_VALUE
    NEXT
    RETURN TRUE_VALUE
END FUNCTION

FUNCTION ParseDqt(BYVAL f AS INTEGER, BYVAL segLen AS USHORT) AS INTEGER
    DIM remain AS INTEGER
    DIM info AS UBYTE
    DIM precision AS INTEGER
    DIM tableId AS INTEGER
    DIM i AS INTEGER
    DIM b AS UBYTE
    DIM v16 AS USHORT
    DIM qValue AS INTEGER

    IF segLen < 2 THEN RETURN FALSE_VALUE
    remain = segLen - 2

    DO WHILE remain > 0
        IF ReadByte(f, info) = FALSE_VALUE THEN RETURN FALSE_VALUE
        remain = remain - 1
        precision = (info SHR 4) AND 15
        tableId = info AND 15
        IF tableId < 0 OR tableId > 3 THEN RETURN FALSE_VALUE
        IF precision <> 0 AND precision <> 1 THEN RETURN FALSE_VALUE

        FOR i = 0 TO 63
            IF precision = 0 THEN
                IF ReadByte(f, b) = FALSE_VALUE THEN RETURN FALSE_VALUE
                qValue = b
                remain = remain - 1
            ELSE
                IF ReadUShortBE(f, v16) = FALSE_VALUE THEN RETURN FALSE_VALUE
                qValue = v16
                remain = remain - 2
            END IF
            IF remain < 0 THEN RETURN FALSE_VALUE
            jpgQuant(tableId, jpgZigZag(i)) = qValue
        NEXT
        jpgQuantValid(tableId) = TRUE_VALUE
    LOOP

    RETURN TRUE_VALUE
END FUNCTION

FUNCTION ParseDht(BYVAL f AS INTEGER, BYVAL segLen AS USHORT) AS INTEGER
    DIM remain AS INTEGER
    DIM info AS UBYTE
    DIM tableClass AS INTEGER
    DIM tableId AS INTEGER
    DIM counts(1 TO 16) AS INTEGER
    DIM lenNum AS INTEGER
    DIM j AS INTEGER
    DIM total AS INTEGER
    DIM symbolByte AS UBYTE
    DIM codeVal AS INTEGER
    DIM outIndex AS INTEGER

    IF segLen < 2 THEN RETURN FALSE_VALUE
    remain = segLen - 2

    DO WHILE remain > 0
        IF ReadByte(f, info) = FALSE_VALUE THEN RETURN FALSE_VALUE
        remain = remain - 1
        tableClass = (info SHR 4) AND 15
        tableId = info AND 15
        IF tableClass < 0 OR tableClass > 1 THEN RETURN FALSE_VALUE
        IF tableId < 0 OR tableId > 3 THEN RETURN FALSE_VALUE

        total = 0
        FOR lenNum = 1 TO 16
            IF ReadByte(f, symbolByte) = FALSE_VALUE THEN RETURN FALSE_VALUE
            counts(lenNum) = symbolByte
            total = total + counts(lenNum)
            remain = remain - 1
        NEXT
        IF total < 0 OR total > 256 THEN RETURN FALSE_VALUE
        IF remain < total THEN RETURN FALSE_VALUE

        jpgHuffCount(tableClass, tableId) = total
        FOR lenNum = 1 TO 16
            jpgHuffMinCode(tableClass, tableId, lenNum) = -1
            jpgHuffMaxCode(tableClass, tableId, lenNum) = -1
            jpgHuffValIndex(tableClass, tableId, lenNum) = 0
        NEXT

        codeVal = 0
        outIndex = 0
        FOR lenNum = 1 TO 16
            IF counts(lenNum) > 0 THEN
                jpgHuffMinCode(tableClass, tableId, lenNum) = codeVal
                jpgHuffValIndex(tableClass, tableId, lenNum) = outIndex
            END IF

            FOR j = 1 TO counts(lenNum)
                IF ReadByte(f, symbolByte) = FALSE_VALUE THEN RETURN FALSE_VALUE
                jpgHuffCode(tableClass, tableId, outIndex) = codeVal
                jpgHuffSize(tableClass, tableId, outIndex) = lenNum
                jpgHuffSymbol(tableClass, tableId, outIndex) = symbolByte
                outIndex = outIndex + 1
                codeVal = codeVal + 1
                remain = remain - 1
            NEXT

            IF counts(lenNum) > 0 THEN
                jpgHuffMaxCode(tableClass, tableId, lenNum) = codeVal - 1
            END IF
            codeVal = codeVal SHL 1
        NEXT
    LOOP

    RETURN TRUE_VALUE
END FUNCTION

FUNCTION ParseSof0(BYVAL f AS INTEGER, BYVAL segLen AS USHORT) AS INTEGER
    DIM precision AS UBYTE
    DIM hVal AS USHORT
    DIM wVal AS USHORT
    DIM compTotal AS UBYTE
    DIM i AS INTEGER
    DIM idByte AS UBYTE
    DIM hvByte AS UBYTE
    DIM qByte AS UBYTE

    IF segLen < 8 THEN RETURN FALSE_VALUE
    IF ReadByte(f, precision) = FALSE_VALUE THEN RETURN FALSE_VALUE
    IF ReadUShortBE(f, hVal) = FALSE_VALUE THEN RETURN FALSE_VALUE
    IF ReadUShortBE(f, wVal) = FALSE_VALUE THEN RETURN FALSE_VALUE
    IF ReadByte(f, compTotal) = FALSE_VALUE THEN RETURN FALSE_VALUE

    IF precision <> 8 THEN RETURN FALSE_VALUE
    IF wVal = 0 OR hVal = 0 THEN RETURN FALSE_VALUE
    IF compTotal <> 1 AND compTotal <> 3 THEN RETURN FALSE_VALUE
    IF segLen <> 8 + compTotal * 3 THEN RETURN FALSE_VALUE

    jpgWidth = wVal
    jpgHeight = hVal
    jpgCompCount = compTotal

    FOR i = 0 TO compTotal - 1
        IF ReadByte(f, idByte) = FALSE_VALUE THEN RETURN FALSE_VALUE
        IF ReadByte(f, hvByte) = FALSE_VALUE THEN RETURN FALSE_VALUE
        IF ReadByte(f, qByte) = FALSE_VALUE THEN RETURN FALSE_VALUE
        jpgCompId(i) = idByte
        jpgCompH(i) = (hvByte SHR 4) AND 15
        jpgCompV(i) = hvByte AND 15
        jpgCompQ(i) = qByte
        jpgCompDc(i) = 0
        jpgCompAc(i) = 0
        jpgCompPrevDc(i) = 0
        IF jpgCompH(i) < 1 OR jpgCompH(i) > 4 THEN RETURN FALSE_VALUE
        IF jpgCompV(i) < 1 OR jpgCompV(i) > 4 THEN RETURN FALSE_VALUE
        IF jpgCompQ(i) < 0 OR jpgCompQ(i) > 3 THEN RETURN FALSE_VALUE
    NEXT

    RETURN TRUE_VALUE
END FUNCTION

FUNCTION ParseDri(BYVAL f AS INTEGER, BYVAL segLen AS USHORT) AS INTEGER
    DIM intervalVal AS USHORT

    IF segLen <> 4 THEN RETURN FALSE_VALUE
    IF ReadUShortBE(f, intervalVal) = FALSE_VALUE THEN RETURN FALSE_VALUE
    jpgRestartInterval = intervalVal
    RETURN TRUE_VALUE
END FUNCTION

FUNCTION ReadJpegEntropy(BYVAL f AS INTEGER, BYREF entropyBytes AS UBYTE PTR, BYREF entropySize AS LONG) AS INTEGER
    DIM b AS UBYTE
    DIM n AS UBYTE
    DIM fileLen AS LONG
    DIM filePos AS LONG
    DIM rawSize AS LONG
    DIM rawData AS STRING
    DIM rawPtr AS UBYTE PTR
    DIM rawPos AS LONG
    DIM maxEntropy AS LONG

    entropyBytes = 0
    entropySize = 0
    maxEntropy = 8388608

    fileLen = LOF(f)
    filePos = SEEK(f)
    IF filePos < 1 THEN RETURN FALSE_VALUE
    IF fileLen < filePos THEN RETURN FALSE_VALUE

    rawSize = fileLen - filePos + 1
    IF rawSize <= 0 OR rawSize > maxEntropy THEN RETURN FALSE_VALUE

    rawData = SPACE$(rawSize)
    GET #f, , rawData
    rawPtr = CAST(UBYTE PTR, STRPTR(rawData))

    entropyBytes = ALLOCATE(rawSize)
    IF entropyBytes = 0 THEN RETURN FALSE_VALUE

    rawPos = 0
    DO WHILE rawPos < rawSize
        b = rawPtr[rawPos]
        rawPos = rawPos + 1

        IF b = &HFF THEN
            DO WHILE rawPos < rawSize AND rawPtr[rawPos] = &HFF
                rawPos = rawPos + 1
            LOOP

            IF rawPos >= rawSize THEN EXIT DO
            n = rawPtr[rawPos]
            rawPos = rawPos + 1

            IF n = &H00 THEN
                b = &HFF
            ELSEIF n >= &HD0 AND n <= &HD7 THEN
                CONTINUE DO
            ELSE
                EXIT DO
            END IF
        END IF

        entropyBytes[entropySize] = b
        entropySize = entropySize + 1
    LOOP

    IF entropySize <= 0 THEN
        IF entropyBytes <> 0 THEN DEALLOCATE entropyBytes
        entropyBytes = 0
        RETURN FALSE_VALUE
    END IF

    RETURN TRUE_VALUE
END FUNCTION

' ---------------------------
' JPEG entropy bitstream and Huffman decode helpers
' ---------------------------

SUB BitstreamInit(BYREF bs AS JPG_BITSTREAM, BYVAL entropyBytes AS UBYTE PTR, BYVAL entropySize AS LONG)
    bs.bytes = entropyBytes
    bs.size = entropySize
    bs.byteIndex = 0
    bs.bitBuffer = 0
    bs.bitCount = 0
END SUB

FUNCTION BitstreamEnsureBits(BYREF bs AS JPG_BITSTREAM, BYVAL bitTotal AS INTEGER) AS INTEGER
    IF bitTotal <= 0 THEN RETURN TRUE_VALUE
    IF bitTotal > 24 THEN RETURN FALSE_VALUE

    DO WHILE bs.bitCount < bitTotal
        IF bs.byteIndex >= bs.size THEN RETURN FALSE_VALUE
        bs.bitBuffer = (bs.bitBuffer SHL 8) OR bs.bytes[bs.byteIndex]
        bs.byteIndex = bs.byteIndex + 1
        bs.bitCount = bs.bitCount + 8
    LOOP

    RETURN TRUE_VALUE
END FUNCTION

FUNCTION BitstreamGetBit(BYREF bs AS JPG_BITSTREAM) AS INTEGER
    IF BitstreamEnsureBits(bs, 1) = FALSE_VALUE THEN RETURN -1
    bs.bitCount = bs.bitCount - 1
    RETURN (bs.bitBuffer SHR bs.bitCount) AND 1
END FUNCTION

FUNCTION BitstreamGetBits(BYREF bs AS JPG_BITSTREAM, BYVAL bitTotal AS INTEGER) AS INTEGER
    DIM result AS UINTEGER
    DIM maskVal AS UINTEGER

    IF bitTotal = 0 THEN RETURN 0
    IF bitTotal < 0 OR bitTotal > 16 THEN RETURN -1
    IF BitstreamEnsureBits(bs, bitTotal) = FALSE_VALUE THEN RETURN -1

    maskVal = (CUINT(1) SHL bitTotal) - 1
    result = (bs.bitBuffer SHR (bs.bitCount - bitTotal)) AND maskVal
    bs.bitCount = bs.bitCount - bitTotal
    RETURN CINT(result)
END FUNCTION

FUNCTION HuffmanDecode(BYREF bs AS JPG_BITSTREAM, BYVAL tableClass AS INTEGER, BYVAL tableId AS INTEGER) AS INTEGER
    DIM lenNum AS INTEGER
    DIM codeVal AS INTEGER
    DIM bitVal AS INTEGER
    DIM minCode AS INTEGER
    DIM maxCode AS INTEGER
    DIM symIndex AS INTEGER

    IF tableClass < 0 OR tableClass > 1 THEN RETURN -1
    IF tableId < 0 OR tableId > 3 THEN RETURN -1
    IF jpgHuffCount(tableClass, tableId) <= 0 THEN RETURN -1

    codeVal = 0
    FOR lenNum = 1 TO 16
        bitVal = BitstreamGetBit(bs)
        IF bitVal < 0 THEN RETURN -1
        codeVal = (codeVal SHL 1) OR bitVal

        maxCode = jpgHuffMaxCode(tableClass, tableId, lenNum)
        IF maxCode >= 0 THEN
            minCode = jpgHuffMinCode(tableClass, tableId, lenNum)
            IF codeVal >= minCode AND codeVal <= maxCode THEN
                symIndex = jpgHuffValIndex(tableClass, tableId, lenNum) + codeVal - minCode
                IF symIndex >= 0 AND symIndex < jpgHuffCount(tableClass, tableId) THEN
                    RETURN jpgHuffSymbol(tableClass, tableId, symIndex)
                END IF
                RETURN -1
            END IF
        END IF
    NEXT

    RETURN -1
END FUNCTION

FUNCTION ReceiveExtend(BYREF bs AS JPG_BITSTREAM, BYVAL bitTotal AS INTEGER) AS INTEGER
    DIM v AS INTEGER
    DIM limit AS INTEGER

    IF bitTotal = 0 THEN RETURN 0
    IF bitTotal < 0 OR bitTotal > 16 THEN RETURN 0
    v = BitstreamGetBits(bs, bitTotal)
    IF v < 0 THEN RETURN 0
    limit = 1 SHL (bitTotal - 1)
    IF v < limit THEN v = v - ((1 SHL bitTotal) - 1)
    RETURN v
END FUNCTION

SUB IdctBlockToSamples( _
    BYVAL coef AS INTEGER PTR, _
    BYVAL qTableIndex AS INTEGER, _
    BYVAL nzList AS INTEGER PTR, _
    BYVAL nzCount AS INTEGER, _
    BYVAL samples AS UBYTE PTR)
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM u AS INTEGER
    DIM v AS INTEGER
    DIM idx AS INTEGER
    DIM n AS INTEGER
    DIM fillVal AS UBYTE
    DIM sumVal AS DOUBLE
    DIM coeffVal AS DOUBLE
    DIM outVal AS INTEGER

    IF coef = 0 OR samples = 0 THEN EXIT SUB
    IF qTableIndex < 0 OR qTableIndex > 3 THEN EXIT SUB

    IF nzCount <= 0 OR nzList = 0 THEN
        FOR y = 0 TO 7
            FOR x = 0 TO 7
                samples[y * 8 + x] = 128
            NEXT
        NEXT
        EXIT SUB
    END IF

    IF nzCount = 1 AND nzList[0] = 0 THEN
        outVal = CINT((coef[0] * jpgQuant(qTableIndex, 0)) / 8.0 + 128.0)
        fillVal = ClampByte(outVal)
        FOR y = 0 TO 7
            FOR x = 0 TO 7
                samples[y * 8 + x] = fillVal
            NEXT
        NEXT
        EXIT SUB
    END IF

    FOR y = 0 TO 7
        FOR x = 0 TO 7
            sumVal = 0.0
            FOR n = 0 TO nzCount - 1
                idx = nzList[n]
                IF idx >= 0 AND idx < 64 THEN
                    u = idx AND 7
                    v = idx \ 8
                    coeffVal = coef[idx] * jpgQuant(qTableIndex, idx)
                    sumVal = sumVal + jpgCScale(u) * jpgCScale(v) * _
                        coeffVal * jpgCosTable(x, u) * jpgCosTable(y, v)
                END IF
            NEXT
            outVal = CINT(sumVal / 4.0 + 128.0)
            samples[y * 8 + x] = ClampByte(outVal)
        NEXT
    NEXT
END SUB

FUNCTION DecodeJpegBlock(BYREF bs AS JPG_BITSTREAM, BYVAL compIndex AS INTEGER, BYVAL samples AS UBYTE PTR) AS INTEGER
    DIM k AS INTEGER
    DIM s AS INTEGER
    DIM rs AS INTEGER
    DIM r AS INTEGER
    DIM dummyVal AS INTEGER
    DIM i AS INTEGER
    DIM dcTable AS INTEGER
    DIM acTable AS INTEGER
    DIM qTable AS INTEGER
    DIM outVal AS INTEGER
    DIM fillVal AS UBYTE

    IF compIndex < 0 OR compIndex >= jpgCompCount THEN RETURN FALSE_VALUE
    IF samples = 0 THEN RETURN FALSE_VALUE

    dcTable = jpgCompDc(compIndex)
    acTable = jpgCompAc(compIndex)
    qTable = jpgCompQ(compIndex)
    IF qTable < 0 OR qTable > 3 THEN RETURN FALSE_VALUE
    IF jpgQuantValid(qTable) = 0 THEN RETURN FALSE_VALUE

    s = HuffmanDecode(bs, 0, dcTable)
    IF s < 0 THEN RETURN FALSE_VALUE
    jpgCompPrevDc(compIndex) = jpgCompPrevDc(compIndex) + ReceiveExtend(bs, s)

    outVal = ((jpgCompPrevDc(compIndex) * jpgQuant(qTable, 0) + 4) \ 8) + 128
    fillVal = ClampByte(outVal)
    FOR i = 0 TO 63
        samples[i] = fillVal
    NEXT

    k = 1
    DO WHILE k < 64
        rs = HuffmanDecode(bs, 1, acTable)
        IF rs < 0 THEN RETURN FALSE_VALUE
        r = (rs SHR 4) AND 15
        s = rs AND 15

        IF s = 0 THEN
            IF r = 0 THEN EXIT DO
            IF r = 15 THEN
                k = k + 16
            ELSE
                RETURN FALSE_VALUE
            END IF
        ELSE
            k = k + r
            IF k >= 64 THEN RETURN FALSE_VALUE
            dummyVal = ReceiveExtend(bs, s)
            k = k + 1
        END IF
    LOOP

    RETURN TRUE_VALUE
END FUNCTION

SUB StoreBlockInPlane( _
    BYVAL plane AS UBYTE PTR, _
    BYVAL mcuW AS INTEGER, _
    BYVAL mcuH AS INTEGER, _
    BYVAL samples AS UBYTE PTR, _
    BYVAL blockX AS INTEGER, _
    BYVAL blockY AS INTEGER, _
    BYVAL compH AS INTEGER, _
    BYVAL compV AS INTEGER, _
    BYVAL hMax AS INTEGER, _
    BYVAL vMax AS INTEGER)
    DIM scaleX AS INTEGER
    DIM scaleY AS INTEGER
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM sx AS INTEGER
    DIM sy AS INTEGER
    DIM dx AS INTEGER
    DIM dy AS INTEGER
    DIM sampleVal AS UBYTE

    IF plane = 0 OR samples = 0 THEN EXIT SUB
    IF compH <= 0 OR compV <= 0 THEN EXIT SUB

    scaleX = hMax \ compH
    scaleY = vMax \ compV
    IF scaleX < 1 THEN scaleX = 1
    IF scaleY < 1 THEN scaleY = 1

    FOR y = 0 TO 7
        FOR x = 0 TO 7
            sampleVal = samples[y * 8 + x]
            FOR sy = 0 TO scaleY - 1
                FOR sx = 0 TO scaleX - 1
                    dx = blockX * 8 * scaleX + x * scaleX + sx
                    dy = blockY * 8 * scaleY + y * scaleY + sy
                    IF dx >= 0 AND dx < mcuW AND dy >= 0 AND dy < mcuH THEN
                        plane[dy * mcuW + dx] = sampleVal
                    END IF
                NEXT
            NEXT
        NEXT
    NEXT
END SUB

SUB StoreSolidBlockInPlane( _
    BYVAL plane AS UBYTE PTR, _
    BYVAL mcuW AS INTEGER, _
    BYVAL mcuH AS INTEGER, _
    BYVAL sampleVal AS UBYTE, _
    BYVAL blockX AS INTEGER, _
    BYVAL blockY AS INTEGER, _
    BYVAL compH AS INTEGER, _
    BYVAL compV AS INTEGER, _
    BYVAL hMax AS INTEGER, _
    BYVAL vMax AS INTEGER)
    DIM scaleX AS INTEGER
    DIM scaleY AS INTEGER
    DIM blockW AS INTEGER
    DIM blockH AS INTEGER
    DIM dx0 AS INTEGER
    DIM dy0 AS INTEGER
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM dx AS INTEGER
    DIM dy AS INTEGER
    DIM rowBase AS LONG

    IF plane = 0 THEN EXIT SUB
    IF compH <= 0 OR compV <= 0 THEN EXIT SUB

    scaleX = hMax \ compH
    scaleY = vMax \ compV
    IF scaleX < 1 THEN scaleX = 1
    IF scaleY < 1 THEN scaleY = 1

    blockW = 8 * scaleX
    blockH = 8 * scaleY
    dx0 = blockX * blockW
    dy0 = blockY * blockH

    FOR y = 0 TO blockH - 1
        dy = dy0 + y
        IF dy >= 0 AND dy < mcuH THEN
            rowBase = CLNG(dy) * mcuW
            FOR x = 0 TO blockW - 1
                dx = dx0 + x
                IF dx >= 0 AND dx < mcuW THEN
                    plane[rowBase + dx] = sampleVal
                END IF
            NEXT
        END IF
    NEXT
END SUB

' ---------------------------
' JPEG entropy decode and block output
' ---------------------------

FUNCTION DecodeJpegEntropy(BYVAL entropyBytes AS UBYTE PTR, BYVAL entropySize AS LONG, BYVAL outputFile AS STRING) AS INTEGER
    DIM bs AS JPG_BITSTREAM
    DIM planeY AS UBYTE PTR
    DIM planeCb AS UBYTE PTR
    DIM planeCr AS UBYTE PTR
    DIM samples AS UBYTE PTR
    DIM outBuf AS UBYTE PTR
    DIM outW AS INTEGER
    DIM outH AS INTEGER
    DIM outRowSize AS LONG
    DIM outBufSize AS LONG
    DIM hMax AS INTEGER
    DIM vMax AS INTEGER
    DIM mcuW AS INTEGER
    DIM mcuH AS INTEGER
    DIM mcuXCount AS INTEGER
    DIM mcuYCount AS INTEGER
    DIM mx AS INTEGER
    DIM my AS INTEGER
    DIM ci AS INTEGER
    DIM scanIndex AS INTEGER
    DIM hb AS INTEGER
    DIM vb AS INTEGER
    DIM srcLeft AS INTEGER
    DIM srcTop AS INTEGER
    DIM srcRightEx AS INTEGER
    DIM srcBottomEx AS INTEGER
    DIM dstXStart AS INTEGER
    DIM dstXEnd AS INTEGER
    DIM dstYStart AS INTEGER
    DIM dstYEnd AS INTEGER
    DIM dstX AS INTEGER
    DIM dstY AS INTEGER
    DIM localX AS INTEGER
    DIM localY AS INTEGER
    DIM sampleIndex AS LONG
    DIM yVal AS INTEGER
    DIM cbVal AS INTEGER
    DIM crVal AS INTEGER
    DIM rVal AS INTEGER
    DIM gVal AS INTEGER
    DIM bVal AS INTEGER
    DIM colorVal AS UINTEGER
    DIM ok AS INTEGER
    DIM mcuCounter AS LONG

    IF entropyBytes = 0 OR entropySize <= 0 THEN RETURN FALSE_VALUE
    IF jpgWidth <= 0 OR jpgHeight <= 0 THEN RETURN FALSE_VALUE
    IF jpgCompCount <> 1 AND jpgCompCount <> 3 THEN RETURN FALSE_VALUE

    hMax = 1
    vMax = 1
    FOR ci = 0 TO jpgCompCount - 1
        IF jpgCompH(ci) > hMax THEN hMax = jpgCompH(ci)
        IF jpgCompV(ci) > vMax THEN vMax = jpgCompV(ci)
    NEXT

    mcuW = hMax * 8
    mcuH = vMax * 8
    IF mcuW <= 0 OR mcuH <= 0 THEN RETURN FALSE_VALUE

    outW = JpegScaledWidth(jpgWidth, jpgHeight)
    outH = JpegScaledHeight(jpgWidth, jpgHeight)
    IF outW <= 0 OR outH <= 0 THEN RETURN FALSE_VALUE

    outRowSize = ((CLNG(outW) * 3 + 3) \ 4) * 4
    outBufSize = outRowSize * outH
    IF outBufSize <= 0 OR outBufSize > 2097152 THEN RETURN FALSE_VALUE

    outBuf = CALLOCATE(outBufSize, SIZEOF(UBYTE))
    planeY = CALLOCATE(CLNG(mcuW) * mcuH, SIZEOF(UBYTE))
    planeCb = CALLOCATE(CLNG(mcuW) * mcuH, SIZEOF(UBYTE))
    planeCr = CALLOCATE(CLNG(mcuW) * mcuH, SIZEOF(UBYTE))
    samples = CALLOCATE(64, SIZEOF(UBYTE))

    IF outBuf = 0 OR planeY = 0 OR planeCb = 0 OR planeCr = 0 OR samples = 0 THEN
        IF samples <> 0 THEN DEALLOCATE samples
        IF planeCr <> 0 THEN DEALLOCATE planeCr
        IF planeCb <> 0 THEN DEALLOCATE planeCb
        IF planeY <> 0 THEN DEALLOCATE planeY
        IF outBuf <> 0 THEN DEALLOCATE outBuf
        RETURN FALSE_VALUE
    END IF

    mcuXCount = (jpgWidth + mcuW - 1) \ mcuW
    mcuYCount = (jpgHeight + mcuH - 1) \ mcuH

    BitstreamInit bs, entropyBytes, entropySize
    FOR ci = 0 TO jpgCompCount - 1
        jpgCompPrevDc(ci) = 0
    NEXT

    ok = TRUE_VALUE
    mcuCounter = 0

    FOR my = 0 TO mcuYCount - 1
        FOR mx = 0 TO mcuXCount - 1
            FOR scanIndex = 0 TO jpgScanCompCount - 1
                ci = jpgScanCompIndex(scanIndex)
                FOR vb = 0 TO jpgCompV(ci) - 1
                    FOR hb = 0 TO jpgCompH(ci) - 1
                        IF DecodeJpegBlock(bs, ci, samples) = FALSE_VALUE THEN
                            ok = FALSE_VALUE
                            EXIT FOR
                        END IF

                        IF jpgCompCount = 1 THEN
                            StoreSolidBlockInPlane planeY, mcuW, mcuH, samples[0], hb, vb, jpgCompH(ci), jpgCompV(ci), hMax, vMax
                        ELSEIF ci = 0 THEN
                            StoreSolidBlockInPlane planeY, mcuW, mcuH, samples[0], hb, vb, jpgCompH(ci), jpgCompV(ci), hMax, vMax
                        ELSEIF ci = 1 THEN
                            StoreSolidBlockInPlane planeCb, mcuW, mcuH, samples[0], hb, vb, jpgCompH(ci), jpgCompV(ci), hMax, vMax
                        ELSEIF ci = 2 THEN
                            StoreSolidBlockInPlane planeCr, mcuW, mcuH, samples[0], hb, vb, jpgCompH(ci), jpgCompV(ci), hMax, vMax
                        END IF
                    NEXT
                    IF ok = FALSE_VALUE THEN EXIT FOR
                NEXT
                IF ok = FALSE_VALUE THEN EXIT FOR
            NEXT
            IF ok = FALSE_VALUE THEN EXIT FOR

            srcLeft = mx * mcuW
            srcTop = my * mcuH
            srcRightEx = srcLeft + mcuW
            srcBottomEx = srcTop + mcuH
            IF srcRightEx > jpgWidth THEN srcRightEx = jpgWidth
            IF srcBottomEx > jpgHeight THEN srcBottomEx = jpgHeight

            dstXStart = CINT((CLNGINT(srcLeft) * outW + jpgWidth - 1) \ jpgWidth)
            dstYStart = CINT((CLNGINT(srcTop) * outH + jpgHeight - 1) \ jpgHeight)
            dstXEnd = CINT((CLNGINT(srcRightEx) * outW - 1) \ jpgWidth)
            dstYEnd = CINT((CLNGINT(srcBottomEx) * outH - 1) \ jpgHeight)

            IF dstXStart < 0 THEN dstXStart = 0
            IF dstYStart < 0 THEN dstYStart = 0
            IF dstXEnd >= outW THEN dstXEnd = outW - 1
            IF dstYEnd >= outH THEN dstYEnd = outH - 1

            IF dstXStart <= dstXEnd AND dstYStart <= dstYEnd THEN
                FOR dstY = dstYStart TO dstYEnd
                    localY = CINT((CLNGINT(dstY) * jpgHeight) \ outH) - srcTop
                    IF localY < 0 THEN localY = 0
                    IF localY >= mcuH THEN localY = mcuH - 1

                    FOR dstX = dstXStart TO dstXEnd
                        localX = CINT((CLNGINT(dstX) * jpgWidth) \ outW) - srcLeft
                        IF localX < 0 THEN localX = 0
                        IF localX >= mcuW THEN localX = mcuW - 1

                        sampleIndex = CLNG(localY) * mcuW + localX
                        yVal = planeY[sampleIndex]
                        cbVal = planeCb[sampleIndex] - 128
                        crVal = planeCr[sampleIndex] - 128

                        IF jpgCompCount = 1 THEN
                            rVal = yVal
                            gVal = yVal
                            bVal = yVal
                        ELSE
                            rVal = yVal + ((91881 * crVal) \ 65536)
                            gVal = yVal - ((22554 * cbVal + 46802 * crVal) \ 65536)
                            bVal = yVal + ((116130 * cbVal) \ 65536)
                        END IF

                        colorVal = (CUINT(ClampByte(rVal)) SHL 16) OR (CUINT(ClampByte(gVal)) SHL 8) OR CUINT(ClampByte(bVal))
                        PutOutputPixel outBuf, outRowSize, dstX, dstY, colorVal
                    NEXT
                NEXT
            END IF

            mcuCounter = mcuCounter + 1
            IF jpgRestartInterval > 0 THEN
                IF (mcuCounter MOD jpgRestartInterval) = 0 THEN
                    bs.bitBuffer = 0
                    bs.bitCount = 0
                    FOR ci = 0 TO jpgCompCount - 1
                        jpgCompPrevDc(ci) = 0
                    NEXT
                END IF
            END IF
        NEXT
        IF ok = FALSE_VALUE THEN EXIT FOR
    NEXT

    IF ok <> FALSE_VALUE THEN
        IF WriteBmpBuffer24(outputFile, outBuf, outW, outH, outRowSize) = FALSE_VALUE THEN ok = FALSE_VALUE
    END IF

    IF samples <> 0 THEN DEALLOCATE samples
    IF planeCr <> 0 THEN DEALLOCATE planeCr
    IF planeCb <> 0 THEN DEALLOCATE planeCb
    IF planeY <> 0 THEN DEALLOCATE planeY
    IF outBuf <> 0 THEN DEALLOCATE outBuf

    IF ok = FALSE_VALUE THEN
        IF DIR(outputFile) <> "" THEN KILL outputFile
    END IF

    RETURN ok
END FUNCTION

' ---------------------------
' Top-level JPEG conversion entry point
' ---------------------------

FUNCTION ConvertJpegToBmp(BYVAL inputFile AS STRING, BYVAL outputFile AS STRING) AS INTEGER
    DIM f AS INTEGER
    DIM b1 AS UBYTE
    DIM b2 AS UBYTE
    DIM markerValue AS UBYTE
    DIM segLen AS USHORT
    DIM i AS INTEGER
    DIM scanComps AS UBYTE
    DIM scanId AS UBYTE
    DIM tableSel AS UBYTE
    DIM dummy AS UBYTE
    DIM ci AS INTEGER
    DIM found AS INTEGER
    DIM entropyBytes AS UBYTE PTR
    DIM entropySize AS LONG
    DIM ok AS INTEGER

    InitJpegTables

    jpgWidth = 0
    jpgHeight = 0
    jpgCompCount = 0
    jpgScanCompCount = 0
    jpgRestartInterval = 0
    FOR i = 0 TO 3
        jpgCompPrevDc(i) = 0
    NEXT

    f = FREEFILE
    IF OPEN(inputFile FOR BINARY ACCESS READ AS #f) <> 0 THEN RETURN FALSE_VALUE

    IF ReadByte(f, b1) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE
    IF ReadByte(f, b2) = FALSE_VALUE THEN CLOSE #f : RETURN FALSE_VALUE
    IF b1 <> &HFF OR b2 <> &HD8 THEN CLOSE #f : RETURN FALSE_VALUE

    entropyBytes = 0
    entropySize = 0
    ok = FALSE_VALUE

    DO
        IF ReadJpegMarker(f, markerValue) = FALSE_VALUE THEN EXIT DO

        SELECT CASE markerValue
        CASE &HD9
            EXIT DO

        CASE &HC0
            IF ReadUShortBE(f, segLen) = FALSE_VALUE THEN EXIT DO
            IF ParseSof0(f, segLen) = FALSE_VALUE THEN EXIT DO

        CASE &HC2
            CLOSE #f
            RETURN FALSE_VALUE

        CASE &HDB
            IF ReadUShortBE(f, segLen) = FALSE_VALUE THEN EXIT DO
            IF ParseDqt(f, segLen) = FALSE_VALUE THEN EXIT DO

        CASE &HC4
            IF ReadUShortBE(f, segLen) = FALSE_VALUE THEN EXIT DO
            IF ParseDht(f, segLen) = FALSE_VALUE THEN EXIT DO

        CASE &HDD
            IF ReadUShortBE(f, segLen) = FALSE_VALUE THEN EXIT DO
            IF ParseDri(f, segLen) = FALSE_VALUE THEN EXIT DO

        CASE &HDA
            IF ReadUShortBE(f, segLen) = FALSE_VALUE THEN EXIT DO
            IF segLen < 6 THEN EXIT DO
            IF ReadByte(f, scanComps) = FALSE_VALUE THEN EXIT DO
            IF scanComps < 1 OR scanComps > 3 THEN EXIT DO
            IF segLen <> 6 + scanComps * 2 THEN EXIT DO
            jpgScanCompCount = scanComps

            found = TRUE_VALUE
            FOR i = 0 TO scanComps - 1
                IF ReadByte(f, scanId) = FALSE_VALUE THEN found = FALSE_VALUE
                IF found <> FALSE_VALUE THEN
                    IF ReadByte(f, tableSel) = FALSE_VALUE THEN found = FALSE_VALUE
                END IF
                IF found <> FALSE_VALUE THEN
                    found = -1
                    FOR ci = 0 TO jpgCompCount - 1
                        IF jpgCompId(ci) = scanId THEN found = ci
                    NEXT
                    IF found < 0 THEN
                        found = FALSE_VALUE
                    ELSE
                        jpgScanCompIndex(i) = found
                        jpgCompDc(found) = (tableSel SHR 4) AND 15
                        jpgCompAc(found) = tableSel AND 15
                        found = TRUE_VALUE
                    END IF
                END IF
            NEXT
            IF found = FALSE_VALUE THEN EXIT DO

            IF ReadByte(f, dummy) = FALSE_VALUE THEN EXIT DO
            IF ReadByte(f, dummy) = FALSE_VALUE THEN EXIT DO
            IF ReadByte(f, dummy) = FALSE_VALUE THEN EXIT DO

            IF ReadJpegEntropy(f, entropyBytes, entropySize) = FALSE_VALUE THEN EXIT DO
            ok = DecodeJpegEntropy(entropyBytes, entropySize, outputFile)
            EXIT DO

        CASE &HD0 TO &HD7
            ' Standalone restart marker outside entropy data. Ignore.

        CASE ELSE
            IF ReadUShortBE(f, segLen) = FALSE_VALUE THEN EXIT DO
            IF SkipJpegSegment(f, segLen) = FALSE_VALUE THEN EXIT DO
        END SELECT
    LOOP

    CLOSE #f
    IF entropyBytes <> 0 THEN DEALLOCATE entropyBytes
    RETURN ok
END FUNCTION

' ---------------------------
' Command-line usage text
' ---------------------------

SUB PrintUsage()
    PRINT "IMGCODEC - Backlash external image converter"
    PRINT "Usage: IMGCODEC inputfile output.bmp [BG=r,g,b]"
    PRINT "Supports: BMP, GIF87a/GIF89a first frame, baseline JPG/JPEG"
END SUB

DIM inputFile AS STRING
DIM outputFile AS STRING
DIM ext AS STRING
DIM backColor AS UINTEGER
DIM parseOk AS INTEGER

inputFile = TRIM$(COMMAND(1))
outputFile = TRIM$(COMMAND(2))
backColor = (CUINT(255) SHL 16) OR (CUINT(255) SHL 8) OR CUINT(255)

IF COMMAND(3) <> "" THEN
    parseOk = ParseBgColor(COMMAND(3), backColor)
END IF

IF inputFile = "" OR outputFile = "" THEN
    PrintUsage
    END 1
END IF

ext = FileExtUpper(inputFile)

SELECT CASE ext
CASE "BMP"
    IF ConvertBmpToBmp24(inputFile, outputFile) = FALSE_VALUE THEN
        IF CopyBinaryFile(inputFile, outputFile) = FALSE_VALUE THEN
            PRINT "BMP conversion failed"
            END 2
        END IF
    END IF
    END 0

CASE "GIF"
    IF ConvertGifToBmp(inputFile, outputFile, backColor) = FALSE_VALUE THEN
        PRINT "GIF conversion failed"
        END 3
    END IF
    END 0

CASE "JPG", "JPEG"
    IF ConvertJpegToBmp(inputFile, outputFile) = FALSE_VALUE THEN
        PRINT "JPEG conversion failed"
        END 4
    END IF
    END 0

CASE ELSE
    PRINT "Unsupported input format: "; ext
    END 5
END SELECT
