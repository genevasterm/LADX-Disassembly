; Code for bank 0 ("Home").
; Unlike other banks, this code is always adressable at `0000:xxxx`, without
; the need to switch banks.

include "code/home/init.asm"
include "code/home/render_loop.asm"
include "code/home/interrupts.asm"

; Switch to the bank defined in a, and save the active bank
SwitchBank::
    ld   [wCurrentBank], a
    ld   [MBC3SelectBank], a
    ret

; Switch to the bank defined in a, depending on GB or GBC mode
SwitchAdjustedBank::
    call AdjustBankNumberForGBC
    ld   [wCurrentBank], a
    ld   [MBC3SelectBank], a
    ret

ReloadSavedBank::
    push af
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    pop  af
    ret

; Load the dungeon minimap tiles and palettes.
;
; The loading is done in several stages. hBGTilesLoadingStage controls which stage
; is to be executed. At the end of this function, hBGTilesLoadingStage is incremented by 1.
LoadDungeonMinimapTiles::
    ; Select the bank containing the dungeon minimap tiles
    ld   a, BANK(DungeonMinimapTiles)
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a

    ; If hBGTilesLoadingStage < 8, load the tiles
    ldh  a, [hBGTilesLoadingStage]
    cp   $08
    jr   c, .loadTiles

    ; If hBGTilesLoadingStage == 8, load the palette stage 1
    jr   nz, .paletteStage1End
    callsb CopyDungeonMinimapPalette
    ld   hl, hBGTilesLoadingStage
    inc  [hl]
    ret
.paletteStage1End

    ; If hBGTilesLoadingStage == 9, load the palette stage 2
    cp   $09
    jr   nz, .paletteStage2End
    callsb label_002_6827
    ld   hl, hBGTilesLoadingStage
    inc  [hl]
    ret
.paletteStage2End

    ; If hBGTilesLoadingStage == $0A, load the palette stage 3
    cp   $0A
    jr   nz, .paletteStage3End
    callsb label_002_680B
    ld   hl, hBGTilesLoadingStage
    inc  [hl]
    ret
.paletteStage3End

    ; else if hBGTilesLoadingStage >= $0B, load the palette stage 4…
    callsb label_002_67E5
    ; … and reset the loading stage to zero.
    xor  a
    ldh  [hNeedsUpdatingBGTiles], a
    ldh  [hBGTilesLoadingStage], a
    ret

.loadTiles
    ; tiles offset = [hBGTilesLoadingStage] * $40
    ld   c, a
    ld   b, $00
    sla  c
    rl   b
    sla  c
    rl   b
    sla  c
    rl   b
    sla  c
    rl   b
    sla  c
    rl   b
    sla  c
    rl   b
    ; destination = (vTiles1 + $500) + tiles offset
    ld   hl, vTiles1 + $500
    add  hl, bc
    ld   e, l
    ld   d, h
    ; origin = DungeonMinimapTiles + tiles offset
    ld   hl, DungeonMinimapTiles
    add  hl, bc
    ld   bc, $40
    ; Copy the tiles from ROM to tiles memory
    call CopyData
    ; Increment hBGTilesLoadingStage
    ldh  a, [hBGTilesLoadingStage]
    inc  a
    ldh  [hBGTilesLoadingStage], a
    ret

PlayAudioStep::
    callsw PlaySfx

    ; If a wave SFX is playing, return early
    ldh  a, [hWaveSfx]
    and  a
    jr   nz, .return

    ; If wMusicTrackTiming != 0…
    ld   a, [wMusicTrackTiming]
    and  a
    jr   z, .doAudioStep
    ; … and wMusicTrackTiming != 2…
    cp   $02
    ; … play two audio steps (double speed)
    jr   nz, .doAudioStepTwice
    ; Otherwise, play the audio step only on odd frames (half speed)
    ldh  a, [hFrameCounter]
    and  $01
    jr   nz, .return

    jr   .doAudioStep

.doAudioStepTwice
    call .doAudioStep
    ; Fallthrough to doAudioStep a second time

.doAudioStep
    ; TODO: clarify the respective purpose of these two functions
    callsw PlayMusicTrack_1B
    callsw PlayMusicTrack_1E

.return
    ret

;
; Palette-related code in bank $20
;

func_020_6A30_trampoline::
    callsb func_020_6A30

RestoreBankAndReturn::
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

func_020_6AC1_trampoline::
    callsb func_020_6AC1
    jr   RestoreBankAndReturn

func_020_6BA4_trampoline::
    callsb func_020_6BA4
    jr   RestoreBankAndReturn

ClearFileMenuBG_trampoline::
    push af
    callsb func_020_6BDC
    jr   RestoreStackedBankAndReturn

; Load file menu background and palette, then switch back to bank 1
LoadFileMenuBG_trampoline::
    callsb LoadFileMenuBG
    jr   LoadBank1AndReturn

CopyLinkTunicPalette_trampoline::
    callsb CopyLinkTunicPalette

LoadBank1AndReturn::
    ld   a, $01
    ld   [MBC3SelectBank], a
    ret

func_91D::
    push af
    ld   b, $00
    ld   a, [$DDD8]
    sla  a
    rl   b
    sla  a
    rl   b
    ld   c, a
    jr   .jp_92F

.jp_92E
    push af

.jp_92F
    callsb GetBGAttributesAddressForObject
    ldh  a, [hScratch8]
    ld   [MBC3SelectBank], a
    ld   hl, $DC91
    ld   a, [$DC90]
    ld   e, a
    add  a, $0A
    ld   [$DC90], a
    ld   d, $00
    add  hl, de
    ldh  a, [hScratch9]
    ld   d, a
    ldh  a, [hScratchA]
    ld   e, a
    ldh  a, [$FFCF]
    ldi  [hl], a
    ldh  a, [$FFD0]
    ldi  [hl], a
    ld   a, $81
    ldi  [hl], a
    ld   a, [de]
    ldi  [hl], a
    inc  de
    inc  de
    ld   a, [de]
    ldi  [hl], a
    dec  de
    ldh  a, [$FFCF]
    ldi  [hl], a
    ldh  a, [$FFD0]
    inc  a
    ldi  [hl], a
    ld   a, $81
    ldi  [hl], a
    ld   a, [de]
    ldi  [hl], a
    inc  de
    inc  de
    ld   a, [de]
    ldi  [hl], a
    xor  a
    ldi  [hl], a

; Restore bank saved on stack and return
RestoreStackedBankAndReturn::
    pop  af
    ld   [MBC3SelectBank], a
    ret

func_020_6D0E_trampoline::
    push af
    callsb func_020_6D0E
    jr   RestoreStackedBankAndReturn

; Load palette data
; Inputs:
;   b   ???
;   de  ???
; Returns:
;   a   palette data
func_983::
    ; Retrieve and store palette data into hScratch9 and hScratchA
    callsb func_01A_6710

    ; Switch to the bank containing this room's palettes
    ldh  a, [hScratch8]
    ld   [MBC3SelectBank], a

    ; Read value from address [hScratchA hScratch9]
    ldh  a, [hScratch9]
    ld   h, a
    ldh  a, [hScratchA]
    ld   l, a
    ld   a, [hl]

    inc  de
    ret

; Inputs:
;   a   ???
;   b   ???
;   de  ???
func_999::
    push af
    push bc
    call func_983

    ldh  [hScratch0], a
    pop  bc
    call func_983
    ldh  [hScratch1], a
    ld   a, [$DC90]
    ld   c, a
    ld   b, $00
    add  a, $05
    ld   [$DC90], a
    ld   hl, $DC91
    add  hl, bc
    ldh  a, [$FFCF]
    ldi  [hl], a
    ldh  a, [$FFD0]
    ldi  [hl], a
    ld   a, $01
    ldi  [hl], a
    ldh  a, [hScratch0]
    ldi  [hl], a
    ldh  a, [hScratch1]
    ldi  [hl], a
    xor  a
    ldi  [hl], a
    jr   RestoreStackedBankAndReturn

CheckPushedTombStone_trampoline::
    push af
    callsb CheckPushedTombStone
    jr   RestoreStackedBankAndReturn

func_020_4518_trampoline::
    push af
    ; Will lookup something in an entity id table
    callsb func_020_4518
    jr   RestoreStackedBankAndReturn

func_020_4874_trampoline::
    push af
    callsb func_020_4874
    jr   RestoreStackedBankAndReturn

func_020_4954_trampoline::
    push af
    callsb func_020_4954
    jp   RestoreStackedBankAndReturn

ReplaceObjects56and57_trampoline::
    push af
    callsb ReplaceObjects56and57
    jp   RestoreStackedBankAndReturn

;
; Specific data-copying routines
;

; Copy $100 bytes without DMA (used on DMG), then switch back to bank at h
; Inputs:
;  b   source address high byte
;  c   destination address high byte
;  h   bank to switch back after the transfert
Copy100Bytes_noDMA::
    ; Save h
    push hl

    ; Copy $100 bytes from "${b}00" to "${c}80"
    ld   l, $00
    ld   e, l
    ld   h, b
    ld   a, c
    add  a, $80
    ld   d, a
    ld   bc, $100
    call CopyData

    ; Switch back to the bank in h
    pop  hl
    jr   SelectBankAtHAndReturn

; Copy $100 bytes from bank at a, then switch back to bank at h
; Inputs:
;  a   bank to copy data from
;  b   source address high byte
;  c   destination address high byte
;  h   bank to switch back after the transfert
Copy100BytesFromBankAtA::
    ; Switch to bank in a
    ld   [MBC3SelectBank], a

    ; If running on DMG, use a loop to copy the data
    ldh  a, [hIsGBC]
    and  a
    jr   z, Copy100Bytes_noDMA

    ; On CGB, configure a DMA transfert
    ; to copy $0F bytes from "${b}00" to "${c}00"
    ld   a, b
    ld   [rHDMA1], a
    ld   a, $00
    ld   [rHDMA2], a
    ld   a, c
    ld   [rHDMA3], a
    ld   a, $00
    ld   [rHDMA4], a
    ld   a, $0F
    ld   [rHDMA5], a

    ; Fallthrough to switch back to the bank in h
SelectBankAtHAndReturn::
    ld   a, h
    ld   [MBC3SelectBank], a
    ret

; Copy Color Dungeon tiles?
CopyColorDungeonSymbols::
    push af
    ld   a, BANK(ColorDungeonTiles)
    ld   [MBC3SelectBank], a
    ld   hl, $4F00
    ld   de, $DCC0
    ld   bc, $20
    call CopyData
    jp   RestoreStackedBankAndReturn

;
; Various trampolines
;

func_036_505F_trampoline::
    push af
    callsb func_036_505F
    jp   RestoreStackedBankAndReturn

func_036_4F9B_trampoline::
    push af
    callsb func_036_4F9B
    jp   RestoreStackedBankAndReturn

func_A5F::
    push af
    ld   a, $20
    ld   [MBC3SelectBank], a
    call RenderActiveEntitySpritesRect
    jp   RestoreStackedBankAndReturn

func_003_5A2E_trampoline::
    push af
    callsb func_003_5A2E
    jp   RestoreStackedBankAndReturn

func_036_4F68_trampoline::
    push af
    callsb func_036_4F68
    jp   RestoreStackedBankAndReturn

func_020_6D52_trampoline::
    push af
    callsb func_020_6D52
    jp   RestoreStackedBankAndReturn

func_036_4BE8_trampoline::
    push af
    callsb func_036_4BE8
    jp   RestoreStackedBankAndReturn

func_A9B::
    push af
    ld   a, BANK(FontTiles)
    call SwitchBank
    call ExecuteDialog
    jp   RestoreStackedBankAndReturn

func_036_705A_trampoline::
    push af
    callsw func_036_705A

RestoreStackedBank::
    pop  af
    call SwitchBank
    ret

func_AB5::
    push af
    callsb func_024_5C1A
    ld   de, wRequest
    call ExecuteBackgroundCopyRequest
    jr   RestoreStackedBank

func_036_703E_trampoline::
    push af
    callsb func_036_703E
    jp   RestoreStackedBankAndReturn

func_036_70D6_trampoline::
    push af
    callsb func_036_70D6
    jp   RestoreStackedBankAndReturn

func_036_4A77_trampoline::
    push af
    callsw func_036_4A77
    jp   RestoreStackedBankAndReturn

func_036_4A4C_trampoline::
    push af
    callsb func_036_4A4C
    jp   RestoreStackedBankAndReturn

func_036_7161_trampoline::
    push af
    callsb func_036_7161
    jp   RestoreStackedBankAndReturn

; Load Background map and attributes for photo
LoadPhotoBgMap_trampoline::
    callsb LoadPhotoBgMap
    ret

; Toogle an extra byte to the bank number on GBC (on DMG, does nothing)
; Input:  a: the bank number to adjust
; Output: a: the adjusted bank number
AdjustBankNumberForGBC::
    push bc
    ld   b, a
    ldh  a, [hIsGBC]
    and  a           ; if !isGBC
    jr   z, .notGBC  ;   handle standard GB
    ld   a, b        ; else
    or   $20         ;   set 6-th bit of `a` to 1
    pop  bc          ;   restore registers
    ret              ;   return a
.notGBC
    ld   a, b        ; return the original value of a
    pop  bc
    ret

; Copy a block of data from a given bank to a target address in WRAM2,
; then return to bank 20.
; Inputs:
;   hScratch0 : source bank
;   bc :        number of bytes to copy
;   de :        destination address
;   hl :        source address
CopyObjectsAttributesToWRAM2::
    ldh  a, [hScratch0]
    ld   [MBC3SelectBank], a
    ld   a, $02
    ld   [rSVBK], a
    call CopyData
    xor  a
    ld   [rSVBK], a
    ; Restore bank $20
    ld   a, $20
    ld   [MBC3SelectBank], a
    ret

; On GBC, copy some overworld objects to ram bank 2
func_2BF::
    ldh  [hScratch2], a
    ldh  a, [hIsGBC]
    and  a
    ret  z

    ld   a, [wIsIndoor]
    and  a
    ret  nz

    push bc
    ldh  a, [hScratch2]
    and  $80
    jr   nz, .else
    callsb func_020_6E50
    jr   c, .endIf
.else
    ld   b, [hl]
    ld   a, $02
    ld   [rSVBK], a
    ld   [hl], b
    xor  a
    ld   [rSVBK], a
.endIf

    ldh  a, [hScratch2]
    and  $7F
    ld   [MBC3SelectBank], a
    pop  bc
    ret

; Copy data from bank in a, then switch back to bank $28
CopyData_trampoline::
    ld   [MBC3SelectBank], a
    call CopyData
    ld   a, $28
    ld   [MBC3SelectBank], a
    ret

; Copy data to vBGMap0
; Inputs:
;   a           source bank
;   hl          source address
;   hhScratchF  return bank to restore
CopyBGMapFromBank::
    push hl
    ld   [MBC3SelectBank], a

    ; If on GBC…
    ldh  a, [hIsGBC]
    and  a
    jr   z, .gbcEnd
    ; hl += $168
    ld   de, $168
    add  hl, de
    ; Switch to RAM bank 1
    ld   a, $01
    ld   [rVBK], a
    call CopyToBGMap0
    ; Switch back to RAM bank 0
    xor  a
    ld   [rVBK], a
.gbcEnd

    pop  hl
    push hl
    call CopyToBGMap0
    pop  hl

    ld   a, [wGameplayType]
    cp   GAMEPLAY_PHOTO_ALBUM
    jr   nz, .photoAlbumEnd
    call func_BB5
.photoAlbumEnd

    ldh  a, [hScratchF]
    ld   [MBC3SelectBank], a
    ret

CopyToBGMap0::
    ld   de, vBGMap0

.loop
    ld   a, [hli]
    ld   [de], a
    inc  e
    ld   a, e
    and  $1F
    cp   $14
    jr   nz, .loop
    ld   a, e
    add  a, $0C
    ld   e, a
    ld   a, d
    adc  a, $00
    ld   d, a
    cp   $9A
    jr   nz, .loop
    ld   a, e
    cp   $40
    jr   nz, .loop
    ret

func_BB5::
    ld   bc, $168
    ld   de, $D000
    jp   CopyData

LoadBaseTiles_trampoline::
    push af
    call LoadBaseTiles
    jp   RestoreStackedBankAndReturn

func_BC5::
    ld   a, [$D16A]
    ld   [MBC3SelectBank], a
.loop
    ld   a, [hli]
    ld   [de], a
    inc  de
    dec  b
    jr   nz, .loop

    ld   a, $28
    ld   [MBC3SelectBank], a
    ret

; Generic trampoline, for calling a function into another bank.
Farcall::
    ; Switch to bank wFarcallBank
    ld   a, [wFarcallBank]
    ld   [MBC3SelectBank], a
    ; Call the target function
    call Farcall_trampoline
    ; Switch back to bank wFarcallReturnBank
    ld   a, [wFarcallReturnBank]
    ld   [MBC3SelectBank], a
    ret

;Jump to address in wFarcallAdressHigh, wFarcallAdressLow
Farcall_trampoline::
    ld   a, [wFarcallAdressHigh]
    ld   h, a
    ld   a, [wFarcallAdressLow]
    ld   l, a
    jp   hl

func_BF0::
    ld   a, BANK(Data_002_4948)
    ld   [MBC3SelectBank], a
    call func_1A50
    jp   ReloadSavedBank

IsEntityDropTimerZero::
    ld   hl, wEntitiesDropTimerTable
    jr   IsZero

IsEntityUnknownFZero::
    ld   hl, wEntitiesUnknowTableF
    jr   IsZero

; Test if the frame counter for the given entity is 0
; Input:
;  - bc: entity number
; Output:
;  - a: the value read
;  - z: whether the value equal to zero
GetEntityTransitionCountdown::
    ld   hl, wEntitiesTransitionCountdownTable

; Test if the value at given address is equal to zero
; Inputs:
;  - hl: an address
;  - bc: an offset
; Output:
;  - a: the value read
;  - z: whether the value equal to zero
IsZero::
    add  hl, bc
    ld   a, [hl]
    and  a
    ret

; Create a new temporary entity with the current trading item.
; Used when Link trades a new item.
CreateTradingItemEntity::
    ld   a, ENTITY_TRADING_ITEM
    call SpawnNewEntity_trampoline
    ldh  a, [hLinkPositionX]
    ld   hl, wEntitiesPosXTable
    add  hl, de
    ld   [hl], a
    ldh  a, [hLinkPositionY]
    ld   hl, wEntitiesPosYTable
    add  hl, de
    ld   [hl], a
    ret

PlayWrongAnswerJingle::
    ld   a, JINGLE_WRONG_ANSWER
    ldh  [hJingle], a
    ret

ReadTileValueFromAsciiTable::
    ld   hl, AsciiToTileMap
    jr   ReadValueInDialogsBank

ReadDialogBankFromTable::
    ld   hl, DialogBankTable

ReadValueInDialogsBank::
    ld   a, BANK(AsciiToTileMap) ; or BANK(DialogBankTable)
    ld   [MBC3SelectBank], a
    add  hl, bc
    ld   a, [hl]
    ld   hl, MBC3SelectBank
    ld   [hl], $01
    ret

; Copy 4 tiles from bank $0C, then return to bank 1.
; Inputs:
;   hl:  target address of the instrument tiles
CopySirenInstrumentTiles::
    ld   a, BANK(SirenInstrumentsTiles)
    ld   [MBC3SelectBank], a
    ld   bc, $40
    call CopyData
    ld   a, $01
    ld   [MBC3SelectBank], a
    ret

PlayBombExplosionSfx::
    ld   hl, hNoiseSfx
    ld   [hl], NOISE_SFX_BOMB_EXPLOSION

func_C50::
    ld   hl, $C502
    ld   [hl], $04
    ret

func_C56::
    ld   hl, wEntitiesUnknowTableT
    add  hl, bc
    ld   a, [hl]
    and  a
    jr   z, .endIf
    dec  [hl]
.endIf
    ret

MarkTriggerAsResolved::
    push af

    ; If the event effect was already executed, return.
    ld   a, [wRoomEventEffectExecuted]
    and  a
    jr   nz, .return

    ; $C1CF = 0
    ld   [$C1CF], a
    ; wRoomEventEffectExecuted = $C5A6 = 1
    inc  a
    ld   [wRoomEventEffectExecuted], a
    ld   [$C5A6], a

    ; If $C19D == 0…
    ld   a, [$C19D]
    and  a
    jr   nz, .return
    ; play puzzle solved jingle
    ld   a, JINGLE_PUZZLE_SOLVED
    ldh  [hJingle], a
.return
    pop  af
    ret

ApplyMapFadeOutTransition::
    ld   a, $30
    ldh  [$FFA8], a
    jr   label_C9A

label_C83::
    ld   a, $30
    ldh  [$FFA8], a
    jr   label_C9E

label_C89::
    ld   a, [wWarp0MapCategory]
    cp   $01
    jr   nz, ApplyMapFadeOutTransition
    ld   a, [wIsIndoor]
    and  a
    jr   z, ApplyMapFadeOutTransition
    ld   a, $01
    ldh  [hFFBC], a

label_C9A::
    ld   a, NOISE_SFX_STAIRS
    ldh  [hNoiseSfx], a

label_C9E::
    ; Prevent Link from moving during the transition
    ld   a, LINK_MOTION_MAP_FADE_OUT
    ld   [wLinkMotionState], a

    ; Reset the transition variables
    xor  a
    ld   [wTransitionSequenceCounter], a
    ld   [$C16C], a
    ld   [$D478], a
    and  a
    ret

ResetSpinAttack::
    xor  a
    ld   [wIsUsingSpinAttack], a
    ld   [wSwordCharge], a

ResetPegasusBoots::
    xor  a
    ld   [wPegasusBootsChargeMeter], a
    ld   [wIsRunningWithPegasusBoots], a
    ret

CopyLinkFinalPositionToPosition::
    ldh  a, [hLinkFinalPositionX]
    ldh  [hLinkPositionX], a
    ldh  a, [hLinkFinalPositionY]
    ldh  [hLinkPositionY], a
    ret

; Display a temporary visual effect as a non-interacting sprite.
; The effect is automatically removed after a while.
;
; Inputs:
;   a           visual effect type
;   hScratch0   effect X position
;   hScratch1   effect Y position
AddTranscientVfx::
    push af
    ld   e, $0F
    ld   d, $00

    ; Find index of the last zero in the transcient VFXs table
.loop
    ld   hl, wTranscientVfxTypeTable
    add  hl, de
    ld   a, [hl]
    and  a
    jr   z, .jp_CEC
    dec  e
    ld   a, e
    cp   -1
    jr   nz, .loop

    ; If a zero value is not found, decrement $C5C0
    ld   hl, $C5C0
    dec  [hl]
    ; (wrap $C5C0 to $0F if it reached 0)
    ld   a, [hl]
    cp   -1
    jr   nz, .wrapEnd
    ld   a, $0F
    ld   [$C5C0], a
.wrapEnd

    ; e = $C5C0
    ld   a, [$C5C0]
    ld   e, a

.jp_CEC
    pop  af
    ld   hl, wTranscientVfxTypeTable
    add  hl, de
    ld   [hl], a
    ldh  a, [hScratch1]
    ld   hl, wTranscientVfxPosYTable
    add  hl, de
    ld   [hl], a
    ldh  a, [hScratch0]
    ld   hl, wTranscientVfxPosXTable
    add  hl, de
    ld   [hl], a
    ld   hl, wTranscientVfxCountdownTable
    add  hl, de
    ld   [hl], $0F
    ret

label_D07::
    ld   a, [$C140]
    sub  a, $08
    ldh  [hScratch0], a
    ld   a, [$C142]
    sub  a, $08
    ldh  [hScratch1], a

label_D15::
    ld   a, JINGLE_SWORD_POKING
    ldh  [hJingle], a
    ld   a, TRANSCIENT_VFX_SWORD_POKE
    jp   AddTranscientVfx

; Load sprites for the next room,
; either during a map transition or a room transition.
LoadRoomSprites::
    ld   a, $20
    ld   [MBC3SelectBank], a

    ; If is indoor…
    ld   a, [wIsIndoor]
    and  a
    jr   z, .overworld

    ;
    ; Indoor
    ;

    ldh  a, [hMapRoom]
    ld   e, a
    ld   d, $00
    ld   hl, data_020_6EB3
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .label_D3C
    ld   hl, data_020_70B3
    jr   .label_D45

.label_D3C
    cp   $1A
    jr   nc, .label_D45
    cp   $06
    jr   c, .label_D45
    inc  h

.label_D45
    add  hl, de
    ldh  a, [$FF94]
    ld   e, a
    ld   a, [hl]
    cp   e
    jr   z, .label_D57
    ldh  [$FF94], a
    cp   $FF
    jr   z, .label_D57
    ld   a, $01
    ldh  [hNeedsUpdatingBGTiles], a

.label_D57::
    jr   .indoorOutdoorEnd

.overworld
    ;
    ; Overworld
    ;

    ldh  a, [hMapRoom]
    cp   $07
    jr   nz, .label_D60
    inc  a

.label_D60
    ld   d, a
    srl  a
    srl  a
    and  $F8
    ld   e, a
    ld   a, d
    srl  a
    and  $07
    or   e
    ld   e, a
    ld   d, $00
    ld   hl, data_020_6E73
    add  hl, de
    ldh  a, [$FF94]
    ld   e, a
    ld   a, [hl]
    cp   e
    jr   z, .indoorOutdoorEnd
    cp   $0F
    jr   z, .indoorOutdoorEnd
    cp   $1A
    jr   nz, .label_D8B
    ldh  a, [hMapRoom]
    cp   $37
    jr   nz, .indoorOutdoorEnd
    ld   a, [hl]

.label_D8B
    ldh  [$FF94], a
    ld   a, $01
    ldh  [hNeedsUpdatingBGTiles], a

