        read "symbols-32.asm"
;        read "symbols-fake.asm"

        org applet_base
        
entrypoint:
        nop                     ;1      L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        ld bc,#bc01             ;3      L0+16
        out (c),c               ;4      L0+20
        ld bc,#bd28             ;3      L0+23     ; WIDTH=320
        out (c),c               ;4      L0+27

        defs line+1-27          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
        
        ld bc,#bc02             ;3      L0+16
        out (c),c               ;4      L0+20
        ld bc,#bd2e             ;3      L0+23
        out (c),c               ;4      L0+27     ; HSYNC for 320

        defs line+1-27          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        ld bc,#bc0c             ;3      L0+30
        out (c),c               ;4      L0+17
        ld bc,#bd30             ;3      L0+20
        out (c),c               ;4      L0+24     ; start address = #c000

        defs line+1-27          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
        
        ld bc,#bc0d             ;3      L0+30
        out (c),c               ;4      L0+17
        ld bc,#bd00             ;3      L0+20
        out (c),c               ;4      L0+24     ; start address = #c000

	defs line-2-24          ;       L1- 2
        jp mainloop_1           ;       L1+ 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
