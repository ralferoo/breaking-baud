        read "symbols-32.asm"
;        read "symbols-fake.asm"

        org text_base
        
entrypoint:
        nop                     ;1      L0+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

;        ld hl,intvec_frame1     ;3      L0+16
;        ld (intvec_palette_vsync_ptr),hl ;5 L0+21

        ld hl,mainloop_text     ;3      L0+16
        ld (mainloop_patch),hl ;5 L0+21
        
        ld hl,#c000             ;3     L0+24
        ld (8),hl               ;5     L0+29

        defs line+1-29          ;       L1+ 1         
        nop                     ;1      L0+ 1      
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
 
        ld a,#ff                ;2      L0+15
        ld (10),a               ;4      L0+19

	defs line-2-19          ;       L1- 2
        jp mainloop_1           ;       L1+ 1

mainloop_text:
        nop                     ;1      L0+ 1      
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
        
next_text_ptr equ $+1
        ld hl,text_out_base     ;3      L0+16
        ld a,(hl)               ;2      L0+18
        or a                    ;1      L0+19
        jr nz, got_char_22      ;2/3    L0+21
        
	defs line-3-21          ;       L1- 3
        jp mainloop             ;       L1+ 0
                
got_char_22:
        inc hl                  ;2      L1+24
        ld (next_text_ptr),hl   ;5      L1+29
        ld h,0                  ;2      L1+31
        ld l,a                  ;1      L1+32

        defs line+1-32          ;       L1+ 1         
        nop                     ;1      L0+ 1      
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
 
        nop
        ld a,l                  ;1      L0+15     
        add a,a                 ;1      L0+16
        rl h                    ;2      L0+18
        add a,a                 ;1      L0+19
        rl h                    ;2      L0+21
        add a,a                 ;1      L0+22
        rl h                    ;2      L0+24
        add a,a                 ;1      L0+25
        rl h                    ;2      L0+27
        add a,a                 ;1      L0+28
        rl h                    ;2      L0+30
        ld l,a                  ;1      L0+31
                 
        defs line+1-31          ;       L1+ 1
        nop                     ;1      L0+ 1      
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
 
font_base_hi equ font_base / 256
 
        ld a,h                  ;1      L0+14
        add a,font_base_hi               ;2      L0+16
        ld h,a                  ;1      L0+18
                         
        defs line+1-18          ;       L1+ 1
        nop                     ;1      L0+ 1      
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
 
        ld de,(8)               ;6      L0+19
        ld a,(10)               ;4      L0+23
        ld c,a                  ;1      L0+24
        
        ld a,d                  ;1      L0+25      
        and #f7                 ;2      L0+27
        bit 3,d                 ;2      L0+29
        jr nz,overflow_scr      ;2/3    L0+31
        ld d,a                  ;1      L0+32    
overflow_scr:
                              
        defs line+1-31          ;       L1+ 1
        nop                     ;1      L0+ 1      
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        push de                 ;4      L0+17
        ld b,8                 ;2      L0+19
line_loop_19:        
        ld a,(hl)               ;2      L0+21
        and c                   ;1      L0+22
        ld (de),a               ;2      L0+24
        inc hl                  ;2      L0+26

        defs line+1-26          ;       L1+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
	
        inc de                  ;2      L0+15
        ld a,(hl)               ;2      L0+17
        and c                   ;1      L0+18
        ld (de),a               ;2      L0+20
        inc hl                  ;2      L0+22
        dec de                  ;2      L0+24
        defs 2                  ;       L0+26

        ld a,d                  ;1      L0+27
        add a,8                 ;2      L0+29
        ld d,a                  ;1      L0+30

        defs line+1-30          ;       L1+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        defs 2 ; inc de                  ;2      L0+15
        djnz line_loop_19       ;3/4    L0+18
        
        pop de                  ;3      L0+21
        push de                 ;4      L0+25

        defs line+1-25          ;       L1+ 1
        nop                     ;1      L0+ 1      
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
        
        ld a,c                  ;1      L0+14
        ld bc,80                ;3      L0+17
        ex de,hl                ;1      L0+18
        add hl,bc               ;3      L0+21
        ld c,a                  ;1      L0+22
        ex de,hl                ;1      L0+23
        ld b,8                  ;2      L0+25
        
line_loop_25:        
        ld a,(hl)               ;2      L0+27
        and c                   ;1      L0+28
        ld (de),a               ;2      L0+30
        inc hl                  ;2      L0+32

        defs line+1-32          ;       L1+ 1
        nop                     ;1      L0+ 1      
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        inc de                  ;2      L0+15
        ld a,(hl)               ;2      L0+17
        and c                   ;1      L0+18
        ld (de),a               ;2      L0+20
        inc hl                  ;2      L0+22
        dec de                  ;2      L0+24

        defs line+1-24          ;       L1+ 1
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13
	
        ld a,d                  ;1      L0+14
        add a,8                 ;2      L0+16
        ld d,a                  ;1      L0+17
        defs 21-17              ;       L0+21
        djnz line_loop_25       ;3/4    L0+24

        defs line+1-24          ;       L1+ 1
        nop                     ;1      L0+ 1      
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        
        pop de                  ;3      L0+15 
        inc de                  ;2      L0+17
        inc de                  ;2      L0+19
        ld (8),de               ;6      L0+25     ; update text pos       
        
	defs line-3-27          ;       L1- 3
        jp mainloop             ;       L1+ 0
                
              
         

;	defs line-3-17          ;       L1- 3
;mainloop_patch equ $+1
;        jp mainloop             ;       L1+ 0

