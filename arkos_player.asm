
;*** Start of Arkos Tracker Player

; the arkos player has been quite heavily modified for the tape demo as it
; has unusual requirements... every 31us, we need to insert 12us of code
; (leaving 19us for other stuff), we can't use the alternate set or index
; registers and af is trashed in our inserted code too unless we take special
; care to save it in af' (and if we do, that'll also need to be preserved by
; us)
;
; i'm also removing all the unused code and making it pasmo and wincpc friendly

MUSIC_FADE_SPEED equ 3 ; about 2 second

	read "symbols-32.asm"
        org player_base

	nolist

	read "playertest.asm"

entrypoint:
        nop                     		;1      L0+ 1
	exx                     		;1      L0+ 2
	in a,(c)				;4	L0+ 6
	xor c					;1	L0+ 7     ; check for edge
	call m,new_found_edge			;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)				;2	L0+12     ; update counter
	exx                     		;1      L0+13

        ld de, songdata				;3	L0+16
	defs 27-16				;	L1+27
        call PLY_Init 				;5	L1+32 -> L1+24

        ld hl,player_music_hook16		;3      L0+27
        ld (music_hook_ptr),hl 			;5	L0+32

	defs line+1-32        	 		;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	defs line-2-13          		;       L1- 2
        jp mainloop_1           		;       L1+ 1

; music_change_count
;
; 00 = keep playing current music
; 01 = transition to next song
; 02+ = countdown


player_music_hook16:				;	L1+16
reentry equ $+1
	ld a,1					;2	L1+18
	dec a					;1	L1+19
	jp nz, cannot_enter_22			;3	L1+22

	ld (reentry),a				;4	L1+26

	defs line+1-26        	 		;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	jp safe_music_hook_return16		;3	L1+16
	
cannot_enter_22:
	defs line+1-22        	 		;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	jp music_hook_return16			;3	L1+16


safe_music_hook_return16:			;	L1+16
	ld hl,music_change_count		;3	L1+19
	ld a,(hl)				;2	L1+21
	or a					;1	L1+22
	jr z,no_change_music_25			;2/3	L1+24

	add a,MUSIC_FADE_SPEED			;2	L1+25
	jr c,change_music_29			;2/3	L1+27	

	ld (hl),a				;2	L1+29	; store new fade count
	and #f0					;2	L1+31
	ld e,a					;1	L1+32

	defs line+1-32        	 		;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,e					;1	L1+14
	rrca					;1	L1+15
	rrca					;1	L1+16
	rrca					;1	L1+17
	rrca					;1	L1+18
	inc a					;1	L1+19
	ld (PLY_FadeOutValuePtr),a		;4	L1+23	; store the fade out

	defs 25-23				;	L1+25
no_change_music_25:
	defs 27-25				;	L1+27
no_change_music_27:
        call PLY_Play 				;5	L1+32 -> L1+24

	ld hl,reentry				;3	L1+27
	inc (hl)				;3	L1+30

	defs line+1-30        	 		;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	jp music_hook_return16			;3	L1+16

change_music_29:
	xor a					;1	L1+30
	ld (hl),a				;2	L1+32	; clear old counter

	defs line+1-32        	 		;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	xor a					;1	L1+14
	ld (PLY_FadeOutValuePtr),a		;4	L1+18	; clear the fade out

	ld de,(music_change_addrlo)		;6	L1+24
	defs 27-24				;	L1+27
        call PLY_Init 				;5	L1+32 -> L1+24
	jr no_change_music_27			;3	L1+27	; start on the next tune





	


PLY_RetrigValue	equ #77		;Value used to trigger the Retrig of Register 13. Can be anything >= 0x10


PLY_Digidrum db 0						;Read here to know if a Digidrum has been played (0=no).



PLY_Play
	defs line+1-32        	 		;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	xor a					;1	L1+14
	ld (PLY_Digidrum),a			;4	L1+18	Reset the Digidrum flag.

	ex af,af'		;1	L1+19
	push af			;4	L1+23
	ex af,af'		;1	L1+24

	defs line+1-24        	 		;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

;Manage Speed. If Speed counter is over, we have to read the Pattern further.
PLY_SpeedCpt:
	ld a,1					;2	L1+15
	dec a					;1	L1+16
	jp nz,PLY_SpeedEnd_19			;3	L1+19

	;Moving forward in the Pattern. Test if it is not over.

PLY_HeightCpt 
	ld a,1					;2	L1+21
	dec a					;1	L1+22
	jp nz,PLY_HeightEnd_25			;3	L1+25

;Pattern Over. We have to read the Linker.

	;Get the Transpositions, if they have changed, or detect the Song Ending !
PLY_Linker_PT
	ld hl,0					;3	L1+28
	ld b,(hl)				;2	L1+30
	inc hl					;2	L1+32

	defs line+1-32   	      		;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,b					;1	L1+14
	rra					;1	L1+15
	jr nc,PLY_SongNotOver_18		;2/3	L1+17

	;Song over ! We read the address of the Loop point.
	ld a,(hl)				;2	L1+19
	inc hl					;2	L1+21
	ld h,(hl)				;2	L1+23
	ld l,a					;1	L1+24

	defs line+1-24         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,(hl)				;2	L1+15	We know the Song won't restart now, so we can skip the first bit.
	inc hl					;2	L1+17
	rra					;1	L1+18
PLY_SongNotOver_18:

	ld de,Track1_data+3			;3	L1+21
	rra					;1	L1+22
	jr c,PLY_NoNewTransposition1_C_25	;2/3	L1+24
	defs 27-24				;	L1+27
	ld b,a					;1	L1+28
	jr PLY_NoNewTransposition1_31		;3	L1+31
PLY_NoNewTransposition1_C_25:
	ldi					;5	L1+30
	ld b,a					;1	L1+31
PLY_NoNewTransposition1_31:

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,b					;1	L1+14
	ld de,Track2_data+3			;3	L1+17
	rra					;1	L1+18
	jr c,PLY_NoNewTransposition2_C_21	;2/3	L1+20
	defs 23-20				;	L1+23
	jr PLY_NoNewTransposition2_26		;3	L1+26
PLY_NoNewTransposition2_C_21:
	ldi					;5	L1+26
PLY_NoNewTransposition2_26:

	ld de,Track3_data+3			;3	L1+29
	ld b,a					;1	L1+30
	ld c,#ff				;2	L1+32	; prevent B decreasing later in the LDIs

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	rr b					;2	L1+15
	jr c,PLY_NoNewTransposition2_C_18	;2/3	L1+17
	defs 20-17				;	L1+20
	jr PLY_NoNewTransposition2_23		;3	L1+23
PLY_NoNewTransposition2_C_18:
	ldi					;5	L1+23
PLY_NoNewTransposition2_23:

	;Get the Tracks addresses.
	ld de,Track1_data+1			;3	L1+26
	ldi					;5	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ldi					;5	L1+18
	ld de,Track2_data+1			;3	L1+21
	ldi					;5	L1+26
	ldi					;5	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld de,Track3_data+1			;3	L1+16
	ldi					;5	L1+21
	ldi					;5	L1+26

	;Get the Special Track address, if it has changed.
	ld de,PLY_Height + 1			;3	L1+29

	defs line+1-29         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,b					;1	L1+14
	rra					;2	L1+15
	jr c,PLY_NoNewHeight_C_17		;2/3	L1+17
	defs 20-17				;	L1+20
	jr PLY_NoNewHeight_23			;3	L1+23
PLY_NoNewHeight_C_17:
	ldi					;5	L1+23
PLY_NoNewHeight_23:

	rra					;1	L1+24
	jr nc,PLY_NoNewSpecialTrack_NC_27	;2/3	L1+26

	ld e,(hl)				;2	L1+28
	inc hl					;2	L1+30

	defs line+1-30         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld d,(hl)				;2	L1+15
	inc hl					;2	L1+17
	ld (PLY_SaveSpecialTrack + 1),de	;6	L1+23
	defs 27-23				;	L1+27

PLY_NoNewSpecialTrack_NC_27:
	ld (PLY_Linker_PT + 1),hl		;5	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,1					;2	L1+15
	ld (PLY_SpecialTrack_WaitCounter + 1),a	;4	L1+19
	ld (Track1_data + 0),a			;4	L1+23
	ld (Track2_data + 0),a			;4	L1+27
	ld (Track3_data + 0),a			;4	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

