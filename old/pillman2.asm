        ;
        ; Pillman
        ;
        ; by Oscar Toledo G.
        ;
        ; Creation date: Jun/11/2019.
        ; Revision date: Jun/12/2019. Draws level.
        ; Revision date: Jun/13/2019. Pillman can move.
        ; Revision date: Jun/14/2019. Now ghosts don't get stuck. Ghost are
        ;                             transparent. Pillman doesn't leave
        ;                             trash.
        ; Revision date: Jun/15/2019. Ghosts can catch pillman. 538 bytes.
        ;

        ;
        ; TODO:
        ; * Detect all pills eaten?
        ;

    %ifndef com_file            ; If not defined create a boot sector
com_file:       equ 0
    %endif

base:           equ 0xfc80      ; Memory base (same segment as video)
old_time:       equ base+0x00
x_player:       equ base+0x04
y_player:       equ base+0x06
frame:          equ base+0x07
intended_dir:   equ base+0x08
pos1:           equ base+0x09

X_OFFSET:       equ 0x0140

SPEED:          equ 2

MAZE_COLOR:     equ 0x37        ; No color should be higher or equal value
PILL_COLOR:     equ 0x02
PLAYER_COLOR:   equ 0x0e        ; Should be unique

        ;
        ; XOR combination of these plus PILL_COLOR shouldn't
        ; result in PLAYER_COLOR
        ;
GHOST1_COLOR:   equ 0x21
GHOST2_COLOR:   equ 0x2e
GHOST3_COLOR:   equ 0x28
GHOST4_COLOR:   equ 0x34

    %if com_file
        org 0x0100
    %else
        org 0x7c00
    %endif
restart:
        mov ax,0x0013   ; Set mode 0x13 (320x200x256 VGA)
        int 0x10        ; Call BIOS
        cld
        mov ax,0xa000   ; Video segment
        mov ds,ax       ; Use as source data segment
        mov es,ax       ; Use as target data segment
        mov di,8*X_OFFSET+32
        mov si,maze
g2:     cs lodsw
        xchg ax,cx
        mov bx,30*8
g3:     shl cx,1
        mov ax,MAZE_COLOR*0x0100+0x18
        jnc dm1
        mov ax,PILL_COLOR*0x0100+0x38
dm1:    call draw_sprite
        add di,bx
        sub bx,16
        jc dm2
        call draw_sprite
        sub di,bx
        sub di,8
        jmp g3

dm2:   
        add di,X_OFFSET*8-15*8
        cmp si,maze+42
        jne g2

        mov di,pos1
        mov cx,5*2
        repz
        cs movsw

game_loop:

clock_wait:
        mov ah,0x00
        int 0x1a                ; BIOS clock read
        cmp dx,[old_time]       ; Wait for change
        je clock_wait
        mov [old_time],dx

        mov ah,0x01             ; BIOS Key available
        int 0x16
        mov ah,0x00             ; BIOS Read Key
        je g5
        int 0x16

g5:     mov al,[intended_dir]
        cmp ah,0x48             ; Up
        jne g6
        mov al,0x01
g6:
        cmp ah,0x4b             ; Left
        jne g7
        mov al,0x08
g7:
        cmp ah,0x4d             ; Right
        jne g8
        mov al,0x02
g8:          
        cmp ah,0x50             ; Down
        jne g9
        mov al,0x04
g9:
        mov [intended_dir],al

        mov si,pos1
        lodsw
        xchg ax,di
        lodsw
        xchg ax,bx
        xor ax,ax               ; Delete pillman
        call move_sprite2       ; Move
        xor byte [frame],0x80   
        mov ax,0x0e28           ; Closed mouth
        js g1
        mov al,[pos1+2]
        mov cl,3
        shl al,cl               ; Open mouth
g1:
        call draw_sprite        ; Draw
        xor bp,bp
        mov bh,GHOST1_COLOR
        call move_ghost
        mov bh,GHOST2_COLOR
        call move_ghost
        mov bh,GHOST3_COLOR
        call move_ghost
        mov bh,GHOST4_COLOR
        call move_ghost
        and bp,bp               ; Pillman catched?
        je game_loop            ; No, jump
        jmp restart             ; Yes, restart

        ;
        ; DI = address on screen
        ; BL = wanted direction
        ;
move_sprite3:        
        je move_sprite
move_sprite2:
        call draw_sprite        ; Remove ghost
