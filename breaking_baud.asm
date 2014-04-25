;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; COMPRESSED TAPE LOADER
; (c) 2013-2014 Ranulf Doswell, cpc@ranulf.net
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FIRST_BLOCK equ #100

PILOT_COL_OK  equ #54
PILOT_COL_ERR equ #48
PILOT_COL_XOR equ PILOT_COL_OK xor PILOT_COL_ERR

line        equ 31
;line        equ 32
;line        equ 64

halfpulse   equ 3
halfpulse3  equ 9
halfpulse4  equ 12
halfpulse6  equ 18

errorsymbol  equ #f5

pilotlength  equ 32

stack_top equ #600

free_buffer equ #100 ; for list of things to decompress                                                              
                                                                                           
;new_table equ #200
new_table equ #203      ; #203-#900 or #200-#8fc                                                              
new_table_406 equ #200  ; #200-#c3f                                                        

player_base equ #1000
text_base   equ #2800
applet_base equ #3800
song_data   equ #4000
song2_data  equ #5000
font_base   equ #6000
text_out_base equ #7000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; memory map:
;
; 0000 - 0007 reset vector
; 0008 - 0009 current text address
; 000a        current text mask
; 000b        free
; 000c - 000e music transition info: addrlo,addrhi,addrcnt
; 000f        mode 0,1,2
; 0010 - 001f palette registers
; 0020 - 0037
; 0038 - 003f interrupt vector
; 0040 - 00af count table for normal data
; 00b0 - 00ff count table for sync pulse
; 0100 - 01ff decompression job table
; 0200 - 0541 symbol decode binary tree
; 0542 - 0551 AY buffer (15 bytes used)
; 0552 - 05ff stack space
; 0600 - 0fff code
; 1000 - 1fff music player code
; 2000 - 37ff code
; 3800 - 3fff applet
; 4000 - 7fff music player
; 8000 - bfff screen 2                                                                    
; c000 - ffff screen 1

; transition to:

; 2000 - 3fff music data + player
; 4000 - 7fff screen 3                                                                    
; 8000 - bfff screen 2                                                                    
; c000 - ffff screen 1
;
; note the 3 screen buffers are still not quite enough to hold 2 overscan
; screens:
; 384*272 => 2*#6600 = #cc00 bytes
; 384*256 => 2*#6000 = #c000 bytes

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; data addresses

music_change_addrlo equ 12
music_change_addrhi equ 13
music_change_count  equ 14
screen_mode equ 15
palette     equ 16

;ay_tones_out equ #600
;ay_tones_end equ #1b00
;;ay_tones_end equ #4000
;
;;ay_tones_end_check equ #c00e ;ffff-1000+sizeof(AY)
;ay_tones_end_check equ #e-ay_tones_end ;ffff-1000+sizeof(AY)
ay_tones_end_check_fake equ #ffff

ay_tones_out equ #542
ay_tones_end equ #550
ay_tones_end_check equ ay_tones_end_check_fake



spare       equ 32  ; to #38                                                             
                                                                    
count_table_ofs_start equ #40
count_table_ofs_sync  equ #b0

count_table equ #000			 ; now auto generated
count_table_start equ count_table+count_table_ofs_start	
count_table_sync  equ count_table+count_table_ofs_sync	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	org #600
        jp program_start

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This function is called by the main program whenever an edge is detected.
; The main function is expected to look something like this:
;
;	exx			;1	L0+ 1                           
;	ex af,af'		;1	L0+ 2
;	in a,(c)		;4	L0+ 6
;	xor c			;1	L0+ 7     ; check for edge
;	call m,new_found_edge	;3/5	L0+10
;	
;	ld l,(hl)		;2	L0+12     ; update counter
;	ex af,af'		;1	L0+13
;	exx			;1	L0+14
;	defs line-(16+3)
;	jp mainloop		;3	L0+17
;
; Here, "line" is defined as 64 for debugging or 31 for the final configuration
; and determines the fundamental baud rate of the loader. Each symbol nominally
; takes 16*6 lines to transfer and would call into this function up to 32 times.
;
; This function is designed so that for the first pulse in a pair of pulses
; it returns at the same time in the next line. The processing for a second
; pulse is a bit more involved and may take several lines.
;
; The upshot of this is that the "ld l,(hl)" executed after the call is always
; run at 10 cycles after the start of this code block and the defs always
; occur at 16 cycles after the start of the block. You could nominally consider
; the block to start at e.g. line-17 so that your calculations can start at 0.
;
; Because we're only sampling every line, we could miss a sample by being 1us
; early and the next by being 1us late, so a pulse could be misdetected by
; +-2 lines. To combat this, we allow a margin either side. Because we've
; chosen nominal pulse lengths of 2*3 and 2*3*3, so 6 and 18 lines for a double
; pulse, we can afford a 50% margin for tape speed variability in the worst
; case. This corresponds to 3-6-9, 9-18-27. This in turn allows us some
; flexibility in increasing the speed.
;
; One nice upshot of this though, is that although the 2nd pulse processing
; can take longer, as long as it has returned before the 2nd line, it can
; take 2 samples before the worst case 3rd line and so we can still detect the
; shortest pulse we're allowing.
;
; One final note is that you shouldn't rely on this routine always returning
; after line cycles. If a sync error is detected, this routine may well exit
; at any cycle position.
;
; It assumed you are using the alternate set of registers. BC,DE,HL all hold
; tape state that must be preserved. IY holds the handler for the next input
; symbol. AF will be trashed but does not need to be preserved and will usually
; be used by the caller as a scratch for the INP(#F5xx). Your main loop can
; save 2us if it doesn't need to save AF...
;
; One final note, when a user code block is executed, it will be at time 0
; in terms of this counting system as it is executed like this:
;        jp (hl)                 ;1      L0+ 0     ; event type 0 = execute next addr
; By the time the code is executed, we may be reading a new data block, so please
; start with the code block above and check tape data regularly...
; You should jump back to mainloop or mainloop_1 depending on preference when
; you are done.
;
; HL=count_table pointer
;  B=#F5 for IO port, also used as symbol base
;  C=border colour>>1, so high bit is current edge
; IY=symbol handler
; CF clear		    
;  A=trashed

; DE=current symbol lookup ptr (data), E=edge counter (sync)

; ENTRY POINT:
       
new_found_edge:
				;	L0+12
        ld a,c                  ;1      L0+13
        xor #87                 ;2      L0+15 swap between #44/#4a (#22,#a5)
        ld c,a                  ;1      L0+16
        add a,a                 ;1      L0+17   ; colours: pre-pilot 2a/ad, pilot 2a/ac, data 22/a5               

	ld b,#7f		;2	L0+19	       
	out (c),a		;4	L0+23	; change border colour (~L0+19)
	ld b,#f5		;2	L0+25
	
	inc l			;1	L0+26	; move to transition table
	ld a,(hl)		;2	L0+28	; peek at next value
	sub b			;1	L0+29	; symbols start at F5 :)
	jr c,not_a_symbol	;2/3	L0+31

	defs line+0-31		;	L1+ 0
	ld pc,iy ; jp (iy)	;2	L1+ 2	; jump to symbol handler
            
not_a_symbol:
                                ;	L0+32
	defs line+1-32          ;	L1+ 1
	in a,(c)		;4	L1+ 5 
	xor c			;1	L1+ 6	; check for edge
	ret p			;2/4	L1+ 8	; back at caller at 10
	nop            	        ;1	L1+ 9
	jr new_found_edge     	;3	L1+12

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; The following handlers deal with identifying the pilot tone and header
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; start_sync_handler initialises the system for searching for a sync pulse

start_sync_handler equ start_sync_handler_2

start_sync_handler_28:
        nop                      
start_sync_handler_29:        
        defs line+2-29          ;	L1+ 2
start_sync_handler_2:
        defs 5-2                ;	L1+ 5
start_sync_handler_5:
        defs 8-5                ;	L1+ 8
start_sync_handler_8:
        defs 9-8               ;	L1+ 9