PLY_SaveSpecialTrack:
	ld hl,0					;3	L1+16
	ld (PLY_SpecialTrack_PT + 1),hl		;5	L1+21

	;Reset the SpecialTrack/Tracks line counter.
	;We can't rely on the song data, because the Pattern Height is not related to the Tracks Height.

PLY_Height ld a,1				;2	L1+23
	defs 25-23				;	L1+25

PLY_HeightEnd_25:
	ld (PLY_HeightCpt + 1),a		;4	L1+29

	; allow interrupts
	defs line+1-29
	exx			;1	L1+ 2                           
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10
	
	nop                     ;1      L1+11
	nop                     ;1      L1+12
        ei                      ;1      L1+13
	ld l,(hl)		;2	L1+15     ; update counter
	di                      ;1      L1+16
	exx			;1	L1+17
	defs 29-17




;Read the Special Track/Tracks.
;------------------------------

	ld c,1					;2	L1+31	; used for PLY_PT_SpecialTrack_EndData_32

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

PLY_SpecialTrack_WaitCounter:
	ld a,1					;2	L1+15
	dec a					;1	L1+16
	jp nz,PLY_SpecialTrack_Wait_19		;3	L1+19

PLY_SpecialTrack_PT:
	ld hl,0					;3	L1+22
	ld b,(hl)				;2	L1+24
	inc hl					;2	L1+26
	srl b					;2	L1+28	;Data (1) or Wait (0) ?
	jp nc,PLY_SpecialTrack_NewWait_31	;3	L1+31	;If Wait, B contains the Wait value.

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	;Data. Effect Type ?
	ld a,b					;1	L1+14
	srl a					;2	L1+16	;Speed (0) or Digidrum (1) ?

	;First, we don't test the Effect Type, but only the Escape Code (=0)
	jr nz,PLY_SpecialTrack_NoEscapeCode_19	;2/3	L1+18

	ld a,(hl)				;2	L1+20
	inc hl					;2	L1+22

PLY_SpecialTrack_NoEscapeCode_22:

	ld b,c					;1	L1+23	B=1 ready to fall into PLY_PT_SpecialTrack_EndData_32 (we set it above)

	;Now, we test the Effect type, since the Carry didn't change.
	jr nc,PLY_SpecialTrack_Speed_26		;2/3	L1+25

	ld (PLY_Digidrum),a			;4	L1+29
	jr PLY_PT_SpecialTrack_EndData_32	;3	L1+32

PLY_SpeedEnd_19:
	defs 22-19				;	L1+22
	jp PLY_SpeedEnd_25			;	L1+25

PLY_SpecialTrack_NoEscapeCode_19:
	jr PLY_SpecialTrack_NoEscapeCode_22	;3	L1+22

PLY_SpecialTrack_Speed_26:
	ld (PLY_Speed + 1),a			;4	L1+30
	nop					;	L1+31
PLY_SpecialTrack_NewWait_31:						; tricky! B=wait value here
	nop					;	L1+32
PLY_PT_SpecialTrack_EndData_32:

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld (PLY_SpecialTrack_PT + 1),hl		;5	L1+18
	ld a,b					;1	L1+19

PLY_SpecialTrack_Wait_19:
	ld (PLY_SpecialTrack_WaitCounter + 1),a	;4	L1+23

	; allow interrupts
	defs line+1-23
	exx			;1	L1+ 2                           
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10
	
	nop                     ;1      L1+11
	nop                     ;1      L1+12
        ei                      ;1      L1+13
	ld l,(hl)		;2	L1+15     ; update counter
	di                      ;1      L1+16
	exx			;1	L1+17
	defs 23-17

	ld hl,Track1_data			;3	L1+26
	call PLY_Track				;5	L1+31 -> L1+23

	; allow interrupts
	defs line+1-23
	exx			;1	L1+ 2                           
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10
	
	nop                     ;1      L1+11
	nop                     ;1      L1+12
        ei                      ;1      L1+13
	ld l,(hl)		;2	L1+15     ; update counter
	di                      ;1      L1+16
	exx			;1	L1+17
	defs 23-17

	ld hl,Track2_data			;3	L1+26
	call PLY_Track				;5	L1+31 -> L1+23

	; allow interrupts
	defs line+1-23
	exx			;1	L1+ 2                           
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10
	
	nop                     ;1      L1+11
	nop                     ;1      L1+12
        ei                      ;1      L1+13
	ld l,(hl)		;2	L1+15     ; update counter
	di                      ;1      L1+16
	exx			;1	L1+17
	defs 23-17

	ld hl,Track3_data			;3	L1+26
	call PLY_Track				;5	L1+31 -> L1+23

	; allow interrupts
	defs line+1-23
	exx			;1	L1+ 2                           
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10
	
	nop                     ;1      L1+11
	nop                     ;1      L1+12
        ei                      ;1      L1+13
	ld l,(hl)		;2	L1+15     ; update counter
	di                      ;1      L1+16
	exx			;1	L1+17
	defs 23-17

PLY_Speed:
	ld a,1					;2	L1+25

PLY_SpeedEnd_25:
	ld (PLY_SpeedCpt + 1),a			;4	L1+29

;;;;;;;;;;;; PROCESS THE TRACKS HERE

	defs line+1-29         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

;Plays the sound on each frame, but only save the forwarded Instrument pointer when Instrument Speed is reached.
;This is needed because TrackPitch is involved in the Software Frequency/Hardware Frequency calculation, and is calculated every frame.