move_sprite:
        mov ax,di
        xor dx,dx
        mov cx,X_OFFSET
        div cx
        mov ah,al
        or ah,dl
        and ah,0x07
        jne ms1
        ; AH is zero already
       ;mov ah,0
        cmp byte [di-0x0001],MAZE_COLOR
        adc ah,ah
        cmp byte [di+X_OFFSET*8],MAZE_COLOR
        adc ah,ah
        cmp byte [di+0x0008],MAZE_COLOR
        adc ah,ah
        cmp byte [di-X_OFFSET],MAZE_COLOR
        adc ah,ah

        test bh,bh       ; Is it pillman?
        je ms4

        ;
        ; Ghost
        ;
        test bl,0x05   
        je ms6
        ; Current direction is up/down
        cmp dx,[x_player]
        mov bh,0x02
        jc ms8
        mov bh,0x08
        jmp ms8

        ; Current direction is left/right
ms6:    cmp al,[y_player]
        mov bh,0x04
        jc ms8
        mov bh,0x01
ms8:
        test ah,bh
        je ms9
        mov bl,bh
        jmp ms1

ms9:    test ah,bl
        jne ms1
        shr bl,1
        jne ms9
        mov bl,0x08
        jmp ms9

        ;
        ; Pillman
        ;
ms4:
        mov [x_player],dx
        mov [y_player],al
        mov al,[intended_dir]
        test ah,al
        je ms5
        mov bl,al
        jmp ms1

ms5:
        and ah,bl       ; Can pillman go in direction?
        je ms2          ; No, pillman stops

ms1:    mov [si-2],bl
        test bl,5
        mov ax,-X_OFFSET*SPEED
        jne ms3
        mov ax,1*SPEED
ms3:
        test bl,12
        je ms7
        neg ax
ms7:
        add di,ax
        mov [si-4],di
ms2:
        ret

bitmaps:
        db 0x00,0x42,0xe7,0xe7,0xff,0xff,0x7e,0x3c
        db 0x3c,0x7e,0xfc,0xf0,0xf0,0xfc,0x7e,0x3c
        db 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff      ; Maze
        db 0x3c,0x7e,0xff,0xff,0xe7,0xe7,0x42,0x00
        db 0x3c,0x7e,0xff,0xff,0xff,0xff,0x7e,0x3c      
        db 0x3c,0x7e,0xdb,0xdb,0xff,0xff,0xff,0xa5      ; Ghost
        db 0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00      ; Pill
        db 0x3c,0x7e,0x3f,0x0f,0x0f,0x3f,0x7e,0x3c

maze:
        dw 0x0000
        dw 0x7ffe
        dw 0x4202
        dw 0x4202
        dw 0x7fff
        dw 0x4240
        dw 0x7e7e
        dw 0x0202
        dw 0x027f
        dw 0x03c0
        dw 0x0240
        dw 0x027f
        dw 0x0240
        dw 0x7ffe
        dw 0x4202
        dw 0x7bff
        dw 0x0a40
        dw 0x7e7e
        dw 0x4002
        dw 0x7fff
        dw 0x0000

setup_data:
        dw 0x80*X_OFFSET+0x98
        dw 0x0002
        dw 0x48*X_OFFSET+0x90-X_OFFSET*SPEED
        dw 0x0101
        dw 0x48*X_OFFSET+0x98-1*SPEED
        dw 0x0108
        dw 0x48*X_OFFSET+0xa0-X_OFFSET*SPEED
        dw 0x0101
        dw 0x48*X_OFFSET+0xa8+1*SPEED
        dw 0x0102

        ;
        ; Move ghost
        ;
move_ghost:
        lodsw
        xchg ax,di
        lodsw
        cmp ah,0x01
        xchg ax,bx
        mov al,0x30
        push ax
        mov byte [si-1],0x02
        call move_sprite3
        pop ax
        ; ah = sprite color
        ; al = sprite (x8)
        ; di = Target address
draw_sprite:
        push ax
        push bx
        push cx
        push di
ds0:    push ax
        mov bx,bitmaps-8
        cs xlat                 ; Extract one byte from bitmap
        xchg ax,bx
        mov cx,8               
ds1:    mov al,bh
        shl bl,1
        jc ds2
        xor ax,ax
ds2:
        cmp bh,0x10
        jc ds4
        cmp byte [di],PLAYER_COLOR
        jne ds3
        inc bp
ds3:
        xor al,[di]
ds4:
        stosb
        loop ds1
        add di,X_OFFSET-8       ; Go to next video line
        pop ax
        inc ax                  ; Next bitmap byte
        test al,7               ; Sprite complete?
        jne ds0                 ; No, jump
        pop di
        pop cx
        pop bx
        pop ax
        ret

    %if com_file
    %else
        times 510-($-$$) db 0x4f
        db 0x55,0xaa            ; Make it a bootable sector
    %endif
