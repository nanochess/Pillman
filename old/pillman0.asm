        ;
        ; Pillman
        ;
        ; by Oscar Toledo G.
        ;
        ; Creation date: Jun/11/2019.
        ; Revision date: Jun/12/2019. Draws level.
        ; Revision date: Jun/13/2019. Pillman can move.
        ;

        ;
        ; TODO:
        ; * Ghost can get stuck because cannot try a third direction.
        ; * Ghost should be transparent.
        ; * Pillman should not leave trash.
        ;

    %ifndef com_file            ; If not defined create a boot sector
com_file:       equ 0
    %endif

base:           equ 0xfc80      ; Memory base (same segment as video)
old_time:       equ base+0x00
frame:          equ base+0x02
dir:            equ base+0x03
intended_dir:   equ base+0x04
x_player:       equ base+0x06
y_player:       equ base+0x08
pos1:           equ base+0x0a

X_OFFSET:       equ 0x0140

MAZE_COLOR:     equ 0x01
PILL_COLOR:     equ 0x0e
PLAYER_COLOR:   equ 0x0e
GHOST1_COLOR:   equ 0x09
GHOST2_COLOR:   equ 0x0a
GHOST3_COLOR:   equ 0x0b
GHOST4_COLOR:   equ 0x0c

    %if com_file
        org 0x0100
    %else
        org 0x7c00
    %endif
        mov ax,0x0013   ; Set mode 0x13 (320x200x256 VGA)
        int 0x10        ; Call BIOS
        cld
        mov ax,0xa000
        mov ds,ax
        mov es,ax
        xor ax,ax
        xor di,di
        xor cx,cx
        rep
        stosw
        mov di,8*X_OFFSET+32
        mov si,maze
g2:     cs lodsw
        push ax
        mov cx,16
g3:     shl ax,1
        call draw_maze
        loop g3
        pop ax
        mov cx,15
        shr ax,1
g4:     shr ax,1
        call draw_maze
        loop g4
        add di,X_OFFSET*8-31*8
        cmp si,maze+42
        jne g2

        mov byte [dir],0x10
        mov di,pos1
        mov ax,0x80*X_OFFSET+0x98
        stosw
        mov ax,0x0001*2
        stosw
        mov ax,0x48*X_OFFSET+0x90
        stosw
        mov ax,-X_OFFSET*2
        stosw
        mov ax,0x48*X_OFFSET+0x98
        stosw
        mov ax,-1*2
        stosw
        mov ax,0x48*X_OFFSET+0xa0
        stosw
        mov ax,-X_OFFSET*2
        stosw
        mov ax,0x48*X_OFFSET+0xa8
        stosw
        mov ax,1
        stosw
game_loop:

clock_wait:
        mov ah,0x00
        int 0x1a                ; BIOS clock read
        cmp dx,[old_time]       ; Wait for change
        je clock_wait
        mov [old_time],dx

        mov ah,0x01                     ; BIOS Key available
        int 0x16
        mov ah,0x00                     ; BIOS Read Key
        je g5
        int 0x16

g5:     mov bx,[intended_dir]
        cmp ah,0x48
        jne g6
        mov bx,-X_OFFSET*2
g6:
        cmp ah,0x4b
        jne g7
        mov bx,-1*2
g7:
        cmp ah,0x4d
        jne g8
        mov bx,1*2
g8:
        cmp ah,0x50
        jne g9
        mov bx,X_OFFSET*2
g9:
        mov [intended_dir],bx

        mov si,pos1
        lodsw
        xchg ax,di
        lodsw
        xchg ax,bx
        call move_sprite
        mov [x_player],dx
        mov [y_player],ax
        or al,dl
        and al,7
        jne g10
        mov bx,[intended_dir]
        push di
        call move_sprite
        pop ax
        cmp ax,di
        je g10
        xchg ax,di
        mov [pos1+2],bx
g10:
        xor byte [frame],1
        mov ax,0x0e00
        je g1
        mov al,[dir]