.indoorOutdoorEnd
    xor  a
    ldh  [hScratch0], a
    ldh  a, [hMapRoom]
    ld   e, a
    ld   d, $00
    ld   hl, $70D3
    ld   a, [wIsIndoor]
    ld   d, a
    ldh  a, [hMapId]
    cp   $1A
    jr   nc, .label_DAB
    cp   MAP_EAGLES_TOWER
    jr   c, .label_DAB
    inc  d

.label_DAB
    add  hl, de
    ld   e, [hl]
    ld   a, d
    and  a
    jr   z, .label_DC1
    ldh  a, [hMapId]
    cp   MAP_HOUSE
    jr   nz, .label_DDB
    ldh  a, [hMapRoom]
    cp   $B5
    jr   nz, .label_DDB
    ld   e, $3D
    jr   .label_DDB

.label_DC1
    ld   a, e
    cp   $23
    jr   nz, .label_DCE
    ld   a, [$D8C9]
    and  $20
    jr   z, .label_DCE
    inc  e

.label_DCE
    ld   a, e
    cp   $21
    jr   nz, .label_DDB
    ld   a, [$D8FD]
    and  $20
    jr   z, .label_DDB
    inc  e

.label_DDB
    ld   d, $00
    sla  e
    rl   d
    sla  e
    rl   d
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .label_DF1
    ld   a, $01
    ldh  [hNeedsUpdatingEnnemiesTiles], a
    jr   .return

.label_DF1
    ld   hl, $73F3
    ld   a, [wIsIndoor]
    and  a
    jr   z, .label_DFD
    ld   hl, $763B

.label_DFD
    add  hl, de
    ld   d, $00
    ld   bc, $C193

.loop
    ld   e, [hl]
    ld   a, [bc]
    cp   e
    jr   z, .label_E29
    ld   a, e
    cp   $FF
    jr   z, .label_E29
    ld   [bc], a
    ldh  a, [hScratch0]
    and  a
    jr   z, .label_E1E
    ld   a, d
    ld   [$C10D], a
    ld   a, $01
    ld   [wNeedsUpdatingNPCTiles], a
    jr   .label_E29

.label_E1E
    inc  a
    ldh  [hScratch0], a
    ld   a, d
    ld   [$C197], a
    ld   a, $01
    ldh  [hNeedsUpdatingEnnemiesTiles], a

.label_E29
    inc  hl
    inc  bc
    inc  d
    ld   a, d
    cp   $04
    jr   nz, .loop

.return
    jp   ReloadSavedBank

ExecuteGameplayHandler::
    ld   a, [wGameplayType]
    cp   GAMEPLAY_MINI_MAP ; If GameplayType < MINI_MAP
    jr   c, jumpToGameplayHandler
    cp   GAMEPLAY_WORLD ; If GameplayType != World
    jr   nz, presentSaveScreenIfNeeded
    ; If GameplayType == WORLD
    ld   a, [wGameplaySubtype]
    cp   GAMEPLAY_WORLD_DEFAULT ; If GameplaySubtype != 7 (standard overworld gameplay)
    jr   nz, jumpToGameplayHandler

presentSaveScreenIfNeeded::
    ; If a indoor/outdoor transition is running
    ld   a, [wTransitionSequenceCounter]
    cp   $04
    jr   nz, jumpToGameplayHandler

    ; If a dialog is visible, or the screen is animating from one map to another
    ld   a, [wDialogState]
    ld   hl, $C167
    or   [hl]
    ld   hl, wRoomTransitionState
    or   [hl]
    jr   nz, jumpToGameplayHandler

    ; If GameplayType > INVENTORY (i.e. photo album and pictures)
    ld   a, [wGameplayType]
    cp   GAMEPLAY_INVENTORY
    jr   nc, jumpToGameplayHandler

    ; If not all A + B + Start + Select buttons are pressed
    ldh  a, [hPressedButtonsMask]
    cp   J_A | J_B | J_START | J_SELECT
    jr   nz, jumpToGameplayHandler

    ; If $D474 != 0
    ld   a, [$D474]
    and  a
    jr   nz, jumpToGameplayHandler

    ; If $D464 != 0
    ld   a, [$D464]
    and  a
    jr   nz, jumpToGameplayHandler

    ; Present save screen
    xor  a ; Clear variables
    ld   [wTransitionSequenceCounter], a
    ld   [$C16C], a
    ld   [wDialogState], a
    ld   [wGameplaySubtype], a
    ld   a, GAMEPLAY_FILE_SAVE ; Set GameplayType to FILE_SAVE
    ld   [wGameplayType], a

jumpToGameplayHandler::
    ld   a, [wGameplayType]
    JP_TABLE
._00 dw IntroHandler
._01 dw EndCreditsHandler
._02 dw FileSelectionHandler
._03 dw FileCreationHandler
._04 dw FileDeletionHandler
._05 dw FileCopyHandler
._06 dw FileSaveHandler
._07 dw MinimapHandler
._08 dw PeachPictureHandler
._09 dw MarinBeachHandler
._0A dw FaceShrineMuralHandler
._0B dw WorldHandler
._0C dw InventoryHandler
._0D dw PhotoAlbumHandler
._0E dw PhotoPictureHandler ; Dizzy Link photo
._0F dw PhotoPictureHandler ; Good-looking Link photo
._10 dw PhotoPictureHandler ; Marin cliff photo (with cutscene)
._11 dw PhotoPictureHandler ; Marin well photo
._12 dw PhotoPictureHandler ; Mabe village photo (with cutscene)
._13 dw PhotoPictureHandler ; Ulrira photo
._14 dw PhotoPictureHandler ; Bow-wow photo (with cutscene)
._15 dw PhotoPictureHandler ; Thief photo
._16 dw PhotoPictureHandler ; Fisherman photo
._17 dw PhotoPictureHandler ; Zora photo
._18 dw PhotoPictureHandler ; Kanalet Castle photo (with cutscene)
._19 dw PhotoPictureHandler ; Ghost photo
._1A dw PhotoPictureHandler ; Bridge photo

FaceShrineMuralHandler::
    call FaceShrineMuralEntryPoint
    jp   returnFromGameplayHandler

PeachPictureHandler::
    call PeachPictureEntryPoint
    jp   returnFromGameplayHandler

MarinBeachHandler::
    call MarineBeachEntryPoint
    jp   returnFromGameplayHandler

MinimapHandler::
    call MinimapEntryPoint
    jp   returnFromGameplayHandler

FileSaveHandler::
    jpsw FileSaveEntryPoint

IntroHandler::
    jp   IntroHandlerEntryPoint

EndCreditsHandler::
    callsw EndCreditsEntryPoint
    jp   returnFromGameplayHandler

AnimateEntitiesAndRestoreBank17::
    ld   a, $03
    ld   [MBC3SelectBank], a
    ld   a, $17

; Call AnimateEntities, then restore bank in a
AnimateEntitiesAndRestoreBank::
    push af
    call AnimateEntities
    pop  af
    jp   SwitchBank

AnimateEntitiesAndRestoreBank01::
    ld   a, $03
    ld   [MBC3SelectBank], a
    ld   a, $01
    jr   AnimateEntitiesAndRestoreBank

AnimateEntitiesAndRestoreBank02::
    ld   a, $03
    ld   [MBC3SelectBank], a
    ld   a, $02
    jr   AnimateEntitiesAndRestoreBank

FileSelectionHandler::
    jp   FileSelectionEntryPoint

FileCreationHandler::
    jp   FileCreationEntryPoint

FileDeletionHandler::
    jp   FileDeletionEntryPoint

FileCopyHandler::
    jp   FileCopyEntryPoint

WorldHandler::
    ld   a, BANK(UpdatePaletteEffectForInteractiveObjects)
    ld   [MBC3SelectBank], a
    call UpdatePaletteEffectForInteractiveObjects
    call PerformOverworldAudioTasks
    jpsw WorldHandlerEntryPoint

InventoryHandler::
    jpsw InventoryEntryPoint

PhotoAlbumHandler::
    callsw PhotoAlbumEntryPoint
    jp   returnFromGameplayHandler

PhotoPictureHandler::
    jpsw PhotosEntryPoint

; World handler for GAMEPLAY_WORLD_DEFAULT (dispatched from WorldHandlerEntryPoint)
WorldDefaultHandler::
    ld   a, $02
    call SwitchBank
    ; If a dialog is already open, continue to the normal flow
    ld   a, [wDialogState]
    and  a
    jr   nz, .normalFlow

    ; If [$FFB4] != 0…
    ld   hl, $FFB4
    ld   a, [hl]
    and  a
    jr   z, .noDungeonName
    ; … and inventory window is not visible…
    ld   a, [wWindowY]
    cp   $80
    jr   nz, .noDungeonName
    ; … and inventory is not opening…
    ld   a, [wInventoryAppearing]
    and  a
    jr   nz, .noDungeonName
    ; … display the dungeon name.
    dec  [hl]
    jr   nz, .noDungeonName
    callsb OpenDungeonNameDialog
    call ReloadSavedBank
.noDungeonName

    ; If still no dialog is open…
    ld   a, [wDialogState]
    and  a
    jr   nz, .normalFlow

    ; … and a countdown to load the previous map is > 0…
    ld   a, [wLoadPreviousMapCountdown]
    and  a
    jr   z, .normalFlow

    ; … decrement the counter
    ld   hl, hLinkInteractiveMotionBlocked
    ld   [hl], $02
    dec  a
    ld   [wLoadPreviousMapCountdown], a

    ; If the countdown reached zero, apply the transition
    jr   nz, .normalFlow
    jp   ApplyMapFadeOutTransition

.normalFlow

    ; If $DBC7 > 0, decrement it
    ld   hl, $DBC7
    ld   a, [hl]
    and  a
    jr   z, .DBC7End
    dec  [hl]
.DBC7End

    ; Copy Link's position into Link's final position
    ldh  a, [hLinkPositionX]
    ldh  [hLinkFinalPositionX], a
    ldh  a, [hLinkPositionY]
    ldh  [hLinkFinalPositionY], a

    ld   hl, hLinkPositionZ
    sub  a, [hl]
    ldh  [$FFB3], a
    call func_002_60E0

    xor  a
    ld   [$C140], a
    ld   [$C13C], a
    ld   [$C13B], a

    ld   hl, $C11D
    res  7, [hl]

    ld   hl, $C11E
    res  7, [hl]

    ; Execute room events
    call label_002_593B

    callsw ApplyRoomTransition

    call ApplyGotItem

    ld   a, [$C15C]
    ld   [$C3CF], a

    callsb func_20_4B1F

    callsw func_019_7A9A

    call AnimateEntities
    callsw label_002_5487

    ld   hl, wRequestDestination
    ldh  a, [hFrameCounter]
    and  $03
    or   [hl]
    jr   nz, label_1012
    ld   a, [wLinkMotionState]
    cp   $02
    jr   nc, label_1012
    ld   c, $01
    ld   b, $00

label_1000::
    ld   e, $00
    ldh  a, [hFrameCounter]
    and  $04
    jr   z, .label_100A
    dec  c
    dec  e

.label_100A
    callsb func_020_5C9C

label_1012::
    callsw func_014_54F8

returnFromGameplayHandler::
    ; Present dialog if needed
    ld   a, BANK(FontTiles)
    call SwitchBank
    call ExecuteDialog

    ; If on DMG, return now to the main game loop
    ldh  a, [hIsGBC]
    and  a
    ret  z

    ; Load Background palettes if needed
    ; (and then return to the main game loop)
    ld   a, BANK(LoadBGPalettes)
    call SwitchBank
    jp   LoadBGPalettes

; Dialog to open, indexed by wDialogGotItem value
DialogForItem::
.gotItem1 db $008 ; Piece of Power
.gotItem2 db $00E ; Toadstool
.gotItem3 db $099 ; Magic powder
.gotItem4 db $028 ; Break pots (?)
.gotItem5 db $0EC ; Guardian Acorn

ApplyGotItem::
    ldh  a, [hLinkPositionY]
    ld   hl, hLinkPositionZ
    sub  a, [hl]
    ld   [$C145], a
    ld   a, [wDialogGotItem]
    and  a
    jr   z, InitGotItemSequence
    ld   a, [wDialogState]
    and  a
    jr   nz, .dispatchItemType

    ; Did the "got item" dialog countdown reached the target value yet?
    ld   hl, wDialogGotItemCountdown
    dec  [hl]
    ld   a, [hl]
    cp   $02
    jr   nz, .countdownNotFinished

    ; Dialog countdown reached the target value: open the "Got item" dialog
    ld   a, [wDialogGotItem]
    ld   e, a
    ld   d, $00
    ld   hl, DialogForItem - $01
    add  hl, de
    ld   a, [hl]
    call OpenDialog
    ld   a, $01

.countdownNotFinished
    and  a
    jr   nz, .dispatchItemType
    xor  a
    ld   [wDialogGotItem], a
    ld   [$C1A8], a
    jr   InitGotItemSequence

.dispatchItemType
    ld   a, [wDialogGotItem]
    ld   [$C1A8], a
    dec  a
    JP_TABLE
._00 dw HandleGotItemA
._01 dw HandleGotItemB
._02 dw HandleGotItemB
._03 dw HandleGotItemB
._04 dw HandleGotItemA

InitGotItemSequence::
    ldh  a, [hPressedButtonsMask]
    and  $B0
    jr   nz, .jp_10DB
    ldh  a, [hPressedButtonsMask]
    and  $40
    jr   z, .jp_10DB
    ld   a, [$D45F]
    inc  a
    ld   [$D45F], a
    cp   $04
    jr   c, .jp_10DF
    ldh  a, [hLinkInteractiveMotionBlocked]
    cp   $02
    jr   z, .jp_10DB
    ldh  a, [hLinkAnimationState]
    cp   $FF
    jr   z, .jp_10DB
    ld   a, [wLinkMotionState]
    cp   $02
    jr   nc, .jp_10DB
    ld   a, [wDialogState]
    ld   hl, $C167
    or   [hl]
    ld   hl, wRoomTransitionState
    or   [hl]
    jr   nz, .jp_10DB
    ld   a, [$D464]
    and  a
    jr   nz, .jp_10DB

    ; Show a location on the mini-map
    xor  a
    ld   [wTransitionSequenceCounter], a
    ld   [$C16C], a
    ld   [wGameplaySubtype], a
    ld   a, GAMEPLAY_MINI_MAP
    ld   [wGameplayType], a
    callsb func_002_755B
    call DrawLinkSprite
    call AnimateEntities
    pop  af
    ret

.jp_10DB
    xor  a
    ld   [$D45F], a

.jp_10DF
    ldh  a, [$FFB7]
    and  a
    jr   z, .jp_10E7
    dec  a
    ldh  [$FFB7], a

.jp_10E7
    ldh  a, [$FFB6]
    and  a
    jr   z, .jp_10EF
    dec  a
    ldh  [$FFB6], a

.jp_10EF
    ld   a, [wDialogState]
    and  a
    jp   nz, ApplyLinkMotionState
    ld   a, [wRoomTransitionState]
    and  a
    jp   nz, label_114F
    ld   a, [wLinkMotionState]
    cp   LINK_MOTION_PASS_OUT
    jr   z, .linkMotionJumpTable
    ld   a, [wHealth]
    ld   hl, $C50A
    or   [hl]
    ld   hl, wInventoryAppearing
    or   [hl]
    jr   nz, .handleLinkMotion
    ld   a, $07
    ld   [wLinkMotionState], a
    ld   a, $BF
    ldh  [$FFB7], a
    ld   a, $10
    ld   [$C3CC], a
    xor  a
    ld   [$DBC7], a
    ldh  [$FF9C], a
    ld   [$DDD6], a
    ld   [$DDD7], a
    ld   [$D464], a
    call label_27F2
    ld   a, WAVE_SFX_LINK_DIES
    ldh  [hWaveSfx], a

.handleLinkMotion
    ld   a, [wLinkMotionState]
.linkMotionJumpTable
    JP_TABLE
._00 dw LinkMotionInteractiveHandler
._01 dw LinkMotionFallingUpHandler
._02 dw LinkMotionJumpingHandler
._03 dw LinkMotionMapFadeOutHandler
._04 dw LinkMotionMapFadeInHandler
._05 dw LinkMotionRevolvingDoorHandler
._06 dw LinkMotionFallingDownHandler
._07 dw LinkMotionPassOutHandler
._08 dw LinkMotionRecoverHandler
._09 dw LinkMotionTeleportUpHandler
._0F dw LinkMotionUnknownHandler

label_114F::
    call ApplyLinkMotionState
    jp   DrawLinkSpriteAndReturn

LinkMotionTeleportUpHandler::
    jpsw func_019_5D6A

LinkMotionPassOutHandler::
    jpsw LinkPassOut

LinkMotionInteractiveHandler::
    callsb func_036_725A
    and  a
    ret  z

    jpsw label_002_4287

Func_1177::
    ld   a, [$C50A]
    ld   hl, $C167
    or   [hl]
    ld   hl, $C1A4
    or   [hl]
    ret  nz
    ld   a, [wIsRunningWithPegasusBoots]
    and  a
    jr   z, label_11BC
    ld   a, [wBButtonSlot]
    cp   $01
    jr   z, label_11AA
    ld   a, [wAButtonSlot]
    cp   $01
    jr   z, label_11AA
    ld   a, [wBButtonSlot]
    cp   $04
    jr   z, label_11A5
    ld   a, [wAButtonSlot]
    cp   $04
    jr   nz, label_11BA

label_11A5::
    call SetShieldVals
    jr   label_11BA

label_11AA::
    ld   a, [wSwordAnimationState]
    dec  a
    cp   $04
    jr   c, label_11BA
    ld   a, $05
    ld   [wSwordAnimationState], a
    ld   [$C16A], a

label_11BA::
    jr   label_11C3

label_11BC::
    xor  a
    ld   [wIsUsingShield], a
    ld   [wHasMirrorShield], a

label_11C3::
    ld   a, [$C117]
    and  a
    jp   nz, label_12ED
    ld   a, [$C15C]
    and  a
    jp   nz, label_12ED
    ld   a, [wSwordAnimationState]
    and  a
    jr   z, label_11E2
    cp   $03
    jr   nz, label_11E2
    ld   a, [$C138]
    cp   $03
    jr   nc, label_11E8

label_11E2::
    ldh  a, [hLinkInteractiveMotionBlocked]
    and  a
    jp   nz, label_12ED

label_11E8::
    ld   a, [wAButtonSlot]
    cp   $08
    jr   nz, label_11FE
    ldh  a, [hPressedButtonsMask]
    and  $20
    jr   z, label_11FA
    call UsePegasusBoots
    jr   label_11FE

label_11FA::
    xor  a
    ld   [wPegasusBootsChargeMeter], a

label_11FE::
    ld   a, [wBButtonSlot]
    cp   $08
    jr   nz, label_1214
    ldh  a, [hPressedButtonsMask]
    and  $10
    jr   z, label_1210
    call UsePegasusBoots

label_120E::
    jr   label_1214

label_1210::
    xor  a
    ld   [wPegasusBootsChargeMeter], a

label_1214::
    ld   a, [wBButtonSlot]
    cp   $04
    jr   nz, label_1235
    ld   a, [wShieldLevel]
    ld   [wHasMirrorShield], a
    ldh  a, [hPressedButtonsMask]
    and  $10
    jr   z, label_1235
    ld   a, [$C1AD]
    cp   $01
    jr   z, label_1235
    cp   $02
    jr   z, label_1235
    call SetShieldVals

label_1235::
    ld   a, [wAButtonSlot]
    cp   $04
    jr   nz, label_124B
    ld   a, [wShieldLevel]
    ld   [wHasMirrorShield], a
    ldh  a, [hPressedButtonsMask]
    and  $20
    jr   z, label_124B
    call SetShieldVals

label_124B::
    ldh  a, [$FFCC]
    and  $20
    jr   z, label_125E
    ld   a, [$C1AD]
    cp   $02
    jr   z, label_125E
    ld   a, [wAButtonSlot]
    call ItemFunction

label_125E::
    ldh  a, [$FFCC]
    and  $10
    jr   z, label_1275
    ld   a, [$C1AD]
    cp   $01
    jr   z, label_1275
    cp   $02
    jr   z, label_1275
    ld   a, [wBButtonSlot]
    call ItemFunction

label_1275::
    ldh  a, [hPressedButtonsMask]
    and  $20
    jr   z, label_1281
    ld   a, [wAButtonSlot]
    call label_1321

label_1281::
    ldh  a, [hPressedButtonsMask]
    and  $10
    jr   z, label_128D
    ld   a, [wBButtonSlot]
    call label_1321

label_128D::
    ; Special code for the Color Dungeon
    callsb func_020_48CA
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

ItemFunction::
    ld   c, a
    cp   $01
    jp   z, UseSword
    cp   $04
    jp   z, UseShield
    cp   $02
    jp   z, PlaceBomb
    cp   $03
    jp   z, UsePowerBracelet
    cp   $05
    jp   z, ShootArrow
    cp   $0D
    jp   z, UseBoomerang
    cp   $06
    jp   z, UseHookshot
    cp   $0A
    jp   z, UseRocksFeather
    cp   $09
    jp   z, UseOcarina
    cp   $0C
    jp   z, UseMagicPowder
    cp   $0B
    jp   z, UseShovel
    cp   $07 ; Magic wand
    jr   nz, label_12ED ; Jump to use boots?
    ld   hl, wSwordAnimationState
    ld   a, [$C19B]
    or   [hl]
    jr   nz, label_12ED
    ld   a, [wActiveProjectileCount]
    cp   $02
    jr   nc, label_12ED
    ld   a, $8E
    ld   [$C19B], a

label_12ED::
    ret

UseShield::
    ld   a, [$C144]
    and  a
    ret  nz
    ld   a, NOISE_SFX_DRAW_SHIELD
    ldh  [hNoiseSfx], a
    ret

UseShovel::
    ld   a, [$C1C7]
    ld   hl, $C146
    or   [hl]
    ret  nz

    call func_002_4D20
    jr   nc, .notPoking

    ld   a, JINGLE_SWORD_POKING
    ldh  [hJingle], a
    jr   .endIf

.notPoking
    ld   a, NOISE_SFX_SHOWEL_DIG
    ldh  [hNoiseSfx], a
.endIf

    ld   a, $01
    ld   [$C1C7], a
    xor  a
    ld   [$C1C8], a
    ret

UseHookshot::
    ld   a, [$C1A4]
    and  a
    ret  nz
    jp   FireHookshot

label_1321::
    cp   $01
    ret  nz
    ld   hl, wSwordAnimationState
    ld   a, [$C1AD]
    and  $03
    or   [hl]
    ret  nz
    ld   a, [$C160]
    and  a
    ret  nz
    xor  a
    ld   [$C1AC], a
    ld   a, $05
    ld   [wSwordAnimationState], a
    ld   [$C5B0], a
    ret

SetShieldVals::
    ld   a, $01
    ld   [wIsUsingShield], a
    ld   a, [wShieldLevel]
    ld   [wHasMirrorShield], a
    ; fallthrough

func_020_4B4A_trampoline::
    callsb func_020_4B4A
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

PlaceBomb::
    ld   a, [wHasPlacedBomb]
    cp   $01
    ret  nc
    ld   a, [wBombCount]
    and  a
    jp   z, PlayWrongAnswerJingle
    sub  a, $01
    daa
    ld   [wBombCount], a
    ld   a, ENTITY_BOMB
    call SpawnPlayerProjectile
    ret  c

func_1373::
    callsb func_020_4B81
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

UsePowerBracelet::
    ret

UseBoomerang::
    ld   a, [wActiveProjectileCount]
    and  a

label_1387::
    ret  nz
    ld   a, ENTITY_BOOMERANG
    call SpawnPlayerProjectile
    ret  c
    callsb func_020_4BFF
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

data_139D::
    db   0, 0, 0, 0

data_13A1::
    db   0, 0, 0, 0

data_13A5::
    db   $20, $E0, 0, 0

data_13A9::
    db   0, 0, $E0, $20

data_13AD::
    db   $30, $D0, 0, 0, $40, $C0, 0, 0

data_13B5::
    db   0, 0, $D0, $30, 0, 0, $C0, $40

ShootArrow::
    ld   a, [wIsShootingArrow]
    and  a
    ret  nz
    ld   a, [wActiveProjectileCount]
    cp   $02
    jr   nc, label_142E
    ld   a, $10
    ld   [wIsShootingArrow], a
    ld   a, [wArrowCount]
    and  a
    jp   z, PlayWrongAnswerJingle
    sub  a, $01
    daa
    ld   [wArrowCount], a
    call label_157C
    ld   a, ENTITY_ARROW
    call SpawnPlayerProjectile
    ret  c
    ld   a, e
    ld   [$C1C2], a
    ld   a, [wBombArrowCooldown]
    and  a
    jr   z, label_1401
    ld   a, [$C1C1]
    ld   c, a
    ld   b, d
    ld   hl, wEntitiesStatusTable
    add  hl, bc
    ld   [hl], b
    ld   hl, $C290
    add  hl, de
    ld   [hl], $01
    xor  a
    jr   label_1407

label_1401::
    ld   a, NOISE_SFX_SHOOT_ARROW
    ldh  [hNoiseSfx], a
    ld   a, $06

label_1407::
    ld   [wBombArrowCooldown], a
    ldh  a, [hLinkDirection]
    ld   c, a
    ld   b, $00

label_140F::
    ld   a, [wActivePowerUp]
    cp   $01
    jr   nz, label_141A
    ld   a, c
    add  a, $04
    ld   c, a

label_141A::
    ld   hl, data_13AD
    add  hl, bc
    ld   a, [hl]
    ld   hl, wEntitiesSpeedXTable
    add  hl, de
    ld   [hl], a
    ld   hl, data_13B5
    add  hl, bc
    ld   a, [hl]
    ld   hl, wEntitiesSpeedYTable
    add  hl, de
    ld   [hl], a

label_142E::
    ret