; But first a little jump point where we can insert a fade out... (actually we won't)
PLY_FadeoutPatchPtr equ $+1
	jp PLY_FadeoutPatchDone 		;3	L1+16
PLY_FadeoutPatchDone:

	; 3,2,1 order for when multiple HW envs collide...
	ld hl,Track1_data			;3	L1+19
	call PLY_CalcSoundData_AllowInt		;5	L1+24 -> L1+16

	ld hl,Track2_data			;3	L1+19
	call PLY_CalcSoundData_AllowInt		;5	L1+24 -> L1+16

	ld hl,Track3_data			;3	L1+19
	call PLY_CalcSoundData_AllowInt		;5	L1+24 -> L1+16

; calculate the enable bits
						;	L1+16
PLY_Track3Bits equ $+1
	ld a,0					;2	L1+18
	add a,a					;1	L1+19
PLY_Track2Bits equ $+1
	or 0					;2	L1+21
	add a,a					;1	L1+22
PLY_Track1Bits equ $+1
	or 0					;2	L1+24
	ld (PLY_PSGReg7_new),a			;4	L1+28

	defs 32-28				;	L1+32


;Send the registers to PSG. Various codes according to the machine used.
PLY_SendRegisters
	; allow interrupts
	defs line+1-32
	exx			;1	L1+ 2                           
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10
	
	nop                     ;1      L1+11
	nop                     ;1      L1+12
        ei                      ;1      L1+13
	ld l,(hl)		;2	L1+15     ; update counter
	di                      ;1      L1+16
	exx			;1	L1+17

; NOTE - this section will be totally different for the tape player demo anyway

	pop af			;3	L1+20
	ex af,af'		;1	L1+21

	defs 25-21		;	L1+25


        ld de,#1090             ;3      L1+28
ay_tones_out_ptr equ $+1
        ld hl,PLY_PSGRegistersArray_new ;3 L1+31         

; AY REG 0

	defs line+1-31          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f400             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 1

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f401             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 2

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f402             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 3

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f403             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 4

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f404             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 5

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f405             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 6

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f406             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 7

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f407             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 8

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f408             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 9

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f409             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 10

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f40a             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 11

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f40b             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 12

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f40c             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
        outi                    ;5      L1+18 B=#F4, output data (HL++)
        ld b,#f6                ;2      L1+20
        out (c),e		;4      L1+24 write data
        out (c),d		;4      L1+28 inactive                                                                            

; AY REG 13 env shape (special case)

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld bc,#f40d             ;3      L1+16    
        out (c),c               ;4      L1+20 output reg to select
        ld bc,#f6d0             ;3      L1+23
        out (c),c		;4      L1+27 select 
        out (c),d		;4      L1+31 inactive
        dec b                   ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
       
;Register 13 is a bit special as writing to it restarts the waveform
; So, we only write to it if it's different from last time or it's been manually retriggered
; (hl) contains r13
; (hl+1) contains the last r13 written, changing that to an invalid value will cause a retrigger

        ld a,(hl)               ;2      L1+15
        outi                    ;5      L1+20 B=#F4, output data (HL++)
	cp (hl)			;2	L1+22 check for last value / retrig
	ld (hl),a		;2	L1+24
        jr nz,env_changed_27    ;2/3    L1+26 same = unchanged / no retrig
        ld e,d                  ;1      L1+27 skip write  
env_changed_27:        
        ld b,#f6                ;2      L1+29

	defs line+1-29          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        out (c),e		;4      L1+17 write data
        out (c),d		;4      L1+21 inactive

	ret			;3	L1+24







;	call PLY_CalcSoundData_AllowInt		;5	L1+24 -> L1+16

PLY_CalcSoundData_AllowInt:			;5	L1+24
	defs line+0-24          ;       L1+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	nop                     ;1      L1+11
	nop                     ;1      L1+12
        ei                      ;1      L1+13
	ld l,(hl)		;2	L1+15     ; update counter
	di                      ;1      L1+16
	exx			;1	L1+17

	defs 21-17		;	L1+21
	jp PLY_CalcSoundData	;3	L1+24







PLY_Track_WaitNotReady_19:
	nop					;1	L1+20
	ret					;3	L1+23

; play a single track, HL = track data block, returns HL=HL+2, AF,BC,DE corrupt
;
;	call PLY_Track				;5	L1+31 -> L1+23
PLY_Track:
	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	dec (hl)				;3	L1+16
	jr nz,PLY_Track_WaitNotReady_19		;2/3	L1+18	more delay until next note required

	inc hl					;2	L1+20
	ld e,(hl)				;2	L1+22
	inc hl					;2	L1+24
	ld d,(hl)				;2	L1+26	 DE=track pointer
	inc hl					;2	L1+28

	ex de,hl				;1	L1+29	 HL=track pointer, DE=track_data+3

	defs line+1-29         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

;PLY_ReadTrack:
	ld a,(hl)				;2	L1+15
	inc hl					;2	L1+17 get next instruction and advance
	srl a					;2	L1+19 Full Optimisation ?
	jp c,xPLY_ReadTrack_FullOptimisation_22	;3	L1+22 If yes = Note only, no Pitch, no Volume, Same Instrument.

	sub 32					;2	L1+24 0-31 = Wait.
	jr c,xPLY_ReadTrack_Wait_27		;2	L1+26 <32, do wait

	jp z,xPLY_ReadTrack_NoOptimisation_EscapeCode_29 ;3 L1+29	 0 (32-32) = Escape Code for more Notes (parameters will be read)

	dec a					;1	L1+30 Note. Parameters are present. But the note is only present if Note? flag is 1.
	ld b,a					;1	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,(de)				;2	L1+15 get transposition
	inc de					;2	L1+17 DE=track_data+4
	add a,b					;1	L1+18
	ld c,a					;1	L1+19
	jp xPLY_ReadTrack_ReadParameters_22	;3	L1+22

xPLY_ReadTrack_Wait_27:
	add a,32				;2	L1+29 restore wait
	ex de,hl				;1	L1+30 DE=track pointer, HL=track_data+3
	ld b,a					;1	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,b					;1	L1+14
	ld bc,-3				;3	L1+17
	jp xPLY_ReadTrack_End_BC_Delta_A_wait_20 ;3	L1+20

xPLY_ReadTrack_FullOptimisation_note_27:
	jr xPLY_ReadTrack_FullOptimisation_note_30

xPLY_ReadTrack_FullOptimisation_22:
	sub 1					;2	L1+24 normalise and check for escape code
	jr nc,xPLY_ReadTrack_FullOptimisation_note_27 ;2/3 L1+26
	ld a,(hl)				;2	L1+28
	inc hl					;2	L1+30 fetch escape code

xPLY_ReadTrack_FullOptimisation_note_30:
	ld b,a					;1	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,(de)				;2	L1+15 get transposition
	inc de					;2	L1+17 DE=track_data+4
	add a,b					;1	L1+18
	ld c,a					;1	L1+19
	inc de					;2	L1+21 DE=track_data+5

	inc de					;2	L1+23 skip pitch_add
	inc de					;2	L1+25 DE=track_data+7

	xor a					;1	L1+26
	ld (de),a				;2	L1+28
	inc de					;2	L1+30
	ld (de),a				;2	L1+32 clear pitch

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc de					;2	L1+15 DE=track_data+9

	ld a,c					;1	L1+16
	ld (de),a				;2	L1+18 store new transposed note
	inc de					;2	L1+20 DE=track_data+10

	jp xPLY_ReadTrack_NoNewInstrument_23	;3	L1+23

xPLY_ReadTrack_NoOptimisation_EscapeCode_29:
	ld a,(de)				;2	L1+31 get transposition
	ld b,a					;1	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc de					;2	L1+15 DE=track_data+4	
	ld a,b					;1	L1+16
	add a,(hl)				;2	L1+18
	ld c,a					;2	L1+19 C=new note temporarily
	jr xPLY_ReadTrack_ReadParameters_22	;3	L1+22

xPLY_ReadTrack_SameVolume_29:			;	L1+29
	jr xPLY_ReadTrack_SameVolume_32		;3	L1+32

xPLY_ReadTrack_ReadParameters_22:		; DE=track_data+4
	ld b,(hl)                               ;2      L1+24

	ld a,b					;1	L1+25 save parameters
	rra					;1	L1+26
	jr nc,xPLY_ReadTrack_SameVolume_29	;2/3	L1+28	; no volume bits

	and #f					;2	L1+30 mask just volume bits
	ld (de),a				;2	L1+32 store new inverted volume bits
xPLY_ReadTrack_SameVolume_32:

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc de					;2	L1+15 DE=track_data+5
	inc hl                                  ;2	L1+17 skip first byte we read earlier

	rl b					;2	L1+19 Pitch ?
	jr c,xPLY_ReadTrack_Pitch_End_C_22	;2/3	L1+21

	inc de					;2	L1+23 no pitch, leave existing bytes alone
	inc de					;2	L1+25 skip pitch_add
	jr xPLY_ReadTrack_Pitch_End_28		;3	L1+28

xPLY_ReadTrack_Pitch_End_C_22:
	ldi					;5	L1+27 Get PitchAdd, update structure
	ldi					;5	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc bc					;2	L1+15
	inc bc					;2	L1+17
	jr xPLY_ReadTrack_Pitch_End_20		;3	L1+20

xPLY_ReadTrack_Pitch_End_28:			; DE=track_data+7

	defs line+1-28         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	defs 20-13				;	L1+20

xPLY_ReadTrack_Pitch_End_20:			; DE=track_data+7
	rl b					;2	L1+22 IsNote? flag.
	jp nc,xPLY_ReadTrack_NoNewNote_25	;3	L1+25

	xor a					;1	L1+26
	ld (de),a				;2	L1+28
	inc de					;2	L1+30 clear pitch
	ld (de),a				;2	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc de					;2	L1+15 DE=track_data+9

	ld a,c					;1	L1+16
	ld (de),a				;2	L1+18
	inc de					;2	L1+20 DE=track_data+10

	rl b					;2	L1+22 New Instrument ?
	jp nc,xPLY_ReadTrack_NoNewInstrument_25	;3	L1+25

	ld b,0					;2	L1+27
	ld c,(hl)				;2	L1+29 BC=new instrument
	inc hl					;2	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	push hl					;4	L1+17 save track_data_tr
xPLY_Track_InstrumentsTablePT equ $+1
	ld hl,0					;3	L1+20
	add hl,bc				;3	L1+23
	add hl,bc				;3	L1+26
	ld c,(hl)				;2	L1+28 Get Instrument address.
	inc hl					;2	L1+30
	ld h,(hl)				;2	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld l,c					;1	L1+14	HL= new instrument

	ld a,(hl)				;2	L1+16 Get Instrument speed.
	inc hl					;2	L1+18

	ld (de),a				;2	L1+20 save instrument speed
	inc de					;2	L1+22 DE=track_data+11
	ld (de),a				;2	L1+24 save intstrument speed counter
	inc de					;2	L1+26 DE=track_data+12

	ld c,(hl)				;2	L1+28 C=retrig data
	inc hl					;2	L1+30
	ex de,hl				;1	L1+31 HL=track_data+12, DE=instrument addr

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,c					;1	L1+14
	or a					;1	L1+15 Get IsRetrig?. Code it only if different to 0, else next Instruments are going to overwrite it.
	jr z,xPLY_Track_NoRetrig_18		;2/3	L1+17
	ld (PLY_PSGReg13_new_Retrig),a		;4	L1+21 overwrite retrig if not 0
xPLY_Track_NoRetrig_21:

	ld (hl),e				;2	L1+23 store instr restart
	inc hl					;2	L1+25 HL=track_data+13
	ld (hl),d				;2	L1+27
	inc hl					;2	L1+29 HL=track_data+14

	ld (hl),e				;2	L1+31 store instr current

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc hl					;2	L1+15 HL=track_data+15
	ld (hl),d				;2	L1+17
	pop de					;3	L1+20

	defs 26-20				;	L1+26
	jr xPLY_ReadTrack_End_BC_Delta_15_at29	;3	L1+29

xPLY_Track_NoRetrig_18:
	jr xPLY_Track_NoRetrig_21

xPLY_ReadTrack_NoNewNote_25:
	ex de,hl				;1	L1+26 HL=track_data+7, DE instrument ptr

	ld bc,-7				;3	L1+29
	jr xPLY_ReadTrack_End_BC_Delta_at_32	;3	L1+32

xPLY_ReadTrack_NoNewInstrument_23:
	defs 25-23
xPLY_ReadTrack_NoNewInstrument_25:
	ex de,hl				;1	L1+26 HL=track_data+10, DE instrument ptr

	ld a,(hl)				;2	L1+28 get instrument speed
	inc hl					;2	L1+30 HL=track_data+11
	ld (hl),a				;2	L1+32 save intstrument speed counter

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc hl					;2	L1+15 HL=track_data+12

	ld c,(hl)				;2	L1+17 get instrument start lo
	inc hl					;2	L1+19 HL=track_data+13
	ld b,(hl)				;2	L1+21 get instrument start hi
	inc hl					;2	L1+23 HL=track_data+14

	ld (hl),c				;2	L1+25 store instrument start lo
	inc hl					;2	L1+27 HL=track_data+15
	ld (hl),b				;2	L1+29 store instrument start hi

xPLY_ReadTrack_End_BC_Delta_15_at29:
	ld bc,-15				;3	L1+32

xPLY_ReadTrack_End_BC_Delta_at_32:
	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,1					;2	L1+15 restart instrument
	defs 20-15				;	L1+20

xPLY_ReadTrack_End_BC_Delta_A_wait_20:
	add hl,bc				;3	L1+23 HL=track_data+0, DE instrument ptr
	ld (hl),a				;2	L1+25 instrument start pos
	inc hl					;2	L1+27 HL=track_data+1
	ld (hl),e				;2	L1+29  save current instrument ptr
	inc hl					;2	L1+31 HL=track_data+2

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld (hl),d				;2	L1+15
	defs 20-15				;	L1+20
	ret					;3	L1+23










; HL = track data structure again
;
;	call PLY_CalcSoundData			;5	L1+24 -> L1+16
PLY_CalcSoundData:
	inc hl					;2	L1+26 +1 skip ptr lo
	inc hl					;2	L1+28 +2 skip ptr hi
	inc hl					;2	L1+30 +3 skip counter
	inc hl					;2	L1+32 +4 skip transposition

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,(hl)				;2	L1+15 A=volume
PLY_FadeOutValuePtr equ $+1
	add a,0					;2	L1+17 adjust volume for fade out
	inc hl					;2	L1+19 +5
	ld (PLY_CurrentVolume),a		;4	L1+23

	ld c,(hl)				;2	L1+25 C=pitchadd lo
	inc hl					;2	L1+27
	ld b,(hl)				;2	L1+29 B=pitchadd hi
	inc hl					;2	L1+31 +7

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld e,(hl)				;2	L1+15 E=pitch lo
	inc hl					;2	L1+17
	ld d,(hl)				;2	L1+19 D=pitch hi
	dec hl					;2	L1+21 +7

	ex de,hl				;1	L1+22 update pitch
	add hl,bc				;3	L1+25
	ex de,hl				;1	L1+26

	ld (hl),e				;2	L1+28 save pitch lo
	inc hl					;2	L1+30
	ld (hl),d				;2	L1+32 save pitch hi

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc hl					;2	L1+15 +9

	; HL=track_data+8, DE=pitch*4

	ld a,(hl)				;2	L1+17 A=note
	ld (PLY_CalcSound_Note),a		;4	L1+21
	inc hl					;2	L1+23 +10
	inc hl					;2	L1+25 +11 skip instr speed
	ld (PLY_CalcSound_InstrCounterPtr),hl	;5	L1+30
	inc hl					;2	L1+32 +12 skip instr counter

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	; normalise pitch

	sra d					;2	L1+15 Shift the Pitch to slow its speed.
	rr e					;2	L1+17
	sra d					;2	L1+19
	rr e					;2	L1+21

	ld (PLY_CalcSound_Pitch),de		;6	L1+27
	inc hl					;2	L1+29 +13 skip instr restart lo
	inc hl					;2	L1+31 +14 skip instr restart hi

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld e,(hl)				;2	L1+15 E=instr ptr lo
	inc hl					;2	L1+17
	ld d,(hl)				;2	L1+19 D=instr ptr hi
	inc hl					;2	L1+21 +16

	ld c,(hl)				;2	L1+23 fetch freq ptr
	inc hl					;2	L1+25
	ld b,(hl)				;2	L1+27
	ld (PLY_StoreFreqPtr),bc		;6	L1+33

; vvvv NOTE OUT OF SYNC BY 1 CYCLE HERE vvvv, BUT CBA TO FIX!
	defs line+2-33         			;       L1+ 2 XXX
	exx					;1	L1+ 3 XXX
	in a,(c)				;4	L1+ 7 XXX
	xor c					;1	L1+ 8 XXX     ; check for edge
	call m,new_found_edge			;3/5	L1+11 XXX	
	ld l,(hl)				;2	L1+13 XXX     ; update counter
	exx					;1	L1+14 XXX
; ^^^^ NOTE OUT OF SYNC BY 1 CYCLE HERE ^^^^, BUT CBA TO FIX!

	inc hl					;2	L1+16

	ld c,(hl)				;2	L1+18 fetch volume ptr
	inc hl					;2	L1+20
	ld b,(hl)				;2	L1+22
	inc hl					;2	L1+24
	ld (PLY_StoreVolPtr),bc			;6	L1+30

	ld c,(hl)				;2	L1+32 fetch volume ptr

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc hl					;2	L1+15

	ld b,(hl)				;2	L1+17
	ld (PLY_StoreBitsPtr),bc		;6	L1+23
	ex de,hl				;1	L1+24	; HL = instr pointer

PLY_CurrentVolume equ $+1
	ld d,0					;1	L1+26	; D = volume

	nop					;1	L1+27
	jr PLY_CalcSoundData_Looped_30		;3	L1+30


PLY_CS_Hard_LoopOrIndep_18:
	bit 0,b					;2	L1+20	; check for jump or independent
	jp z, PLY_CS_Hard_Indep_23		;3	L1+23

	ld a,(hl)				;2	L1+25	; get loop address
	inc hl					;2	L1+27
	ld h,(hl)				;2	L1+29
	ld l,a					;1	L1+30	; HL=new instr addr

	; HL=instr ptr, D=volume
PLY_CalcSoundData_Looped_30:
	ld b,(hl)				;2	L1+32 get instrument byte

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc hl					;2	L1+15

	; HL=instr ptr, D=volume, B=instr byte

	rr b					;2	L1+17
	jp c,PLY_CS_Hard_20			;3	L1+20

; Software sound

	rr b					;2	L1+22 2nd byte needed?
	jp c, PLY_CS_S_2ndbyte_25		;3	L1+25

	ld a,b					;1	L1+26 check volume
	and #f					;2	L1+28
	jr nz, PLY_CS_S_on_31			;2/3	L1+30

	ld d,a					;1	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,d					;1	L1+14
	defs 23-14				;	L1+23
	call PLY_Store_Vol_A_28			;5	L1+28 -> L1+16
	defs 22-16				;	L1+22
	ld e,#9					;2	L1+24 noise off, sound off
	jp PLY_CalcSound_Finished_Bits_in_E_27	;3	L1+27

PLY_CS_S_on_31:
	ld e,a					;1	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,e					;1	L1+14
	sub d					;1	L1+15 subtract volume adj
	jr nc, PLY_CS_S_on_but_silent_18	;2/3	L1+17
	xor a					;1	L1+18
PLY_CS_S_on_but_silent_18:
	defs 23-18				;	L1+23
	call PLY_Store_Vol_A_28			;5	L1+28 -> L1+16
	defs 17-16				;	L1+17

	rr b					;2	L1+19 bit adjust for correct position
	call PLY_CS_CalculateFrequency_24	;5	L1+24 -> L1+23
	call PLY_Store_Freq_DE_28		;5	L1+28 -> L1+22

	ld e,#8					;2	L1+24 noise off, sound on
	jp PLY_CalcSound_Finished_Bits_in_E_27	;3	L1+27

PLY_CS_S_2ndbyte_nonoise_18:
	ld a,#8					;2	L1+20 noise off, sound on
	jr PLY_CS_S_2ndbyte_nonoise_23		;3	L1+23

PLY_CS_S_2ndbyte_25:
	ld c,(hl)				;2	L1+27 get 2nd byte
	inc hl					;2	L1+29
	ld e,#1f				;2	L1+31	constant for after break

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,c					;1	L1+14
	and e					;1	L1+15 check for noise
	jr z, PLY_CS_S_2ndbyte_nonoise_18	;2/3	L1+17

	ld (PLY_PSGReg6_new),a			;4	L1+21 store noise
	ld a,#0					;2	L1+23 noise on, sound on
PLY_CS_S_2ndbyte_nonoise_23:
	ld (PLY_CS_S_2ndbyte_sound_Bits),a	;4	L1+27 save sound bits


	defs line+1-27         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,b					;2	L1+15 prepare volume
	and #f					;2	L1+17
	sub d					;1	L1+18 adjust for note
	jr nc,PLY_CS_S_2ndbyte_but_silent_21	;2/3	L1+20
	xor a					;1	L1+21
PLY_CS_S_2ndbyte_but_silent_21:
	call PLY_Store_Vol_A_26			;5	L1+26 -> L1+16

	bit 5,c					;2	L1+18 check if we're inhibiting sound
	jr nz, PLY_CS_S_2ndbyte_sound_21	;2/3	L1+20

	ld a,(PLY_CS_S_2ndbyte_sound_Bits)	;4	L1+24
	inc a					;1	L1+25 stop sound
	jp PLY_CalcSound_Finished_Bits_in_A_28	;1	L1+28

PLY_CS_S_2ndbyte_sound_21:
	rr b					;2	L1+30 bit adjust for correct position

	defs line+1-30         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	bit 6,c					;2	L1+15
	call PLY_CS_CalculateFrequency_PossiblyManual_21 ;5 L1+21 -> L1+23
	call PLY_Store_Freq_DE_28		;5	L1+28 -> L1+22

PLY_CS_S_2ndbyte_sound_Bits equ $+1
	ld e,0					;2	L1+24
	jp PLY_CalcSound_Finished_Bits_in_E_27	;3	L1+27



PLY_CS_Hard_20:					
	push hl					;4	L1+24

	rr b					;2	L1+26	; test retrig
	jr nc, PLY_CS_Hard_NoRetrig_29		;2/3	L1+28

	defs line+1-28         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld hl,(PLY_CalcSound_InstrCounterPtr)	;5	L1+18
	ld a,(hl)				;2	L1+20	; get current instr count
	dec hl					;2	L1+22
	cp (hl)					;2	L1+24	; check if this is the first line of instrument
	jr nz, PLY_CS_Hard_NoRetrig_27		;2/3	L1+26

	defs line+1-26         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	
	ld a,PLY_RetrigValue			;2	L1+15	; if first line, we can force retrig
	ld (PLY_PSGReg13_new_Retrig),a		;4	L1+19

	defs 27-19				;	L1+27
PLY_CS_Hard_NoRetrig_27:
	defs 29-27				;	L1+29
PLY_CS_Hard_NoRetrig_29:
	pop hl					;3	L1+32


	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	bit 1,b					;2	L1+15	; test for indep/loop or soft/hw dep
	jp nz, PLY_CS_Hard_LoopOrIndep_18	;3	L1+18

	ld a,16					;2	L1+20	; set volume to follow env
	defs 23-20				;	L1+23
	call PLY_Store_Vol_A_28			;5	L1+28 -> L1+16

	ld c,(hl)				;2	L1+18	; get 2nd byte
	inc hl					;2	L1+20
	ld a,c					;1	L1+21	; get hw env pattern
	and #f					;2	L1+23
	ld (PLY_PSGReg13_new),a			;4	L1+27

	bit 0,b					;2	L1+29
	defs line-2-29				;	L1- 2
	jp z, PLY_CS_HWDep_1			;3	L1+ 1

; SW dep
PLY_CS_SWDep_1:					;	L1+1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	bit 4-2,b				;2	L1+15	; manual frequency
	defs 16-15				;	L1+16
	call PLY_CS_CalculateFrequency_PossiblyManual_21 ;5 L1+21 -> L1+23
	call PLY_Store_Freq_DE_28		;5	L1+28 -> L1+22

	ld a,c					;1	L1+23	; do a frequency shift
	rra					;1	L1+24
	rra					;1	L1+25	; shift*=4 (inverted in memory)
	and #1c					;2	L1+27
	ld (PLY_CS_SD_Shift + 1),a		;4	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	
PLY_CS_SD_Shift jr $+2   			;3	L1+16   			;Stable version shift processing.

	jp PLY_CS_SD_Shift0			;3	L1+19
	nop
	jp PLY_CS_SD_Shift1			;3	L1+19
	nop
	jp PLY_CS_SD_Shift2			;3	L1+19
	nop
	jp PLY_CS_SD_Shift3			;3	L1+19
	nop
	jp PLY_CS_SD_Shift4			;3	L1+19
	nop
	jp PLY_CS_SD_Shift5			;3	L1+19
	nop
	jp PLY_CS_SD_Shift6			;3	L1+19
	nop
	jp PLY_CS_SD_Shift7			;3	L1+19




PLY_CS_SD_Shift0
	srl d					;2	L1+21
	rr e					;2	L1+23
	srl d					;2	L1+25
	rr e					;2	L1+27
	srl d					;2	L1+29
	rr e					;2	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	srl d					;2	L1+16
	rr e					;2	L1+18
	srl d					;2	L1+20
	rr e					;2	L1+22
	srl d					;2	L1+24
	rr e					;2	L1+26
	srl d					;2	L1+28
	rr e					;2	L1+30

	defs line+0-30         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	jp PLY_CS_SD_Shift_Return		;3	L1+17

PLY_CS_SD_Shift1
	srl d					;2	L1+21
	rr e					;2	L1+23
	srl d					;2	L1+25
	rr e					;2	L1+27
	srl d					;2	L1+29
	rr e					;2	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	srl d					;2	L1+16
	rr e					;2	L1+18
	srl d					;2	L1+20
	rr e					;2	L1+22
	srl d					;2	L1+24
	rr e					;2	L1+26
	defs 4*1				;	L1+30

	defs line+0-30         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	jp PLY_CS_SD_Shift_Return		;3	L1+17

PLY_CS_SD_Shift2
	srl d					;2	L1+21
	rr e					;2	L1+23
	srl d					;2	L1+25
	rr e					;2	L1+27
	srl d					;2	L1+29
	rr e					;2	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	srl d					;2	L1+16
	rr e					;2	L1+18
	srl d					;2	L1+20
	rr e					;2	L1+22
	defs 4*2				;	L1+30

	defs line+0-30         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	jp PLY_CS_SD_Shift_Return		;3	L1+17

PLY_CS_SD_Shift3
	srl d					;2	L1+21
	rr e					;2	L1+23
	srl d					;2	L1+25
	rr e					;2	L1+27
	srl d					;2	L1+29
	rr e					;2	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	srl d					;2	L1+16
	rr e					;2	L1+18
	defs 4*3				;	L1+30

	defs line+0-30         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	jp PLY_CS_SD_Shift_Return		;3	L1+17


PLY_CS_SD_Shift4
	srl d					;2	L1+21
	rr e					;2	L1+23
	srl d					;2	L1+25
	rr e					;2	L1+27
	srl d					;2	L1+29
	rr e					;2	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	jp PLY_CS_SD_Shift_Return		;3	L1+17

PLY_CS_SD_Shift5
	srl d					;2	L1+21
	rr e					;2	L1+23
	srl d					;2	L1+25
	rr e					;2	L1+27
	defs 4*1				;	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	jp PLY_CS_SD_Shift_Return		;3	L1+17

PLY_CS_SD_Shift6
	srl d					;2	L1+21
	rr e					;2	L1+23
	defs 4*2				;	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	jp PLY_CS_SD_Shift_Return		;3	L1+17

PLY_CS_SD_Shift7
	and a					;1	L1+20

	defs line+0-20         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	jp PLY_CS_SD_Shift_Return		;3	L1+17

	; shifted result in DE, increase if carry shifted out last
PLY_CS_SD_Shift_Return:
	jr c,PLY_CS_SD_Shift_Return_Overflow_20	;2/3	L1+19
	jr PLY_CS_SD_Shift_Return_NoOverflow	;3	L1+22
PLY_CS_SD_Shift_Return_Overflow_20:
	inc de					;2	L1+22
PLY_CS_SD_Shift_Return_NoOverflow:		;	L1+22

	bit 7-2,b				;2	L1+24 check for hardware pitch
	jp z, PLY_CS_SD_NoHWPitch_27		;3	L1+27

	ld a,(hl)				;2	L1+29
	add a,e					;1	L1+30
	ld e,a					;1	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc hl					;2	L1+15

	ld a,(hl)				;2	L1+17
	adc a,d					;1	L1+18
	ld d,a					;1	L1+19 DE = HW pitch delta
	inc hl					;2	L1+21
PLY_CS_SD_NoHWPitch_21:
	ld (PLY_PSGReg11_new),de		;6	L1+27

	ld e,#8					;2	L1+29 sound on, noise off
	jp PLY_CS_SD_Noise_32			;3	L1+32

PLY_CS_SD_NoHWPitch_27:
	defs line+1-27         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	defs 18-18				;	L1+18
	jr PLY_CS_SD_NoHWPitch_21		;3	L1+21




; HW dep
PLY_CS_HWDep_1:
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	bit 4-2,b				;2	L1+15	; manual frequency
	defs 16-15				;	L1+16
	call PLY_CS_CalculateFrequency_PossiblyManual_21 ;5 L1+21 -> L1+23

	ld a,c					;1	L1+24	; do a frequency shift
	rra					;1	L1+25
	rra					;1	L1+26	; shift*=4 (inverted in memory)
	and #1c					;2	L1+28
	ld (PLY_CS_HD_Shift + 1),a		;4	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld (PLY_PSGReg11_new),de		;6	L1+19




	
PLY_CS_HD_Shift jr $+2          		;3	L1+22	;Stable version shift processing.

	jp PLY_CS_HD_Shift0			;3	L1+25
	nop
	jp PLY_CS_HD_Shift1			;3	L1+25
	nop
	jp PLY_CS_HD_Shift2			;3	L1+25
	nop
	jp PLY_CS_HD_Shift3			;3	L1+25
	nop
	jp PLY_CS_HD_Shift4			;3	L1+25
	nop
	jp PLY_CS_HD_Shift5			;3	L1+25
	nop
	jp PLY_CS_HD_Shift6			;3	L1+25
	nop
	jp PLY_CS_HD_Shift7			;3	L1+25

PLY_CS_HD_Shift0
						;3	L1+25
	sla e					;2	L1+27
	rl d					;2	L1+29
	sla e					;2	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	sla e					;2	L1+18
	rl d					;2	L1+20
	sla e					;2	L1+22
	rl d					;2	L1+24
	sla e					;2	L1+26
	rl d					;2	L1+28
	sla e					;2	L1+30

	defs line+0-30         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	sla e					;2	L1+18
	rl d					;2	L1+20

	jp PLY_CS_HD_Shift_Return		;3	L1+23

PLY_CS_HD_Shift1
						;3	L1+25
	sla e					;2	L1+27
	rl d					;2	L1+29
	sla e					;2	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	sla e					;2	L1+18
	rl d					;2	L1+20
	sla e					;2	L1+22
	rl d					;2	L1+24
	sla e					;2	L1+26
	defs 4*1				;	L1+30

	defs line+0-30         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	sla e					;2	L1+18
	rl d					;2	L1+20

	jp PLY_CS_HD_Shift_Return		;3	L1+23

PLY_CS_HD_Shift2
						;3	L1+25
	sla e					;2	L1+27
	rl d					;2	L1+29
	sla e					;2	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	sla e					;2	L1+18
	rl d					;2	L1+20
	sla e					;2	L1+22
	defs 4*2				;	L1+30

	defs line+0-30         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	sla e					;2	L1+18
	rl d					;2	L1+20

	jp PLY_CS_HD_Shift_Return		;3	L1+23

PLY_CS_HD_Shift3
						;3	L1+25
	sla e					;2	L1+27
	rl d					;2	L1+29
	sla e					;2	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	sla e					;2	L1+18
	defs 4*3				;	L1+30

	defs line+0-30         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	sla e					;2	L1+18
	rl d					;2	L1+20

	jp PLY_CS_HD_Shift_Return		;3	L1+23

PLY_CS_HD_Shift4
						;3	L1+25
	sla e					;2	L1+27
	rl d					;2	L1+29
	sla e					;2	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	sla e					;2	L1+18
	rl d					;2	L1+20

	jp PLY_CS_HD_Shift_Return		;3	L1+23

PLY_CS_HD_Shift5
						;3	L1+25
	sla e					;2	L1+27
	defs 4*1				;	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	sla e					;2	L1+18
	rl d					;2	L1+20

	jp PLY_CS_HD_Shift_Return		;3	L1+23

PLY_CS_HD_Shift6
						;3	L1+25
	sla e					;2	L1+27
	defs 4*1				;	L1+31

	defs line+0-31         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	rl d					;2	L1+16
	defs 4*1				;	L1+20

	jp PLY_CS_HD_Shift_Return		;3	L1+23

PLY_CS_HD_Shift7
	defs line+0-25         			;       L1+ 0
	ex af,af'				;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	ex af,af'				;1	L1+14

	defs 20-14				;	L1+20
	jp PLY_CS_HD_Shift_Return		;3	L1+23


	; shifted result in DE, increase if carry shifted out last
PLY_CS_HD_Shift_Return:
						;3	L1+23
	bit 7-2,b				;2	L1+25 check for software pitch
	jp z, PLY_CS_SD_NoSWPitch_28		;3	L1+28

	ld a,(hl)				;2	L1+30
	add a,e					;1	L1+31
	ld e,a					;1	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc hl					;2	L1+15

	ld a,(hl)				;2	L1+17
	adc a,d					;1	L1+18
	ld d,a					;1	L1+19 DE = SW pitch delta
	inc hl					;2	L1+21

PLY_CS_HD_NoSWPitch_21:
	defs 23-12				;	L1+23
	call PLY_Store_Freq_DE_28		;5	L1+28 -> L1+22

	ld e,#8					;2	L1+24 sound on, noise off
	defs 29-24				;	L1+29
	jp PLY_CS_SD_Noise_32			;3	L1+32

PLY_CS_SD_NoSWPitch_28:
	defs line+1-28         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	defs 18-13				;	L1+18
	jp PLY_CS_HD_NoSWPitch_21		;3	L1+21








; Independent sounds

PLY_CS_Hard_Indep_23:
	bit 7-2,b				;2	L1+25 check if we have sound
	jr nz, PLY_CS_I_Sound_28		;2/3	L1+27

	defs line+1-27         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld e,#9					;2	L1+15 no noise, no sound
	defs 21-15				;	L1+21
	jr PLS_CS_I_skip_soft_freq_24		;3	L1+24

PLY_CS_I_Sound_28:
	defs line+1-28         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	bit 4-2,b				;2	L1+15 manual frequency?
	nop					;1	L1+16
	call PLY_CS_CalculateFrequency_PossiblyManual_21 ;5 L1+21 -> L1+23
	call PLY_Store_Freq_DE_28		;5	L1+28 -> L1+22
	ld e,#8					;2	L1+24 no noise, use sound

PLS_CS_I_skip_soft_freq_24:
	ld a,(hl)				;2	L1+26 get second byte
	and #f					;2	L1+28 get HW env waveform
	ld (PLY_PSGReg13_new),a			;4	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld b,(hl)				;2	L1+15 get second byte
	inc hl					;2	L1+17
	rr b					;2	L1+19 shift bits to expect pos
	rr b					;2	L1+21

	ld a,16					;2	L1+23 set volume to follow env
	call PLY_Store_Vol_A_28			;5	L1+28 -> L1+16

	; calculate hardware freq

	defs line+1-16         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld c,e					;1	L1+14 preserve sound bit
	bit 4-2,b				;2	L1+16 manual hw freq?
	call PLY_CS_CalculateFrequency_PossiblyManual_21 ;5 L1+21 -> L1+23
	ld (PLY_PSGReg11_new),de		;6	L1+29
	ld e,c					;1	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	; check for noise btis

	bit 7-2,c				;2	L1+15 check for noise
	jr z, PLS_CS_I_skip_noise_18		;2/3	L1+17

	ld a,(hl)				;2	L1+19 copy the noise freq
	inc hl					;2	L1+21
	ld (PLY_PSGReg6_new),a			;4	L1+25
	res 3,e					;2	L1+27 remove the noise bit

	defs line+1-27         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	defs 18-15				;	L1+18
PLS_CS_I_skip_noise_18:
	defs 20-18				;	L1+20

PLY_CalcSound_Finished_Bits_in_E_20:
	defs 24-20				;	L1+24
	jr PLY_CalcSound_Finished_Bits_in_E_27	;3	L1+27

	;This code is also used by Hardware Dependent.
PLY_CS_SD_Noise_32:				;	L1+32
	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	bit 7,c					;2	L1+15 check for noise
	jr z, PLY_CalcSound_Finished_Bits_in_E_20 ;2/3	L1+17
	ld a,(hl)				;2	L1+19
	inc hl					;2	L1+21
	ld (PLY_PSGReg6_new),a			;4	L1+25

	ld e,#0					;2	L1+27 sound on, noise on

PLY_CalcSound_Finished_Bits_in_E_27:
	ld a,e					;1	L1+28
PLY_CalcSound_Finished_Bits_in_A_28:
PLY_StoreBitsPtr equ $+1
	ld (0),a				;4	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

;PLY_CalcSound_Finished:

	ex de,hl				;1	L1+14 DE = instrument point
PLY_CalcSound_InstrCounterPtr equ $+1
	ld hl,0					;3	L1+17 +11 instr counter

	dec (hl)				;3	L1+20
	jr nz,PLY_CalcSound_InstrCounter_Done_23 ;2/3	L1+22 still on this instrument line

	dec hl					;2	L1+24 +10 instr speed
	ld a,(hl)				;2	L1+26
	inc hl					;2	L1+28 +11 instr counter
	ld (hl),a				;2	L1+30	otherwise advance to the new line
	inc hl					;2	L1+32 +12 instr restart lo

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc hl					;2	L1+15 +13 instr restart hi
	inc hl					;2	L1+17 +14 instr ptr lo

	ld (hl),e				;2	L1+19 store instr ptr lo
	inc hl					;2	L1+21 +15 instr ptr hi
	ld (hl),d				;2	L1+23 store instr ptr hi
	inc hl					;2	L1+25 +16
	nop					;1	L1+26

PLY_CalcSound_InstrCounter_Done_26:
	defs line+1-26         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ret					;3	L1+16
;	call PLY_CalcSoundData			;5	L1+24 -> L1+16

PLY_CalcSound_InstrCounter_Done_23:
	jr PLY_CalcSound_InstrCounter_Done_26











;	call PLY_CS_CalculateFrequency_PossiblyManual_21 ;5 L1+21 -> L1+23

	; B=1st byte, HL=instrument pointer
	; corrupts A, returns DE=frequency, HL=updated pointer
PLY_CS_CalculateFrequency_PossiblyManual_21:	;	L1+21
	jr z, PLY_CS_CalculateFrequency_24	;2/3	L1+23

	ld de,(PLY_CalcSound_Pitch)		;6	L1+29 get track pitch

	defs line+1-29         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,e					;1	L1+14 add manual lo
	add a,(hl)				;2	L1+16
	inc hl					;2	L1+18
	ld e,a					;1	L1+19

	ld a,d					;1	L1+20 add manual hi
	adc a,(hl)				;2	L1+22
	inc hl					;2	L1+24
	ld d,a					;2	L1+25
;	ret					;3	L1+28


	defs line+1-25         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13
	
	defs 20-13				;	L1+20
	ret					;3	L1+23



	; B=1st byte, HL=instrument pointer
	; corrupts A, returns DE=frequency, HL=updated pointer
PLY_CS_CalculateFrequency_24:			;	L1+24
PLY_CalcSound_Pitch equ $+1
	ld de, 0				;3	L1+27

	defs line+1-27         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	bit 5-1,b				;2	L1+15
	jr z,PLY_CS_CalculateFrequency_GotPitch_18 ;2/3 L1+17

	ld a,(hl)				;2	L1+19 get pitch lo
	inc hl					;2	L1+21
	add a,e					;1	L1+22
	ld e,a					;1	L1+23
	ld a,(hl)				;2	L1+25 get pitch hi
	inc hl					;2	L1+27
	adc a,d					;1	L1+29
	ld d,a					;1	L1+30 DE=trackpitch + notepitch

	defs line+1-30         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	defs 18-13				;	L1+18
PLY_CS_CalculateFrequency_GotPitch_18:

PLY_CalcSound_Note equ $+1
	ld a,#00				;2	L1+20 current note

	bit 4-1,b				;2	L1+22
	jr z, PLY_CS_CalculateFrequency_GotArp_25 ;2/3	L1+24

	add a,(hl)				;2	L1+26 add arp
	ld (PLY_CalcSound_TempArp),a		;4	L1+30
	inc hl					;2	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

PLY_CalcSound_TempArp equ $+1
	ld a,0					;2	L1+15
	cp 144					;2	L1+17

	jr c,PLY_CS_CalculateFrequency_GotArp_20 ;2/3	L1+19
	ld a,143				;2	L1+21 clamp arp note
	defs 25-21				;	L1+25
PLY_CS_CalculateFrequency_GotArp_25:

PLY_FrequencyTable_Lo equ PLY_FrequencyTable 
PLY_FrequencyTable_Hi equ PLY_FrequencyTable / 256

	push hl					;4	L1+29
	ld h,0					;2	L1+31
	ld l,a					;1	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,l					;1	L1+14
	add a,a					;1	L1+15 A=note*2
	rl h					;2	L1+17 H=carry
	add a,PLY_FrequencyTable_Lo		;2	L1+19
	ld l,a					;1	L1+20 L=note*2 + freq table lo

	ld a,h					;1	L1+21 A=carry from previous
	adc a,PLY_FrequencyTable_Hi		;2	L1+23
	ld h,a					;1	L1+24 H=freq table hi + any carries

	ld a,(hl)				;2	L1+26
	inc hl					;2	L1+28
	ld h,(hl)				;2	L1+30
	ld l,a					;1	L1+31 HL=note pitch

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	add hl,de				;3	L1+16 DE=track pitch + instr pitch
	ex de,hl				;1	L1+17
	pop hl					;3	L1+20 restore instruction ptr
	ret					;3	L1+23

PLY_CS_CalculateFrequency_GotArp_20:
	defs 22-20				;	L1+22
	jr PLY_CS_CalculateFrequency_GotArp_25	;3	L1+25








;	call PLY_Store_Freq_DE			;5	L1+28 -> L1+22

PLY_Store_Freq_DE_28:				;	L1+28
	defs 32-28
PLY_Store_Freq_DE_32:				;	L1+32
	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

PLY_StoreFreqPtr equ $+2
	ld (0),de				;6	L1+19

	ret					;3	L1+22


;	call PLY_Store_Vol_A_26			;5	L1+26 -> L1+16
;	call PLY_Store_Vol_A_28			;5	L1+28 -> L1+16

PLY_Store_Vol_A_26:				;	L1+26
	nop					;1	L1+27
PLY_Store_Vol_A_27:				;	L1+27
	nop					;1	L1+28
PLY_Store_Vol_A_28:				;	L1+28
PLY_StoreVolPtr equ $+1
	ld (0),a				;4	L1+32

	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ret					;3	L1+16



PLY_FrequencyTable
; 12 per octave, 12 octaves
	defw 3822,3608,3405,3214,3034,2863,2703,2551,2408,2273,2145,2025
	defw 1911,1804,1703,1607,1517,1432,1351,1276,1204,1136,1073,1012
	defw 956,902,851,804,758,716,676,638,602,568,536,506
	defw 478,451,426,402,379,358,338,319,301,284,268,253
	defw 239,225,213,201,190,179,169,159,150,142,134,127
	defw 119,113,106,100,95,89,84,80,75,71,67,63
	defw 60,56,53,50,47,45,42,40,38,36,34,32
	defw 30,28,27,25,24,22,21,20,19,18,17,16
	defw 15,14,13,13,12,11,11,10,9,9,8,8
	defw 7,7,7,6,6,6,5,5,5,4,4,4
	defw 4,4,3,3,3,3,3,2,2,2,2,2
	defw 2,2,2,2,1,1,1,1,1,1,1,1


;        call PLY_Init 				;5	L1+32 -> L1+24
;
;DE = Music
PLY_Init
	defs line+1-32         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld hl,9					;3	L1+16	;Skip Header, SampleChannel, YM Clock (DB*3), and Replay Frequency.
	add hl,de				;3	L1+19

	ld de,PLY_Speed + 1			;3	L1+22
	ldi					;5	L1+27	Copy Speed.
	ld c,(hl)				;2	L1+29	Get Instruments chunk size.
	inc hl					;2	L1+31

	defs line+1-31         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld b,(hl)				;2	L1+15
	inc hl					;2	L1+19
	ld (xPLY_Track_InstrumentsTablePT),hl	;5	L1+24

	add hl,bc				;3	L1+27	Skip Instruments to go to the Linker address.

	;Get the pre-Linker information of the first pattern.
	ld de,PLY_Height + 1			;3	L1+30

	defs line+1-30         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ldi					;5	L1+18
	ld de,Track1_data+3			;3	L1+21
	ldi					;5	L1+26

	ld de,Track2_data+3			;3	L1+29

	defs line+1-29         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ldi					;5	L1+18
	ld de,Track3_data+3			;3	L1+21
	ldi					;5	L1+26

	ld de,PLY_SaveSpecialTrack + 1		;3	L1+29

	defs line+1-29         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ldi					;5	L1+18
	ldi					;5	L1+23
	ld (PLY_Linker_PT + 1),hl		;3	L1+26	Get the Linker address.

	;Set the Instruments pointers to Instrument 0 data (Header has to be skipped).
	ld hl,(xPLY_Track_InstrumentsTablePT)	;5	L1+31

	defs line+1-29         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld a,1					;2	L1+15
	ld (PLY_SpeedCpt + 1),a			;4	L1+19
	ld (PLY_HeightCpt + 1),a		;4	L1+23

	ld a,#ff				;2	L1+25
	ld (PLY_PSGReg13_new),a			;4	L1+29
	
	ld e,(hl)				;2	L1+31

	defs line+1-29         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	inc hl					;2	L1+15
	ld d,(hl)				;2	L1+17
	ex de,hl				;2	L1+19
	inc hl					;2	L1+21	Skip Instrument 0 Header.
	inc hl					;2	L1+23

	ld (Track1_data+12),hl			;5	L1+28

	defs line+1-28         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld (Track1_data+14),hl			;5	L1+18
	ld (Track2_data+12),hl			;5	L1+23
	ld (Track2_data+14),hl			;5	L1+28

	defs line+1-28         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ld (Track3_data+12),hl			;5	L1+18
	ld (Track3_data+14),hl			;5	L1+23

	defs line+1-23         			;       L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	ret					;3	L1+16



;Stop the music, cut the channels.
PLY_Stop

	ld hl,PLY_PSGReg8_new
	xor a
	ld (hl),a
	inc hl
	ld a,#3f ;%00111111
	jp PLY_SendRegisters











	;list
;*** End of Arkos Tracker Player
	;nolist



;	org #3f00

Track1_data:
      	defb 1	; +0  PLY_Track1_WaitCounter
	defw 0	; +1  PLY_Track1_PT
	defb 0	; +3  transposition
	defb 0	; +4  volume
	defw 0	; +5  pitch add
	defw 0	; +7  pitch
	defb 0	; +9  note
	defb 1	; +10 instrument speed
	defb 1	; +11 instrument count
	defw 0	; +12 instrument restart ptr
	defw 0	; +14 instrument current ptr
	defw PLY_PSGRegistersArray_new+0	; freq ptr r0/r1
	defw PLY_PSGRegistersArray_new+8	; volume ptr r8
	defw PLY_Track1Bits
;	defs 16-6	; +16
;	defb "^^^ TRACK  1 ^^^"

Track2_data:
      	defb 1	; +0  PLY_Track1_WaitCounter
	defw 0	; +1  PLY_Track1_PT
	defb 0	; +3  transposition
	defb 0	; +4  volume
	defw 0	; +5  pitch add
	defw 0	; +7  pitch
	defb 0	; +9  note
	defb 1	; +10 instrument speed
	defb 1	; +11 instrument count
	defw 0	; +12 instrument restart ptr
	defw 0	; +14 instrument current ptr
	defw PLY_PSGRegistersArray_new+2	; freq ptr r2/r3
	defw PLY_PSGRegistersArray_new+9	; volume ptr r9
	defw PLY_Track2Bits
;	defs 16-6	; +16
;	defb "^^^ TRACK  2 ^^^"

Track3_data:
      	defb 1	; +0  PLY_Track1_WaitCounter
	defw 0	; +1  PLY_Track1_PT
	defb 0	; +3  transposition
	defb 0	; +4  volume
	defw 0	; +5  pitch add
	defw 0	; +7  pitch
	defb 0	; +9  note
	defb 1	; +10 instrument speed
	defb 1	; +11 instrument count
	defw 0	; +12 instrument restart ptr
	defw 0	; +14 instrument current ptr
	defw PLY_PSGRegistersArray_new+4	; freq ptr r4/r5
	defw PLY_PSGRegistersArray_new+10	; volume ptr r10
	defw PLY_Track3Bits
;	defs 16-6	; +16
;	defb "^^^ TRACK  3 ^^^"


;There are two holes in the list, because the Volume registers are set relatively to the Frequency of the same Channel (+7, always).
;Also, the Reg7 is passed as a register, so is not kept in the memory.
;
; TODO this is kind of irrelevant now

PLY_PSGRegistersArray_new:
	defs 16
PLY_PSGReg11_new equ PLY_PSGRegistersArray_new+11	; hack
PLY_PSGReg13_new equ PLY_PSGRegistersArray_new+13	; hack
PLY_PSGReg6_new equ PLY_PSGRegistersArray_new+6
PLY_PSGReg8_new equ PLY_PSGRegistersArray_new+8
PLY_PSGReg7_new equ PLY_PSGRegistersArray_new+7

PLY_PSGReg13_new_Retrig equ PLY_PSGRegistersArray_new+14

;	defs 16,#ee
time:	defs 2
;	defb "<< TIME"
;	defs 16


;STOPHERE


	org #4000
songdata:               
;	incbin "music/test-4000.bin"
	incbin "music/cr4sh-4000.bin"
;	incbin "music/bonito-4000.bin"
;	incbin "music/remember david-4000.bin"
;	incbin "music/hardstyle-4000.bin"
;	incbin "music/quasar-4000.bin"
;	incbin "music/littlesailor-4000.bin"

;	incbin "music/weekend-4000.bin"
;	incbin "music/takeoff-4000.bin"

	incbin "music/ymtype-4000.bin"
;	incbin "music/carpet-4000.bin"
;	incbin "music/demoisart-4000.bin"

               

