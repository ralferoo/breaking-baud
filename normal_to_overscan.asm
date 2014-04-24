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

        ld hl,intvec_frame1     ;3      L0+16
        ld (intvec_palette_vsync_ptr),hl ;5 L0+21

	defs line-2-21          ;       L1- 2
        jp mainloop_1           ;       L1+ 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;intvec_palette_vsync_ptr equ $+1
;        jp intvec_palette_vsync_2 ;3    L1+ 2
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


intvec_frame1:
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        push bc                 ;4      L1+17
        ld bc,intvec_frame2     ;3      L1+20
        ld (intvec_palette_vsync_ptr),bc ;6      L1+26

        ld bc,#bc04             ;3      L1+29

        defs line+1-29          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
        
        out (c),c               ;4      L0+17
        ld bc,#bd22             ;3      L0+20
        out (c),c               ;4      L0+24     ; VTOT = normal - 4
        
        ld bc,#bc07             ;3      L0+27
        out (c),c               ;4      L0+31

        defs line+1-31          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
        
        ld bc,#bd7f             ;3      L0+16
        out (c),c               ;4      L0+20     ; VSYNC = off
        
        ld bc,#bc01             ;3      L0+23
        out (c),c               ;4      L0+27
        ld bc,#bd2e             ;3      L0+30     ; WIDTH=368

        defs line+1-30          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
        
        out (c),c               ;4      L0+17

        ld bc,#bc02             ;3      L0+20
        out (c),c               ;4      L0+24
        ld bc,#bd31             ;3      L0+27
        out (c),c               ;4      L0+31     ; HSYNC for 368

        defs line+1-31          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        ld bc,#bc06             ;3      L0+16
        out (c),c               ;4      L0+20
        ld bc,#bd20             ;3      L0+23
        out (c),c               ;4      L0+27     ; VIS for 256

        ld bc,#bc0c             ;3      L0+30

        defs line+1-30          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        out (c),c               ;4      L0+17
        ld bc,#bd2e             ;3      L0+20
        out (c),c               ;4      L0+24     ; start address = #8468+wrap

        ld bc,#bc0d             ;3      L0+27
        out (c),c               ;4      L0+31

        defs line+1-31          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
        
        ld bc,#bd34             ;3      L0+16
        out (c),c               ;4      L0+20     ; start address = #8468+wrap

        pop bc                  ;3      L0+23

        defs line-2-23          ;       L1- 2
        exx                     ;1      L1- 1
        jp intvec_palette_vsync_2 ;3    L1+ 2
                                             
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

intvec_frame2:
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        push bc                 ;4      L1+17
        ld bc,intvec_palette_vsync_2 ;3 L1+20
        ld (intvec_palette_vsync_ptr),bc ;6      L1+26

        ld bc,#bc04             ;3      L1+29

        defs line+1-29          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
        
        out (c),c               ;4      L0+17
        ld bc,#bd26             ;3      L0+20
        out (c),c               ;4      L0+24     ; VTOT = normal
        
        ld bc,#bc07             ;3      L0+27
        out (c),c               ;4      L0+31

        defs line+1-31          ;       L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
        
        ld bc,#bd22             ;3      L0+16
        out (c),c               ;4      L0+20     ; VSYNC = normal+4
        
        pop bc                  ;3      L0+23

        defs line-2-23          ;       L1- 2
        exx                     ;1      L1- 1
        jp intvec_palette_vsync_2 ;3    L1+ 2
                                                            