g1:
        call draw_sprite
        mov ah,GHOST1_COLOR
        call move_ghost
        mov ah,GHOST2_COLOR
        call move_ghost
        mov ah,GHOST3_COLOR
        call move_ghost
        mov ah,GHOST4_COLOR
        call move_ghost
        jmp game_loop

        ;
        ; Move ghost
        ;
move_ghost:
        mov al,0x28
        push ax
        lodsw
        xchg ax,di
        lodsw
        xchg ax,bx
        call move_sprite
        mov cl,al
        or cl,dl
        and cl,7
        jne mg1
        cmp bh,0xff
        je mg2
        cmp bh,0x00
        je mg2
        ; Moving vertically
        cmp dx,[x_player]
        mov bx,-1*2
        jnc mg3
        neg bx
        jmp mg3

        ; Moving horizontally
mg2:    cmp ax,[y_player]
        mov bx,-X_OFFSET*2
        jnc mg3
        neg bx
mg3:
        push di
        call move_sprite
        pop ax
        cmp ax,di
        je mg1
        xchg ax,di
        mov [si-2],bx
mg1:
        pop ax
        jmp draw_sprite

        ;
        ; Try to move sprite in desired direction
        ;
        ; Input:
        ; DI = address on screen
        ; BX = offset of movement
        ;
move_sprite:
        or bx,bx
        js ms1
        mov cl,2
        shl bx,cl
        mov al,[bx+di]
        sar bx,cl
        jmp ms3

        ;
        ; Moving in negative direction
        ;
ms1:
        mov al,[bx+di]
ms3:
        cmp al,MAZE_COLOR
        je ms2          ; Yes, don't move
        add di,bx       ; No, move
        mov [si-4],di
ms2:
        mov ax,di
        xor dx,dx
        mov cx,X_OFFSET
        div cx
        ret

        ;
        ; Draw a maze square.
        ;
        ; Input:
        ; Carry = 0 = Draw border
        ;         1 = Draw pill
        ; DI = address on screen
        ;
        ; Output:
        ; DI = Moved 8 pixels to right
        ;
        ; Destroys:
        ; BX
        ;
draw_maze:
        push ax
        mov ax,MAZE_COLOR*0x0100+0x30
        jnc dm1
        mov ax,PILL_COLOR*0x0100+0x38
dm1:    call draw_sprite
        add di,8
        pop ax
        ret

bitmaps:
        db 0x3c,0x7e,0xff,0xff,0xff,0xff,0x7e,0x3c
        db 0x00,0x42,0xe7,0xe7,0xff,0xff,0x7e,0x3c
        db 0x3c,0x7e,0xfc,0xf0,0xf0,0xfc,0x7e,0x3c
        db 0x3c,0x7e,0xff,0xff,0xe7,0xe7,0x42,0x00
        db 0x3c,0x7e,0x3f,0x0f,0x0f,0x3f,0x7e,0x3c
        db 0x3c,0x7e,0xdb,0xdb,0xff,0xff,0xff,0xa5
        db 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
        db 0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00

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
        dw 0xffc0
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

        ;
        ; Draw 1 pixel inside reg. al (bit 7)
        ;
bit:    jc big_pixel
zero:   xor ax,ax
big_pixel:
        stosb
        ret

        ; ah = sprite color
        ; al = sprite (x8)
        ; di = Target address
draw_sprite:
        push cx
        push di
in3:    push ax
        mov bx,bitmaps
        cs xlat                 ; Extract one byte from bitmap
        xchg ax,bx
        mov cx,8               
in0:    mov al,bh
        mov ah,bh
        shl bl,1
        call bit                ; Draw pixel
        loop in0
        add di,X_OFFSET-8       ; Go to next video line
        pop ax
        inc ax                  ; Next bitmap byte
        test al,7               ; Sprite complete?
        jne in3                 ; No, jump
        pop di
        pop cx
        ret

    %if com_file
    %else
        times 510-($-$$) db 0x4f
        db 0x55,0xaa            ; Make it a bootable sector
    %endif