start_sync_handler_9:
        defs 11-9               ;	L1+11
start_sync_handler_11:
        defs 13-11               ;	L1+13
start_sync_handler_13:
        defs 14-13              ;	L1+14
start_sync_handler_14:
        defs 15-14              ;	L1+15
start_sync_handler_15:
        defs 17-15              ;	L1+17
start_sync_handler_17:
        defs 22-17              ;	L1+22
start_sync_handler_22:
                                ;	L1+22
        rl c                    ;2      L1+24    ; current pulse to CF
pilot_colour equ $+1
        ld c,PILOT_COL_OK       ;2      L1+26    ; black/green
        rr c                    ;2      L1+28    ; shift back
        ld hl,count_table_sync  ;3      L1+31    ; sync section pulse table 
        defs line-31
                                ;	L2+ 0
        ld de,pilotlength       ;3      L2+ 3
        ld iy,find_sync_handler ;4      L2+ 7    ; default symbol handler
	ret			;3	L2+10

; find_sync_handler counts down e (number of expected pilot pulses) and when
; it finds the "end pilot" pulse and e==0 then we transition into the proper
; loader handler 

find_sync_handler:
                                ;	L1+ 2
        jr z, start_sync_handler_5 ;2/3 L1+ 4                        
        dec a                   ;1      L1+ 5
        jr z, check_pilot_end   ;2/3    L1+ 7

        bit 7,d                 ;2      L1+ 9
        jr nz, done_pilot       ;2/3    L1+11
        jr still_in_pilot       ;3      L1+14

done_pilot:                     ;	L1+12
        res 0,c                 ;2      L1+14    ; green/bright green

still_in_pilot:                 ;	L1+14

        ld hl,#0101             ;3      L1+17
        ld (current_crc),hl     ;5      L1+22                        

        defs line+2-22          ;	L2+ 2
        dec de                  ;2      L2+ 4   ; decrease pilot count
        ld hl,count_table_ofs_sync ;3   L2+ 7   ; sync section pulse table 

	ret			;3	L2+10
        
check_pilot_end:
                                ;	L1+ 8
        bit 7,d                 ;2      L1+10
        jp z, start_sync_handler_13 ;3  L1+13                
        
        ld hl,check_sync_byte1  ;3      L1+16
        ld (head_finished),hl   ;5      L1+21    

        ld hl,count_table_ofs_start ;3  L1+24    ; data section pulse table 
        ld de,new_table         ;3      L1+27    ; pulse to symbol table
        ld iy,head_byte_handler ;4      L1+31    ; default symbol handler

        defs line+1-31
	in a,(c)		;4	L2+ 5 
	xor c			;1	L2+ 6	; check for edge
	ret p			;2/4	L2+ 8	; back at caller at 10
	nop                     ;1      L2+ 9
	jp new_found_edge      	;3	L2+12
       
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_sync_byte1:               ;       L2+ 8
        ld a,e                  ;1      L2+ 9
        ld (found_sync1),a      ;4      L2+13                        
        call continue_header_18 ;5      L2+18

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_sync_byte2:               ;       L2+ 8
        ld a,e                  ;1      L2+ 9
        ld (found_sync2),a      ;4      L2+13                        
        call continue_header_18 ;5      L2+18

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_addr_lo:                  ;       L2+ 8
        ld xl,e                 ;2      L2+10                        
        defs 13-10              ;       L2+13                                            
        call continue_header_18 ;5      L2+18

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_addr_hi:                  ;       L2+ 8
        ld xh,e                 ;2      L2+10                        
        defs 13-10              ;       L2+13                                            
        call continue_header_18 ;5      L2+18

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_len_lo:                   ;       L2+ 8
        ld a,e                  ;1      L2+ 9
        ld (remaining_length),a ;4      L2+13                        
        call continue_header_18 ;5      L2+18

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_len_hi:                   ;       L2+ 8
        ld a,e                  ;1      L2+ 9
        ld (remaining_length+1),a ;4    L2+13                        
        call continue_header_18 ;5      L2+18

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_crc_byte1:                ;       L2+ 8
        defs 13-8               ;       L2+13                                            
        call continue_header_18 ;5      L2+18

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_crc_byte2:                ;       L2+ 8
        ld a,l                  ;1      L2+ 9
        and h                   ;1      L2+10    ; A=0xff if correct sync
        inc a                   ;1      L2+11    ; A=0 if correct sync                                                                  
        jp nz, start_sync_handler_14 ;3 L2+14    ; sync error                                                                                                                                                        

        ld iy,data_byte_handler ;4      L2+18    ; default symbol handler

        ld hl,count_table_ofs_start ;3  L2+21    ; data section pulse table 
        ld de,new_table         ;3      L2+24    ; pulse to symbol table

        ; we've read a header successfully, make sure it's the block we're
        ; expecting...

        exx                     ;1      L2+25
        push hl                 ;4      L2+29
found_sync1 equ $+2
found_sync2 equ $+1
        ld hl,0                 ;3      L2+32

        defs line+1-32          ;       L3+ 1
        exx                     ;1      L3+ 2
	in a,(c)		;4	L3+ 6
	xor c			;1	L3+ 7     ; check for edge
	call m,new_found_edge	;3/5	L3+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L3+12     ; update counter
        exx                     ;1      L3+13     

        push de                 ;4      L3+17
next_sync equ $+1
        ld de,FIRST_BLOCK       ;3      L3+20     ; note carry clear from xor in tape check
        sbc hl,de               ;4      L3+24     ; check for next block
        jr nz,not_correct_block_27 ;2/3 L3+26     ; WATCH_TAPE_TEST                      

        exx                     ;1      L3+27
        rl c                    ;2      L3+29    ; current pulse to CF
        ld c,#44                ;2      L3+31    ; blue/yellow
;        ld c,0 ; no border 
        rr c                    ;2      L3+33    ; shift back
        
        defs line+2-33          ;       L4+ 1
	in a,(c)		;4	L4+ 6
	xor c			;1	L4+ 7     ; check for edge
	call m,new_found_edge	;3/5	L4+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L4+12     ; update counter
        exx                     ;1      L4+13     

        ld hl,(remaining_length) ;5     L4+18
        ld a,h                  ;1      L4+19
        or l                    ;1      L4+20     ; check if length == 0 -> jump to (ix)
        jp z,empty_block_jp_23  ;3      L4+23     
        pop de                  ;3      L4+26
        pop hl                  ;3      L4+29

        exx                     ;1      L4+30                                                                  

        defs line+1-30
	in a,(c)		;4	L5+ 5 
	xor c			;1	L5+ 6	; check for edge
	ret p			;2/4	L5+ 8	; back at caller at 10
	nop                     ;1      L5+ 9
	jp new_found_edge      	;3	L5+12

not_correct_block_27:
; carry set   if behind   desired position -> FF
; carry clear if ahead of desired position -> RW

        sbc a,a                 ;1      L0+28
        and PILOT_COL_XOR       ;2      L0+30
        xor PILOT_COL_ERR       ;2      L0+32
        defs line+1-32          ;       L1+ 1
        ld (pilot_colour),a     ;4      L1+ 5                                       

        pop de                  ;3      L1+ 8
        pop hl                  ;3      L1+11
        exx                     ;1      L1+12
        jp start_sync_handler_15 ;      L1+15

empty_block_jp_23:
        ld a,(next_sync+1)      ;4      L4+27  ; current block high
        inc a                   ;1      L4+28  ; L=0 already
        ld h,a                  ;1      L4+29  ; HL=next block ID
        ld (next_sync),hl       ;5      L4+34

        defs line+3-34          ;       L5+ 3
        
        ld d,xh                 ;2      L5+ 5
        ld e,xl                 ;2      L5+ 7        
        
        ld a,d                  ;1      L5+ 8 
        or e                    ;1      L5+ 9  ; check if exec address set
        jr z, not_exec_12       ;2/3    L5+11
        
        ; if we have an exec address, put it on the decompress event queue
        ; so it gets run after any decompression that is needed
        
        ld hl,(patchup_write_ptr) ;5    L5+16  ; get patchup write address
        xor a                   ;1      L5+17

        ld (hl),a               ;2      L5+19
        inc l                   ;1      L5+20  ; event     
        
        ld (hl),a               ;2      L5+22
        inc l                   ;1      L5+23  ; JUMP     
                
        ld (hl),e               ;2      L5+25
        inc l                   ;1      L5+26  ; addrlo     
        
        ld (hl),d               ;2      L5+28
        inc l                   ;1      L5+29  ; addrhi     
        
        ld (patchup_write_ptr),hl ;5    L5+34  ; save write addr

        defs line+12-34         ;       L6+12