; Spawn a arrow, liftable rock, hookshot element…
; with the same X, Y, Z and speed than the player.
SpawnPlayerProjectile::
    call SpawnNewEntity_trampoline
    ret  c

    ld   a, $0C
    ld   [$C19B], a
    push bc
    ldh  a, [hLinkDirection]
    ld   c, a
    ld   b, $00
    ld   hl, data_139D
    add  hl, bc
    ldh  a, [hLinkPositionX]
    add  a, [hl]
    ld   hl, wEntitiesPosXTable
    add  hl, de
    ld   [hl], a
    ld   hl, data_13A1
    add  hl, bc
    ldh  a, [hLinkPositionY]
    add  a, [hl]
    ld   hl, wEntitiesPosYTable
    add  hl, de
    ld   [hl], a
    ldh  a, [hLinkPositionZ]
    inc  a
    ld   hl, wEntitiesPosZTable
    add  hl, de
    ld   [hl], a
    ld   hl, data_13A5
    add  hl, bc
    ld   a, [hl]
    ld   hl, wEntitiesSpeedXTable
    add  hl, de
    ld   [hl], a
    ld   hl, data_13A9
    add  hl, bc
    ld   a, [hl]
    ld   hl, wEntitiesSpeedYTable
    add  hl, de
    ld   [hl], a
    ldh  a, [hLinkDirection]
    ld   hl, $C3B0
    add  hl, de
    ld   [hl], a
    ld   hl, wEntitiesDirectionTable
    add  hl, de
    ld   [hl], a
    ld   hl, $C5D0
    add  hl, de
    ld   [hl], a
    ld   hl, wEntitiesUnknowTableJ
    add  hl, de
    ld   [hl], $01
    pop  bc
    scf
    ccf
    ret

UseMagicPowder::
    ld   a, [$C19B]
    and  a
    ret  nz
    ld   a, [wHasToadstool]
    and  a
    jr   z, label_14A7
    ldh  a, [hLinkPositionZ]
    and  a
    ret  nz
    ld   a, $02
    ld   [wDialogGotItem], a
    ld   a, $2A
    ld   [wDialogGotItemCountdown], a
    ret

label_14A7::
    ld   a, [wMagicPowderCount]
    and  a
    jp   z, PlayWrongAnswerJingle

    ld   a, ENTITY_MAGIC_POWDER_SPRINKLE
    call SpawnNewEntity_trampoline
    ret  c
    callsb func_020_4C47
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

data_14C3::
    db $1C, $E4, 0, 0

data_14C7::
    db 0, 0, $E4, $1C

UseRocksFeather::
    ld   a, [$C130]
    cp   $07
    ret  z
    ld   a, [$C146]
    and  a
    ret  nz
    ld   a, $01
    ld   [$C146], a
    xor  a
    ld   [$C152], a
    ld   [$C153], a
    ld   a, JINGLE_FEATHER_JUMP
    ldh  [hJingle], a
    ldh  a, [hIsSideScrolling]
    and  a
    jr   z, label_1508
    call label_1508
    ldh  a, [hPressedButtonsMask]
    and  $03
    ld   a, $EA
    jr   z, label_14F8
    ld   a, $E8

label_14F8::
    ldh  [hLinkPositionYIncrement], a
    xor  a
    ldh  [$FFA3], a
    call UpdateFinalLinkPosition
    jpsw CheckPositionForMapTransition

label_1508::
    ld   a, $20
    ldh  [$FFA3], a
    ld   a, [wIsRunningWithPegasusBoots]
    and  a
    ret  z
    ldh  a, [hLinkDirection]
    ld   e, a
    ld   d, b
    ld   hl, data_14C3
    add  hl, de
    ld   a, [hl]
    ldh  [hLinkPositionXIncrement], a
    ld   hl, data_14C7
    add  hl, de
    ld   a, [hl]
    ldh  [hLinkPositionYIncrement], a

label_1523::
    ret

SwordRandomSfxTable::
    db   NOISE_SFX_SWORD_A, NOISE_SFX_SWORD_B, NOISE_SFX_SWORD_C, NOISE_SFX_SWORD_D

UseSword::
    ld   a, [$C16D]
    ld   hl, wIsUsingSpinAttack
    or   [hl]
    ret  nz
    ld   a, $03
    ld   [$C138], a

label_1535::
    ld   a, $01
    ld   [wSwordAnimationState], a
    ld   [$C5B0], a
    xor  a
    ld   [$C160], a
    ld   [$C1AC], a

    ; Play a random SFX
    call GetRandomByte
    and  $03
    ld   e, a
    ld   d, $00
    ld   hl, SwordRandomSfxTable
    add  hl, de
    ld   a, [hl]
    ldh  [hNoiseSfx], a

    call label_157C
    ld   a, [$C146]
    and  a
    jr   nz, label_1562
    call ResetSpinAttack
    call ClearLinkPositionIncrement

label_1562::
    ld   a, [wActiveProjectileCount]
    and  a
    ret  nz
    ld   a, [$C5A9]
    and  a
    ret  z
    ld   a, [wSwordLevel]
    cp   $02
    ret  nz
    ld   a, ENTITY_SWORD_BEAM
    call SpawnPlayerProjectile
    xor  a
    ld   [$C19B], a
    ret

label_157C::
    ldh  a, [hPressedButtonsMask]
    and  $0F
    ld   e, a
    ld   d, $00
    ld   hl, $4905
    add  hl, de
    ld   a, [hl]
    cp   $0F
    jr   z, .return
    ldh  [hLinkDirection], a
.return
    ret

SwordCollisionMapX::
    ; Single sword swing (right-left-top-bottom)
    db $16, $FA, $08, $08
    ; Spin attack (anti-clockwise from right)
    db $16, $16, $08, $FA, $FA, $FA, $08, $16

SwordCollisionMapY::
    ; Single sword swing (right-left-top-bottom)
    db $08, $08, $FA, $16
    ; Spin attack (anti-clockwise from right)
    db $08, $16, $16, $16, $08, $FA, $FA, $FA

; Check sword collisions with static elements and objects, then return to bank 2
CheckStaticSwordCollision_trampoline::
    call CheckStaticSwordCollision
    ld   a, $02
    jp   SwitchBank

; Check sword collision with static elements (bushes, grasses)
; and items lying on the floor.
CheckStaticSwordCollision::
    ld   a, [$C1C4]
    and  a
    ret  nz
    ld   a, [wIsRunningWithPegasusBoots]
    and  a
    jr   nz, .label_15C0
    ld   a, [$C16A]
    cp   $05
    ret  z
.label_15C0

    ; a = IsUsingSpinAttack ? (SwordDirection + 4) : LinkDirection
    ld   a, [wIsUsingSpinAttack]
    and  a
    jr   z, .notSpinning
    ld   a, [wSwordDirection]
    add  a, $04
    jr   .end
.notSpinning
    ldh  a, [hLinkDirection]
.end

    ; Compute the horizontal intersected area
    ld   e, a
    ld   d, $00
    ld   hl, SwordCollisionMapX
    add  hl, de
    ldh  a, [hLinkPositionX]
    add  a, [hl]
    sub  a, $08
    and  $F0
    ldh  [hSwordIntersectedAreaX], a

    ; Compute the vertical intersected area
    swap a
    ld   c, a
    ld   hl, SwordCollisionMapY
    add  hl, de
    ldh  a, [hLinkPositionY]
    add  a, [hl]
    sub  a, $10
    and  $F0
    ldh  [hSwordIntersectedAreaY], a
    or   c
    ld   e, a
    ld   hl, wRoomObjects
    add  hl, de
    ld   a, h
    cp   $D7
    ret  nz
    push de
    ld   a, [hl]
    ldh  [hObjectUnderEntity], a
    ld   e, a
    ld   a, [wIsIndoor]
    ld   d, a
    call ReadValueFromBaseMap_trampoline
    pop  de

    cp   $D0
    jp   c, .label_1610

    cp   $D4
    jp   c, CheckItemsSwordCollision

.label_1610
    cp   $90
    jp   nc, CheckItemsSwordCollision

    cp   $01
    jp   z, CheckItemsSwordCollision

    ld   c, $00
    ld   a, [wIsIndoor]
    and  a
    ldh  a, [hObjectUnderEntity]
    jr   z, label_1629

    cp   $DD
    jr   z, label_1637

    ret

label_1629::
    inc  c
    cp   $D3
    jr   z, label_1637
    cp   $5C
    jr   z, label_1637
    cp   $0A
    ret  nz
    ld   c, $FF

label_1637::
    ld   a, c
    ldh  [hActiveEntitySpriteVariant], a
    call func_014_5526_trampoline
    ld   a, [wIsRunningWithPegasusBoots]
    and  a
    jr   nz, label_1653
    ld   a, [$C16A]
    cp   $05
    jr   nz, label_1653
    xor  a
    ld   [wSwordCharge], a
    ld   a, $0C
    ld   [$C16D], a

label_1653::
    ld   a, ENTITY_ENTITY_LIFTABLE_ROCK
    call SpawnPlayerProjectile
    jr   c, .dropRandomItem
    xor  a
    ld   [$C19B], a
    ld   hl, wEntitiesPosXTable
    add  hl, de
    ldh  a, [hSwordIntersectedAreaX]
    add  a, $08
    ld   [hl], a
    ld   hl, wEntitiesPosYTable
    add  hl, de
    ldh  a, [hSwordIntersectedAreaY]
    add  a, $10
    ld   [hl], a
    ld   hl, $C3B0
    add  hl, de
    ldh  a, [hActiveEntitySpriteVariant]
    ld   [hl], a
    ld   c, e
    ld   b, d
    call label_3942

.dropRandomItem
    ; In some random cases, don't drop anything.
    call GetRandomByte
    and  $07
    ret  nz

    ; If stairs are hiding behind the cut bush, don't drop anything.
    ldh  a, [hObjectUnderEntity]
    cp   OBJECT_BUSH_GROUND_STAIRS
    ret  z

    ; Randomly drop a rupee or heart
    call GetRandomByte
    rra
    ld   a, ENTITY_DROPPABLE_RUPEE
    jr   nc, .randomEnd
    ld   a, ENTITY_DROPPABLE_HEART
.randomEnd
    call SpawnNewEntity_trampoline
    ret  c

    ; Configure the dropped entity
    ld   hl, wEntitiesPosXTable
    add  hl, de
    ldh  a, [hSwordIntersectedAreaX]
    add  a, $08
    ld   [hl], a
    ld   hl, wEntitiesPosYTable
    add  hl, de
    ldh  a, [hSwordIntersectedAreaY]
    add  a, $10
    ld   [hl], a
    ld   hl, wEntitiesDropTimerTable
    add  hl, de
    ld   [hl], $80
    ld   hl, $C2F0
    add  hl, de
    ld   [hl], $18
    ld   hl, wEntitiesSpeedZTable
    add  hl, de
    ld   [hl], $10
    ret

data_16BA::
    db $12, $EE, $FC, 4

data_16BE::
    db 4, 4, $EE, $12

; Check sword collision with items lying on the ground
CheckItemsSwordCollision::
    ld   c, a
    ld   a, [$C16D]
    and  a
    ret  z
    ldh  a, [hLinkDirection]
    ld   e, a
    ld   d, $00
    ld   hl, data_16BA
    add  hl, de
    ldh  a, [hLinkPositionX]
    add  a, [hl]
    ldh  [hScratch0], a
    ld   hl, data_16BE
    add  hl, de
    ldh  a, [hLinkPositionY]
    add  a, [hl]
    ldh  [hScratch1], a
    ld   a, $04
    ld   [$C502], a
    call label_D15
    ld   a, $10
    ld   [$C1C4], a
    ld   a, c
    and  $F0
    cp   $90
    jr   z, .label_16F8
    ld   a, JINGLE_SWORD_POKING
    ldh  [hJingle], a
    ret

.label_16F8
    ld   a, $17
    ldh  [hNoiseSfx], a
    ret

data_16FD::
    db   $20, $E0, 0, 0

data_1701::
    db   0, 0, $E0, $20

UsePegasusBoots::
    ldh  a, [hIsSideScrolling]
    and  a
    jr   z, .label_1713
    ldh  a, [$FF9C]
    and  a
    ret  nz
    ldh  a, [hLinkDirection]
    and  $02
    ret  nz

.label_1713
    ld   a, [wIsRunningWithPegasusBoots]
    and  a
    ret  nz
    ldh  a, [hLinkPositionZ]
    ld   hl, $C146
    or   [hl]
    ret  nz
    ld   a, [$C120]
    add  a, $02
    ld   [$C120], a
    call func_1756
    ld   a, [wPegasusBootsChargeMeter]
    inc  a
    ld   [wPegasusBootsChargeMeter], a
    cp   $20
    ret  nz
    ld   [wIsRunningWithPegasusBoots], a
    xor  a
    ld   [wIsUsingSpinAttack], a
    ld   [wSwordCharge], a
    ldh  a, [hLinkDirection]
    ld   e, a
    ld   d, $00
    ld   hl, data_16FD
    add  hl, de
    ld   a, [hl]
    ldh  [hLinkPositionXIncrement], a
    ld   hl, data_1701
    add  hl, de
    ld   a, [hl]
    ldh  [hLinkPositionYIncrement], a
    xor  a
    ld   [$C1AC], a
    ret

func_1756::
    ldh  a, [hFrameCounter]
    and  $07
    ld   hl, hLinkPositionZ
    or   [hl]
    ld   hl, hLinkInteractiveMotionBlocked
    or   [hl]
    ld   hl, $C146
    or   [hl]
    ret  nz
    ldh  a, [hLinkPositionX]
    ldh  [hScratch0], a
    ld   a, [$C181]
    cp   $05
    jr   z, .label_1781
    ld   a, NOISE_SFX_FOOTSTEP
    ldh  [hNoiseSfx], a
    ldh  a, [hLinkPositionY]
    add  a, $06
    ldh  [hScratch1], a
    ld   a, TRANSCIENT_VFX_PEGASUS_DUST
    jp   AddTranscientVfx

.label_1781
    ldh  a, [hLinkPositionY]
    ldh  [hScratch1], a
    ld   a, JINGLE_WATER_DIVE
    ldh  [hJingle], a
    ld   a, TRANSCIENT_VFX_PEGASUS_SPLASH
    jp   AddTranscientVfx

ClearLinkPositionIncrement::
    xor  a
    ldh  [hLinkPositionXIncrement], a
    ldh  [hLinkPositionYIncrement], a
    ret

; Animate Link motion?
ApplyLinkMotionState::
    call label_753A
.skipInitialCall
    ld   a, [wLinkMotionState]
    cp   $01
    ret  z
    ld   a, [$C16A]
    and  a
    jr   z, .label_17DB
    ld   bc, $C010
    ld   a, [$C145]
    ld   hl, $C13B
    add  a, [hl]
    ldh  [hScratch0], a
    ldh  a, [hLinkPositionX]
    ldh  [hScratch1], a
    ld   hl, hScratch3
    ld   [hl], $00
    ld   a, [wSwordCharge]
    cp   $28
    jr   c, .label_17C6
    ldh  a, [hFrameCounter]
    rla
    rla
    and  $10
    ld   [hl], a

.label_17C6
    ld   a, [$C139]
    ld   h, a
    ld   a, [$C13A]
    ld   l, a
    ld   a, [wSwordDirection]
    ldh  [hScratch2], a
    ldh  a, [hLinkPositionY]
    cp   $88
    ret  nc
    jp   func_1819

.label_17DB
    ld   a, [$C19B]
    push af
    bit  7, a
    jp   z, .magicRodEnd
    callsw label_002_5310
    ld   a, [$C19B]
    and  $7F
    cp   $0C
    jr   nz, .magicRodEnd
    ld   hl, wDialogState
    ld   a, [wRoomTransitionState]
    or   [hl]
    jr   nz, .magicRodEnd
    call label_157C
    ld   a, ENTITY_HOOKSHOT_HIT
    call SpawnPlayerProjectile
    jr   c, .magicRodEnd
    ld   a, NOISE_SFX_MAGIC_ROD
    ldh  [hNoiseSfx], a
    callsw label_002_538B
.magicRodEnd

    pop  af
    ld   [$C19B], a
    ret

func_1819::
    callsb func_020_4AB3
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

func_1828::
    callsb func_020_49BA
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

LinkMotionMapFadeOutHandler::
    call func_002_754F
    ld   a, [$C3C9]
    and  a
    jr   z, .label_1847
    xor  a
    ld   [$C3C9], a
    jp   ApplyMapFadeOutTransition

.label_1847
    call func_1A22
    xor  a
    ld   [$C157], a
    inc  a
    ld   [$C1A8], a
    ld   a, [wTransitionSequenceCounter]
    cp   $04
    jp   nz, SetSpawnLocation.return
    xor  a
    ldh  [hBaseScrollX], a
    ldh  [hBaseScrollY], a
    ldh  [$FFB4], a
    ld   [$DDD6], a
    ld   [$DDD7], a

    ld   e, $10
    ld   hl, wEntitiesStatusTable
.clearEntitiesStatusLoop
    ldi  [hl], a
    dec  e
    jr   nz, .clearEntitiesStatusLoop

    ld   a, [$C509]
    and  a
    jr   z, .label_1898
    push af
    ld   a, BANK(label_004_7A5F)
    call SwitchBank
    pop  af
    call label_004_7A5F
    ld   hl, wIsThief
    inc  [hl]
    ld   hl, $DB46
    inc  [hl]
    ld   a, [$DC0C]
    or   $40
    ld   [$DC0C], a
    ld   a, $01
    ld   [wDidStealItem], a
    xor  a
    ldh  [hLinkAnimationState], a

.label_1898
    ldh  a, [hIsSideScrolling]
    ldh  [hScratchD], a
    ld   a, GAMEPLAY_WORLD
    ld   [wGameplayType], a
    xor  a
    ld   [wGameplaySubtype], a
    ld   [wObjectAffectingBGPalette], a
    ldh  [hIsSideScrolling], a
    ld   hl, wWarpStructs
    ld   a, [wIsIndoor]
    ldh  [hFreeWarpDataAddress], a
    and  a
    jr   nz, .label_18DF
    ld   hl, wWarpPositions
    ld   c, $00

.loop
    ldh  a, [hLinkPositionX]
    swap a
    and  $0F
    ld   e, a
    ldh  a, [hLinkPositionY]
    sub  a, $08
    and  $F0
    or   e
    cp   [hl]
    jr   z, .break
    inc  hl
    inc  c
    ld   a, c
    cp   $04
    jr   nz, .loop

.break
    ld   a, c
    sla  a
    sla  a
    add  a, c
    ld   e, a
    ld   d, $00
    ld   hl, wWarp0MapCategory
    add  hl, de

.label_18DF
    push hl
    ld   a, [hli]
    ld   [wIsIndoor], a
    cp   $02
    jr   nz, .label_18F2
    ldh  [hIsSideScrolling], a
    dec  a
    ld   [wIsIndoor], a
    ld   a, $01
    ldh  [$FF9C], a

.label_18F2
    ld   a, [hli]
    ldh  [hMapId], a
    ld   a, [wIsIndoor]
    and  a
    ld   a, [hli]
    ldh  [hMapRoom], a
    jr   nz, .label_1909
    ldh  a, [hFreeWarpDataAddress]
    and  a
    jr   z, .label_1907
    xor  a
    ld   [wActivePowerUp], a

.label_1907
    jr   .label_196F

.label_1909
    ld   c, a
    ld   a, $14
    call SwitchBank
    push hl
    ldh  a, [hMapId]
    swap a
    ld   e, a
    ld   d, $00
    sla  e
    rl   d
    sla  e
    rl   d
    ld   hl, $4220
    add  hl, de
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .colorDungeonEnd
    ld   hl, $44E0
    jr   .label_193C
.colorDungeonEnd

    cp   $06
    jr   nz, .label_193C
    ld   a, [$DB6B]
    and  $04
    jr   z, .label_193C
    ld   hl, $4520

.label_193C
    ld   e, $00

.loop_193E
    ld   a, [hli]
    cp   c
    jr   z, .break_1948
    inc  e
    ld   a, e
    cp   $40
    jr   nz, .loop_193E
.break_1948

    ld   a, e
    ld   [wIndoorRoom], a
    ldh  a, [hFreeWarpDataAddress]
    and  a
    jr   nz, .label_196E
    xor  a
    ld   [wActivePowerUp], a
    ldh  a, [hMapId]
    cp   MAP_CAVE_B
    jr   nc, .label_196E
    callsw IsMapRoomE8
    ld   a, $30
    ldh  [$FFB4], a
    xor  a
    ld   [$D6FB], a
    ld   [$D6F8], a

.label_196E
    pop  hl

.label_196F
    ld   a, [hli]
    ld   [wMapEntrancePositionX], a
    ld   a, [hl]
    ld   [wMapEntrancePositionY], a
    pop  hl
    ldh  a, [hIsSideScrolling]
    and  a
    jr   nz, label_19DA
    ldh  a, [hScratchD]
    and  a
    jr   nz, SetSpawnLocation.return
    ld   a, [wIsIndoor]
    and  a
    jr   z, SetSpawnLocation
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .label_1993
    ld   hl, $4E3C
    jr   .label_19A4

.label_1993
    cp   $0A
    jr   nc, SetSpawnLocation
    ld   e, a
    sla  a
    sla  a
    add  a, e
    ld   e, a
    ld   d, $00
    ld   hl, $4DF1
    add  hl, de

.label_19A4
    ld   a, $14
    ld   [MBC3SelectBank], a
    call SetSpawnLocation
    push de
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .label_19B7
    ld   a, $3A
    jr   .label_19BF

.label_19B7
    ld   e, a
    ld   d, $00
    ld   hl, $4E41
    add  hl, de
    ld   a, [hl]

.label_19BF
    pop  de
    ld   [de], a
    ret

; Record Link's spawn point, that will be used when loading the save file
; or starting after a game over.
SetSpawnLocation::
    ; Initialize counter
    ld   a, $00
    ldh  [hScratch0], a
    ld   de, wSpawnLocationData

    ; Copy warp data (5 bytes) from wWarp1 to wSpawnLocationData
.loop
    ld   a, [hli]
    ld   [de], a
    inc  de
    ldh  a, [hScratch0]
    inc  a
    ldh  [hScratch0], a
    cp   $05
    jr   nz, .loop

    ; Save the indoor room
    ld   a, [wIndoorRoom]
    ld   [de], a

.return
    ret

label_19DA::
    xor  a
    ldh  [hLinkDirection], a
    ret

LinkMotionMapFadeInHandler::
    call func_002_754F
    ld   a, [$D474]
    and  a
    jr   z, .label_19FC
    xor  a
    ld   [$D474], a
    ld   a, $30
    ld   [$C180], a
    ld   a, TRANSITION_GFX_MANBO_OUT
    ld   [wTransitionGfx], a
    ld   a, $04
    ld   [wTransitionSequenceCounter], a
    jr   .label_1A06

.label_19FC
    call func_1A39
    ld   a, [wTransitionSequenceCounter]
    cp   $04
    jr   nz, .return

.label_1A06
    ld   a, [$D463]
    cp   $01
    jr   z, .label_1A0F
    ld   a, $00

.label_1A0F
    ld   [wLinkMotionState], a
    ld   a, [wDidStealItem]
    and  a
    jr   z, .return
    xor  a
    ld   [wDidStealItem], a
    ld   a, $36
    jp   OpenDialog

.return
    ret

func_1A22::
    callsb func_020_6C4F
    callsb func_020_55CA
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

func_1A39::
    callsb func_020_6C7A
    callsb func_020_563B
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

func_1A50::
    ld   a, [$C120]
    sra  a
    sra  a
    sra  a
    and  $01
    ld   d, a
    ldh  a, [hLinkDirection]
    sla  a
    or   d
    ld   c, a
    ld   b, $00
    ld   hl, Data_002_4948
    ld   a, [wLinkMotionState]
    cp   $01
    jr   nz, .label_1A78
    ldh  a, [$FF9C]
    and  a
    jr   z, .label_1A76
    ld   hl, Data_002_4950

.label_1A76
    jr   .label_1AC7

.label_1A78
    ldh  a, [hIsSideScrolling]
    and  a
    jr   z, .label_1A88
    ldh  a, [$FF9C]
    cp   $02
    jr   nz, .label_1A88
    ld   hl, Data_002_4958
    jr   .label_1AC7

.label_1A88
    ld   a, [$C15C]
    cp   $01
    jr   z, .label_1AC4
    ldh  a, [$FFB2]
    and  a
    jr   nz, .label_1A9A
    ld   a, [$C144]
    and  a
    jr   nz, .label_1ABF

.label_1A9A
    ld   a, [wHasMirrorShield]
    and  a
    jr   nz, .label_1AA5
    ld   hl, $4910
    jr   .label_1AC7

.label_1AA5
    ld   hl, $4918
    cp   $02
    jr   nz, .label_1AAF
    ld   hl, $4928

.label_1AAF
    ld   a, [wIsUsingShield]
    and  a
    jr   z, .label_1ABD
    ld   a, l
    add  a, $08
    ld   l, a
    ld   a, h
    adc  a, $00
    ld   h, a

.label_1ABD
    jr   .label_1AC7

.label_1ABF
    ld   hl, $4938
    jr   .label_1AC7

.label_1AC4
    ld   hl, $4940

.label_1AC7

    add  hl, bc
    ld   a, [hl]
    ldh  [hLinkAnimationState], a
    ret

include "code/home/animated_tiles.asm"

label_1DE9::
    ld   hl, $4F00
    ld   a, $0E
    jr   label_1DF5

label_1DF0::
    ld   a, $12
    ld   hl, $6080

label_1DF5::
    ld   [MBC3SelectBank], a
    ld   de, $8400
    ld   bc, $40
    jp   label_1F3B

label_1E01::
    ld   a, [wTradeSequenceItem]
    cp   $02
    jp  c, label_1F3E
    sub  a, $02
    ld   d, a
    ld   e, $00
    sra  d
    rr   e
    sra  d
    rr   e
    ld   hl, $4400
    add  hl, de
    ld   de, $89A0
    ld   bc, $40
    ld   a, $0C
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    jp   label_1F3B

