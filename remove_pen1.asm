        read "symbols-32.asm"
;        read "symbols-fake.asm"

        org applet_base
        
entrypoint:
        nop                     ;1      L0+ 1
trans_1:
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        ld hl,#6200             ;3      L0+16     ; note 1 less than screen
trans_16:
        ld a,l                  ;1      L0+17
        and #f                  ;2      L0+19
        ld b,a                  ;1      L0+20
        add a,a                 ;1      L0+21
        add a,a                 ;1      L0+22
        add a,a                 ;1      L0+23
        add a,a                 ;1      L0+24
        or b                    ;1      L0+25
        and l                   ;1      L0+26
        ld (hl),a               ;2      L0+28
        inc l                   ;1      L0+29
        jr z, done_trans_32     ;2/3    L0+31
        
        defs line+1-31

	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        jr trans_16             ;3      L0+16
        
done_trans_32:         
        defs line+1-32

	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        ex de,hl                ;1      L0+14     ; DE=trans
        ld hl,#c000             ;3      L0+17     ; HL=screen

fade_17:
        ld e,(hl)               ;2      L0+19  
        ld a,(de)               ;2      L0+21
        ld (hl),a               ;2      L0+23     ; remove pen 1
        inc l                   ;1      L0+24

        ld e,(hl)               ;2      L0+26  
        ld a,(de)               ;2      L0+28
        ld (hl),a               ;2      L0+30     ; remove pen 1

        defs line+1-30
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
	
        inc l                   ;1      L0+14
        jr nz, fade_17          ;2/3    L0+16     ; loop
        inc h                   ;1      L0+17
        
	defs line-2-17          ;       L1- 2
        jp z, mainloop_1        ;       L1+ 1

	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        nop                     ;1      L0+14
        jr fade_17              ;3      L0+17
          