not_exec_12:

        ld a, PILOT_COL_OK      ;2      L6+14
        ld (pilot_colour),a     ;4      L6+18
            
;        sbc a,a                 ;1      L0+29
;        and (PILOT_COL_OK xor PILOT_COL_ERR) ;2 L0+31
;        xor PILOT_COL_OK        ;2      L0+33                                       
;
;pilot_colour equ $+1
;PILOT_COL_OK  equ #54
;PILOT_COL_ERR equ #48

        pop de                  ;3      L6+21
        pop hl                  ;3      L6+24
        exx                     ;1      L6+25             
        jp start_sync_handler_28 ;      L6+28

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;

; continue_header - used to read another byte from the header  

start_header_14:                ;       L2+14
        ld iy,head_byte_handler ;4      L2+18
  
continue_header_18:             ;       L2+18
        pop hl                  ;3      L2+21              
continue_header_hl_21:          ;       L2+21
        ld (head_finished),hl   ;5      L2+26    

        ld hl,count_table_ofs_start ;3  L2+29    ; data section pulse table 
        ld de,new_table         ;3      L2+32    ; pulse to symbol table

        defs line+1-32
	in a,(c)		;4	L3+ 5 
	xor c			;1	L3+ 6	; check for edge
	ret p			;2/4	L3+ 8	; back at caller at 10
	nop                     ;1      L3+ 9
	jp new_found_edge      	;3	L3+12


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; The following handlers deal with transferring data
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; data_byte_handler is used for normal data within a block

data_byte_handler:
                                ;	L1+ 2
        jr z, start_sync_handler_5b ;3  L1+ 4                        

        dec a                   ;1      L1+ 5
        ex de,hl                ;1      L1+ 6
        ld a,(hl)               ;2      L1+ 8
        jr z,data_byte_left     ;2/3    L1+10
        inc l                   ;1      L1+11

        inc l                   ;1      L1+12
        ld e,(hl)               ;2      L1+14
        and #f                  ;2      L1+16
        jr z,data_byte_simple   ;2/3    L1+18
        
        nop                     ;1      L1+19
        jr data_byte_complex    ;3      L1+22
        
start_sync_handler_5b:
        jp start_sync_handler_8 ;3
                              
data_byte_left:                 ;       L1+11
        inc l                   ;1      L1+12
        ld e,(hl)               ;2      L1+14
        and #f0                 ;2      L1+16
        jr z,data_byte_simple   ;2/3    L1+18

        rrca                    ;1      L1+19
        rrca                    ;1      L1+20
        rrca                    ;1      L1+21
        rrca                    ;1      L1+22
                                        
data_byte_complex:              ;       L1+22   ; symbol >= 0x100                        
        ld d,a                  ;1      L1+23         
        and #e                  ;2      L1+25
        jp z, data_byte_extend  ;2/3    L1+28
        ld hl,count_table_start ;3      L1+31

        defs line+1-31          ;       L2+ 1
	in a,(c)		;4	L2+ 5 
	xor c			;1	L2+ 6	; check for edge
	ret p			;2/4	L2+ 8	; back at caller at 10
	nop                     ;1      L2+ 9
	jp new_found_edge      	;3	L2+12
        
data_byte_simple:               ;       L1+19   ; symbol < 0x100
        ld (ix+0),e             ;5      L1+24

        ld a,e                  ;1      L1+25
current_crc equ $+1
        ld hl,#ffff             ;3      L1+28
        add a,l                 ;1      L2+29
        adc a,d                 ;1      L2+30
        defs line-1-30          ;       L2- 1
        ld l,a                  ;1      L2+ 0
        add a,h                 ;1      L2+ 1
        adc a,d                 ;1      L2+ 2
        ld h,a                  ;1      L2+ 3   ; HL = updated CRC
        ld (current_crc),hl     ;5      L2+ 8
                                
remaining_length equ $+1
        ld hl,#ffff             ;3      L2+11        
        dec hl                  ;2      L2+13
        ld (remaining_length),hl ;5     L2+18

        ld a,h                  ;1      L2+19
        or l                    ;1      L2+20                                        
        jr z, data_byte_block_end ;2/3  L2+22

        inc ix                  ;3      L1+25

        ld hl,count_table_start+3 ;3    L2+28
        ld de,new_table         ;3      L2+31
        defs line+1-31          ;       L3+ 1

	in a,(c)		;4	L3+ 5 
	xor c			;1	L3+ 6	; check for edge
	ret p			;2/4	L3+ 8	; back at caller at 10
	nop                     ;1      L3+ 9
	jp new_found_edge      	;3	L3+12

;data_byte_block_end:            ;       L2+22
;        ld iy, block_end_handler ;4     L2+26      
;        ld hl,count_table_start+3 ;3    L2+29
;        defs line+1-29          ;       L3+ 1
;
;	in a,(c)		;4	L3+ 5 
;	xor c			;1	L3+ 6	; check for edge
;	ret p			;2/4	L3+ 8	; back at caller at 10
;	nop                     ;1      L3+ 9
;	jp new_found_edge      	;3	L3+12

data_byte_block_end:            ;       L2+23
        ld hl,count_table_start+3 ;3    L2+26
        ld de,new_table          ;3     L2+29
        ld iy, head_byte_handler ;4     L2+33

        defs line+2-33          ;       L3+ 2
	in a,(c)		;4	L3+ 6
	xor c			;1	L3+ 7     ; check for edge
	call m,new_found_edge	;3/5	L3+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L3+12     ; update counter

        push hl                 ;4      L3+16
        ld hl,check_footer      ;3      L2+19
        ld (head_finished),hl   ;5      L2+24
        pop hl                  ;3      L2+27    
        
        defs line+1-27          ;       L3+ 1
	in a,(c)		;4	L3+ 5 
	xor c			;1	L3+ 6	; check for edge
	ret p			;2/4	L3+ 8	; back at caller at 10
	nop                     ;1      L3+ 9
	jp new_found_edge      	;3	L3+12

check_footer:                   ;       L2+ 8
        defs 13-8               ;       L2+13                                            
        call continue_header_18 ;5      L2+18

check_footer_byte2:             ;       L2+ 8
        ld a,l                  ;1      L2+ 9
        and h                   ;1      L2+10    ; A=0xff if correct sync
        inc a                   ;1      L2+11    ; A=0 if correct sync
        jp nz, start_sync_handler_14 ;3 L2+14    ; sync error                                                                                                                                                        

        ld hl,(next_sync)       ;5      L2+19
        inc hl                  ;2      L2+21    ; set the next block sync so we
        ld (next_sync),hl       ;5      L2+26    ; start loading of next block
        jp start_sync_handler_29 ;3     L2+29         

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; data_byte_extend handles the special symbols, 256-276

data_byte_extend:               ;       L1+28   ; symbol < 0x200
        defs line-3-28          ;       L2- 3