label_1E2B::
    ld   hl, $68C0
    ld   de, $88E0
    jr   label_1EA7

label_1E33::
    ld   a, $11
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   a, [$D000]
    swap a
    and  $F0
    ld   e, a
    ld   d, $00
    sla  e
    rl   d
    sla  e
    rl   d
    ld   hl, $8D00
    add  hl, de
    push hl
    ld   hl, $5000

label_1E55::
    add  hl, de
    pop  de
    ld   bc, $40
    call CopyData
    xor  a
    ldh  [$FFA5], a
    ld   a, $0C
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ret

label_1E69::
    ld   a, $13
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   a, [$D000]
    swap a
    and  $F0
    ld   e, a
    ld   d, $00
    sla  e
    rl   d
    sla  e
    rl   d
    ld   hl, $8D00
    add  hl, de
    push hl
    ld   hl, $4D00
    jr   label_1E55

label_1E8D::
    ld   hl, $48E0
    ld   de, $88E0
    ld   a, $0C
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   bc, $20
    jp   label_1F3B

label_1EA1::
    ld   hl, $68E0
    ld   de, $8CA0

label_1EA7::
    ld   a, $0C
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   bc, $20
    jp   label_1F3B

label_1EB5::
    ld   hl, $7F00
    ld   a, $12
    jr   label_1EC1

label_1EBC::
    ld   hl, $4C40
    ld   a, $0D

label_1EC1::
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   de, $9140
    jp   label_1F38

data_1ECD::
    db $40, $68, $40, $68

data_1ED1::
    db 0, $68

data_1ED3::
    db $80, $68, 0, $68

label_1ED7::
    push af
    ld   a, $0C
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    pop  af
    ld   hl, hLinkInteractiveMotionBlocked
    ld   [hl], $01
    ld   hl, $D6FB
    ld   e, [hl]
    ld   d, $00
    inc  a
    cp   $03
    jr   nz, label_1EFB
    push af
    ld   a, [$D6FB]
    xor  $02
    ld   [$D6FB], a
    pop  af

label_1EFB::
    ld   [$D6F8], a
    cp   $04

label_1F00::
    jr   nz, label_1F07
    ld   hl, data_1ECD
    jr   label_1F0E

label_1F07::
    cp   $08
    jr   nz, label_1F14
    ld   hl, data_1ED1

label_1F0E::
    add  hl, de
    ld   de, $9040
    jr   label_1F2C

label_1F14::
    cp   $06
    jr   nz, label_1F1D
    ld   hl, data_1ECD
    jr   label_1F28

label_1F1D::
    cp   $0A
    jr   nz, label_1F35
    xor  a
    ld   [$D6F8], a
    ld   hl, data_1ED3

label_1F28::
    add  hl, de
    ld   de, $9080

label_1F2C::
    ld   bc, $40
    ld   a, [hli]
    ld   h, [hl]
    ld   l, a
    jp   CopyData

label_1F35::
    jp   DrawLinkSpriteAndReturn

label_1F38::
    ld   bc, $40

label_1F3B::
    call CopyData

label_1F3E::
    xor  a
    ldh  [$FFA5], a
    ld   a, $0C
    ld   [MBC3SelectBank], a
    jp   DrawLinkSpriteAndReturn

; Number of horizontal pixels the sword reaches in Link's direction when drawing the sword
SwordAreaXForDirection::
.right db $0C
.left  db $03
.up    db $08
.down  db $08

; Number of vertical pixels the sword reaches in Link's direction when drawing the sword
SwordAreaYForDirection::
.right db $0A
.left  db $0A
.up    db $05
.down  db $10

; Array of constants for Link animation state
data_1F51::
    db   $36, $38, $3A, $3C

data_1F55::
    db   2, 1, 8, 4

data_1F59::
    db   $FC, 4, 0, 0

data_1F5D::
    db   0, 0, 4, 0

; Call label_1F69, then restore bank 2
; (Only ever called from label_002_4287)
label_1F69_trampoline::
    call label_1F69
    ld   a, $02
    jp   SwitchBank

