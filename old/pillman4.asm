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
        ; Revision date: Jun/15/2019. Ghosts can catch pillman. Optimized.
        ;                             509 bytes.
        ;

    %ifndef com_file            ; If not defined create a boot sector
com_file:       equ 0
    %endif

base:           equ 0xf9fe      ; Memory base (same segment as video)
intended_dir:   equ base+0x00
frame:          equ base+0x01
x_player:       equ base+0x02
y_player:       equ base+0x04
old_time:       equ base+0x06

        ;
        ; Maze should start at x,y coordinate multiple of 8
        ;
BASE_MAZE:      equ 16*X_OFFSET+32      
pos1:           equ BASE_MAZE+21*8*X_OFFSET

X_OFFSET:       equ 0x0140

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
        mov ax,0x0013           ; Set mode 0x13 (320x200x256 VGA)
        int 0x10                ; Call BIOS
        cld
        mov ax,0xa000           ; Video segment
        mov ds,ax               ; Use as source data segment
        mov es,ax               ; Use as target data segment
        mov si,maze
        mov di,BASE_MAZE
draw_maze_row:
        cs lodsw
        xchg ax,cx
        mov bx,30*8
draw_maze_col:
        shl cx,1
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
        jmp draw_maze_col

dm2:   
        add di,X_OFFSET*8-15*8
        cmp si,setup_data
        jne draw_maze_row

        ; CX is zero at this point
        ; DI is equal to pos1 at this point
       ;mov di,pos1
        mov cl,5
        mov ax,2                ; Going to right
dm3:
        cs movsw
        stosw
        loop dm3

game_loop:
        mov ah,0x00
        int 0x1a                ; BIOS clock read
        cmp dx,[old_time]       ; Wait for change
        je game_loop
        mov [old_time],dx

        mov ah,0x01             ; BIOS Key available
        int 0x16
        mov ah,0x00             ; BIOS Read Key
        je no_key
        int 0x16
no_key:
        mov al,ah
        sub al,0x48
        jc no_key2
        cmp al,0x09
        jnc no_key2
        mov bx,dirs
        cs xlat
        mov [intended_dir],al
no_key2:
        mov si,pos1
        lodsw
        xchg ax,di
        lodsw
        xchg ax,bx
        xor ax,ax               ; Delete pillman
        call move_sprite2       ; Move
        xor byte [frame],0x80   
        mov ax,0x0e28           ; Closed mouth
        js close_mouth
        mov al,[pos1+2]
        mov cl,3
        shl al,cl               ; Open mouth
close_mouth:
        call draw_sprite        ; Draw
        mov bh,GHOST1_COLOR
        call move_ghost
        mov bh,GHOST2_COLOR
        call move_ghost
        mov bh,GHOST3_COLOR
        call move_ghost
        mov bh,GHOST4_COLOR
        call move_ghost
        jmp game_loop           

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
        mov ah,dl
        or ah,al
        and ah,7
        jne ms0
        ; AH is zero already
       ;mov ah,0
        mov ch,MAZE_COLOR
        cmp [di-0x0001],ch
        adc ah,ah
        cmp [di+X_OFFSET*8],ch
        adc ah,ah
        cmp [di+0x0008],ch
        adc ah,ah
        cmp [di-X_OFFSET],ch
        adc ah,ah

        test bh,bh              ; Is it pillman?
        je ms4

        ;
        ; Ghost
        ;
        test bl,0x05   
        je ms6
        ; Current direction is up/down
        cmp dx,[x_player]
        mov al,0x02
        jc ms8
        mov al,0x08
        jmp ms8

        ; Current direction is left/right
ms6:    cmp al,[y_player]
        mov al,0x04
        jc ms8
        mov al,0x01
ms8:
        test ah,al              ; Can it go in wanted direction?
        jne ms1                 ; Yes, go in direction

        mov al,bl
ms9:    test ah,al              ; Can it go in current direction?
        jne ms1                 ; Yes, jump
        shr al,1                ; Try another direction
        jne ms9
        mov al,0x08             ; Cycle direction
        jmp ms9

        ;
        ; Pillman
        ;
ms4:
        mov [x_player],dx       ; Save current X coordinate
        mov [y_player],al       ; Save current Y coordinate

        mov al,[intended_dir]
        test ah,al              ; Can it go in intended direction?
        jne ms1                 ; Yes, go in that direction

ms5:    and ah,bl               ; Can it go in current direction?
        je ms2                  ; No, stops

ms0:    mov al,bl

ms1:    mov [si-2],al
        test al,5
        mov bx,-X_OFFSET*2
        jne ms3
        mov bx,1*2
ms3:
        test al,12
        je ms7
        neg bx
ms7:
        add di,bx
        mov [si-4],di
ms2:
        ret

bitmaps:
        db 0x00,0x42,0xe7,0xe7,0xff,0xff,0x7e,0x3c      ; dir = 1
        db 0x3c,0x7e,0xfc,0xf0,0xf0,0xfc,0x7e,0x3c      ; dir = 2
        db 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff      ; Maze
        db 0x3c,0x7e,0xff,0xff,0xe7,0xe7,0x42,0x00      ; dir = 4
        db 0x3c,0x7e,0xff,0xff,0xff,0xff,0x7e,0x3c      ; Closed mouth
        db 0x3c,0x7e,0xdb,0xdb,0xff,0xff,0xff,0xa5      ; Ghost
        db 0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00      ; Pill
        db 0x3c,0x7e,0x3f,0x0f,0x0f,0x3f,0x7e,0x3c      ; dir = 8

maze:
        dw 0b0000_0000_0000_0000
        dw 0b0111_1111_1111_1110
        dw 0b0100_0010_0000_0010
        dw 0b0100_0010_0000_0010
        dw 0b0111_1111_1111_1111
        dw 0b0100_0010_0100_0000
        dw 0b0111_1110_0111_1110
        dw 0b0000_0010_0000_0010
        dw 0b0000_0010_0111_1111
        dw 0b0000_0011_1100_0000
        dw 0b0000_0010_0100_0000
        dw 0b0000_0010_0111_1111
        dw 0b0000_0010_0100_0000
        dw 0b0111_1111_1111_1110
        dw 0b0100_0010_0000_0010
        dw 0b0111_1011_1111_1111
        dw 0b0000_1010_0100_0000
        dw 0b0111_1110_0111_1110
        dw 0b0100_0000_0000_0010
        dw 0b0111_1111_1111_1111
        dw 0b0000_0000_0000_0000

setup_data:
        dw BASE_MAZE+0x78*X_OFFSET+0x78
        dw BASE_MAZE+0x30*X_OFFSET+0x70
        dw BASE_MAZE+0x40*X_OFFSET+0x78
        dw BASE_MAZE+0x20*X_OFFSET+0x80
        dw BASE_MAZE+0x30*X_OFFSET+0x88

dirs:
        db 0x01,0x00,0x00,0x08,0x00,0x02,0x00,0x00,0x04

        ;
        ; Move ghost
        ; bh = color
        ;
move_ghost:
        lodsw
        xchg ax,di
        lodsw
        test ah,ah
        xchg ax,bx              ; Color now in ah
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
        jmp restart             ; It should crash after several hundred games
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