; A=0, D=1, E=low byte, no carry

        ld hl,(current_crc)     ;5      L2+ 2
        ld a,e                  ;1      L2+ 3
        add a,d                 ;1      L2+ 4
        dec d                   ;1      L2+ 5   ; restore D=0  
        adc a,l                 ;1      L2+ 6   ; note should add extra 1 for hi-bit
        adc a,d                 ;1      L2+ 7
        ld l,a                  ;1      L2+ 8
        add a,h                 ;1      L2+ 9
        adc a,d                 ;1      L2+10
        ld h,a                  ;1      L2+11   ; HL = updated CRC
        ld (current_crc),hl     ;5      L2+16

        ld hl,count_table_start+3 ;3    L2+19   ; pulse translations 
        ld a,e                  ;1      L2+20
        rra                     ;1      L2+21   ; carry clear, so shift right
        jr nc, extend_implicit  ;2/3    L2+23   ; odds are remapped 272-276

        defs line-8-23          ;       L3- 8

extend_explicit_rle_or_skip:    ;       L3- 8
        rrca                    ;1      L3- 7
        jr c, extend_rle_or_skip ;2/3   L3- 5

rpt_ofs8_ofs16:                 ;       L3- 5
        rrca                    ;1      L3- 4
        jr c, rpt_ofs16         ;2/3    L3- 2
        and a                   ;1      L3- 1                        
        jp z, rpt_ofs8          ;3      L3+ 2

extend_skip16:                  ;       L3+ 2
	in a,(c)		;4	L3+ 6
	xor c			;1	L3+ 7     ; check for edge
	call m,new_found_edge	;3/5	L3+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L3+12     ; update counter

        ld de, continue_skip16  ;3      L3+15
        jr store_extend_cont    ;3      L3+18 

;        defs 5-2                ;       L3- 2                                
;        rrca                    ;1      L3- 1
;        jp c, rpt_ofs16         ;3      L3+ 2                        
        
rpt_ofs8:                       ;       L3+ 2
	in a,(c)		;4	L3+ 6
	xor c			;1	L3+ 7     ; check for edge
	call m,new_found_edge	;3/5	L3+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L3+12     ; update counter

        ld de, continue_rpt_ofs8 ;3     L3+15
        jr store_extend_cont    ;3      L3+18 
        
rpt_ofs16:                      ;       L3- 1
        defs 2+1                ;       L3+ 2                        
	in a,(c)		;4	L3+ 6
	xor c			;1	L3+ 7     ; check for edge
	call m,new_found_edge	;3/5	L3+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L3+12     ; update counter

        ld de, continue_rpt_ofs16 ;3    L3+15
        jr store_extend_cont    ;3      L3+18 
        
extend_rle_or_skip:             ;       L3- 4
        defs 4-2                ;       L3- 2                                
        rrca                    ;1      L3- 1
        jp c, extend_skip       ;3      L3+ 2                        
                                
extend_rle:                     ;       L3+ 2
	in a,(c)		;4	L3+ 6
	xor c			;1	L3+ 7     ; check for edge
	call m,new_found_edge	;3/5	L3+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L3+12     ; update counter

        ld de, continue_rle8    ;3      L3+15
        jr store_extend_cont    ;3      L3+18 

extend_skip:                    ;       L3+ 2
	in a,(c)		;4	L3+ 6
	xor c			;1	L3+ 7     ; check for edge
	call m,new_found_edge	;3/5	L3+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L3+12     ; update counter

        ld de, continue_skip    ;3      L3+15
        jr store_extend_cont    ;3      L3+18 

extend_implicit:                ;       L2+24        
        rra                     ;1      L2+25   ; carry for ofs16, nc for ofs8  
        ld (ix+0),a             ;5      L2+30   ; store implicit length                                
        defs line-1-30          ;       L3- 1                                
        jp c, extend_imp_ofs16  ;3      L3+ 2

extend_imp_ofs8:                ;       L3+ 2  
	in a,(c)		;4	L3+ 6
	xor c			;1	L3+ 7     ; check for edge
	call m,new_found_edge	;3/5	L3+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L3+12     ; update counter

        ld de, continue_ofs8    ;3      L3+15
        jr store_extend_cont    ;3      L3+18 

extend_imp_ofs16:               ;       L3+ 2  
	in a,(c)		;4	L3+ 6
	xor c			;1	L3+ 7     ; check for edge
	call m,new_found_edge	;3/5	L3+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L3+12     ; update counter

        ld de, continue_ofs16   ;3      L3+15
        jr store_extend_cont    ;3      L3+18 

store_extend_cont:              ;       L3+18
        ld iy,head_byte_handler ;4      L3+22     ; default symbol handler
        ld (head_finished),de   ;6      L3+28    
        ld de,new_table         ;3      L0+31
        defs line+1-31          ;       L1+ 1
        
	in a,(c)		;4	L1+ 5 
	xor c			;1	L1+ 6	; check for edge
	ret p			;2/4	L1+ 8	; back at caller at 10
	nop                     ;1      L1+ 9
	jp new_found_edge      	;3	L1+12

continue_skip16:                ;       L2+ 8
        ld a,e                  ;1      L2+ 9
        ld (continue_skip16_lo),a ;4    L2+13                                
        call continue_header_18 ;5      L2+18

continue_skip16hi:              ;       L2+ 8
        ld a,e                  ;       L2+ 9                        
        ld hl,count_table_ofs_start ;3  L2+12    ; data section pulse table 
        ld de,new_table         ;3      L2+15    ; pulse to symbol table

        ld iy,data_byte_handler ;4      L0+19   ; default symbol handler
        exx                     ;1      L0+20
        push de                 ;4      L0+24
        ld d,a                  ;1      L0+25
        push hl                 ;4      L0+29
continue_skip16_lo equ $+1
        ld e,0                  ;2      L0+31                   

        defs line+1-31          ;       L0+ 1
        exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
        exx                     ;1      L0+13     
        
        ld hl,(remaining_length) ;5     L0+18     ; remaining lenth
        sbc hl,de                ;4     L0+22     ; carry was clear
        ld (remaining_length),hl ;5     L0+27     ; save length
        defs line-4-27           ;      L1- 4

        jr c, long_skip_error    ;2/3   L1- 2
        jp z, extend_done        ;3     L1+ 1

        exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
        exx                     ;1      L0+13     

        add ix,de               ;4      L0+17     ; update write ptr

        inc h                   ;1      L0+18     ; check if we overran
        pop hl                  ;3      L1+21
        pop de                  ;3      L1+24
        exx                     ;1      L1+25
        jp z, start_sync_handler_28 ;3  L1+28     ; overran
        
        defs line+1-28          ;       L3+ 1
	in a,(c)		;4	L3+ 5 
	xor c			;1	L3+ 6	; check for edge
	ret p			;2/4	L3+ 8	; back at caller at 10
	nop                     ;1      L3+ 9
	jp new_found_edge      	;3	L3+12

long_skip_error:                ;       L1- 1
        pop hl                  ;3      L1+ 2
        pop de                  ;3      L1+ 5
        exx                     ;1      L1+ 6
        jp start_sync_handler_9 ;3      L1+ 9 
    
continue_skip:                  ;       L2+ 8
        ld a,e                  ;       L2+ 9                        
        ld hl,count_table_ofs_start ;3  L2+12    ; data section pulse table 
        ld de,new_table         ;3      L2+15    ; pulse to symbol table

        ld iy,data_byte_handler ;4      L0+19   ; default symbol handler
        exx                     ;1      L0+20
        push de                 ;4      L0+24
        ld e,a                  ;1      L0+25
        push hl                 ;4      L0+29
        jp skip_update_write_ptr_32 ;3  L0+32

continue_rpt_ofs8:              ;       L2+ 8
        ld (ix+0),e             ;5      L2+13  ; rpt
        call continue_header_18 ;5      L2+18

continue_ofs8:                  ;       L2+ 8
        ld (ix+1),e             ;5      L2+13  ; ofs8 lo
        ld (ix+2),#ff           ;6      L2+19  ; ofs8 hi
        defs 22-19              ;       L2+22
        jr extend_restart_25    ;       L2+25

continue_rpt_ofs16:             ;       L2+ 8
        ld (ix+0),e             ;5      L2+13  ; rpt
        call continue_header_18 ;5      L2+18