; Physics for Link interactive motion?
; (Only ever called from label_002_4287)
label_1F69::
    ; If running with pegagus boots, or hLinkPositionZ != 0, or Link's motion != LINK_MOTION_INTERACTIVE, return
    ld   hl, wIsRunningWithPegasusBoots
    ld   a, [$C15C]
    or   [hl]
    ld   hl, hLinkPositionZ
    or   [hl]
    ld   hl, wLinkMotionState
    or   [hl]
    jp   nz, label_1F69_return

    ; Update hSwordIntersectedAreaX according to Link's position and direction
    ldh  a, [hLinkDirection]
    ld   e, a
    ld   d, $00
    ld   hl, SwordAreaXForDirection
    add  hl, de

    ldh  a, [hLinkPositionX]
    add  a, [hl]
    sub  a, $08
    and  $F0
    ldh  [hSwordIntersectedAreaX], a

    ; Update hSwordIntersectedAreaY according to Link's position and direction
    swap a
    ld   c, a
    ld   hl, SwordAreaYForDirection
    add  hl, de
    ldh  a, [hLinkPositionY]
    add  a, [hl]
    sub  a, $10
    and  $F0
    ldh  [hSwordIntersectedAreaY], a

    ; hl = address of the room object that would intersect with the sword
    or   c
    ld   e, a
    ldh  [hScratch1], a
    ld   hl, wRoomObjects
    add  hl, de

    ; (Sanity check: if HIGH(hl) != $D7, then we're far out of bounds: return)
    ld   a, h
    cp   $D7
    jp   nz, clearC15FAndReturn

    ; hScratch0 = id of room object under the sword
    ld   a, [hl]
    ldh  [hScratch0], a

    ; hScratch5 = unknown value read from the base map
    ; d = map group id
    ; e = room object
    ld   e, a
    ld   a, [wIsIndoor]
    ld   d, a
    call ReadValueFromBaseMap_trampoline
    ldh  [hScratch5], a

    ; If the object is $9A, skip this section

    ldh  a, [hScratch0]
    cp   $9A
    jr   z, .notObject9AEnd

    ldh  a, [hScratch5]
    cp   $00
    jp   z, clearC15FAndReturn
    cp   $01
    jr   z, .jp_1FE6
    cp   $50
    jp   z, clearC15FAndReturn
    cp   $51
    jp   z, clearC15FAndReturn
    cp   $11
    jp  c, clearC15FAndReturn
    cp   $D4
    jp   nc, clearC15FAndReturn
    cp   $D0
    jr   nc, .jp_1FE6
    cp   $7C
    jp   nc, clearC15FAndReturn

.jp_1FE6
    ldh  a, [hScratch0]
    ld   e, a
    cp   $6F
    jr   z, .jp_1FF6
    cp   $5E
    jr   z, .jp_1FF6
    cp   $D4
    jp   nz, label_2098

.jp_1FF6
    ld   a, [wIsIndoor]
    and  a

    ld   a, e
    jp   nz, label_2098
.notObject9AEnd

    ld   e, a

    ; If Link is facing up, handle some special cases.
    ldh  a, [hLinkDirection]
    cp   DIRECTION_UP
    jp   nz, specialCasesEnd
    ; Set [$C1AD] = 2
    ld   a, $02
    ld   [$C1AD], a

    ; If A or B is pressed…
    ldh  a, [hJoypadState]
    and  J_A | J_B
    jp   z, specialCasesEnd
    ld   a, e
    cp   $5E
    ld   a, $8E
    jr   z, label_2088
    ld   a, e
    cp   $6F
    jr   z, label_2049
    cp   $D4
    jr   z, label_2049
    ld   a, [wIsMarinFollowingLink]
    and  a
    jr   z, label_2030
    ; Open Marin's "Do you look in people's drawers?" dialog
    call_open_dialog $278
    jp   specialCasesEnd

label_2030::
    ; If no sword yet…
    ld   a, [wSwordLevel]
    and  a
    ldh  a, [hMapRoom]
    jr   nz, .noSwordEnd
    ld   e, $FF
    cp   $A3
    jr   z, label_2046
.noSwordEnd

    ld   e, $FC
    cp   $FA
    jr   z, label_2046
    ld   e, $FD

label_2046::
    ld   a, e
    jr   label_208E

label_2049::
    ldh  a, [hMapRoom]
    ld   e, a
    ld   d, $00
    ld   a, $14
    ld   [MBC3SelectBank], a
    ld   hl, $5118
    add  hl, de
    ld   a, [wOcarinaSongFlags]
    ld   e, a
    ld   a, [hl]
    cp   $A9
    jr   nz, label_2066
    bit  0, e
    jr   z, label_2066
    ld   a, $AF

label_2066::
    cp   $AF
    jr   nz, label_2080
    bit  0, e
    jr   nz, label_2080
    ldh  a, [hSwordIntersectedAreaX]
    swap a
    and  $0F
    ld   e, a
    ldh  a, [hSwordIntersectedAreaY]
    and  $F0
    or   e
    ld   [$D473], a
    jp   specialCasesEnd

label_2080::
    cp   $83
    jr   z, label_208E
    cp   $2D
    jr   z, label_2093

label_2088::
    call OpenDialogInTable1
    jp   specialCasesEnd

label_208E::
    call OpenDialog
    jr   specialCasesEnd

label_2093::
    call OpenDialogInTable2
    jr   specialCasesEnd

label_2098::

    ; When throwing a pot at a chest in the right room, open the chest
    cp   OBJECT_CHEST_CLOSED
    jr   nz, specialCasesEnd
    ld   a, [wRoomEvent]
    and  EVENT_TRIGGER_MASK
    cp   TRIGGER_THROW_POT_AT_CHEST
    jr   z, specialCasesEnd
    ldh  a, [hLinkDirection]
    cp   $02
    jr   nz, specialCasesEnd
    ld   [$C1AD], a
    ldh  a, [hJoypadState]
    and  $30
    jr   z, specialCasesEnd
    ldh  a, [hIsSideScrolling]
    and  a
    jr   nz, .label_20BF
    ldh  a, [hLinkDirection]
    cp   $02
    jr   nz, specialCasesEnd

.label_20BF
    callsb func_014_5900
    callsb SpawnChestWithItem
specialCasesEnd:

    ld   a, [wAButtonSlot]
    cp   INVENTORY_POWER_BRACELET
    jr   nz, label_20DD
    ldh  a, [hPressedButtonsMask]
    and  $20
    jr   nz, label_20EC
    ret

label_20DD::
    ld   a, [wBButtonSlot]
    cp   INVENTORY_POWER_BRACELET
    jp   nz, label_1F69_return
    ldh  a, [hPressedButtonsMask]
    and  $10
    jp   z, label_1F69_return

label_20EC::
    callsb label_002_48B0
    ld   a, $01
    ldh  [hLinkInteractiveMotionBlocked], a
    ldh  a, [hLinkDirection]
    ld   e, a
    ld   d, $00
    ld   hl, data_1F51

    add  hl, de
    ld   a, [hl]
    ldh  [hLinkAnimationState], a
    ld   hl, data_1F55
    add  hl, de
    ldh  a, [hPressedButtonsMask]
    and  [hl]
    jr   z, clearC15FAndReturn
    ld   hl, data_1F59
    add  hl, de
    ld   a, [hl]
    ld   [$C13C], a
    ld   hl, data_1F5D
    add  hl, de
    ld   a, [hl]
    ld   [$C13B], a
    ld   hl, hLinkAnimationState
    inc  [hl]
    ld   e, $08
    ld   a, [wActivePowerUp]
    cp   $01
    jr   nz, .jp_212C
    ld   e, $03

.jp_212C
    ld   hl, $C15F
    inc  [hl]
    ld   a, [hl]
    cp   e
    jr   c, .return
    xor  a
    ldh  [$FFE5], a
    ldh  a, [hScratch0]
    cp   $8E
    jr   z, label_2153
    cp   $20
    jr   z, label_2153
    ld   a, [wIsIndoor]
    and  a
    jr   nz, .return
    ldh  a, [hScratch0]
    cp   $5C
    jr   z, label_2161

.return
    ret

clearC15FAndReturn::
    xor  a
    ld   [$C15F], a
    ret

label_2153::
    call label_2165
    callsb func_014_50C3
    jp   ReloadSavedBank

label_2161::
    ld   a, $01
    ldh  [$FFE5], a

label_2165::
    ldh  a, [hScratch1]
    ld   e, a
    ldh  a, [hScratch0]
    ldh  [hObjectUnderEntity], a
    call func_014_5526_trampoline
    ldh  a, [hLinkDirection]
    ld   [$C15D], a
    jp   label_2183

label_1F69_return::
    ret

func_014_5526_trampoline::
    callsb func_014_5526
    jp   ReloadSavedBank

label_2183::
    ld   a, ENTITY_ENTITY_LIFTABLE_ROCK
    call SpawnPlayerProjectile
    jr   c, label_21A7

    ld   a, WAVE_SFX_ZIP
    ldh  [hWaveSfx], a

    ld   hl, wEntitiesStatusTable
    add  hl, de
    ld   [hl], $07
    ld   hl, $C3B0
    add  hl, de
    ldh  a, [$FFE5]
    ld   [hl], a
    ld   c, e
    ld   b, d
    ld   e, $01
    jpsw func_003_5795

label_21A7::
    ret

UpdateFinalLinkPosition::
    ; If inventory is appearing, return
    ld   a, [wInventoryAppearing]
    and  a
    ret  nz

    ; Compute next Link vertical position
    ld   c, $01
    call ComputeLinkPosition

.horizontal
   ; Compute next Link horizontal position
    ld   c, $00
    ldh  [hScratch0], a

; Inputs:
;   c : direction (0: horizontal ; 1: vertical)
ComputeLinkPosition::
    ; b = 0
    ld   b, $00
    ; a = [hLinkPositionXIncrement + direction]
    ld   hl, hLinkPositionXIncrement
    add  hl, bc
    ld   a, [hl]

    push af
    swap a
    and  $F0
    ld   hl, $C11A
    add  hl, bc
    add  a, [hl]
    ld   [hl], a

    rl   d
    ; hl = [hLinkPositionX + direction]
    ld   hl, hLinkPositionX
    add  hl, bc

    pop  af
    ld   e, $00
    bit  7, a
    jr   z, .label_21D7
    ld   e, $F0
.label_21D7

    swap a
    and  $0F
    or   e
    rr   d
    adc  a, [hl]
    ld   [hl], a
    ret

func_21E1::
    ldh  a, [$FFA3]
    push af
    swap a
    and  $F0
    ld   hl, $C149
    add  a, [hl]
    ld   [hl], a
    rl   d
    ld   hl, hLinkPositionZ
    pop  af
    ld   e, $00
    bit  7, a
    jr   z, .label_21FB
    ld   e, $F0
.label_21FB
    swap a
    and  $0F
    or   e
    rr   d
    adc  a, [hl]
    ld   [hl], a
    ret

; Increment the BG map offset by this amount during room transition,
; depending on the transition direction.
BGRegionIncrement::
.right  db $10
.left   db $10
.top    db $01
.bottom db $01

; Update a region (row or column) of the BG map during room transition
UpdateBGRegion::
    ; Switch to Map Data bank
    ld   a, $08
    ld   [MBC3SelectBank], a
    call DoUpdateBGRegion
    ; Reload saved bank and return
    jp   ReloadSavedBank

IncrementBGMapSourceAndDestination_Vertical::
    ld   a, [wBGUpdateRegionOriginLow]
    and  $20
    jr   z, .noColumnEnd
    inc  hl
    inc  hl
.noColumnEnd

    ld   a, [hli]
    ld   [bc], a
    inc  bc
    ld   a, [hl]
    ld   [bc], a
    inc  bc
    ret

IncrementBGMapSourceAndDestination_Horizontal::
    ld   a, [wBGUpdateRegionOriginLow]
    and  $01
    jr   z, .noColumnEnd
    inc  hl
.noColumnEnd

    ld   a, [hli]
    ld   [bc], a
    inc  hl
    inc  bc
    ld   a, [hl]
    ld   [bc], a
    inc  bc
    ret

; Update a region (row or column) of the BG map during room transition
DoUpdateBGRegion::
    ; Configures an async data request to copy background tilemap
    callsb func_020_4A76

    ; Switch back to Map Data bank
    ld   a, $08
    ld   [MBC3SelectBank], a

.loop
    push bc
    push de

    ; hl = wRoomObjects + hScratch2
    ldh  a, [hScratch2]
    ld   c, a
    ld   b, $00
    ld   hl, wRoomObjects
    add  hl, bc

    ; c = wRoomObjects[hScratch2]
    ld   b, $00
    ld   c, [hl]

    ; If running on GBC…
    ldh  a, [hIsGBC]
    and  a
    jr   z, .ramSwitchEnd
    ; … and is indoor…
    ld   a, [wIsIndoor]
    and  a
    jr   nz, .ramSwitchEnd
    ; … switch to RAM Bank 2,
    ld   a, $02
    ld   [rSVBK], a
    ; read hl,
    ld   c, [hl]
    ; switch back to RAM Bank 0.
    xor  a
    ld   [rSVBK], a
.ramSwitchEnd

    sla  c
    rl   b
    sla  c
    rl   b

    ;
    ; Map base address selection
    ;

    ; If IsIndoor…
    ld   a, [wIsIndoor]
    and  a
    jr   z, .baseAddress_isOverworld
    ld   hl, IndoorBaseMapDMG
    ; if IsGBC…
    ldh  a, [hIsGBC]
    and  a
    jr   z, .palettesskipEntityLoad
    ; … hl = (MapId == MAP_COLOR_DUNGEON ? ColorDungeonBaseMap : IndoorBaseMapGBC)
    ld   hl, IndoorBaseMapGBC
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .configurePalettes
    ld   hl, ColorDungeonBaseMap
    jr   .configurePalettes

.baseAddress_isOverworld
    ; hl = (hIsGBC ? OverworldBaseMapGBC : OverworldBaseMapDMG)
    ld   hl, OverworldBaseMapDMG
    ldh  a, [hIsGBC]
    and  a
    jr   z, .palettesskipEntityLoad
    ld   hl, OverworldBaseMapGBC

    ;
    ; Palettes configuration (GBC only)
    ;

.configurePalettes
    ; Set the BG attributes bank in hScratch8,
    ; and the target BG attributes address in FFE0-FFE1
    callsb GetBGAttributesAddressForObject
.palettesskipEntityLoad

    ;
    ; BG map offset selection
    ;

    ; Switch to the bank containing the BG map
    call SwitchToMapDataBank
    ; hl = base map address + BG map offset
    add  hl, bc
    pop  de
    pop  bc

    ; If the Room transition is vertical…
    ld   a, [wRoomTransitionDirection]
    and  $02
    jr   z, .horizontalRoomTransition
    ; Increment the source and target destination
    call IncrementBGMapSourceAndDestination_Vertical

    ; If IsGBC, load BG palette data
    ldh  a, [hIsGBC]
    and  a
    jr   z, .verticalIncrementEnd
    push bc
    push de
    callsb func_020_49D9

    ; Select BG attributes bank
    ldh  a, [hScratch8]
    ld   [MBC3SelectBank], a
    ; Increment again the source and target destination
    call IncrementBGMapSourceAndDestination_Vertical
    ld   a, b
    ldh  [$FFE2], a
    ld   a, c
    ldh  [$FFE3], a
    ld   a, d
    ldh  [hScratchD], a
    ld   a, e
    ldh  [$FFE5], a
    ; Restore state
    call SwitchToMapDataBank
    pop  de
    pop  bc

.verticalIncrementEnd
    jr   .incrementEnd

.horizontalRoomTransition
    call IncrementBGMapSourceAndDestination_Horizontal
    ; If IsGBC…
    ldh  a, [hIsGBC]
    and  a
    jr   z, .incrementEnd
    ; Load BG palette data
    push bc
    push de
    callsb func_020_49D9
    ; Select BG attributes bank
    ldh  a, [hScratch8]
    ld   [MBC3SelectBank], a
    call IncrementBGMapSourceAndDestination_Horizontal
    ld   a, b
    ldh  [$FFE2], a
    ld   a, c
    ldh  [$FFE3], a
    ld   a, d
    ldh  [hScratchD], a
    ld   a, e
    ldh  [$FFE5], a
    ; Cleanup
    call SwitchToMapDataBank
    pop  de
    pop  bc

.incrementEnd

    push bc
    ; Increment BG destination address
    ; (by a column or by a row)
    ld   a, [wRoomTransitionDirection]
    ld   c, a
    ld   b, $00
    ld   hl, BGRegionIncrement
    add  hl, bc
    ldh  a, [hScratch2]
    add  a, [hl]
    ldh  [hScratch2], a
    pop  bc

    ; Decrement loop counter
    ld   a, [wBGUpdateRegionTilesCount]
    dec  a
    ld   [wBGUpdateRegionTilesCount], a

    ; Loop until BG map data for the whole region is copied
    jp   nz, .loop

    ; Set next BG region origin, and decrement wRoomTransitionFramesBeforeMidScreen
    jpsb func_020_5570

include "code/home/dialog.asm"

; Set the music track to play on the world
; Input:
;   a:   soundtrack id to load
SetWorldMusicTrack::
    ld   [wActiveMusicTrack], a
    ldh  [hNextWorldMusicTrack], a
    ; $FFAB = a
    ld   a, $38
    ldh  [$FFAB], a
    ; $FFA8 = 0
    xor  a
    ldh  [$FFA8], a
    ret

EnableExternalRAMWriting::
    push hl
    ld   hl, $4000
    ld   [hl], $00 ; Switch to RAM bank 0
    ld   hl, $00
    ld   [hl], $0A ; Enable external RAM writing
    pop  hl
    ret

; Load soudtrack after map or gameplay transition
label_27DD::
    ld   a, BANK(SelectMusicTrackAfterTransition)
    ld   [MBC3SelectBank], a
    push bc
    call SelectMusicTrackAfterTransition
    pop  bc
    jp   ReloadSavedBank

label_27EA::
    ld   a, $38
    ldh  [$FFA8], a
    xor  a
    ldh  [$FFAB], a
    ret

label_27F2::
    ldh  a, [hFFBC]
    and  a
    jr   nz, .skip
    callsb func_01F_4003
.skip
    jp   ReloadSavedBank

SynchronizeDungeonsItemFlags_trampoline::
    callsb SynchronizeDungeonsItemFlags
    jp   ReloadSavedBank

; Return a random number in `a`
GetRandomByte::
    push hl
    ldh  a, [hFrameCounter]
    ld   hl, wRandomSeed
    add  a, [hl]
    ld   hl, rLY
    add  a, [hl]
    rrca
    ld   [wRandomSeed], a ; wRandomSeed += FrameCounter + rrca(rLY)
    pop  hl
    ret

ReadJoypadState::
    ; Ignore joypad during map transitions
    ld   a, [wRoomTransitionState]
    and  a
    jr   nz, .return

    ld   a, [wGameplayType]
    cp   GAMEPLAY_WORLD
    jr   nz, .readState
    ld   a, [wGameplaySubtype]
    cp   GAMEPLAY_WORLD_DEFAULT
    jr   nz, .notWorld
    ld   a, [wLinkMotionState]
    cp   LINK_MOTION_PASS_OUT
    jr   nz, .linkNotPassingOut
    ldh  a, [$FF9C]
    cp   $04
    jr   z, .readState

.linkNotPassingOut
    ld   a, [wTransitionSequenceCounter]
    cp   $04
    jr   nz, .notWorld
    ld   a, [$DDD5]
    and  a
    jr   z, .readState

.notWorld
    xor  a
    ldh  [hPressedButtonsMask], a
    ldh  [$FFCC], a
    ret

.readState
    ld   a, $20
    ld   [rP1], a
    ld   a, [$FF00]
    ld   a, [$FF00]
    cpl
    and  $0F
    ld   b, a
    ld   a, $10
    ld   [rP1], a
    ld   a, [$FF00]
    ld   a, [$FF00]
    ld   a, [$FF00]
    ld   a, [$FF00]
    ld   a, [$FF00]
    ld   a, [$FF00]
    ld   a, [$FF00]
    ld   a, [$FF00]
    swap a
    cpl
    and  $F0
    or   b
    ld   c, a
    ldh  a, [hPressedButtonsMask]
    xor  c
    and  c
    ldh  [$FFCC], a
    ld   a, c
    ldh  [hPressedButtonsMask], a
    ld   a, $30
    ld   [rP1], a

.return
    ret

label_2887::
    push bc
    ldh  a, [hSwordIntersectedAreaY]
    ld   hl, hBaseScrollY
    add  a, [hl]
    and  $F8
    srl  a
    srl  a
    srl  a
    ld   de, $00
    ld   e, a
    ld   hl, vBGMap0
    ld   b, $20

.loop
    add  hl, de
    dec  b
    jr   nz, .loop

    push hl
    ldh  a, [hSwordIntersectedAreaX]
    ld   hl, hBaseScrollX
    add  a, [hl]
    pop  hl
    and  $F8
    srl  a
    srl  a
    srl  a
    ld   de, $00
    ld   e, a
    add  hl, de
    ld   a, h
    ldh  [$FFCF], a
    ld   a, l
    ldh  [$FFD0], a
    pop  bc
    ret

; Jump to the routine defined at the given index in the jump table.
;
; Usage:
;   ld   a, <routine_index>
;   rst  0
;   dw   Func_0E00 ; jump address for index 0
;   dw   Func_0F00 ; jump address for index 1
;   ...
;
; Input:
;   a:  index of the routine address in the jump table
TableJump::
    ld   e, a    ; \
    ld   d, $00  ; | Multiply the index by 2, and store it in de
    sla  e       ; |
    rl   d       ; /
    pop  hl
    add  hl, de  ; Add the base address and the offset
    ld   e, [hl] ; Load the low byte of the target address
    inc  hl
    ld   d, [hl] ; Load the high byte of the target address
    ld   l, e
    ld   h, d
    jp   hl    ; Jump to the target address

; Turn off LCD at next vertical blanking
LCDOff::
    ld   a, [rIE]
    ldh  [$FFD2], a ; Save interrupts configuration
    res  0, a
    ld   [rIE], a   ; Disable all interrupts
.waitForEndOfLine
    ld   a, [rLY]
    cp   $91
    jr   nz, .waitForEndOfLine ; Wait for row 145
    ld   a, [rLCDC]  ; \
    and  $7F         ; | Switch off LCD screen
    ld   [rLCDC], a  ; /
    ldh  a, [$FFD2]
    ld   [rIE], a    ; Restore interrupts configuration
    ret

LoadTilemap0F_trampoline::
    jpsw LoadTilemap0F

; Fill the Background Map with all 7Es
LoadTilemap8::
    ld   a, $7E    ; value
    ld   bc, $400 ; count
    jr   FillBGMap

; Fill the Background Map with all 7Fs
ClearBGMap::
    ld   a, $7F    ; value
    ld   bc, $800 ; count

; Fill the Background map with a value
; Inputs:
;   a  : value to fill
;   bc : count
FillBGMap::
    ld   d, a
    ld   hl, vBGMap0
.loop
    ld   a, d
    ldi  [hl], a
    dec  bc
    ld   a, b
    or   c
    jr   nz, .loop
    ret

include "code/home/copy_data.asm"

include "src/code/home/clear_memory.asm"

GetChestsStatusForRoom_trampoline::
    callsb GetChestsStatusForRoom
    jp   ReloadSavedBank

; Play the boomerang sound effect, then reload the current bank
PlayBoomerangSfx_trampoline::
    callsb PlayBoomerangSfx
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ret

label_2A07::
    ld   a, $01
    ld   [MBC3SelectBank], a
    call label_5A59
    jp   ReloadSavedBank

; Read an unknown value from the base map bank
ReadValueFromBaseMap::
    ld   a, $08
    ld   [MBC3SelectBank], a
    ld   hl, $4AD4
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .colorDungeonEnd
    ld   hl, $4BD4
.colorDungeonEnd
    add  hl, de
    ld   a, [hl]
    ret

ReadValueFromBaseMap_trampoline::
    call ReadValueFromBaseMap
    jp   ReloadSavedBank

label_2A2C::
    call ReadValueFromBaseMap
    push af
    ld   a, $03
    ld   [MBC3SelectBank], a
    pop  af
    ret

LoadTilemap1E::
    ld   a, $13
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a

    ld   hl, $6800
    ld   de, vTiles2
    ld   bc, TILE_SIZE * $80
    call CopyData

    ld   hl, $7000
    ld   de, vTiles1
    ld   bc, TILE_SIZE * $80
    jp   CopyData

LoadTilemap1F::
    call LoadTilemap15
    ld   de, vTiles0 + $400
    ld   hl, $7600
    ld   bc, TILE_SIZE * $10
    jp   CopyData

LoadTilemap15::
    ld   a, $13
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a

    ld   hl, $4000
    ld   de, vTiles0
    ld   bc, TILE_SIZE * $180
    call CopyData

    ld   a, $0C
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   hl, $57E0
    ld   de, $97F0
    ld   bc, TILE_SIZE
    call CopyData

    ld   a, $12
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   hl, $7500
    ld   de, vTiles0
    ld   bc, TILE_SIZE * 4
    call CopyData

    ld   de, $8D00
    ld   hl, $7500
    ld   bc, $200
    jp   CopyData

LoadTilemap1D::
    ld   a, $0C
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   hl, $5000
    ld   de, vTiles2
    ld   bc, TILE_SIZE * $80
    call CopyData

    ld   a, $12
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   hl, $6000
    ld   de, $8000
    ld   bc, $800
    call CopyData
    ld   a, $0F
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   hl, $6000
    ld   de, $8800
    ld   bc, $800
    jp   CopyData

LoadTilemap18::
    ld   hl, $4000
    ldh  a, [hIsGBC]
    and  a
    jr   z, label_2B01
    ld   hl, $6800
    ld   a, $35
    jr   label_2B06

LoadTilemap17::
    ld   hl, $4800
    jr   label_2B01

LoadTilemap16::
    ld   hl, $6000

label_2B01::
    ld   a, $13
    call AdjustBankNumberForGBC

label_2B06::
    ld   [MBC3SelectBank], a
    ld   de, $8000
    ld   bc, $800
    call CopyData
    ld   a, $13
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   hl, $5800
    ld   de, $8800
    ld   bc, $1000
    jp   CopyData

LoadTilemap1B::
    call PlayAudioStep
    ld   hl, $6800
    ld   a, $10
    call label_2B92
    call PlayAudioStep
    ld   a, $12
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   hl, $6600
    ld   de, $8000
    ld   bc, $80
    call CopyData
    call PlayAudioStep
    ldh  a, [hIsGBC]
    and  a
    jr   nz, label_2B61
    ld   a, $10
    ld   [MBC3SelectBank], a
    ld   hl, $6900
    ld   de, $8100
    ld   bc, $700
    jp   CopyData

label_2B61::
    ld   a, $38
    ld   [MBC3SelectBank], a
    ld   hl, $5000
    ld   de, $8000
    ld   bc, $800
    jp   CopyData

LoadTilemap1A::
    ld   hl, $7800
    ldh  a, [hIsGBC]
    and  a
    jr   z, label_2B90
    ld   hl, $7800
    ld   a, $35
    jr   label_2B95

LoadTilemap19::
    ld   hl, $4800
    ldh  a, [hIsGBC]
    and  a
    jr   z, label_2B90
    ld   hl, $7000
    ld   a, $35
    jr   label_2B95

label_2B90::
    ld   a, $13

label_2B92::
    call AdjustBankNumberForGBC

label_2B95::
    ld   [MBC3SelectBank], a
    ld   de, $8000
    ld   bc, $800
    call CopyData
    ld   a, $13
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   hl, $7000
    ld   de, $8800
    ld   bc, $800
    call CopyData
    ld   hl, $6800
    ld   de, $9000
    ld   bc, $800
    jp   CopyData

label_2BC1::
    push bc
    callsb func_014_5838
    call ReloadSavedBank
    pop  bc
    ret

; Load the basic tiles (Link's character, items icons) to tile memory
LoadBaseTiles::
    ; Select the tiles sheet bank ($0C on DMG, $2C on GBC)
    ld   a, BANK(LinkCharacterTiles)
    call SwitchAdjustedBank
    ; Copy $400 bytes from the link's tile sheet to Tiles map 0
    ld   hl, LinkCharacterTiles
    ld   de, vTiles0
    ld   bc, $400
    call CopyData

    ; Select the tiles sheet bank ($0C on DMG, $2C on GBC)
    ld   a, BANK(Items2Tiles)
    call SwitchAdjustedBank
    ; Copy $1000 bytes from the items tile sheet to Tiles Map 1
    ld   hl, Items2Tiles
    ld   de, vTiles1
    ld   bc, $1000
    call CopyData

    ; Copy two tiles from the times tile sheet to a portion of Tiles Map 1
    ld   hl, Items1Tiles + $3A0
    ld   de, vTiles1 + $600
    ld   bc, $20
    call CopyData

    ; Swtich back to bank 1
    ld   a, $01
    call SwitchBank
    ret

LoadInventoryTiles::
    call LoadBaseTiles

    ; Select the tiles sheet bank ($0F on DMG, $2F on GBC)
    ld   a, BANK(MenuTiles)
    call SwitchAdjustedBank
    ; Copy $400 bytes from the menu tile sheet to Tiles Map 1
    ld   hl, MenuTiles
    ld   de, vTiles1
    ld   bc, $400
    call CopyData

    ; Select the tiles sheet bank ($0F on DMG, $2F on GBC)
    ld   a, BANK(FontTiles)
    call SwitchAdjustedBank
    ; Copy $800 bytes from the menu tile sheet to Tiles Map 2
    ld   hl, FontTiles
    ld   de, vTiles2
    ld   bc, $800
    jp   CopyData ; tail-call

LoadDungeonTiles::
    ; Switch to bank $20
    ld   a, $20
    call SwitchBank
    ld   hl, data_020_4589
    ; e = [hMapId]
    ldh  a, [hMapId]
    ld   e, a
    ld   d, $00
    ; If inside the Color Dungeon…
    cp   MAP_COLOR_DUNGEON
    jr   nz, .notColorDungeon
    ; … switch to bank $35
    ld   a, $35
    ld   [MBC3SelectBank], a
    ; … and copy Color Dungeon tiles to Tiles Map 2
    ld   hl, $6200
    ld   de, vTiles2
    ld   bc, $100
    call CopyData

    ld   e, $00
    ld   d, e
    ld   hl, $6000
    push de
    jr   .endIf

.notColorDungeon
    push de
    add  hl, de
    ld   h, [hl]
    ld   l, $00
    ld   a, $0D
    call SwitchAdjustedBank
.endIf

    ld   de, $9100
    ld   bc, $100
    call CopyData
    ld   a, $0D
    call SwitchAdjustedBank
    ld   hl, $4000
    ld   de, $9200
    ld   bc, $600
    call CopyData

    ld   a, $20
    ld   [MBC3SelectBank], a
    pop  de
    push de
    ld   hl, $45A9
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .colorDungeonEnd
    ld   hl, $45C9
.colorDungeonEnd

    add  hl, de
    ld   h, [hl]
    ld   l, $00
    call ReloadSavedBank
    ld   de, $9200
    ld   bc, $200
    call CopyData

    ld   a, $0C
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   hl, $47C0
    ld   de, $DCC0
    ld   bc, $40
    call CopyData

    call func_2D50
    ld   a, $20
    ld   [MBC3SelectBank], a
    pop  de
    ld   hl, $45CA
    add  hl, de
    ld   h, [hl]
    ld   l, $00

    ld   a, $12
    call SwitchAdjustedBank

    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .colorDungeonEnd2
    ld   hl, $6100
    ld   a, $35
    ld   [MBC3SelectBank], a
.colorDungeonEnd2

    ld   de, $8F00
    ld   bc, $100
    call CopyData
    ld   a, [wCurrentBank]
    ld   [MBC3SelectBank], a
    ld   hl, $7D00
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   z, .label_2CF5
    cp   MAP_CAVE_B
    jr   c, .label_2CF5
    ld   a, $0C
    call SwitchAdjustedBank
    ld   hl, $4C00

.label_2CF5
    ld   de, $8C00
    ld   bc, $300
    call CopyData

label_2CFE::
    ld   a, [wHasToadstool]
    and  a
    jr   z, label_2D07
    call label_1E2B

label_2D07::
    ld   a, [wIsIndoor]
    and  a
    jr   z, label_2D17
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   z, label_2D21
    cp   MAP_CAVE_B
    jr   c, label_2D21

label_2D17::
    ld   a, [$DB15]
    cp   $06
    jr   c, label_2D21
    call label_1EA1

label_2D21::
    ld   a, [wTradeSequenceItem]
    cp   $02
    jr   c, .return
    ld   a, $0D
    ldh  [$FFA5], a

.return
    ret

LoadTilemap5::
    ld   a, $0C
    call SwitchAdjustedBank
    ld   hl, $5200
    ld   de, vTiles2 + $200
    ld   bc, $600
    call CopyData
    ; Load keys tiles
    ld   hl, $4C00
    ld   de, $8C00
    ld   bc, $400
    call CopyData
    call func_2D50
    jp   label_2CFE

func_2D50::
    xor  a
    ldh  [hAnimatedTilesFrameCount], a
    ldh  [hAnimatedTilesDataOffset], a
    call AnimateTiles.jumpTable

    ld   a, BANK(Items2Tiles)
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a

    ld   hl, Items2Tiles
    ld   de, vTiles1
    ld   bc, $800
    call CopyData

    ld   hl, $4200
    ld   de, vTiles0 + $200
    ld   bc, $100
    call CopyData
    ret

; Load Map n°10 (introduction sequence)
LoadIntroSequenceTiles::
    ; Copy $80 bytes of map tiles from 01:6D4A to Tiles Memory
    ; (rain graphics)
    ld   a, $01
    call SwitchBank
    ld   hl, $6D4A
    ld   de, vTiles0 + $700
    ld   bc, $80
    call CopyData

    ; Copy $600 bytes of map tiles from 10:5400 to Tiles Memory
    ; (some intro sequence graphics)
    ld   a, $10
    call SwitchAdjustedBank
    ld   hl, $5400
    ld   de, vTiles0
    ld   bc, $600
    call CopyData

    ; Copy $1000 bytes of map tiles from 10:4000 to Tiles Memory
    ; (intro sequence graphics)
    ld   hl, $4000
    ld   de, vTiles1
    ld   bc, $1000
    jp   CopyData ; tail-call ; will return afterwards.

LoadTilemap11::
    ld   a, $0F
    call SwitchAdjustedBank
    ld   hl, $4900
    ld   de, $8800
    ld   bc, $700
    call CopyData
    ld   a, $38
    call SwitchBank

    ldh  a, [hIsGBC]
    and  a
    jr   nz, .else
    ld   hl, $5C00
    jr   .endIf
.else
    ld   hl, $5800
.endIf

    ld   de, $8400
    ld   bc, $400
    call CopyData
    ldh  a, [hIsGBC]
    and  a
    jr   nz, .label_2DDD
    ld   hl, $6600
    jr   .label_2DE0
.label_2DDD
    ld   hl, $6500
.label_2DE0

    ld   de, $8200
    ld   bc, $100
    jp   CopyData

LoadTilemap0B::
    ld   a, $0C
    call SwitchAdjustedBank
    ld   hl, $7800
    ld   de, $8F00
    ld   bc, $800
    call CopyData

    ld   hl, $5000
    ld   de, $8200
    ld   bc, $100
    jp   CopyData

LoadTilemap14::
    ld   hl, $7000
    jr   CopyTilesToVTiles2

LoadTilemap20::
    ld   hl, $7800
    jr   CopyTilesToVTiles2

LoadTilemap12::
    ld   hl, $5800

CopyTilesToVTiles2::
    ld   a, $10
    call SwitchAdjustedBank
    ld   de, vTiles2
    ld   bc, TILE_SIZE * $80
    jp   CopyData

LoadTilemap21::
    ld   a, $13
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ld   hl, $7C00
    ld   de, $8C00
    ld   bc, $400
    call CopyData

    ld   hl, $6800
    ld   de, $9000
    ld   bc, $400
    jp   CopyData

LoadTilemap13::
    ld   a, $10
    call SwitchAdjustedBank
    ld   hl, $6700
    ld   de, $8400
    ld   bc, $400
    call CopyData

    ld   hl, $6000
    ld   de, $9000
    ld   bc, $600
    jp   CopyData

LoadTilemap0D::
    ld   a, $0F
    call SwitchBank
    ld   hl, $4400
    ld   de, $8800
    ld   bc, $500
    jp   CopyData

; NPC tiles banks
NpcTilesBankTable::
    db   $00, BANK(Npc2Tiles), BANK(Npc1Tiles), BANK(Npc3Tiles)

; Load lower section of OAM tiles (NPCs),
; and upper section of BG tiles
LoadTilemap9::
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .colorDungeonEnd
    callsb func_020_475A
    jp   .oamTilesEnd
.colorDungeonEnd

    ;
    ; Load 4 rows of tiles (64 tiles) to NPCs tiles VRAM
    ;

    xor  a
    ; Copy a row of 16 tiles
.copyOAMTilesRow
    ldh  [hScratch0], a
    ld   hl, $C193
    ld   e, a
    ld   d, $00
    add  hl, de
    and  a
    jr   nz, .label_2ED3
    ld   a, [wIsIndoor]
    and  a
    jr   z, .label_2EB0
    ldh  a, [hIsSideScrolling]
    and  a
    jr   nz, .label_2ED3
    ldh  a, [hMapId]
    cp   MAP_KANALET
    jr   z, .label_2ED3
    cp   MAP_CAVE_B
    jr   c, .label_2ED3
    ldh  a, [hMapRoom]
    cp   $FD
    jr   z, .label_2ED3
    cp   $B1
    jr   z, .label_2ED3

.label_2EB0
    ld   a, [wIsBowWowFollowingLink]
    cp   $01
    ld   a, $A4
    jr   z, .label_2ED1
    ld   a, [wIsGhostFollowingLink]
    and  a
    ld   a, $D8
    jr   nz, .label_2ED1
    ld   a, [wIsRoosterFollowingLink]
    and  a
    ld   a, $DD
    jr   nz, .label_2ED1
    ld   a, [wIsMarinFollowingLink]
    and  a
    jr   z, .label_2ED3
    ld   a, $8F

.label_2ED1
    jr   .jr_2ED4

.label_2ED3
    ld   a, [hl]

.jr_2ED4
    and  a
    jr   z, .copyskipEntityLoad
    push af
    and  $3F
    ld   b, a
    ld   c, $00
    pop  af
    swap a
    rra
    rra
    and  $03
    ld   e, a
    ld   d, $00
    ld   hl, NpcTilesBankTable
    add  hl, de
    ld   a, [hl]
    and  a
    jr   z, .bankAdjustmentEnd
    call AdjustBankNumberForGBC
.bankAdjustmentEnd

    ; Do the actual copy to OAM tiles
    ld   [MBC3SelectBank], a
    ldh  a, [hScratch0]
    ld   d, a
    ld   e, $00
    ; destination = Lower-half of the OAM tiles section (NPCs tiles)
    ld   hl, vTiles0 + $400
    add  hl, de
    ld   e, l
    ld   d, h
    ; source = $4000 + bc
    ld   hl, $4000
    add  hl, bc
    ; length = $100
    ld   bc, TILE_SIZE * 16
    call CopyData
.copyskipEntityLoad

    ; while hScratch0 < 4, copy the next row
    ldh  a, [hScratch0]
    inc  a
    cp   $04
    jp   nz, .copyOAMTilesRow
.oamTilesEnd

    ;
    ; Load 8 rows (128 tiles) to the BG-only tiles
    ;

    ld   de, $9000
    ld   a, [wIsIndoor]
    and  a
    jp   z, label_2FAD
    ld   a, $0D
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ldh  a, [hIsSideScrolling]
    and  a
    jr   z, label_2F4B
    ld   hl, $7000
    ldh  a, [hMapId]
    cp   MAP_EAGLES_TOWER
    jr   z, .label_2F41
    cp   MAP_CAVE_B
    jr   nc, .label_2F3B

.label_2F36
    ld   hl, $7800
    jr   .label_2F41

.label_2F3B
    ldh  a, [hMapRoom]
    cp   $E9
    jr   z, .label_2F36
.label_2F41

    ; Copy tiles to the BG tiles
    ld   de, vTiles2
    ld   bc, TILE_SIZE * 128
    call CopyData

    ret

label_2F4B::
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, label_2F57
    ldh  a, [hMapRoom]
    cp   $12
    jr   nz, label_2F69

label_2F57::
    ld   hl, $5000
    ldh  a, [$FF94]
    cp   $FF
    jr   z, label_2F69
    add  a, $50
    ld   h, a
    ld   bc, $100
    call CopyData

label_2F69::
    ldh  a, [hMapId]
    cp   MAP_HOUSE
    jr   nz, label_2F87
    ldh  a, [hMapRoom]
    cp   $B5
    jr   nz, label_2F87
    ld   a, $35
    ld   [MBC3SelectBank], a
    ld   hl, $6600
    ld   de, $8F00
    ld   bc, $200
    call CopyData
    ret

label_2F87::
    ldh  a, [hIsGBC]
    and  a
    ret  z
    ldh  a, [hMapId]
    and  a
    ret  nz
    ld   a, $35
    ld   [MBC3SelectBank], a
    ld   hl, $6E00
    ld   de, $9690
    ld   bc, $10
    call CopyData
    ld   hl, $6E10
    ld   de, $9790
    ld   bc, $10
    call CopyData
    ret

label_2FAD::
    ld   a, $0F
    call AdjustBankNumberForGBC
    ld   [MBC3SelectBank], a
    ldh  a, [$FF94]
    cp   $0F
    jr   z, .return
    add  a, $40
    ld   h, a
    ld   l, $00
    ld   bc, $200
    call CopyData
.return
    ret

; Copy two bytes from hl to de
CopyWord::
    ld   a, [hli]
    ld   [de], a
    inc  de
    ld   a, [hli]
    ld   [de], a
    ret

; TODO: document better
CopySomeDMGMapData::
    ld   a, [hl]
    ld   c, a
    ld   b, $00
    sla  c
    rl   b
    sla  c
    rl   b
    ld   hl, $6749
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   z, label_2FEC
    cp   MAP_HOUSE
    jr   nz, label_2FF1
    ldh  a, [hMapRoom]
    cp   $B5
    jr   nz, label_2FF1

label_2FEC::
    ld   hl, $4760
    jr   label_2FFA

label_2FF1::
    ld   a, [wIsIndoor]
    and  a
    jr   z, label_2FFA
    ld   hl, $4000

label_2FFA::
    add  hl, bc
    ld   a, [hli]
    ld   [de], a
    inc  de
    ld   a, [hli]
    ld   [de], a
    ld   a, e
    add  a, $1F
    ld   e, a
    ld   a, d
    adc  a, $00
    ld   d, a
    ld   a, [hli]
    ld   [de], a
    inc  de
    ld   a, [hl]
    ld   [de], a
    ret

; Given an overworld object, retrieve its tiles and palettes (2x2), and copy them to the BG map
; (CGB only)
;
; Inputs:
;   hl   address of the object in the object map (see wRoomObjects)
WriteOverworldObjectToBG::
    ; Switch to RAM bank 2 (object attributes?)
    ld   a, $02
    ld   [rSVBK], a
    ; ObjectAttributeValue = [hl]
    ld   c, [hl]
    ; Switch back to RAM bank 0
    xor  a
    ld   [rSVBK], a
    jr   doCopyObjectToBG

; Given an indoor object, retrieve its tiles and palettes (2x2), and copy them to the BG map
WriteIndoorObjectToBG::
    ld   c, [hl]

doCopyObjectToBG:
    ; bc = ObjectAttributeValue * 4
    ld   b, $00
    sla  c
    rl   b
    sla  c
    rl   b

    callsb GetBGAttributesAddressForObject

    call SwitchToMapDataBank

    ;
    ; Select the base address for the source tile map
    ;

    ; If IsIndoor…
    ld   a, [wIsIndoor]
    and  a
    jr   z, .isOverworld
    ; … set the default base address
    ld   hl, $43B0
    ; If MapID == MAP_COLOR_DUNGEON, hl = $4760
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   z, .hasSpecialBaseAddress
    ; If MapId == MAP_HOUSE && MapRoom == $B5, hl = $4760
    cp   MAP_HOUSE
    jr   nz, .baseAddressskipEntityLoad
    ldh  a, [hMapRoom]
    cp   $B5
    jr   nz, .baseAddressskipEntityLoad

.hasSpecialBaseAddress
    ld   hl, $4760
    jr   .baseAddressskipEntityLoad

.isOverworld
    ld   hl, $6B1D
.baseAddressskipEntityLoad

    ; Copy tile numbers to BG map for tiles on the upper row
    push de
    add  hl, bc
    call CopyWord
    pop  de

    ; Copy tile attributes to BG map for tiles on the upper row
    push hl
    ldh  a, [hScratch8]
    ld   [MBC3SelectBank], a
    ldh  a, [hScratch9]
    ld   h, a
    ldh  a, [hScratchA]
    ld   l, a
    ld   a, $01
    ld   [rVBK], a
    call CopyWord

    ; Restore RAM and ROM banks
    xor  a
    ld   [rVBK], a
    call SwitchToMapDataBank

    ; Update palette offset
    ld   a, h
    ldh  [hScratch9], a
    ld   a, l
    ldh  [hScratchA], a
    pop  hl

    ; Move BG target down by one row
    ld   a, e
    add  a, $1F
    ld   e, a
    ld   a, d
    adc  a, $00
    ld   d, a

    ; Copy tile numbers for tiles on the lower row
    push de
    call CopyWord
    pop  de

    ; Copy palettes from WRAM1 for tiles on the lower row
    ldh  a, [hScratch8]
    ld   [MBC3SelectBank], a
    ldh  a, [hScratch9]
    ld   h, a
    ldh  a, [hScratchA]
    ld   l, a
    ld   a, $01
    ld   [rVBK], a
    call CopyWord

    ; Restore RAM and ROM banks
    xor  a
    ld   [rVBK], a
    call SwitchToMapDataBank

    ret

; Copy the tile map of a room to BG video memory.
;
; This is used when loading a map in one go (instead
; of having a sliding screen transition.)
; (called by LoadMapData)
LoadTilemap1::
    call SwitchToMapDataBank
    call SwitchBank
    ld   de, vBGMap0
    ld   hl, wRoomObjects
    ld   c, $80

.loop
    push de
    push hl
    push bc

    ; If not running on GBC…
    ldh  a, [hIsGBC]
    and  a
    jr   nz, .copyObjectToBG
    ; …copy some data to vBGMap0
    call CopySomeDMGMapData
    jr   .objectCopyEnd

    ; Copy the object tiles and palettes (2x2 tiles) to the BG map
.copyObjectToBG
    ; If IsIndoor…
    ld   a, [wIsIndoor]
    and  a
    jr   z, .isOverworld
    ; then copy tiles for indoor room
    call WriteIndoorObjectToBG
    jr   .objectCopyEnd
.isOverworld
    ; else copy tiles for overworld room
    call WriteOverworldObjectToBG
.objectCopyEnd

    pop  bc
    pop  hl
    pop  de

    inc  hl
    ld   a, l
    and  $0F
    cp   $0B
    jr   nz, .lEnd
    ld   a, l
    and  $F0
    add  a, $11
    ld   l, a
.lEnd

    ld   a, e
    add  a, $02
    ld   e, a
    and  $1F
    cp   $14
    jr   nz, .aEnd
    ld   a, e
    and  $E0
    add  a, $40
    ld   e, a
    ld   a, d
    adc  a, $00
    ld   d, a
.aEnd

    ; Loop until all objects of the room are copied to the BG
    dec  c
    jr   nz, .loop

    jpsb UpdateMinimapEntranceArrowAndReturn

; Load room objects
LoadRoom::
    ; Disable all interrupts except VBlank
    ld   a, $01
    ld   [rIE], a

    ; Increment $D47F
    ld   hl, $D47F
    inc  [hl]

    callsb ResetRoomVariables

    ; If running on GBC…
    ldh  a, [hIsGBC]
    and  a
    jr   z, .gbcEnd
    ; load palettes
    callsb LoadRoomPalettes
    ; load tile attributes
    callsb LoadRoomObjectsAttributes
.gbcEnd

    ;
    ; Load map pointers bank
    ;

    ld   a, BANK(OverworldRoomPointers)
    ld   [MBC3SelectBank], a
    ; If loading an indoor room…
    ld   a, [wIsIndoor]
    and  a
    jr   z, .indoorSpecialCodeEnd
    ; Do some stuff
    ld   a, BANK(func_014_5897)
    ld   [MBC3SelectBank], a
    ldh  [hRoomBank], a
    call func_014_5897
    ld   e, a
    ld   hl, wKillCount2
.loop
    xor  a
    ldi  [hl], a
    inc  e
    ld   a, e
    cp   $11
    jr   nz, .loop
.indoorSpecialCodeEnd

    ;
    ; Load the room status
    ;

    ; de = hMapRoom
    ldh  a, [hMapRoom]
    ld   e, a
    ld   d, $00
    ; hl = wOverworldRoomStatus
    ld   hl, wOverworldRoomStatus
    ; If loading an indoor room…
    ld   a, [wIsIndoor]
    and  a
    jr   z, .roomStatusEnd
    ; … use the room status for indoor map A
    ld   hl, wIndoorARoomStatus
    ; If Color Dungeon…
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .notColorDungeon
    ; … use the room status for color dungeon
    ld   hl, wColorDungeonRoomStatus
    jr   .roomStatusEnd
.notColorDungeon
    ; Unless on one of the special rooms, use the room status for the indoor map B
    cp   $1A
    jr   nc, .roomStatusEnd
    cp   $06
    jr   c, .roomStatusEnd
    ld   hl, wIndoorBRoomStatus
.roomStatusEnd

    ; a = RoomStatusTable[hMapRoom]
    add  hl, de
    ldh  a, [hIsSideScrolling]
    and  a
    ld   a, [hl]

    ; If the room status was zero (not visited yet), mark the room as visited
    jr   nz, .markVisitedRoomEnd
    or   ROOM_STATUS_VISITED
    ld   [hl], a
.markVisitedRoomEnd

    ; Set the room status as the current room status
    ldh  [hRoomStatus], a

    ;
    ; Select the bank and address for the map pointers table
    ;

    ; bc = hMapRoom
    ldh  a, [hMapRoom]
    ld   c, a
    ld   b, $00
    sla  c
    rl   b

    ; If the room is indoor…
    ld   a, [wIsIndoor]
    and  a
    jr   z, .isIndoorEnd

    ; …use the bank for IndoorA map
    ld   a, BANK(IndoorsARoomPointers)
    ld   [MBC3SelectBank], a
    ldh  [hRoomBank], a

    ; If the room is in the Color Dungeon…
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .colorDungeonEnd
    ; …use the map pointers table specific to the color dungeon.
    ld   hl, ColorDungeonRoomPointers ; color dungeon map pointers table
    jp   .fetchRoomAddress
.colorDungeonEnd

    ; If have the Magnifying Lens, load an alternate Goriya room (where the Goriya NPC is actually present)
    cp   MAP_CAVE_E
    jr   nz, .goriyaRoomEnd
    ldh  a, [hMapRoom]
    cp   $F5
    jr   nz, .goriyaRoomEnd
    ld   a, [wTradeSequenceItem]
    cp   $0E ; Magnifying Glass
    jr   nz, .goriyaRoomEnd
    ld   bc, IndoorsAUnreferenced02
    jp   .parseRoomHeader
.goriyaRoomEnd

    ; If the map is less than MAP_UNKNOWN_1A…
    ld   hl, IndoorsARoomPointers
    ldh  a, [hMapId]
    cp   MAP_UNKNOWN_1A
    jr   nc, .fetchRoomAddress
    ; …and the map is greater than the first 6 dungeons…
    cp   MAP_EAGLES_TOWER
    jr   c, .fetchRoomAddress
    ; …use the bank for IndoorB map.
    ld   a, BANK(IndoorsBRoomPointers)
    ld   [MBC3SelectBank], a
    ldh  [hRoomBank], a
    ld   hl, IndoorsBRoomPointers
    jr   .fetchRoomAddress

.isIndoorEnd

    ;
    ; Swap some Overworld rooms with alternative layouts
    ;

    ldh  a, [hMapRoom]
    cp   $0E
    jr   nz, .endEaglesTowerAlt
    ld   a, [$D80E]
    and  ROOM_STATUS_CHANGED
    jr   z, .altRoomsEnd
    ld   bc, OverworldUnreferenced01 ; Eagle's Tower open
    jr   .loadBankForOverworldRooms
.endEaglesTowerAlt

    cp   $8C
    jr   nz, .endSouthFaceShrineAlt
    ld   a, [$D88C]
    and  ROOM_STATUS_CHANGED
    jr   z, .altRoomsEnd
    ld   bc, OverworldUnreferenced05 ; South Face Shrine open
    jr   .loadBankForOverworldRooms
.endSouthFaceShrineAlt

    cp   $79
    jr   nz, .endUpperTalTalHeightsAlt
    ld   a, [$D879]
    and  ROOM_STATUS_CHANGED
    jr   z, .altRoomsEnd
    ld   bc, OverworldUnreferenced04 ; Upper Tal Tal Heights dry
    jr   .loadBankForOverworldRooms
.endUpperTalTalHeightsAlt

    cp   $06
    jr   nz, .endWindfishsEggAlt
    ld   a, [$D806]
    and  ROOM_STATUS_CHANGED
    jr   z, .altRoomsEnd
    ld   bc, OverworldUnreferenced00 ; Windfish's Egg open
    jr   .loadBankForOverworldRooms
.endWindfishsEggAlt

    cp   $1B
    jr   nz, .endTalTalHeightsAlt
    ld   a, [$D82B]
    and  ROOM_STATUS_CHANGED
    jr   z, .altRoomsEnd
    ld   bc, OverworldUnreferenced02 ; Tal Tal Heights dry
    jr   .loadBankForOverworldRooms
.endTalTalHeightsAlt

    cp   $2B
    jr   nz, .altRoomsEnd
    ld   a, [$D82B]
    and  ROOM_STATUS_CHANGED
    jr   z, .altRoomsEnd
    ld   bc, OverworldUnreferenced03 ; Angler's Tunnel open
    jr   .loadBankForOverworldRooms

.altRoomsEnd

    ;
    ; Get room address from index
    ;
    ; hl: rooms base address
    ; bc: room index
    ;

    ; Set the base address for resolving usual room pointers
    ; (except Color Dungeon)
    ld   hl, $4000

.fetchRoomAddress
    ; b = hl[room index]
    ; c = hl[room index + 1]
    add  hl, bc
    ld   a, [hli]
    ld   c, a
    ld   a, [hl]
    ld   b, a

    ;
    ; Load proper bank for Overworld rooms
    ;

    ; If in Overworld…
    ld   a, [wIsIndoor]
    and  a
    jr   nz, .parseRoomHeader
.loadBankForOverworldRooms
    ; … and the overworld room index is >= $80…
    ldh  a, [hMapRoom]
    cp   $80
    jr   c, .parseRoomHeader
    ; … select bank for second half of Overworld rooms
    ld   a, BANK(OverworldRoomsSecondHalf)
    ld   [MBC3SelectBank], a

    ;
    ; Parse room header
    ; bc: address of room header data
    ;
.parseRoomHeader

    ; Parse header first byte (animated tiles group)
    ld   a, [bc]
    cp   ROOM_END
    jr   z, .endOfRoom
    ldh  [hAnimatedTilesGroup], a

    ; Parse header second byte
    inc  bc
    ld   a, [wIsIndoor]
    and  a
    jr   z, .parseOverworldSecondByte

.parseIndoorsSecondByte
    ; For indoor rooms, the lower nybble is the floor tile…
    ld   a, [bc]
    and  $0F
    call FillRoomMapWithObject
    ; … and the upper nybble is the room template
    ld   a, [bc]
    swap a
    and  $0F
    call LoadRoomTemplate_trampoline
    jr   .parseRoomObjectsLoop

.parseOverworldSecondByte
    ; For overworld rooms, the second byte is just the floor tile
    ld   a, [bc]
    call FillRoomMapWithObject

    ;
    ; Parse room objects
    ;

.parseRoomObjectsLoop
    ; Increment the current address
    inc  bc
    ; a = object type
    ld   a, [bc]

    ; If object is warp data…
    and  %11111100
    cp   ROOM_WARP
    jr   nz, .warpDataEnd
    ; …copy object to the first available warp data slot.
    ldh  a, [hFreeWarpDataAddress]
    ld   e, a
    ld   d, $00
    ld   hl, wWarpStructs
    add  hl, de
    ld   a, [bc]
    and  $03
    ldi  [hl], a
    inc  bc
    ld   a, [bc]
    ldi  [hl], a
    inc  bc
    ld   a, [bc]
    ldi  [hl], a
    inc  bc
    ld   a, [bc]
    ldi  [hl], a
    inc  bc
    ld   a, [bc]
    ldi  [hl], a
    ; Increment the address of the first available warp data slot
    ld   a, e
    add  a, $05
    ldh  [hFreeWarpDataAddress], a
    jr   .parseRoomObjectsLoop
.warpDataEnd

    ; a = object type
    ld   a, [bc]
    ; If we reached the end of the room objects, exit the loop
    cp   ROOM_END
    jr   z, .endOfRoom

    call LoadRoomObject
    jr   .parseRoomObjectsLoop

.endOfRoom

    ; Surround the objects area defining a room by ROOM_BORDER values
    callsb PadRoomObjectsArea

    ; Do stuff that returns early if end-of-room
    callsb func_036_6D4D

    ; Load palette for room objects?
    callsb func_021_53F3

    ; Reload saved bank and return
    jp   ReloadSavedBank

; Read an individual room object, and write it to the unpacked room objects area.
; bc : start address of the object
;
; Objects can be 2-bytes objects or 3-bytes objects:
;
; twoBytesObject:
;   ds 1 ; location (YX)
;   ds 1 ; type
;
; threeBytesObject:
;   ds 1 ; direction and length (8X: horizontal + length ; CX: vertical + length)
;   ds 1 ; location (YX)
;   ds 1 ; type
;
LoadRoomObject::
    ; Clear hScratch0
    xor  a
    ldh  [hScratch0], a

    ; If object type first bit is 1…
    ld   a, [bc]
    bit  7, a
    jr   z, .threeBytesObjectEnd
    ; … and object type 4th bit is 0…
    bit  4, a
    jr   nz, .threeBytesObjectEnd
    ; … this is a three-bytes object, that spans more than one block.
    ; The first byte encodes the direction and length of the block:
    ; save it to hScratch0.
    ldh  [hScratch0], a
    ; Skip the parsed direction-and-length byte
    inc  bc
.threeBytesObjectEnd

    ; Increment read pointer to the object type
    inc  bc

    ; e = hRoomStatus
    ldh  a, [hRoomStatus]
    ld   e, a

    ; If currently on Overworld…
    ld   a, [wIsIndoor]
    and  a
    jr   nz, .loadIndoorObject

    ; Overworld objects with type >= $F5 are handled by code in another bank.

    ; If object is an Overworld macro…
    ld   a, [bc]
    sub  a, OBJECT_MACRO_F5
    jr   c, .loadOverworldObject
    ; d = object type
    ld   a, [bc]
    ld   d, a
    ; e = object position
    dec  bc
    ld   a, [bc]
    ld   e, a
    ; (re-increment bc to be at the object type again)
    inc  bc
    ; Handle the macro
    callsb ApplyOverworldObjectMacro
    call SetBankForRoom
    ; Return early
    ret

.loadIndoorObject
    ; a = object type - OBJECT_KEY_DOOR_TOP
    ld   a, [bc]
    sub  a, OBJECT_KEY_DOOR_TOP
    ; If a >= OBJECT_KEY_DOOR_TOP, dispatch to the door object handlers
    jp  c, .loadNonDoorIndoorObject
    JP_TABLE
._EC dw LoadObject_KeyDoorTop
._ED dw LoadObject_KeyDoorBottom
._EE dw LoadObject_KeyDoorLeft
._EF dw LoadObject_KeyDoorRight
._F0 dw LoadObject_ClosedDoorTop
._F1 dw LoadObject_ClosedDoorBottom
._F2 dw LoadObject_ClosedDoorLeft
._F3 dw LoadObject_ClosedDoorRight
._F4 dw LoadObject_OpenDoorTop
._F5 dw LoadObject_OpenDoorBottom
._F6 dw LoadObject_OpenDoorLeft
._F7 dw LoadObject_OpenDoorRight
._F8 dw LoadObject_BossDoor
._F9 dw LoadObject_StairsDoor
._FA dw LoadObject_FlipWall
._FB dw LoadObject_OneWayArrow
._FC dw LoadObject_DungeonEntrance
._FD dw LoadObject_IndoorEntrance

; Load an Overworld object (that is not a macro)
.loadOverworldObject
    ; Re-increment a to be the object type
    add  a, $F5
    push af
    ; d = a
    ld   d, a

    cp   OBJECT_WATERFALL
    jr   nz, .waterfallEnd
    ld   [$C50E], a
.waterfallEnd

    ;
    ; If the Weather Vane is pushed open, shift it to the top
    ;

    cp   OBJECT_WEATHER_VANE_BASE
    jr   nz, .weatherVaneBottomEnd
    bit  5, e ; object position
    jr   nz, .replaceObjectByGroundStairs
.weatherVaneBottomEnd

    cp   OBJECT_WEATHER_VANE_TOP
    jr   nz, .weatherVaneTopEnd
    bit  5, e ; object position
    jr   z, .weatherVaneTopEnd
    ; replace the top by the vane base
    pop  af
    ld   a, OBJECT_WEATHER_VANE_BASE
    ld   d, a
    push af
.weatherVaneTopEnd

    cp   OBJECT_WEATHER_VANE_ABOVE
    jr   nz, .weatherVaneAboveEnd
    bit  5, e ; object position
    jr   z, .weatherVaneAboveEnd
    ; replace the grass above by the vane top
    pop  af
    ld   a, OBJECT_WEATHER_VANE_TOP
    ld   d, a
    push af
.weatherVaneAboveEnd

    ;
    ; If the Monkey Bridge is built yet, display it
    ;

    cp   OBJECT_MONKEY_BRIDGE_TOP
    jr   z, .loadMonkeyBridgeObject
    cp   OBJECT_MONKEY_BRIDGE_MIDDLE
    jr   z, .loadMonkeyBridgeObject
    cp   OBJECT_MONKEY_BRIDGE_BOTTOM
    jr   nz, .monkeyBridgeEnd

.loadMonkeyBridgeObject
    ; If the monkey bridge is built…
    bit  4, e
    jr   z, .monkeyBridgeEnd
    ; …replace the object by the monkey bridge
    pop  af
    ld   a, OBJECT_MONKEY_BRIDGE_BUILT
    ld   d, a
    push af
.monkeyBridgeEnd

    ; If a closed gate has been opened…
    cp   OBJECT_CLOSED_GATE
    jr   nz, .closedGateEnd
    bit  4, e
    jr   z, .closedGateEnd
    ; …replace the object by the open cave entrance
    pop  af
    ld   a, OBJECT_CAVE_DOOR
    ld   d, a
    push af
.closedGateEnd

    ; If a bombable cave door has been bombed…
    ld   a, d
    cp   OBJECT_BOMBABLE_CAVE_DOOR
    jr   nz, .bombableCaveDoorEnd
    bit  2, e
    jr   z, .bombableCaveDoorEnd
    ; …replace the object by the open rocky cave entrance
    pop  af
    ld   a, OBJECT_ROCKY_CAVE_DOOR
    ld   d, a
    push af
.bombableCaveDoorEnd

    ; If a bush masking a cave entrance has been cut…
    ld   a, d
    cp   OBJECT_BUSH_GROUND_STAIRS
    jr   nz, .bushGroundStairsEnd
    bit  4, e
    jr   z, .bushGroundStairsEnd
    ldh  a, [hMapRoom]
    cp   $75
    jr   z, .replaceObjectByGroundStairs
    cp   $07
    jr   z, .replaceObjectByGroundStairs
    cp   $AA
    jr   z, .replaceObjectByGroundStairs
    cp   $4A
    jr   nz, .bushGroundStairsEnd
.replaceObjectByGroundStairs
    pop  af
    ld   a, OBJECT_GROUND_STAIRS
    ld   d, a
    push af
.bushGroundStairsEnd

    ; hScratch9 = object type
    ld   a, d
    ldh  [hScratch9], a

    ; If object is an entrance to somewhere else…
    cp   OBJECT_CLOSED_GATE
    jr   z, .configureDoorWarpData
    cp   OBJECT_ROCKY_CAVE_DOOR
    jr   z, .configureDoorWarpData
    cp   $CB
    jr   z, .configureDoorWarpData
    cp   OBJECT_BOMBABLE_CAVE_DOOR
    jr   z, .configureDoorWarpData
    cp   $61
    jr   z, .configureDoorWarpData
    cp   OBJECT_GROUND_STAIRS
    jr   z, .configureDoorWarpData
    cp   $C5
    jr   z, .configureDoorWarpData
    cp   $E2
    jr   z, .configureDoorWarpData
    cp   OBJECT_CAVE_DOOR
    jr   nz, .overworldDoorEnd

.configureDoorWarpData
    ld   a, [$C19C]
    ld   e, a
    inc  a
    and  $03
    ld   [$C19C], a
    ld   d, $00
    ld   hl, wWarpPositions
    add  hl, de
    dec  bc
    ld   a, [bc]
    ld   [hl], a
    inc  bc
.overworldDoorEnd

    ; a = object type
    ldh  a, [hScratch9]

    cp   $C5
    jp   z, .configureStairs
    cp   OBJECT_GROUND_STAIRS
    jp   z, .configureStairs
    jp   .breakableObjectEnd

.loadNonDoorIndoorObject
    ; Re-increment a to be the object type
    add  a, OBJECT_KEY_DOOR_TOP
    ldh  [hScratch9], a

    ; If object type is a conveyor belt…
    push af
    cp   OBJECT_CONVEYOR_BOTTOM
    jr   c, .conveyorEnd
    cp   OBJECT_TRENDY_GAME_BORDER
    jr   nc, .conveyorEnd
    ; …increment the number of conveyor belts present on screen
    ld   hl, wConveyorBeltsCount
    inc  [hl]
.conveyorEnd

    ; If object is an unlit torch…
    cp   OBJECT_TORCH_UNLIT
    jr   nz, .torchEnd
    ; clear wObjectAffectingBGPalette
    xor  a
    ld   [wObjectAffectingBGPalette], a
    ; If the room is $C4…
    ldh  a, [hMapRoom]
    cp   $C4
    ; … and the object type is not zero…
    ldh  a, [hScratch9]
    jr   z, .torchEnd
    ; …then increment the number of torches in the room
    ld   hl, wTorchesCount
    inc  [hl]
    ; mark the torch as affecting the background palette
    ld   [wObjectAffectingBGPalette], a
    ; $C3CD += 4
    push af
    ld   a, [$C3CD]
    add  a, $04
    ld   [$C3CD], a
    ; If not on GBC…
    ldh  a, [hIsGBC]
    and  a
    jr   nz, .dmgTorchesEnd
    ; …configure the transition counter that will dim the lights
    ; when entering the room.
    ld   a, $04
    ld   [wTransitionSequenceCounter], a
.dmgTorchesEnd
    pop  af
.torchEnd

    ;
    ; Configure switches and movable blocks
    ;

    cp   OBJECT_POT_WITH_SWITCH
    jr   z, .configureSwitchButton
    cp   OBJECT_SWITCH_BUTTON
    jr   z, .configureSwitchButton

    cp   OBJECT_RAISED_BLOCK
    jr   z, .configureMovableBlock
    cp   OBJECT_LOWERED_BLOCK
    jr   nz, .switchableObjectsEnd

.configureMovableBlock
    ld   hl, wRoomSwitchableObject
    ld   [hl], ROOM_SWITCHABLE_OBJECT_MOBILE_BLOCK
    jr   .switchableObjectsEnd

.configureSwitchButton
    ld   hl, wRoomSwitchableObject
    ld   [hl], ROOM_SWITCHABLE_OBJECT_SWITCH_BUTTON
.switchableObjectsEnd

    ;
    ; Configure top and bottom bombable walls
    ;

    cp   OBJECT_BOMBABLE_WALL_TOP
    jr   z, .configureBombableWallTop
    cp   OBJECT_HIDDEN_BOMBABLE_WALL_TOP
    jr   nz, .bombableWallBottom
.configureBombableWallTop
    ; If a top bombable wall has been bombed…
    bit  2, e
    ; …replace the wall by a bombed passage
    jr   nz, .replaceByVerticalBombedPassage

.bombableWallBottom
    cp   OBJECT_BOMBABLE_WALL_BOTTOM
    jr   z, .configureBombableWallBottom
    cp   OBJECT_HIDDEN_BOMBABLE_WALL_BOTTOM
    jr   nz, .verticalBombableWallsEnd
.configureBombableWallBottom
    ; If a bottom bombable wall has been bombed…
    bit  3, e
    jr   z, .verticalBombableWallsEnd
    ; …replace the wall by a bombed passage

.replaceByVerticalBombedPassage
    pop  af
    ld   a, OBJECT_BOMBED_PASSAGE_VERTICAL
    push af
.verticalBombableWallsEnd

    ;
    ; Configure left and right bombable walls
    ;

    cp   OBJECT_BOMBABLE_WALL_LEFT
    jr   z, .configureBombableWallLeft
    cp   OBJECT_HIDDEN_BOMBABLE_WALL_LEFT
    jr   nz, .bombableWallRight

.configureBombableWallLeft
    ; If a left bombable wall has been bombed…
    bit  1, e
    ; …replace the wall by a bombed passage
    jr   nz, .replaceByHorizontalBombedPassage

.bombableWallRight
    cp   OBJECT_BOMBABLE_WALL_RIGHT
    jr   z, .configureBombableWallRight
    cp   OBJECT_HIDDEN_BOMBABLE_WALL_RIGHT
    jr   nz, .horizontalBombableWallsEnd
.configureBombableWallRight
    ; If a right bombable wall has been bombed…
    bit  0, e
    ; …replace the wall by a bombed passage
    jr   z, .horizontalBombableWallsEnd

.replaceByHorizontalBombedPassage
    pop  af
    ld   a, OBJECT_BOMBED_PASSAGE_HORIZONTAL
    push af
.horizontalBombableWallsEnd

    ;
    ; Configure chest
    ;

    ; If object is a chest…
    cp   OBJECT_CHEST_OPEN
    jr   nz, .chestEnd
    ; … and the chest has been opened…
    bit  4, e
    jr   nz, .chestEnd
    ; a = [$FFE9]
    pop  af
    ldh  a, [$FFE9]
    push af
.chestEnd

    ;
    ; Configure hidden stairs
    ;

    ; If the object is hidden stairs…
    cp   OBJECT_HIDDEN_STAIRS_DOWN
    jr   nz, .hiddenStairsEnd
    ; … and the stairs are not visible yet…
    bit  4, e
    jr   nz, .hiddenStairsEnd
    ; return without loading this object.
    pop  af
    ret
.hiddenStairsEnd

    ;
    ; Configure stairs
    ;

    cp   OBJECT_STAIRS_DOWN
    jr   z, .configureStairs
    cp   OBJECT_HIDDEN_STAIRS_DOWN
    jr   z, .configureStairs
    cp   OBJECT_STAIRS_UP
    jr   nz, .stairsEnd

.configureStairs
    dec  bc
    ld   a, $01
    ldh  [$FFAC], a
    ld   a, [bc]
    and  $F0
    add  a, $10
    ldh  [$FFAE], a
    ld   a, [bc]
    swap a
    and  $F0
    add  a, $08
    ldh  [$FFAD], a
    inc  bc
    jp   .breakableObjectEnd
.stairsEnd

    ;
    ; Configure raised fences
    ;
    ; Raised fences can be activated: they turn into a wall
    ; jumpable from the top.
    ;
    ; NB: it seems these objects are not used in the final game.
    ;

    cp   OBJECT_RAISED_FENCE_BOTTOM
    jr   z, .configureVerticalFence
    cp   OBJECT_RAISED_FENCE_TOP
    jr   nz, .verticalFenceEnd
.configureVerticalFence
    ; If the fence has been lowered…
    bit  4, e
    jr   nz, .verticalFenceEnd
    ; … replace the fence by a jumpable wall
    pop  af
    ld   a, OBJECT_WALL_TOP
    push af
.verticalFenceEnd

    cp   OBJECT_RAISED_FENCE_LEFT
    jr   z, .configureHorizontalFence
    cp   OBJECT_RAISED_FENCE_RIGHT
    jr   nz, .horizontalFenceEnd

.configureHorizontalFence
    ; If the fence has been lowered…
    bit  4, e
    jr   nz, .horizontalFenceEnd
    ; … replace the fence by a jumpable wall
    pop  af
    ld   a, OBJECT_WALL_BOTTOM
    push af
.horizontalFenceEnd

    ;
    ; Configure breakable objects
    ;

    ldh  a, [hMapId]
    cp   MAP_CAVE_B
    ldh  a, [hScratch9]
    jr   c, .bombableBlockEnd
    cp   OBJECT_BOMBABLE_BLOCK
    jr   z, .configureBreakableObject
.bombableBlockEnd

    cp   OBJECT_KEYHOLE_BLOCK
    jr   nz, .breakableObjectEnd

.configureBreakableObject
    ; If the object has been broken or activated…
    bit  6, e
    jr   z, .breakableObjectEnd
    ; … replace it by an empty floor tile
    pop  af
    ld   a, OBJECT_FLOOR_OD
    push af
.breakableObjectEnd

    ;
    ; Configure chest
    ;

    ; If the object is an closed chest…
    cp   OBJECT_CHEST_CLOSED
    jr   nz, .closedChestEnd
    ; … and the chest has already been opened…
    bit  4, e
    jr   z, .closedChestEnd
    ; … replace it by an open chest
    pop  af
    ld   a, OBJECT_CHEST_OPEN
    push af
.closedChestEnd

    ; a = multiple-blocks object direction and length
    ld   d, $00
    ldh  a, [hScratch0]
    ; If there are no coordinates for a multiple-blocks object…
    and  a
    ; … this is a single-block object:
    ; copy the object to the unpacked map and return
    jr   z, CopyObjectToActiveRoomMap


    ; This is a multiple-blocks object.
    ; hl = initial position address
    dec  bc
    ld   a, [bc]
    ld   e, a
    ld   hl, wRoomObjects
    add  hl, de
    ; e = count
    ldh  a, [hScratch0]
    and  $0F
    ld   e, a
    ; d = object type
    pop  af
    ld   d, a
    ; fallthrough FillRoomWithConsecutiveObjects

; Fill the active room map with many consecutive objects
; Inputs:
;   d      object type
;   e      count
;   hl     destination address
;   hScratch0  object data (including the direction)
FillRoomWithConsecutiveObjects::
    ; Copy object type to the active room map
    ld   a, d
    ldi  [hl], a

    ; If the object direction is vertical…
    ldh  a, [hScratch0]
    and  $40
    jr   z, .verticalEnd
    ; … increment the target address to move to the next column
    ld   a, l
    add  a, $0F
    ld   l, a
.verticalEnd

    ; While the object count didn't reach 0, loop
    dec  e
    jr   nz, FillRoomWithConsecutiveObjects

    ; Cleanup
    inc  bc
    ret

; On GBC, special case for some overworld objects
label_3500::
    cp   $04
    ret  z
    cp   $09
    jr   nz, label_350E
    ldh  a, [hMapRoom]
    cp   $97
    ret  nz
    jr   label_3527

label_350E::
    cp   $E1
    jr   nz, label_351D
    ldh  a, [hMapRoom]
    cp   $0E
    ret  z
    cp   $0C
    ret  z
    cp   $1B
    ret  z

label_351D::
    ldh  a, [hMapRoom]
    cp   $80
    jr   nc, label_3527
    ld   a, $09
    jr   label_3529

label_3527::
    ld   a, $1A

label_3529::
    call func_2BF
    ret

; Copy an object from the room data to the active room
; Inputs:
;  bc        object object address + 1 ([room position, object value])
;  stack[0]  object value
CopyObjectToActiveRoomMap::
    ; Load the position of the object in the room
    dec  bc
    ld   a, [bc]
    ld   e, a
    ld   hl, wRoomObjects
    add  hl, de
    ; Pop the object value from the stack
    pop  af
    ; Copy the object to the active room
    ld   [hl], a
    ; On GBC, do some special-case handling
    call label_3500
    ; Cleanup
    inc  bc
    ret

; Use the current overworld room to load the adequate bank
SetBankForRoom::
    ldh  a, [hMapRoom]
    ; If hMapRoom <= $80…
    cp   $80
    jr   nc, .moreThan80
    ; … a = $09
    ld   a, BANK(OverworldRoomsFirstHalf)
    jr   .fi
.moreThan80
    ; else a = $1A
    ld   a, BANK(OverworldRoomsSecondHalf)
.fi
    ; Load the bank $09 or $1A
    ld   [MBC3SelectBank], a
    ret

; Load object or objects?
Func_354B::
    push hl
    push de
    ld   a, [bc]
    ld   e, a
    ld   d, $00
    add  hl, de
    pop  de
    ld   a, [de]
    cp   $E1
    jr   z, .label_3560
    cp   $E2
    jr   z, .label_3560
    cp   $E3
    jr   nz, .label_357C

.label_3560
    push af
    push hl
    push de
    ld   a, l
    sub  a, $11
    push af
    ld   a, [$C19C]
    ld   e, a
    inc  a
    and  $03
    ld   [$C19C], a
    ld   d, $00
    ld   hl, wWarpPositions
    add  hl, de
    pop  af
    ld   [hl], a
    pop  de
    pop  hl
    pop  af

.label_357C
    ld   [hl], a
    call label_3500
    inc  de
    inc  bc
    pop  hl
    ld   a, [bc]
    and  a
    cp   $FF
    jr   nz, Func_354B
    pop  bc
    ret

Func_358B::
    push hl
    push de
    ld   a, [bc]
    ld   e, a
    ld   d, $00
    add  hl, de
    pop  de
    ld   a, [de]
    cp   $E1
    jr   z, .label_35A0
    cp   $E2
    jr   z, .label_35A0
    cp   $E3
    jr   nz, .label_35BC

.label_35A0
    push af
    push hl
    push de
    ld   a, l
    sub  a, $11
    push af
    ld   a, [$C19C]
    ld   e, a
    inc  a
    and  $03
    ld   [$C19C], a
    ld   d, $00
    ld   hl, wWarpPositions
    add  hl, de
    pop  af
    ld   [hl], a
    pop  de
    pop  hl
    pop  af

.label_35BC
    ld   [hl], a
    call label_35CB
    inc  de
    inc  bc
    pop  hl
    ld   a, [bc]
    and  a
    cp   $FF
    jr   nz, Func_358B
    pop  bc
    ret

label_35CB::
    cp   $04
    ret  z
    cp   $09
    jr   nz, .label_35D9
    ldh  a, [hMapRoom]
    cp   $97
    ret  nz
    jr   label_35E8

.label_35D9
    cp   $E1
    jr   nz, label_35E8
    ldh  a, [hMapRoom]
    cp   $0E
    ret  z
    cp   $0C
    ret  z
    cp   $1B
    ret  z

label_35E8::
    ld   a, $24
    call func_2BF
    ret

label_35EE::
    dec  bc
    ld   a, [bc]
    ld   e, a
    ld   d, $00
    ld   hl, wRoomObjects
    add  hl, de
    ret

data_35F8::
    db $2D, $2E

LoadObject_KeyDoorTop::
    ld   e, 0
    call func_373F
    ldh  a, [hRoomStatus]
    and  $04
    jp   nz, LoadObject_OpenDoorTop
    push bc
    call label_35EE
    ld   bc, data_37E1
    ld   de, data_35F8
    jp   Func_354B

data_3613::
    db   $2F, $30

LoadObject_KeyDoorBottom::
    ld   e, $01
    call func_373F
    ldh  a, [hRoomStatus]
    and  $08
    jp   nz, LoadObject_OpenDoorBottom

    push bc
    call label_35EE
    ld   bc, data_37E1
    ld   de, data_3613
    jp   Func_354B

data_362E::
    db   $31, $32

LoadObject_KeyDoorLeft::
    ld   e, $02
    call func_373F
    ldh  a, [hRoomStatus]
    and  $02
    jp   nz, LoadObject_OpenDoorLeft

    push bc
    call label_35EE
    ld   bc, data_37E4
    ld   de, data_362E
    jp   Func_354B

data_3649::
    db   $33, $34

LoadObject_KeyDoorRight::
    ld   e, $03
    call func_373F
    ldh  a, [hRoomStatus]
    and  $01
    jp   nz, LoadObject_OpenDoorRight

    push bc
    call label_35EE
    ld   bc, data_37E4
    ld   de, data_3649
    jp   Func_354B

LoadObject_ClosedDoorTop::
    ld   e, $04
    call func_373F
    ld   a, [$C18A]
    or   $01
    ld   [$C18A], a
    ld   [$C18B], a
    jp   LoadObject_OpenDoorTop

LoadObject_ClosedDoorBottom::
    ld   e, $05
    call func_373F
    ld   a, [$C18A]
    or   $02
    ld   [$C18A], a
    ld   [$C18B], a
    jp   LoadObject_OpenDoorBottom

LoadObject_ClosedDoorLeft::
    ld   e, $06
    call func_373F
    ld   a, [$C18A]
    or   $04
    ld   [$C18A], a
    ld   [$C18B], a
    jp   LoadObject_OpenDoorLeft

LoadObject_ClosedDoorRight::
    ld   e, $07
    call func_373F
    ld   a, [$C18A]
    or   $08
    ld   [$C18A], a
    ld   [$C18B], a
    jp   LoadObject_OpenDoorRight

data_36B0::
    db   $43, $44

LoadObject_OpenDoorTop::
    ld   a, $04
    call label_36C4
    push bc
    call label_35EE
    ld   bc, data_37E1
    ld   de, data_36B0
    jp   Func_354B

; Set hRoomStatus depending on the map and room
label_36C4::
    push af
    ld   hl, $D900
    ldh  a, [hMapRoom]
    ld   e, a
    ld   d, $00
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, label_36D8
    ld   hl, $DDE0
    jr   label_36E1

label_36D8::
    cp   $1A
    jr   nc, label_36E1
    cp   $06
    jr   c, label_36E1
    inc  d

label_36E1::
    add  hl, de
    pop  af
    or   [hl]
    ld   [hl], a
    ldh  [hRoomStatus], a
    ret

data_36E8::
    db $8C, 8

LoadObject_OpenDoorBottom::
    ld   a, 8
    call label_36C4
    push bc
    call label_35EE
    ld   bc, data_37E1
    ld   de, data_36E8
    jp   Func_354B

data_36FC::
    db 9, $A

LoadObject_OpenDoorLeft::
    ld   a, $02
    call label_36C4
    push bc
    call label_35EE
    ld   bc, data_37E4
    ld   de, data_36FC
    jp   Func_354B

data_3710::
    db $B, $C

LoadObject_OpenDoorRight::
    ld   a, $01
    call label_36C4
    push bc
    call label_35EE
    ld   bc, data_37E4
    ld   de, data_3710
    jp   Func_354B

data_3724::
    db $A4, $A5

LoadObject_BossDoor::
    ld   e, $08
    call func_373F
    ldh  a, [hRoomStatus]
    and  $04
    jp   nz, LoadObject_OpenDoorTop
    push bc
    call label_35EE
    ld   bc, data_37E1
    ld   de, data_3724
    jp   Func_354B

func_373F::
    ld   d, $00
    ld   hl, $C1F0
    add  hl, de
    dec  bc
    ld   a, [bc]
    ld   [hl], a
    push af
    and  $F0
    ld   hl, $C1E0
    add  hl, de
    ld   [hl], a
    pop  af
    swap a
    and  $F0
    ld   hl, $C1D0
    add  hl, de
    ld   [hl], a
    inc  bc
    ret

data_375C::
    db   $AF, $B0

LoadObject_StairsDoor::
    push bc                                       ; $375E: $C5
    call label_35EE                               ; $375F: $CD $EE $35
    ld   bc, data_37E4                            ; $3762: $01 $E4 $37
    ld   de, data_375C                            ; $3765: $11 $5C $37
    jp   Func_354B                                ; $3768: $C3 $4B $35

data_376B::
    db   $B1, $B2

LoadObject_FlipWall::
    push bc                                       ; $376D: $C5
    call label_35EE                               ; $376E: $CD $EE $35
    ld   bc, data_37E1                            ; $3771: $01 $E1 $37
    ld   de, data_376B                            ; $3774: $11 $6B $37
    jp   Func_354B                                ; $3777: $C3 $4B $35

data_377A::
    db   $45, $46

LoadObject_OneWayArrow::
    push bc                                       ; $377C: $C5
    call label_35EE                               ; $377D: $CD $EE $35
    ld   bc, data_37E1                            ; $3780: $01 $E1 $37
    ld   de, data_377A                            ; $3783: $11 $7A $37
    jp   Func_354B                               ; $3786: $C3 $4B $35

data_3789::
    db   0, 1, 2, 3, $10, $11, $12, $13, $20, $21, $22, $23, $FF

data_3796::
    db   $B3, $B4, $B4, $B5, $B6, $B7, $B8, $B9, $BA, $BB, $BC, $BD

LoadObject_DungeonEntrance::
    ld   a, $08                                   ; $37A2: $3E $08
    call label_36C4                               ; $37A4: $CD $C4 $36
    push bc                                       ; $37A7: $C5
    call label_35EE                               ; $37A8: $CD $EE $35
    ld   bc, data_3789                            ; $37AB: $01 $89 $37
    ld   de, data_3796                            ; $37AE: $11 $96 $37
    jp   Func_354B                               ; $37B1: $C3 $4B $35

data_37B4::
    db   $C1, $C2

LoadObject_IndoorEntrance::
    ; If MapId < $1A…
    ldh  a, [hMapId]
    cp   MAP_UNKNOWN_1A
    jr   nc, .end

    ; … and MapId >= MAP_EAGLES_TOWER…
    cp   MAP_EAGLES_TOWER
    jr   c, .end

    ; … and MapRoom == $D3…
    ldh  a, [hMapRoom]
    cp   $D3
    jr   nz, .end

    ; … and $DB46 != 0…
    ld   a, [$DB46]
    and  a
    jr   z, .end

    ; … handle special case.
    jp   LoadObject_ClosedDoorBottom

.end

    ld   a, $01
    call label_36C4
    push bc
    call label_35EE
    ld   bc, data_37E1
    ld   de, data_37B4
    ; tail-call jump
    jp   Func_354B

data_37E1::
    db   $00
    db   $01
    db   $FF

data_37E4::
    db   $00
    db   $10
    db   $FF

; Fill all the active room map with the same object
; Inputs:
;   a   the object type to fill the map with
FillRoomMapWithObject::
    ldh  [$FFE9], a
    ld   d, TILES_PER_MAP
    ld   hl, wRoomObjects
    ld   e, a

.loop
    ld   a, l
    and  $0F
    jr   z, .continue
    cp   $0B ; TILES_PER_ROW+1
    jr   nc, .continue
    ld   [hl], e

.continue
    inc  hl
    dec  d
    jr   nz, .loop
    ret

; Retrieve the entities list for this room, and load each entity from its definition.
LoadRoomEntities::
    callsb UpdateRecentRoomsList

    ld   a, BANK(OverworldEntitiesPointersTable)
    ld   [MBC3SelectBank], a

    ; Reset the entities load order
    xor  a
    ldh  [hScratchD], a

    ; bc = [hMapRoom] * 2
    ldh  a, [hMapRoom]
    ld   c, a
    ld   b, $00
    sla  c
    rl   b

    ;
    ; Compute the proper entities pointers table for the room
    ;

    ; If on overworld, we're skipEntityLoad.
    ld   hl, OverworldEntitiesPointersTable
    ld   a, [wIsIndoor]
    and  a
    jr   z, .pointersTableEnd

    ; The room is indoors.

    ; If in Eagle's Tower…
    ldh  a, [hMapId]
    cp   MAP_EAGLES_TOWER
    jr   nz, .eaglesTowerEnd
    ; … and [hMapRoom] == [$DB6F]…
    ld   a, [$DB6F]
    ld   hl, hMapRoom
    cp   [hl]
    jr   nz, .eaglesTowerEnd
    ; do some special casing for this room entities
    ld   a, ENTITY_A8
    call SpawnNewEntity_trampoline
    ld   a, [$DB70]
    ld   hl, wEntitiesPosXTable
    add  hl, de
    ld   [hl], a
    ld   a, [$DB71]
    ld   hl, wEntitiesPosYTable
    add  hl, de
    ld   [hl], a
    call LoadEntityFromDefinition.didLoadEntity
    ld   hl, wEntitiesLoadOrderTable
    add  hl, de
    ld   [hl], $FF
    xor  a
    ldh  [hScratchD], a
.eaglesTowerEnd

    ; By default, use the IndoorsA pointers table
    ld   hl, IndoorsAEntitiesPointersTable

    ; If on the Color Dungeon, use ColorDungeonEntitiesPointersTable
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    jr   nz, .useIndoorsBTable
    ld   hl, ColorDungeonEntitiesPointersTable
    jr   .pointersTableEnd
.useIndoorsBTable
    ; If on a map between $06 and $1A…
    cp   MAP_UNKNOWN_1A
    jr   nc, .pointersTableEnd
    cp   MAP_EAGLES_TOWER
    jr   c, .pointersTableEnd
    ; … use IndoorsBEntitiesPointersTable
    ; (by incrementing H from $42 to $44)
    inc  h
    inc  h
.pointersTableEnd

    ; Read the entities list address in the pointers table
    add  hl, bc
    ld   a, [hli]
    ld   c, a
    ld   a, [hl]
    ld   b, a

    ; For each entity definition in the target list…
.loop
    ; if the end of list is reached, break
    ld   a, [bc]
    cp   ENTITIES_END
    jr   z, .break
    ; otherwise load the entity definition.
    call LoadEntityFromDefinition
    jr   .loop
.break

    call ReloadSavedBank
    ret

; Array indexed by load order
EntityMask_387B::
    db   %00000001
    db   %00000010
    db   %00000100
    db   %00001000
    db   %00010000
    db   %00100000
    db   %01000000
    db   %10000000

; Load an entity for the current room from an entity definition.
; An entity definition is 2 bytes:
;   - vertical and horizontal position
;   - entity type
; See files in `data/entities/` for more infos.
;
; Inputs:
;   bc   address of the entity definition
LoadEntityFromDefinition::
    ; a = entity load order
    ldh  a, [hScratchD]

    ; If the load order < 8…
    cp   $08
    jr   nc, .skipClearedEntityEnd
    ; and EntityMask_387B[hScratchD] & wEntitiesClearedRooms[hMapRoom] != 0,
    ld   e, a
    ld   d, $00
    ld   hl, EntityMask_387B
    add  hl, de
    ldh  a, [hMapRoom]
    ld   e, a
    ld   a, [hl]
    ld   hl, wEntitiesClearedRooms
    add  hl, de
    and  [hl]
    ; … then the entity has been cleared previously: don't load it.
    jr   nz, .skipEntityLoad
.skipClearedEntityEnd

    ; de = $0000
    ld   e, $00
    ld   d, e
    ; Find the first available slot (i.e. ENTITY_STATUS_DISABLED)
.loop
    ld   hl, wEntitiesStatusTable
    add  hl, de
    ld   a, [hl]
    cp   ENTITY_STATUS_DISABLED
    jr   z, .createEntityAndReturn
    ; If this slot is not available, try until we reach the last slot
    inc  e
    ld   a, e
    cp   $10
    jr   nz, .loop
    ; If all slots are unavailable, skip this entity

.skipEntityLoad
    ; Increment the entity load order anyway
    ld   hl, hScratchD
    inc  [hl]
    ; Increment the address to the next definition in the list
    inc  bc
    inc  bc
    ret

.createEntityAndReturn
    ; Mark the entity as being initialized
    ld   [hl], ENTITY_STATUS_INIT
    ; Set the entity horizontal position (lowest nybble of first byte)
    ld   a, [bc]
    and  $F0
    ld   hl, wEntitiesPosYTable
    add  hl, de
    add  a, $10
    ld   [hl], a
    ; Set the entity horizontal position (highest nybble of first byte)
    ld   a, [bc]
    inc  bc
    swap a
    and  $F0
    ld   hl, wEntitiesPosXTable
    add  hl, de
    add  a, $08
    ld   [hl], a
    ; Set the entity type
    ld   hl, wEntitiesTypeTable
    add  hl, de
    ld   a, [bc]
    inc  bc
    ld   [hl], a

.didLoadEntity
    callsb ConfigureNewEntity_helper
    callsb PrepareEntityPositionForRoomTransition
    ; Restore bank for entities placement data
    ld   a, BANK(OverworldEntitiesPointersTable)
    ld   [MBC3SelectBank], a
    ret

; Load the template for an indoor room
;   a: the template to use (see ROOM_TEMPLATE_* constants)
LoadRoomTemplate_trampoline::
    ; Load bank for LoadRoomTemplate
    ld   e, a
    ld   a, BANK(LoadRoomTemplate)
    ld   [MBC3SelectBank], a
    ld   a, e

    ; Call function
    push bc
    call LoadRoomTemplate
    pop  bc

    ; Restore previous bank
    ldh  a, [hRoomBank]
    ld   [MBC3SelectBank], a
    ret

LoadTilemap0E_trampoline::
    callsb LoadTilemap0E
    ret

SwitchToMapDataBank::
    ; mapBank = (IsIndoor ? $08 : $1A)
    ld   a, [wIsIndoor]
    and  a
    jr   nz, .indoor
    ld   a, BANK(OverworldBaseMapDMG)
    jr   .end
.indoor
    ld   a, $08
.end
    ; Switch to map bank
    ld   [MBC3SelectBank], a
    ret

LoadTilemap22_trampoline::
    jpsb LoadTilemap22

LoadTilemap23_trampoline::
    jpsb LoadTilemap23

label_3925::
    ld   a, $14
    ld   [MBC3SelectBank], a
    ld   hl, $5218
    add  hl, de
    ld   a, [hl]
    ld   hl, MBC3SelectBank
    ld   [hl], $05
    ret

label_3935::
    callsw func_019_7C50
    ld   a, $03
    jp   SwitchBank

label_3942::
    callsb func_003_53E4
    jp   ReloadSavedBank

label_394D::
    callsb func_014_54AC
    jp   ReloadSavedBank

CreateFollowingNpcEntity_trampoline::
    callsw CreateFollowingNpcEntity
    ld   a, $02
    jp   SwitchBank

label_3965::
    callsb ConfigureNewEntity
    jp   ReloadSavedBank

label_3970::
    callsb func_003_7EFE
    jp   ReloadSavedBank

label_397B::
    callsb func_014_5347
    ld   a, $03
    ld   [MBC3SelectBank], a
    ret

data_3989::
    db   0, 8, $10, $18

AnimateEntities::
    ; Play the Boss Agony audio effect if needed
    ld   hl, wBossAgonySFXCountdown
    ld   a, [hl]
    and  a
    jr   z, .bossAgonyEnd
    dec  [hl]
    jr   nz, .bossAgonyEnd
    ld   a, WAVE_SFX_BOSS_AGONY
    ldh  [hWaveSfx], a
.bossAgonyEnd

    ; If no dialog is open…
    ld   a, [wDialogState]
    and  a
    jr   nz, .C111End
    ; … decrement $C111
    ld   a, [$C111]
    ld   [$C1A8], a
    and  a
    jr   z, .C111End
    dec  a
    ld   [$C111], a
.C111End

    ; If Link is passing out, return
    ld   a, [wLinkMotionState]
    cp   LINK_MOTION_PASS_OUT
    ret  z

    xor  a
    ld   [$C3C1], a
    ldh  a, [hMapId]
    cp   MAP_CAVE_B
    ldh  a, [hFrameCounter]
    jr   c, .label_39C1
    xor  a

.label_39C1
    and  $03
    ld   e, a
    ld   d, $00
    ld   hl, data_3989
    add  hl, de
    ld   a, [hl]
    ld   [$C3C0], a
    callsb func_020_4303
    xor  a
    ld   [MBC3SelectBank], a
    ld   a, [wDialogState]
    and  a
    jr   nz, .label_39E3
    ld   [$C1AD], a

.label_39E3
    ld   a, BANK(func_020_6352)
    ld   [wCurrentBank], a
    ld   [MBC3SelectBank], a
    call func_020_6352

    ; Initialize the entities counter
    ld   b, $00
    ld   c, MAX_ENTITIES - 1

    ; For each entity slot…
.loop
    ; Save the active entity index
    ld   a, c
    ld   [wActiveEntityIndex], a

    ; Read the entity state
    ld   hl, wEntitiesStatusTable
    add  hl, bc
    ld   a, [hl]

    ; If state != 0…
    and  a
    jr   z, .AnimateEntityEnd

    ; animate the entity.
    ldh  [hActiveEntityStatus], a
    call AnimateEntity
.AnimateEntityEnd

    ; While c >= 0, loop
    dec  c
    ld   a, c
    cp   $FF
    jr   nz, .loop

.return:
    ret

ResetEntity_trampoline::
    callsb ResetEntity
    ld   a, $03
    ld   [MBC3SelectBank], a
    ret

AnimateEntity::
    ld   hl, wEntitiesTypeTable
    add  hl, bc
    ld   a, [hl]
    ldh  [hActiveEntityType], a

    ld   hl, wEntitiesStateTable
    add  hl, bc
    ld   a, [hl]
    ldh  [hActiveEntityState], a

    ld   hl, $C3B0
    add  hl, bc
    ld   a, [hl]
    ldh  [hActiveEntitySpriteVariant], a

    ld   a, BANK(UpdateEntityPositionForRoomTransition)
    ld   [wCurrentBank], a
    ld   [MBC3SelectBank], a

    ldh  a, [hActiveEntityType]
    cp   ENTITY_RAFT_RAFT_OWNER
    jr   nz, .raftManEnd
    ldh  a, [$FFB2]
    and  a
    jr   nz, .entityLifted
.raftManEnd

    ldh  a, [hActiveEntityStatus]
    cp   ENTITY_STATUS_LIFTED
    jr   nz, .notLifted
.entityLifted
    call UpdateEntityPositionForRoomTransition
    call CopyEntityPositionToActivePosition
    jr   .liftedEnd
.notLifted
    call CopyEntityPositionToActivePosition
    call UpdateEntityPositionForRoomTransition
.liftedEnd

    ld   a, BANK(func_014_4D73)
    ld   [wCurrentBank], a
    ld   [MBC3SelectBank], a
    call func_014_4D73

    ; Select bank 3
    ld   a, $03
    ld   [wCurrentBank], a
    ld   [MBC3SelectBank], a

    ldh  a, [hActiveEntityStatus]
    cp   ENTITY_STATUS_ACTIVE
    jp   z, ExecuteActiveEntityHandler
    JP_TABLE
._00 dw AnimateEntities.return
._01 dw EntityDeathHandler
._02 dw EntityFallHandler
._03 dw EntityDestructionHandler
._04 dw EntityInitHandler
._05 dw ExecuteActiveEntityHandler
._06 dw EntityStunnedHandler
._07 dw EntityLiftedHandler
._08 dw EntityThrownHandler

; Execute active entity handler, then return to bank 3
ExecuteActiveEntityHandler_trampoline::
    call ExecuteActiveEntityHandler
    ld   a, $03
    ld   [wCurrentBank], a
    ld   [MBC3SelectBank], a
    ret

; Read entity code pointers, then jump to execution
ExecuteActiveEntityHandler::
    ld   a, BANK(EntityPointersTable)
    ld   [MBC3SelectBank], a

    ; de = active entity id
    ldh  a, [hActiveEntityType]
    ld   e, a
    ld   d, b

    ; hl = de * 3
    ld   hl, EntityPointersTable
    add  hl, de
    add  hl, de
    add  hl, de

    ; Read values from the entities pointers table:
    ; a = entity handler bank
    ; d = entity handler address (high)
    ; e = entity handler address (low)
    ld   e, [hl]
    inc  hl
    ld   d, [hl]
    inc  hl
    ld   a, [hl]

    ; Select entity handler bank
    ld   l, e
    ld   h, d
    ld   [wCurrentBank], a
    ld   [MBC3SelectBank], a

    ; Jump to the entity handler
    jp   hl

; Types of entity hitboxes
; Array indexed par (wEntitiesHitboxFlagsTable & $7C)
; Content goes into wEntitiesHitboxPositionTable
; Values:
;  - hitbox X
;  - hitbox Y
;  - ???
;  - ???
HitboxPositions::
._00 db   $08, $05, $08, $05
._04 db   $08, $0A, $08, $0A
._08 db   $08, $0A, $08, $0A
._0C db   $08, $10, $04, $0A
._10 db   $08, $02, $08, $02
._14 db   $08, $13, $08, $13
._18 db   $08, $06, $06, $08
._1C db   $08, $07, $06, $0A
._20 db   $08, $06, $10, $30
._24 db   $08, $07, $04, $0A
._28 db   $0C, $07, $FC, $04
._2C db   $10, $10, $0C, $12
._30 db   $08, $08, $02, $08
._34 db   $10, $0C, $08, $10
._38 db   $08, $07, $0C, $08
._3C db   $08, $08, $02, $08

; Read hitbox params from the hitbox types table, and copy them
; to the entities hitbox table.
; Inputs:
;   bc    entity index
ConfigureEntityHitbox::
    ; de = HitboxPositions[wEntitiesHitboxFlagsTable & $7C]
    ld   hl, wEntitiesHitboxFlagsTable
    add  hl, bc
    ld   a, [hl]
    and  $7C ; '|'
    ld   e, a
    ld   d, b
    ld   hl, HitboxPositions
    add  hl, de
    ld   e, l
    ld   d, h
    push bc
    ; c = c * 4
    sla  c
    sla  c
    ; Destination: hl = wEntitiesHitboxPositionTable + (entity index * 4)
    ld   hl, wEntitiesHitboxPositionTable
    add  hl, bc

    ; Copy 4 bytes from HitboxPositions to wEntitiesHitboxPositionTable
    ld   c, 4
    ; While c != 0
.loop
    ld   a, [de]
    inc  de
    ldi  [hl], a
    dec  c
    jr   nz, .loop
    pop  bc
    ret

; Set the given value to the entity sprite variants table.
;
; Inputs:
;   a    variant value
;   bc   entity index
SetEntitySpriteVariant::
    ld   hl, wEntitiesSpriteVariantTable
    add  hl, bc
    ld   [hl], a
    ret

; Increment the state attribute of the given entity
; Input:
;  - bc: the entity number
IncrementEntityState::
    ld   hl, wEntitiesStateTable
    add  hl, bc
    inc  [hl]
    ret

label_3B18::
    callsb func_002_75F5
    jp   ReloadSavedBank

label_3B23::
    callsb func_003_7893
    jp   ReloadSavedBank

label_3B2E::
    callsb func_003_7CAB
    jp   ReloadSavedBank

label_3B39::
    callsb func_003_6E28
    jp   ReloadSavedBank

label_3B44::
    callsb func_003_6C6B
    jp   ReloadSavedBank

CheckLinkCollisionWithProjectile_trampoline::
    callsb CheckLinkCollisionWithProjectile
    jp   ReloadSavedBank

CheckLinkCollisionWithEnemy_trampoline::
    callsb CheckLinkCollisionWithEnemy.collisionEvenInTheAir
    jp   ReloadSavedBank

label_3B65::
    callsb func_003_73EB
    jp   ReloadSavedBank

label_3B70::
    callsb func_003_6E2B
    jp   ReloadSavedBank

label_3B7B::
    callsb func_003_75A2
    jp   ReloadSavedBank

SpawnNewEntity_trampoline::
    push af
    ld   a, BANK(SpawnNewEntity)
    ld   [MBC3SelectBank], a
    pop  af
    call SpawnNewEntity
    rr   l
    call ReloadSavedBank
    rl   l
    ret

SpawnNewEntityInRange_trampoline::
    push af
    ld   a, BANK(SpawnNewEntityInRange)
    ld   [MBC3SelectBank], a
    pop  af
    call SpawnNewEntityInRange
    rr   l
    call ReloadSavedBank
    rl   l
    ret

ApplyVectorTowardsLink_trampoline::
    ld   hl, MBC3SelectBank
    ld   [hl], BANK(ApplyVectorTowardsLink)
    call ApplyVectorTowardsLink
    jp   ReloadSavedBank

GetVectorTowardsLink_trampoline::
    ld   hl, MBC3SelectBank
    ld   [hl], BANK(GetVectorTowardsLink)
    call GetVectorTowardsLink
    jp   ReloadSavedBank

; Render a pair of sprites for the active entity to the OAM buffer.
;
; The main input is a display list containing OAM attributes (2 bytes each).
; Each display list item is a pair of OAM attributes (one for each sprite).
;
; The entity variant is used to animate the entity, by selecting one of
; the different pairs in the display list.
;
; Inputs:
;   de                          address of the display list
;   hActiveEntitySpriteVariant  the sprite variant to use
RenderActiveEntitySpritesPair::
    ; If hActiveEntitySpriteVariant == -1, return.
    ldh  a, [hActiveEntitySpriteVariant]
    inc  a
    ret  z

    call SkipDisabledEntityDuringRoomTransition

    push de

    ; de = wDynamicOAMBuffer + [$C3C0]
    ld   a, [$C3C0]
    ld   e, a
    ld   d, b
    ld   hl, wDynamicOAMBuffer
    add  hl, de
    ld   e, l
    ld   d, h

    ; [de++] = [$FFEC]
    ldh  a, [$FFEC]
    ld   [de], a
    inc  de

    ; [de++] = [$FFED] + [hActiveEntityPosX] - [wScreenShakeHorizontal]
    ld   a, [wScreenShakeHorizontal]
    ld   c, a
    ldh  a, [$FFED]
    and  $20
    rra
    rra
    ld   hl, hActiveEntityPosX
    add  a, [hl]
    sub  a, c
    ld   [de], a
    inc  de

    ; hl = pop de + [hActiveEntitySpriteVariant] * 2
    ldh  a, [hActiveEntitySpriteVariant]
    ld   c, a
    ld   b, $00
    sla  c
    rl   b
    sla  c
    rl   b
    pop  hl
    add  hl, bc

    ; [de] = [hl++] + [hActiveEntityTilesOffset]
    ldh  a, [hActiveEntityTilesOffset]
    ld   c, a
    ld   a, [hli]
    add  a, c
    ld   [de], a
    and  $0F
    cp   $0F
    jr   nz, .jr_3C08
    dec  de
    ld   a, $F0
    ld   [de], a
    inc  de
.jr_3C08

    inc  de
    ld   a, [hli]
    push hl
    ld   hl, $FFED
    xor  [hl]
    ld   [de], a
    ldh  a, [hIsGBC]
    and  a
    jr   z, .jr_3C21
    ldh  a, [$FFED]
    and  $10
    jr   z, .jr_3C21
    ld   a, [de]
    and  $F8
    or   $04
    ld   [de], a
.jr_3C21

    inc  de
    ldh  a, [$FFEC]
    ld   [de], a
    inc  de
    ld   a, [wScreenShakeHorizontal]
    ld   c, a
    ldh  a, [$FFED]
    and  $20
    xor  $20
    rra
    rra
    ld   hl, hActiveEntityPosX
    sub  a, c
    add  a, [hl]
    ld   [de], a
    inc  de
    pop  hl
    ldh  a, [hActiveEntityTilesOffset]
    ld   c, a
    ld   a, [hli]
    add  a, c
    ld   [de], a
    and  $0F
    cp   $0F
    jr   nz, .jr_3C4B
    dec  de
    ld   a, $F0
    ld   [de], a
    inc  de
.jr_3C4B

    inc  de
    ld   a, [hl]
    ld   hl, $FFED
    xor  [hl]
    ld   [de], a
    ldh  a, [hIsGBC]
    and  a
    jr   z, .jr_3C63
    ldh  a, [$FFED]
    and  $10
    jr   z, .jr_3C63
    ld   a, [de]
    and  $F8
    or   $04
    ld   [de], a
.jr_3C63

    ; Restore the entity index to bc
    ld   a, [wActiveEntityIndex]
    ld   c, a
    ld   b, $00

    callsb func_015_795D
label_3C71::
    call func_015_7995

    ; Reload saved bank and return
    jp   ReloadSavedBank

; Render a single sprite for the active entity to the OAM buffer.
;
; The main input is a display list, containing OAM attributes (2 bytes each).
; There is one OAM attribute per variant.
;
; The entity variant is used to animate the entity, by selecting a sprite
; among the different attributes in the display list.
;
; Inputs:
;   de                          address of the display list
;   wActiveEntityIndex          index
;   hActiveEntitySpriteVariant  the sprite variant to use
;   $C3C0                       index of the dynamically allocated OAM slot
RenderActiveEntitySprite::
    ; If hActiveEntitySpriteVariant == -1, return.
    ldh  a, [hActiveEntitySpriteVariant]
    inc  a
    ret  z

    call SkipDisabledEntityDuringRoomTransition

    push de

    ; de = wDynamicOAMBuffer + [$C3C0]
    ld   a, [$C3C0]
    ld   l, a
    ld   h, $00
    ld   bc, wDynamicOAMBuffer
    add  hl, bc
    ld   e, l
    ld   d, h
    ; bc = [wActiveEntityIndex]
    ld   a, [wActiveEntityIndex]
    ld   c, a
    ld   b, $00

    ; If in a side-scrolling room…
    ldh  a, [hIsSideScrolling]
    and  a
    ldh  a, [$FFEC]
    jr   z, .sideScrollingEnd
    ; … $FFEC -= 4
    sub  a, $04
    ldh  [$FFEC], a
.sideScrollingEnd

    ; (wDynamicOAMBuffer + [$C3C0] + 0) = [$FFEC]
    ld   [de], a
    inc  de
    ; (wDynamicOAMBuffer + [$C3C0] + 1) = [hActiveEntityPosX] + 4 - [wScreenShakeHorizontal]
    ld   a, [wScreenShakeHorizontal]
    ld   h, a
    ldh  a, [hActiveEntityPosX]
    add  a, $04
    sub  a, h
    ld   [de], a
    inc  de
    ; (wDynamicOAMBuffer + [$C3C0] + 2) = DataTable[hActiveEntitySpriteVariant * 2]
    ldh  a, [hActiveEntitySpriteVariant]
    ld   c, a
    ld   b, $00
    sla  c
    rl   b
    pop  hl
    add  hl, bc
    ld   a, [hli]
    ld   [de], a

    ; If on GBC…
    inc  de
    ldh  a, [hIsGBC]
    and  a
    jr   z, .gbcEnd
    ; and not during credits…
    ld   a, [wGameplayType]
    cp   GAMEPLAY_CREDITS
    jr   z, .gbcEnd
    ; and $FFED != 0…
    ldh  a, [$FFED]
    and  a
    jr   z, .gbcEnd
    ; (wDynamicOAMBuffer + [$C3C0] + 4) = (DataTable[hActiveEntitySpriteVariant * 2] + 1) & 0xf8 | 4
    ld   a, [hl]
    and  $F8
    or   $04
    ld   [de], a
    jr   .functionEnd
.gbcEnd

    ; (wDynamicOAMBuffer + [$C3C0] + 4) = (DataTable[hActiveEntitySpriteVariant * 2] + 1) ^ [$FFED]
    ld   a, [hli]
    ld   hl, $FFED
    xor  [hl]
    ld   [de], a

.functionEnd
    inc  de
    jr   RenderActiveEntitySpritesPair.jr_3C63

label_3CD9::
    ld   a, $15
    ld   [MBC3SelectBank], a
    jr   label_3C71

label_3CE0::
    push hl
    ld   hl, wOAMBuffer
    jr   RenderActiveEntitySpritesRect.label_3CF6

; Render a large rectangle of sprites for the active entity to the OAM buffer.
;
; This function takes a display list of OAM attributes.
; Each item of the display list is a tupple of [x (?), y(?), tile n°, tile attributes] values.
;
; The display list is processed regardless of the active sprite variant.
; Variants must be managed by the caller itself.
;
; Inputs:
;   de  the oam attributes display list
;   c   the number of sprites
;
; Return value:
;   c   [wActiveEntityIndex]
RenderActiveEntitySpritesRect::
    ; If hActiveEntitySpriteVariant == -1, return.
    ldh  a, [hActiveEntitySpriteVariant]
    inc  a
    jr   z, .return

    ; hl = wDynamicOAMBuffer + [$C3C0]
    push hl
    ld   a, [$C3C0]
    ld   e, a
    ld   d, $00
    ld   hl, wDynamicOAMBuffer
    add  hl, de

.label_3CF6
    ld   e, l
    ld   d, h
    pop  hl

    ; Save counter to hScratch0
    ld   a, c
    ldh  [hScratch0], a

    ld   a, [wActiveEntityIndex]
    ld   c, a
    call SkipDisabledEntityDuringRoomTransition

    ; Restore counter from hScratch0
    ldh  a, [hScratch0]
    ld   c, a

.loop
    ldh  a, [$FFEC]
    add  a, [hl]
    ld   [de], a
    inc  hl
    inc  de
    push bc
    ld   a, [wScreenShakeHorizontal]
    ld   c, a
    ldh  a, [hActiveEntityPosX]
    add  a, [hl]
    sub  a, c
    ld   [de], a
    inc  hl
    inc  de
    ldh  a, [hActiveEntityTilesOffset]
    ld   c, a
    ld   a, [hli]
    push af
    add  a, c
    ld   [de], a
    pop  af
    cp   $FF
    jr   nz, .jp_3D28
    dec  de
    xor  a
    ld   [de], a
    inc  de
.jp_3D28
    pop  bc

    inc  de
    ldh  a, [$FFED]
    xor  [hl]
    ld   [de], a
    inc  hl

    ldh  a, [hIsGBC]
    and  a
    jr   z, .gbcEnd
    ldh  a, [$FFED]
    and  a
    jr   z, .gbcEnd
    ld   a, [de]
    and  $F8
    or   $04
    ld   [de], a
.gbcEnd

    inc  de
    dec  c
    jr   nz, .loop

    ld   a, [wActiveEntityIndex]
    ld   c, a
    callsb func_015_795D
    jp   ReloadSavedBank

.return
    ld   a, [wActiveEntityIndex]
    ld   c, a
    ret

; If the active entity rendering is disabled during
; the room transition, return to the parent of the caller.
; Otherwise, return to caller normally.
;
; Inputs:
;  bc:   active entity index?
SkipDisabledEntityDuringRoomTransition::
    ; If no room transition is active, return.
    push hl
    ld   a, [wRoomTransitionState]
    and  a
    jr   z, .return

    ; If hActiveEntityPosX - 1 is outside of screen, skip
    ldh  a, [hActiveEntityPosX]
    dec  a
    cp   $C0
    jr   nc, .skip

    ; If $FFEC - 1 is outside of the screen, skip
    ldh  a, [$FFEC]
    dec  a
    cp   $88
    jr   nc, .skip

    ; If wEntitiesPosXSignTable[c] != 0, skip
    ld   hl, wEntitiesPosXSignTable
    add  hl, bc
    ld   a, [hl]
    and  a
    jr   nz, .skip

    ; If wEntitiesPosYSignTable[c] != 0, skip
    ld   hl, wEntitiesPosYSignTable
    add  hl, bc
    ld   a, [hl]
    and  a

    ; Otherwise, don't skip and simply return to caller.
    jr   z, .return

.skip
    ; Pop the caller return address.
    ; The next value to be popped will be the parent caller
    ; address, thus returning to the parent of the parent early.
    pop  af

.return
    pop  hl
    ret

; Inputs:
;   bc   entity slot index
ClearEntitySpeed::
    ld   hl, wEntitiesSpeedXTable
    add  hl, bc
    ld   [hl], b
    ld   hl, wEntitiesSpeedYTable
    add  hl, bc
    ld   [hl], b
    ret

CopyEntityPositionToActivePosition::
    ld   hl, wEntitiesPosXTable
    add  hl, bc
    ld   a, [hl]
    ldh  [hActiveEntityPosX], a
    ld   hl, wEntitiesPosYTable
    add  hl, bc
    ld   a, [hl]
    ldh  [hActiveEntityPosY], a
    ld   hl, wEntitiesPosZTable
    add  hl, bc
    sub  a, [hl]
    ldh  [$FFEC], a
    ret

label_3DA0::
    callhl func_015_7964
    jp   ReloadSavedBank

label_3DAB::
    callhl func_004_5A1A
    jp   ReloadSavedBank

label_3DB6::
    callhl func_004_5690
    jp   ReloadSavedBank

label_3DC1::
    callhl func_004_504B
    jp   ReloadSavedBank

label_3DCC::
    callhl func_014_49BD
    jp   ReloadSavedBank

label_3DD7::
    callhl func_014_72AB
    jp   ReloadSavedBank

label_3DE2::
    callhl func_005_6CC6
    jp   ReloadSavedBank

label_3DED::
    callhl func_005_6818
    jp   ReloadSavedBank

label_3DF8::
    callhl func_005_6302
    jp   ReloadSavedBank

label_3E03::
    callhl func_005_5A1E
    jp   ReloadSavedBank

Entity67Handler_trampoline::
    callhl Entity67Handler
    jp   ReloadSavedBank

label_3E19::
    ld   a, [wCurrentBank]
    push af
    callsw CheckPositionForMapTransition
    pop  af
    jp   SwitchBank

label_3E29::
    callhl func_004_5C63
    jp   ReloadSavedBank

label_3E34::
    callhl SmashRock
    jp   ReloadSavedBank

LoadHeartsAndRuppeesCount::
    ld   hl, MBC3SelectBank
    ld   [hl], BANK(LoadRupeesDigits)
    call LoadRupeesDigits
    call LoadHeartsCount
    jp   ReloadSavedBank

label_3E4D::
    callsw SpawnChestWithItem
    ld   a, $03
    jp   SwitchBank

label_3E5A::
    ld   hl, MBC3SelectBank
    ld   [hl], $20
    ld   c, $01
    ld   b, $00
    ld   e, $FF
    call label_5C9C
    jp   ReloadSavedBank

label_3E6B::
    callhl func_003_6472
    jp   ReloadSavedBank

func_006_783C_trampoline::
    callsw func_006_783C
    ld   a, $03
    jp   SwitchBank

label_3E83::
    ld   e, $10
    ld   hl, wEntitiesStatusTable

label_3E88::
    xor  a
    ldi  [hl], a
    dec  e
    jr   nz, label_3E88
    ret

label_3E8E::
    ld   hl, wEntitiesUnknowTableZ
    add  hl, bc
    ld   a, [hl]
    and  a
    ret  z
    ldh  a, [hFrameCounter]
    xor  c
    and  $03
    ret  nz
    ldh  a, [hActiveEntityPosX]
    ldh  [hScratch0], a
    ldh  a, [$FFEC]
    ldh  [hScratch1], a
    ld   a, TRANSCIENT_VFX_SMOKE
    call AddTranscientVfx
    ld   hl, wTranscientVfxCountdownTable
    add  hl, de
    ld   [hl], $0F
    ret

label_3EAF::
    ld   hl, $C3F0
    add  hl, bc
    ld   a, [hl]
    bit  7, a
    jr   z, label_3EBA
    cpl
    inc  a

label_3EBA::
    ldh  [hScratch0], a
    ld   hl, wEntitiesUnknowTableS
    add  hl, bc
    ld   a, [hl]
    bit  7, a
    jr   z, label_3EC7
    cpl
    inc  a

label_3EC7::
    ld   e, $03
    ld   hl, hScratch0
    cp   [hl]
    jr   c, label_3ED1
    ld   e, $0C

label_3ED1::
    ld   a, e
    ld   hl, wEntitiesCollisionsTable
    add  hl, bc
    and  [hl]
    jr   z, label_3EDE
    ld   hl, wEntitiesUnknowTableT
    add  hl, bc
    ld   [hl], b

label_3EDE::
    ret

data_3EDF::
    db $B0, $B4, $B1, $B2, $B3, $B6, $BA, $BC, $B8

label_3EE8::
    ld   hl, wInventoryAppearing
    ld   a, [wRoomTransitionState]
    or   [hl]
    ret  nz
    ld   a, [$C165]
    and  a
    jr   z, jp_3EFB
    dec  a
    ld   [$C165], a
    ret

jp_3EFB::
    ld   a, [$C1BD]
    and  a
    ret  nz
    inc  a
    ld   [$C1BD], a
    ld   hl, wEntitiesUnknowTableH
    add  hl, bc
    ld   a, [hl]
    and  $04
    ld   a, $19
    jr   z, jp_3F11
    ld   a, $50

jp_3F11::
    ld   [wActiveMusicTrack], a
    ldh  [$FFBD], a
    ld   a, [wTransitionSequenceCounter]
    cp   $04
    ret  nz
    ldh  a, [hActiveEntityType]
    cp   $87
    jr   nz, jp_3F26
    ld   a, $DA
    jr   jp_3F45

jp_3F26::
    cp   $BC
    jr   nz, jp_3F2E
    ld   a, $26
    jr   jp_3F45

jp_3F2E::
    ld   hl, wEntitiesUnknowTableH
    add  hl, bc
    ld   a, [hl]
    and  $04
    ret  nz
    ldh  a, [hMapId]
    cp   MAP_COLOR_DUNGEON
    ret  z
    cp   MAP_FACE_SHRINE
    ret  z
    ld   e, a
    ld   d, b
    ld   hl, data_3EDF
    add  hl, de
    ld   a, [hl]

jp_3F45::
    jp   OpenDialog

data_3F48::
    db 1, 2, 4, 8, $10, $20, $40, $80

DidKillEnemy::
    ld   a, BANK(SpawnEnemyDrop)
    ld   [$C113], a
    ld   [MBC3SelectBank], a
    call SpawnEnemyDrop
    call ReloadSavedBank

.label_3F5E
    ld   hl, wEntitiesLoadOrderTable
    add  hl, bc
    ld   a, [hl]
    cp   $FF
    jr   z, UnloadEntity
    push af
    ld   a, [wKillCount2]
    ld   e, a
    ld   d, b
    inc  a
    ld   [wKillCount2], a
    ld   a, [hl]
    ld   hl, $DBB6
    add  hl, de
    ld   [hl], a
    pop  af

.label_3F78
    cp   $08
    jr   nc, UnloadEntity
    ld   e, a
    ld   d, b
    ld   hl, data_3F48
    add  hl, de
    ldh  a, [hMapRoom]
    ld   e, a
    ld   d, b
    ld   a, [hl]
    ld   hl, wEntitiesClearedRooms
    add  hl, de
    or   [hl]
    ld   [hl], a
    ; fall through UnloadEntity

; Unload an entity by setting its status to 0 (ENTITY_STATUS_DISABLED)
; Input:
;   bc:  index of the entity
UnloadEntity::
UnloadEntityAndReturn::
    ld   hl, wEntitiesStatusTable
    add  hl, bc
    ld   [hl], b
    ret

label_3F93::
    ld   a, BANK(Data_005_59DE)
    ld   [MBC3SelectBank], a
    ld   hl, Data_005_59DE
    ld   de, vTiles0 + $460
    ld   bc, $10
    call CopyData
    ld   hl, Data_005_59EE
    jr   label_3FBD

label_3FA9::
    ld   a, BANK(Data_005_59FE)
    ld   [MBC3SelectBank], a
    ld   hl, Data_005_59FE
    ld   de, vTiles0 + $460
    ld   bc, $10
    call CopyData
    ld   hl, Data_005_5A0E

label_3FBD::
    ld   de, vTiles0 + $480
    ld   bc, $10
    call CopyData
    xor  a
    ldh  [$FFA5], a
    ld   a, $0C
    ld   [MBC3SelectBank], a
    jp   DrawLinkSpriteAndReturn

; Copy data to second half of tiles memory
LoadColorDungeonTiles::
    ; bank = hIsGBC ? $35 : $34
    ld   b, $34
    ldh  a, [hIsGBC]
    and  a
    jr   z, .gbcEnd
    inc  b
.gbcEnd

    ; Switch to bank $34 or $35
    ld   a, b
    ld   [MBC3SelectBank], a
    ld   hl, ColorDungeonTiles
    ld   de, vTiles0 + $0400
    ld   bc, $400
    call CopyData
    ld   a, $20
    ld   [MBC3SelectBank], a
    ret
