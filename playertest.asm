
;line equ 32

	run fake_entry

fake_entry:
	di
	ld a,#c3
	ld hl,intvec_dummy
	ld (#38),a
	ld (#39),hl
;	ld hl,#c9fb
;	ld (#38),hl
;	ei
;	halt

	ld hl,xnew_found_edge
	ld de,new_found_edge
	ld bc,#40
	ldir

	ld hl,#ABCD
	push hl
	pop af
	ex af,af'

        ld de, songdata
        call PLY_Init

	ld bc,#f5ef
	ld hl,#6263
	ld (hl),l
	ld de,0
	ld ix,#c000

	ei
	halt
	exx

xstart:	nop

	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	defs line-13
         
xmainloop:
	nop			;1	L1+ 1

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

        ld b,#f5		;2	L1+19
        in a,(c)		;4	L1+23
        rrca			;1	L1+24

	exx			;1	L1+25
	inc de			;2	L1+27
	exx			;1	L1+28

	defs line-3-28		;	L1- 3
        jp nc,xmainloop		;3	L1+ 0

;mainloop1:
;	ei
;        halt			


xhere:	di					;1	L1+ 1
	exx					;1	L1+ 2
	in a,(c)				;4	L1+ 6
	xor c					;1	L1+ 7     ; check for edge
	call m,new_found_edge			;3/5	L1+10	
	ld l,(hl)				;2	L1+12     ; update counter
	exx					;1	L1+13

	defs 27-13				;	L1+27
        call PLY_Play 				;5	L1+32 -> L1+24

	defs line-3-24				;	L1- 3
        jr xmainloop       			;	L1+ 0  

xnew_found_edge:	
				;	L0+12
        ld a,c                  ;1      L0+13
        xor #87                 ;2      L0+15 swap between #44/#4a (#22,#a5)
        ld c,a                  ;1      L0+16

	defs line+1-16          ;	L1+ 1
	in a,(c)		;4	L1+ 5 
	xor c			;1	L1+ 6	; check for edge
	ret p			;2/4	L1+ 8	; back at caller at 10
	nop            	        ;1	L1+ 9
	jr xnew_found_edge     	;3	L1+12
	ret


intvec_dummy:
	                        ;10     L0+23   ; interrupt takes 10us
	ld (ix+0),e		;5	L0+28
	ld (ix+1),d		;5	L0+33
;	inc ix			;3	L0+36
;	inc ix			;3	L0+39

	ld a,h
	cp #62
	jr nz,notokh
	ld a,l
	cp #63
	jr z,okh
notokh:	nop
okh:


	ld de,0			;3	L0+42
	defs line+12-42		;	L1+12
        ret                     ;3      L1+15	; back at caller at 15                        



	                        ;10     L0+23   ; interrupt takes 10us
        in a,(c)                ;4      L0+27
        rrca                    ;1      L0+28
        defs line-1-28          ;       L1- 1
;        jp c,intvec_palette_vsync_2 ;3    L1+ 2
	defs 3			;	L1+2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10                                                             
	ld l,(hl)		;2	L1+12   ; update counter
        ret                     ;3      L1+15	; back at caller at 15                        


	;org #1000
;	nolist