continue_ofs16:                 ;       L2+ 8
        ld (ix+1),e             ;5      L2+13  ; ofs16 lo
        call continue_header_18 ;5      L2+18

        ld (ix+2),e             ;5      L2+13  ; ofs16 hi
        defs 22-13              ;       L2+22
        jr extend_restart_25    ;       L2+25

continue_rle8:                  ;       L2+ 8
        ld (ix+0),e             ;5      L2+13  ; rpt
        ld (ix+1),#ff           ;6      L2+19  ; -1 hi
        ld (ix+2),#ff           ;6      L2+25  ; -1 hi

extend_restart_25:              ;       L2+25                    
        ld hl,count_table_ofs_start ;3  L2+28    ; data section pulse table 
        ld de,new_table         ;3      L2+31    ; pulse to symbol table

        defs line+2-31          ;       L0+ 2                                
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter

        ld a,(ix+0)             ;5      L0+17    ; get the length
        defs 18-17              ;       L0+18                    
        
extend_add_ix_a_18:             ;       L0+18
        ld iy,data_byte_handler ;4      L0+22    ; default symbol handler
        exx                     ;1      L0+23
        push de                 ;4      L0+27
        ld e,a                  ;1      L0+28
        push hl                 ;4      L0+32
        defs line+1-32          ;       L1+ 1
        
	exx                     ;1      L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L1+12     ; update counter
	exx                     ;1      L1+13

patchup_write_ptr equ $+1
        ld hl, free_buffer      ;3      L0+16         
        ld d,xl                 ;2      L0+18
        ld (hl),d               ;2      L0+20
        inc l                   ;1      L0+21
        ld d,xh                 ;2      L0+23     ; DE=old ix
        ld (hl),d               ;2      L0+25
        nop
        inc l                   ;2      L0+27     ; write buffer address to rolling buffer
        ld (patchup_write_ptr),hl ;5    L0+32     ; this needs to stay atomic!

skip_update_write_ptr_32:
        defs line+1-32          ;       L0+ 1
        exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
        exx                     ;1      L0+13     
        
        ld d,0                  ;2      L0+15     ; DE=new length
;skip_update_write_ptr_15:
        ld hl,(remaining_length) ;5     L0+20     ; remaining lenth
        sbc hl,de                ;4     L0+24     ; carry was clear
        ld (remaining_length),hl ;5     L0+29     ; save length
        defs line-2-29           ;      L0- 2
        jp z, extend_done        ;3     L0+ 1

        exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
        exx                     ;1      L0+13     

        add ix,de               ;4      L0+17     ; update write ptr

        inc h                   ;1      L0+18     ; check if we overran
        pop hl                  ;3      L1+21
        pop de                  ;3      L1+24
        exx                     ;1      L1+25
        jp z, start_sync_handler_28 ;3  L1+28     ; overran
        
        defs line+1-28          ;       L3+ 1
	in a,(c)		;4	L3+ 5 
	xor c			;1	L3+ 6	; check for edge
	ret p			;2/4	L3+ 8	; back at caller at 10
	nop                     ;1      L3+ 9
	jp new_found_edge      	;3	L3+12

extend_done_m1:                 ;       L0- 1
        defs 1+1                ;       L0+ 1
         
extend_done:                    ;       L0+ 1
        exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
        exx                     ;1      L0+13     

        ld iy, head_byte_handler ;4     L2+17
        ld hl,check_footer      ;3      L2+20
        ld (head_finished),hl   ;5      L2+25    
        pop hl                  ;3      L2+28
        pop de                  ;3      L2+31
        exx                     ;1      L2+32      
        
        defs line+1-32          ;       L3+ 1
	in a,(c)		;4	L3+ 5 
	xor c			;1	L3+ 6	; check for edge
	ret p			;2/4	L3+ 8	; back at caller at 10
	nop                     ;1      L3+ 9
	jp new_found_edge      	;3	L3+12


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; head_byte_handler is used for special data, such as headers or rpt/ofs data
; only 8 bit data is allowed

head_byte_handler:
                                ;	L1+ 2
        jr z, start_sync_handler_5a ;3   L1+ 4                        

        dec a                   ;1      L1+ 5
        ex de,hl                ;1      L1+ 6
        ld a,(hl)               ;2      L1+ 8
        jr z,head_byte_left     ;2/3    L1+10
        inc l                   ;1      L1+11

        inc l                   ;1      L1+12
        ld e,(hl)               ;2      L1+14
        and #f                  ;2      L1+16
        jr z,head_byte_simple   ;2/3    L1+18
        
        nop                     ;1      L1+19
        jr head_byte_complex    ;3      L1+22

start_sync_handler_5a:
        jp start_sync_handler_8 ;3
                              
head_byte_left:                 ;       L1+11
        inc l                   ;1      L1+12
        ld e,(hl)               ;2      L1+14
        and #f0                 ;2      L1+16
        jr z,head_byte_simple   ;2/3    L1+18

        rrca                    ;1      L1+19
        rrca                    ;1      L1+20
        rrca                    ;1      L1+21
        rrca                    ;1      L1+22
                                        
head_byte_complex:              ;       L1+22   ; symbol >= 0x100                        
        ld d,a                  ;1      L1+23         
        and #e                  ;2      L1+25
        jp z, head_byte_extend  ;2/3    L1+28
        ld hl,count_table_start ;3      L1+31

        defs line+1-31          ;       L2+ 1
	in a,(c)		;4	L2+ 5 
	xor c			;1	L2+ 6	; check for edge
	ret p			;2/4	L2+ 8	; back at caller at 10
	nop                     ;1      L2+ 9
	jp new_found_edge      	;3	L2+12
        
head_byte_simple:               ;       L1+19   ; symbol < 0x100
        ld hl,(current_crc)     ;5      L1+24
        ld a,e                  ;1      L1+25
        add a,l                 ;1      L1+26
        adc a,d                 ;1      L1+27
        ld l,a                  ;1      L1+28
        add a,h                 ;1      L1+29
        adc a,d                 ;1      L1+30
        ld h,a                  ;1      L1+31   ; HL = updated CRC
        defs line-31            ;       L2+ 0
        ld (current_crc),hl     ;5      L2+ 5

head_finished equ $+1
        jp start_sync_handler   ;3      L2+ 8   ; finished, jump to next part

head_byte_extend:               ;       L1+28   ; symbol < 0x200
        defs line-1-28          ;       L2- 1
        jp start_sync_handler_2 ;       L2+ 2   ; should never be present
                                                                
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; colours: pre-pilot 2a/ad, pilot 2a/ac, data 22/a5

; 40 orange/grey             
; 42 bright green/red        header
; 44 blue/yellow             loading
; 46 pink/grey

; 50 blue/dark yellow
; 52 bright green/red
; 54 bright green/black      searching
; 56 purple/green

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


mainloop:                       ;       L0+ 0
	ex af,af'		;1	L0+ 1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; data copier

mainloop_1:
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

current_read_ptr equ $+1
        ld de, free_buffer      ;3      L0+16         
        ld hl, (patchup_write_ptr) ;5   L0+21        
        sbc hl,de               ;4      L0+25     ; carry was clear
        jp z, copy_finished_28  ;3      L0+28
        ex de,hl                ;1      L0+29
        ld e,(hl)               ;2      L0+31
        inc l                   ;1      L0+32
	defs line+1-32          ;       L1+ 1
        
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        ld d,(hl)               ;2      L0+15
        inc l                   ;1      L0+16     ; DE=address of data to copy

        ld (current_read_ptr),hl ;5     L0+21     ; update the read pointer
        
        ld a,d                  ;1      L0+22
        or a                    ;1      L0+23
        jp z, found_event_26    ;3      L0+26     ; D=0 -> event    

        ex de,hl                ;1      L0+27
        inc hl                  ;2      L0+29
        ld e,(hl)               ;2      L0+31

	defs line+1-31          ;       L1+ 1

	exx                     ;1      L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L0+12     ; update counter
	exx                     ;1      L0+13

        inc hl                  ;2      L0+15
        ld d,(hl)               ;2      L0+17     ; DE=offset
        dec hl                  ;2      L0+19                   
        dec hl                  ;2      L0+21     ; HL=dest address
        ld c,(hl)               ;2      L0+23     ; C=copy length
        ld b,0                  ;2      L0+25
        ex de,hl                ;1      L0+26     ; HL=offset, DE=dest, BC=length
        add hl,de               ;3      L0+29     ; HL=source, DE=dest, BC=length                                  

        defs line+1-29                    
        
