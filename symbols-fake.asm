                org #4000
                
        
         ld bc,#7f10
         out (c),c
         ld c,#46
         out (c),c
        
         di
         jp entrypoint
line equ 32

intvec_palette_vsync_2:
new_found_edge: ret

program_start:
mainloop:
mainloop_1:
        ld b,#f5   
        ei
        halt
        di
mainloop_patch equ $+1        
        jp mainloop_1


player_base     EQU 04000H
applet_base     EQU 03800H
song_data       EQU 06000H