; LDI
; 
; S is not affected
; Z is not affected
; H is reset
; P/V is set if BC -1 != 0; reset otherwise
; N is reset
; C is not affected

copy_bigblock_1:
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

        ld a,c                  ;1      L0+18     ; if we have 6 or more bytes
        sub 6                   ;2      L0+20     ; to copy, we can copy 5  
        jr c,copy_smallblock_23 ;2/3    L0+22     ; quickly and still assume
        
        ldi                     ;5      L0+27     ; at least one byte is left
        ldi                     ;5      L0+32     ; and so just fall into normal                                 
	defs line+1-32          ;       L1+ 1     ; code after the 5 byte copy                                                                    

	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ldi                     ;5      L0+18
        ldi                     ;5      L0+23
        ldi                     ;5      L0+28
	defs line-2-28          ;       L0- 2
        jp copy_bigblock_1      ;3      L1+ 1

copy_smallblock_23:             ;       L1+23
        ldi                     ;5      L1+28
	defs line-2-28          ;       L1- 2
        jp po, copy_finished_1  ;3      L2+ 1     ; copy one single byte
         
copy_continue_1:
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

        ldi                     ;5      L0+22
        jp po, copy_finished_25 ;3      L0+25     ; copy one single byte

	defs line+1-25          ;       L1+ 1
        
	exx                     ;1      L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here

	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ldi                     ;5      L0+18
        jp po, copy_finished_21 ;3      L0+21     ; copy one single byte

        ldi                     ;5      L0+26
        defs line-2-26          ;       L1- 2
        jp pe, copy_continue_1  ;3      L1+ 1     ; copy one single byte and done
;copy_finished_1:

; the following is a special form for the interrupt handler
; the LD L,(HL) is replaced with
; NOP:NOP:EI:LD L,(HL):DI
; the extra nops and EI match the time taken by the interrupt call.
; if an interrupt was latched, it will be forced to be executed immediately
; after the memory load. interrupts are then immediately disabled again.

copy_finished_1:
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

;        out (c),d               ;4      L1+21     ; select background                     
;        out (c),c               ;4      L1+25     ; set colour                  
;        out (c),e               ;4      L1+29     ; select border                  

	defs line-3-17          ;       L1- 3
mainloop_patch equ $+1
        jp mainloop             ;       L1+ 0
     

copy_finished_21:
        defs 25-21              ;       L0+25
copy_finished_25:
        defs 28-25              ;       L0+28
copy_finished_28: 
        defs line-2-28          ;       L1- 2
        jp copy_finished_1      ;3      L1+ 1
        
found_event_26:
        or e                    ;1      L0+27     ; E=event type, if 0 then we're expecting a jump
	defs line-2-27          ;       L0- 2
        jp nz, copy_finished_1  ;3      L1+ 1     ; anything else is error for now    

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
        
        ld e,(hl)               ;2      L0+19
        inc l                   ;1      L0+20
        ld d,(hl)               ;2      L0+22     ; execution address
        inc l                   ;1      L0+23
        ld (current_read_ptr),hl ;5     L0+28     ; update the read pointer

        defs line-2-28          ;       L0- 2 
        ex de,hl                ;1      L0- 1
        jp (hl)                 ;1      L0+ 0     ; event type 0 = execute next addr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;intvec:
;	                        ;10     L0+23   ; interrupt takes 10us                                
;	defs line+2-23          ;	L1+ 2	
;	in a,(c)		;4	L0+ 6
;	xor c			;1	L0+ 7     ; check for edge
;	call m,new_found_edge	;3/5	L0+10                                                             
;	ld l,(hl)		;2	L1+12   ; update counter
;        ret                     ;3      L1+15	; back at caller at 15                        
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

intvec_palette:
	                        ;10     L0+23   ; interrupt takes 10us
        in a,(c)                ;4      L0+27
        rrca                    ;1      L0+28
        defs line-1-28          ;       L1- 1
;        jp c,intvec_palette_vsync_2 ;3    L1+ 2
        jp c,intvec_palette_vsync_join ;3    L1+ 2

	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10                                                             
	ld l,(hl)		;2	L1+12   ; update counter
        ret                     ;3      L1+15	; back at caller at 15                        

; this code is pretty ugly, but as we can't guarantee quick interrupt response
; it's possible for the vsync pulse to have ended before we can get into the
; interrupt routine... so after we've found it once, we start counting interrupts
; instead... needed for sound sync

intvec_palette_synced:          ;10     L0+23   ; interrupt takes 10us
intvec_palette_synced_counter equ $+1
        ld a,6                  ;2      L0+25
        dec a                   ;1      L0+26
        jr z,intvec_palette_synced_29 ;2/3 L0+28
        ld (intvec_palette_synced_counter),a ;4 L0+32                                 

        
        defs line+2-32          ;       L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10     ; note DE preserved as can't transition here
	ld l,(hl)		;2	L1+12     ; update counter
	nop			;1	L1+13

intvec_other_frame_ptr equ $+1
        jp intvec_other_frame_16 ;3     L1+16                       
intvec_other_frame_16:
        in a,(c)                ;4      L1+20
        rrca                    ;1      L1+21
        
        defs 25-21              ;       L1+25
        jr c,intvec_palette_resynced_28 ;2/3 L1+27
        defs 32-27              ;       L1+32

        defs line+2-32          ;       L0+ 2
	in a,(c)		;4	L0+ 6
	xor c			;1	L0+ 7     ; check for edge
	call m,new_found_edge	;3/5	L0+10                                                             
	ld l,(hl)		;2	L1+12   ; update counter
        ret                     ;3      L1+15	; back at caller at 15                        

intvec_palette_resynced_28:       ;       L0+28
	nop			;1	L0+29
intvec_palette_synced_29:       ;       L0+29

	; reset early
        defs line+2-29          ;       L0- 1
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter

        ld a,6                  ;2      L0+14
        ld (intvec_palette_synced_counter),a ;4 L0+18 

        in a,(c)                ;4      L1+22
        rrca                    ;1      L1+23
	jp nc,intvec_palette_lost_sync_26 ;3 L1+26
        defs 29-26          ;       L0- 1

intvec_palette_lost_sync_29:       ;       L0+29
        defs line-1-29          ;       L0- 1

intvec_palette_vsync_ptr equ $+1
        jp intvec_palette_vsync_2 ;3    L1+ 2

intvec_palette_lost_sync_26:
	jp intvec_palette_lost_sync_29 ;3	L1+29

intvec_palette_synced_hi equ (intvec_palette_synced and #ff00) / 256

intvec_palette_vsync_join:
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	nop ; exx		;1	L1+13

        ld a,intvec_palette_synced ;2   L1+15
        ld (#39),a              ;4      L1+19
        ld a,intvec_palette_synced_hi ;2  L1+21
        ld (#3a),a              ;4      L1+25
            
        ld a,6                  ;2      L0+27
        ld (intvec_palette_synced_counter),a ;4 L0+31                                 
        defs line+2-31          ;       L1+ 2                  

intvec_palette_vsync_2:
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        push bc                 ;4      L1+17
        push hl                 ;4      L1+21

        ld bc,#7f00             ;3      L1+24
        ld hl,(palette)         ;5      L1+29

	defs line+1-29          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15  
        out (c),c               ;4      L1+19
        out (c),l               ;4      L1+23  ; colour 0
        out (c),a               ;4      L1+27
        inc c                   ;1      L1+28

	defs line+1-28          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15  
        out (c),c               ;4      L1+19
        out (c),h               ;4      L1+23  ; colour 1
        out (c),a               ;4      L1+27
        ld hl,(palette+2)       ;5      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        inc c                   ;1      L1+14
        ld a,#10                ;2      L1+16  
        out (c),c               ;4      L1+20
        out (c),l               ;4      L1+24  ; colour 2
        out (c),a               ;4      L1+28
        inc c                   ;1      L1+29

	defs line+1-29          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15  
        out (c),c               ;4      L1+19
        out (c),h               ;4      L1+23  ; colour 3
        out (c),a               ;4      L1+27

        ld a,(screen_mode)      ;4      L1+31
        ld l,a                  ;1      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13
 
        ld a,l                  ;1      L1+14
        or #8c                  ;2      L1+16        
        out (c),a               ;4      L1+20  ; screen mode
        and 3                   ;2      L1+22
        jr z, palette_mode_0_25 ;2/3    L1+24

        jp palette_not_mode_0_27 ;3     L1+27

palette_mode_0_25 :        
        ld hl,(palette+4)       ;5      L1+30
        
; mode 0, so do palette entries 4-15

	defs line+1-30          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15
        inc c                   ;1      L1+16  
        out (c),c               ;4      L1+20
        out (c),l               ;4      L1+24  ; colour 4
        out (c),a               ;4      L1+28
        inc c                   ;1      L1+29

	defs line+1-29          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15  
        out (c),c               ;4      L1+19
        out (c),h               ;4      L1+23  ; colour 5
        out (c),a               ;4      L1+27
        ld hl,(palette+6)       ;5      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15
        inc c                   ;1      L1+16  
        out (c),c               ;4      L1+20
        out (c),l               ;4      L1+24  ; colour 6
        out (c),a               ;4      L1+28
        inc c                   ;1      L1+29

	defs line+1-29          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15  
        out (c),c               ;4      L1+19
        out (c),h               ;4      L1+23  ; colour 7
        out (c),a               ;4      L1+27
        ld hl,(palette+8)       ;5      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15
        inc c                   ;1      L1+16  
        out (c),c               ;4      L1+20
        out (c),l               ;4      L1+24  ; colour 8
        out (c),a               ;4      L1+28
        inc c                   ;1      L1+29

	defs line+1-29          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15  
        out (c),c               ;4      L1+19
        out (c),h               ;4      L1+23  ; colour 9
        out (c),a               ;4      L1+27
        ld hl,(palette+10)      ;5      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15
        inc c                   ;1      L1+16  
        out (c),c               ;4      L1+20
        out (c),l               ;4      L1+24  ; colour 10
        out (c),a               ;4      L1+28
        inc c                   ;1      L1+29

	defs line+1-29          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15  
        out (c),c               ;4      L1+19
        out (c),h               ;4      L1+23  ; colour 11
        out (c),a               ;4      L1+27
        ld hl,(palette+12)      ;5      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15
        inc c                   ;1      L1+16  
        out (c),c               ;4      L1+20
        out (c),l               ;4      L1+24  ; colour 12
        out (c),a               ;4      L1+28
        inc c                   ;1      L1+29

	defs line+1-29          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15  
        out (c),c               ;4      L1+19
        out (c),h               ;4      L1+23  ; colour 13
        out (c),a               ;4      L1+27
        ld hl,(palette+14)      ;5      L1+32

	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15
        inc c                   ;1      L1+16  
        out (c),c               ;4      L1+20
        out (c),l               ;4      L1+24  ; colour 14
        out (c),a               ;4      L1+28
        inc c                   ;1      L1+29

	defs line+1-29          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

        ld a,#10                ;2      L1+15  
        out (c),c               ;4      L1+19
        out (c),h               ;4      L1+23  ; colour 15
        out (c),a               ;4      L1+27
palette_not_mode_0_27:

        push de                 ;4      L1+31

	defs line+1-31          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
	exx			;1	L1+13

music_hook_ptr equ $+1
        jp music_hook_return16  ;3      L1+16              

music_hook_return16:  
        nop                     ;1      L1+17                       
        pop de                  ;3      L1+20
        pop hl                  ;3      L1+23
        pop bc                  ;3      L1+26

	defs 32-26
        ;ld a,6                  ;2      L0+28      
        ;ld (intvec_palette_synced_counter),a ;4 L0+32                               
	
	defs line+1-32          ;       L1+ 1
	exx			;1	L1+ 2
	in a,(c)		;4	L1+ 6
	xor c			;1	L1+ 7     ; check for edge
	call m,new_found_edge	;3/5	L1+10	
	ld l,(hl)		;2	L1+12     ; update counter
        ret                     ;3      L1+15	; back at caller at 15                        
       
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; crtc regs: r4=#26 (total height=39 lines), r6=#1b (visible lines=27), r7=#1f vsync 

; new top: r4=#19 (total 26 lines), r6=#19 (visible 25 lines), r7=#1f (out of range)
; new bot: r4=#0c (total 13 lines), r6=#02 (visible 2 lines),  r7=#05 (#1f-#1a)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;intvec_stripe:
;	                        ;10     L0+23   ; interrupt takes 10us
;
;        in a,(c)                ;4      L0+27
;        rrca                    ;1      L0+28
;        jp c,intvec_stripe_vsync ;3     L0+31
;
;	defs line+2-31          ;       L1+ 2
;	in a,(c)		;4	L1+ 6
;	xor c			;1	L1+ 7     ; check for edge
;	call m,new_found_edge	;3/5	L1+10	
;	ld l,(hl)		;2	L1+12     ; update counter
;	exx			;1	L1+13
;
;        push bc                 ;4      L1+17
;intvec_stripe_colour equ $+1
;        ld bc,#7f41             ;3      L1+20
;        inc c                   ;1      L1+21
;
;        ld a,c                  ;1      L1+22
;        ld (intvec_stripe_colour),a ;4  L1+26
;
;	defs line+1-26          ;       L2+ 1
;	exx			;1	L2+ 2                           
;	in a,(c)		;4	L2+ 6
;	xor c			;1	L2+ 7     ; check for edge
;	call m,new_found_edge	;3/5	L2+10	
;	ld l,(hl)		;2	L2+12     ; update counter
;	exx			;1	L2+13
;
;        xor a                   ;1      L2+14
;        out (c),a               ;4      L2+18     ; select background                     
;        out (c),c               ;4      L2+22     ; set colour                  
;        ld a,#10                ;2      L2+24
;        out (c),a               ;4      L2+28     ; select border                  
;        pop bc                  ;3      L2+31
;        
;	defs line+1-31          ;	L3+ 1	
;	exx			;1	L3+ 2
;	in a,(c)		;4	L3+ 6
;	xor c			;1	L3+ 7     ; check for edge
;	call m,new_found_edge	;3/5	L3+10                                                             
;	ld l,(hl)		;2	L3+10   ; update counter
;        ret                     ;3      L3+13	; back at caller at 13                        
;
;intvec_stripe_vsync:
;	defs line+2-31          ;       L1+ 2
;	in a,(c)		;4	L1+ 6
;	xor c			;1	L1+ 7     ; check for edge
;	call m,new_found_edge	;3/5	L1+10	
;	ld l,(hl)		;2	L1+12     ; update counter
;
;        ld a,#53                ;2      L1+14
;        ld (intvec_stripe_colour),a ;4  L1+18
;        
;        ld a,l                  ;1      L1+19
;        cp b                    ;1      L1+20
;        jr nz,not_idle_23       ;2/3    L1+22    
;        
;        ld a,#50                ;2      L1+24
;        ld b,#7f                ;2      L1+26
;        out (c),a               ;4      L1+30
;        ld b,#f5                ;2      L1+32
;
;	defs line+2-32          ;	L1+ 2	
;	in a,(c)		;4	L1+ 6
;	xor c			;1	L1+ 7     ; check for edge
;	call m,new_found_edge	;3/5	L1+10                                                             
;	ld l,(hl)		;2	L1+10   ; update counter
;        ret                     ;3      L1+13	; back at caller at 13                        
;        
;not_idle_23:
;	defs line+2-23          ;	L1+ 2	
;	in a,(c)		;4	L1+ 6
;	xor c			;1	L1+ 7     ; check for edge
;	call m,new_found_edge	;3/5	L1+10                                                             
;	ld l,(hl)		;2	L1+10   ; update counter
;        ret                     ;3      L1+13	; back at caller at 13                        
;        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; EVERYTHING AFTER THIS POINT CAN BE OVERWRITTEN AFTER BUILDING THE TABLE
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


prepare_new_table:
        ld ix,new_table          ; symbol buffer
        ld bc,0                  ; next emitter
        ld a,16                  ; length

;        ld ix,new_table_406
;        ld a,17
                  
prepare_new_table_sub:
        push ix
        ld de,3
        add ix,de

        ex af,af'                ; make sure next value doesn't straddle boundary
        ld a,xl
        cp #fe
        jr c,next_ix_ok
        inc xh
        ld xl,0
next_ix_ok:                      
        ex af,af'
        
        ld de,#1ff               ; error code (shouldn't happen now)

        sub 3                    ; l>3 / l==3
        jr z,left_terminal
        jr c,left_error
        
        add a,2                  ; l-1, descend
        push ix
        call prepare_new_table_sub
        pop de
        inc a
        jr left_done
        
left_terminal:        
        ld d,b
        ld e,c                   ; DE = terminal for left
        call inc_bc
left_error:
        add a,3
left_done:                       ; DE = result for left

        ld hl,#1ff               ; error code (shouldn't happen)
        
        sub 6
        jr c, right_terminal_or_error

        add a,3                  ; l-3, descend   
        push de
        push ix
        call prepare_new_table_sub
        pop hl
        pop de
        jr right_done
        
right_terminal_or_error:
        add a,3
        jr nc, right_error
        ld h,b
        ld l,c                   ; HL = terminal for left
        call inc_bc
right_error:
right_done:                       ; HL = result for left
        add a,3

        rl h
        rl h
        rl h
        rl h

        rl h
        rl d
        rl h
        rl d
        rl h
        rl d
        rl h
        rl d                     ; merge H and D into D   

        pop iy
        ld (iy+2),l
        ld (iy+1),e
        ld (iy+0),d

        ret

inc_bc:                          ; 00..ff, 106..115, 120..124
        inc c
        jr z,start_bc_6

        rrc b
        ret z
        rlc b

        inc c                    ;

        push af
        ld a,c        
        cp 44
        jr z, start_bc_22
        pop af
        ret
        
start_bc_6:
        ld bc,#100+12
        ret           
        
start_bc_22:
        ld bc,#101
        pop af
        ret        
                       

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; EVERYTHING AFTER THIS POINT CAN BE OVERWRITTEN WHEN BUILDING THE TABLE
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; MAIN ENTRY POINT
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

       
program_start:

        ld bc,#f610			; keep tape motor going
        out (c),c

;WTO;        ld hl,msg
;WTO;        call print

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	di
	ld hl,#8
	ld a,#40
clear_lowmem:
        ld (hl),h
        inc l
        cp l
        jr nz,clear_lowmem        

        ld hl,#4a44
        ld (palette+0),hl
        ld hl,#4c53
        ld (palette+2),hl

        ld a,1
        ld (screen_mode),a
        	
	ld hl,#c9fb
	ld (#38),hl
	
	ld bc,#7f10
	out (c),c

        ld sp,stack_top	
	ld hl,0
	push hl

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        call init_border_and_ex_regs
        call loader_initialise            
        call prepare_new_table                                                                   

	ld iy,start_sync_handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ld hl,#8000
        ld de,#8001
        ld bc,#7fff
        ld (hl),#0
        ldir                                                                       

        ld c,#4a
        
	ei
	halt
	halt
	di

        ld a,#c3                ;2  
;	ld hl,intvec_stripe     ;3
;	ld hl,intvec            ;3
	ld hl,intvec_palette    ;3
	ld (#38),a              ;4
	ld (#39),hl             ;5

	defs 56-14

mainloop_entry_ptr equ $+1
        jp mainloop


init_border_and_ex_regs:
; colours: pre-pilot 2a/ad, pilot 2a/ac, data 22/a5

; 40 orange/grey             
; 42 bright green/red        header
; 44 blue/yellow             loading
; 46 pink/grey

; 50 blue/dark yellow
; 52 bright green/red
; 54 bright green/black      searching
; 56 purple/green

	ld b,#f5		;2	Lx+8
	in a,(c)		;4	Lx+12
	ld bc,#7f54		;3	Lx+15
	rla			;1	Lx+16
	rr c			;2	Lx+18
	ld b,#f5		;2	Lx+20

        ld hl,count_table_sync 
        exx

;        ld bc,#bc07             ;3      L1+18
;        out (c),c               ;4      L1+22  ; select R7 sync pos
;        ld bc,#bd1f             ;3      L1+25
;        out (c),c               ;4      L1+29  ; sync=#1f
                                    

        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; initialises the tape system

loader_initialise:

        ld hl,count_table_start	; initial position in edge state machine 
        ld de,table_init_data

        ; initialise normal translation table
        ld c,errorsymbol+1
        
        ld a,(de)
loader_initialise_block:
        inc de
        ld b,a                 ; length for this symbol

loader_initialise_entry:        
        ld a,3
        add a,l

        ld (hl),a              ; 00->03 next for no pulses
        inc l

        inc a
        ld (hl),a              ; 01->04 next for 1st pulse
        inc l

        ld (hl),c              ; 02->symbol for 2nd pulse
        inc l
        djnz loader_initialise_entry

        inc c                  ; next symbol
        
        ld a,(de)        
        or a
        jr nz,loader_initialise_block

table_init_end:
        ld c,errorsymbol        

table_clear_to_end:
        ld (hl),c
        inc l
        jr nz,table_clear_to_end            

;	ld l,#f5                ; fill symbols with links back to themslelves            
;table_fill_error_to_end:
;        ld (hl),l
;        inc l
;        jr nz,table_fill_error_to_end                

; sync pulse every 6*halfline cycles
; end sync pulse twice, each 1*halfline cycles
; 
; so end sync pulse will pulse twice within 2*halfline
; with 50% margin, we allow a double pulse up to 3*halfline
;
; 50% margin on sync pulse is 3*halfline to 9*halfline


        ld l,count_table_ofs_sync; address for sync area           
        ld b,halfpulse3-1          ; low threshold up to 3 x half-pulse
        inc c

loader_initialise_sync_entry:        
        ld a,3
        add a,l

        ld (hl),a              ; 00->03 next for no pulses
        inc l

        inc a
        ld (hl),a              ; 01->04 next for 1st pulse
        inc l

        ld (hl),c              ; 02->symbol for 2nd pulse
        inc l
        djnz loader_initialise_sync_entry
                   
; end sync table created, now make 1st pulse table

        inc c                    ; half pulse code
        ld b,halfpulse6
loader_initialise_sync_initial_entry:        
        ld a,2
        add a,l
        ld (hl),a               ; 00->02 next for no pulse
        inc l
        
        ld (hl),c               ; 01->symbol for 1st pulse
        inc l
        djnz loader_initialise_sync_initial_entry                      
        ret

table_init_data:
        db halfpulse4-2,halfpulse4,0       ; 0.5, 1.5, 2.0          

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;WTO;print:  ld a,(hl)
;WTO;        inc hl
;WTO;        ld b,a
;WTO;        inc b
;WTO;        ret z
;WTO;        call &bb5a
;WTO;        jr print
;WTO;msg:
;WTO;        defb 4,1
;        defb 4,0
;        defb 31,22,1,#f6,#f7," 32/64us rupture",31,22,25,#f6,#f7
;WTO;        defb 31,16,13,"Loading..."
;WTO;   defb 13,10,13,10,"          1         2         3         "
;WTO;   defb             "0123456789012345678901234567890123456789"
;WTO;        defb #ff
;        defb 4,1,31,14,1,"Loading...",#ff

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;new_table:

       END                                                                               

