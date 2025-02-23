.model tiny
.code
org 100h

;-=-=-=-==--=-=-=-=-=-=-=-==-=
VIDEOSEG  equ 0b800h
Y_POS     equ 1d
X_POS     equ 72d
TBL_HGHT  equ 8d
TBL_WDTH  equ 7d
CLR_PRMS  equ 00101110b
NUM_REGS  equ 4d
TTL_REGS  equ 8d
;-=-=-=-==--=-=-=-=-=-=-=-==-=

;------------------------------------------------------------------------------------------------------

    Start:
        xor ax, ax
        mov es, ax              ; es = 0
        mov bx, 08h * 4         ; bx = 9 * 4, each int handler addr is made of 4 bytes

        cli                     ; do not allow to interrupt during these lines
        mov ax, es:[bx]         ; save old handler addr
        mov OldHdlrAddr, ax
        mov ax, es:[bx+2]
        mov OldHdlrSeg, ax

        mov es:[bx], offset Handler ; load handler addr
        push cs
        pop ax
        mov es:[bx+2], ax
        sti

        mov al, 20h
        out 20h, al

        mov ax, 3100h            ; exit and stay resident
        mov dx, offset FileEnd   ; set mem size
        shr dx, 4h               ; size /= 4
        inc dx                   ; size++
        int 21h                  ; dos_func







;======================================================================================================
;Interupt handler
;Comm:
;Entry:
;Exit: -
;Destr:
;======================================================================================================
Handler proc

    push ax bx cx dx si di ds es                ; save condition of registers

    push cs
    pop ds                                      ; ds in command segment

    mov ax, VIDEOSEG                            ; preapre to print chars
    mov es, ax

    mov ah, CLR_PRMS                            ; color attr
    mov bx, offset Style
    mov dl, TBL_HGHT                            ; height
    mov dh, TBL_WDTH                            ; width

    call DrawTable

    mov di, (Y_POS + 1) * 160d + X_POS * 2d     ; pos to print first line
    mov cx, NUM_REGS

    call PrintRegs



    pop es ds di si dx cx bx ax                 ; load condition of registers

                 db 0eah                        ; jmp to next handler
    OldHdlrAddr  dw 0h                          ; space for addr to next handler
    OldHdlrSeg   dw 0h


    iret
    endp






;======================================================================================================
;Comm: Print registers to ES:DI, DS:SI addr to reg name, color params AH, CX - num regs to print
;Entry: ES:DI, DS:SI, CX
;Exit: -
;Destr: DI, SI, CX
;======================================================================================================
PrintRegs proc

LOOP_REG:

    call PrintReg

    push si
    call PrintValue
    pop si
    add di, 160d - 14d        ; move to next line

    loop LOOP_REG

    ret
    endp
;======================================================================================================

;======================================================================================================
;Comm: Print value of registers stored in
;Entry:
;Exit: -
;Destr:
;======================================================================================================
PrintValue proc

    mov bx, sp              ; bx = stack_ptr
    add bx, TTL_REGS * 2    ; bx = stack_ptr + 8 * 2 (ss:[bx] == x[0])
    sub bx, NUM_REGS * 2    ; bx -= num_regs_to_show (ss:[bx] == x[num_reg])
    add cx, 2d              ; stack depth was 3
    shl cx, 1d
    add bx, cx              ; bx += counter * 2      (ss:[bx] == x[i])
    shr cx, 1d
    sub cx, 2d

    mov word ptr dx, ss:[bx]
    mov bx, dx

    mov si, offset Numbers
    push si

    mov dx, bx              ;first byte
    and dx, 0F000h
    shr dx, 12d

    add si, dx
    lodsb
    stosw

    pop si
    push si

    mov dx, bx              ;second byte
    and dx, 0F00h
    shr dx, 8d
    add si, dx
    lodsb
    stosw

    pop si
    push si

    mov dx, bx              ;third byte
    and dx, 00F0h
    shr dx, 4d
    add si, dx
    lodsb
    stosw

    pop si

    mov dx, bx              ;fourth byte
    and dx, 000Fh
    ;shr
    add si, dx
    lodsb
    stosw


    ret
    endp
;======================================================================================================

;======================================================================================================
;Comm: Print register to ES:DI, DS:SI addr to reg name, color params AH
;Entry: AH, ES:DI, DS:SI
;Exit: -
;Destr: DI, SI
;======================================================================================================
PrintReg proc

    lodsb
    stosw

    lodsb
    stosw

    lodsb
    stosw

    ret
    endp
;======================================================================================================




;======================================================================================================
;Comm: Color params AH, DS:BX addr of 9 byte char seq, DL - height, DH - width
;Entry: AH, DS:BX, DL, DH
;Exit: -
;Destr: AL, BX, CX, SI, DX, ES
;======================================================================================================
DrawTable proc

    xor cx, cx
    mov cl, dh                  ; width

    xor al, al                  ; al = 0
    push ax                     ; save ah

    mov ax, VIDEOSEG
    mov es, ax                  ; preapre to print chars

    mov ax, Y_POS * 160d        ; Y pos

    mov di, ax                  ; place 160dl to di

    mov ax, X_POS * 2           ; X pos

    add di, ax                  ; width things


    pop ax                      ; return ah (color attr)
    push di                     ; save video addr for next iteration
    mov si, bx                  ; symbol addr

    call DrawLine

    pop di                      ;
    mov cl, dl


    add bx, 3d                  ; "move" symbols
;---------------------------------

Loop2:
    push cx                     ; save counter

    add di, 160d
    push di                     ; save offset
    mov cl, dh                  ; prepare line counter
    mov si, bx                  ; symbol addr

    call DrawLine

    pop di                      ; load offset
    pop cx                      ; load counter

    loop Loop2

;---------------------------------

    add bx, 3d                  ; "move" symbols
    add di, 160d
    mov cl, dh                  ; prepare line counter
    mov si, bx                  ; symbol addr

    call DrawLine               ; draw final line

    ret
    endp

;======================================================================================================

;================================================================
;DrawLine
;Comm: Color params AH, DS:SI addr of 3 byte char seq, CX - length, ES:DI addr begin
;Entry: AH, DS:SI, CX, ES:DI
;Exit: -
;Destr: CX, SI, DI
;================================================================
DrawLine proc

    sub di, 2d

    lodsb                       ; load  first char
    stosw                       ; place first char

    lodsb                       ; load second char
    rep stosw                   ; until CX != 0 place second char

    lodsb                       ; load  third char
    stosw                       ; place third char

    ret
    endp
;================================================================
Style:      db 201, 205, 187, 186, 0, 186, 200, 205, 188
Registers:  db "ax:bx:cx:dx:si:di:ds:es:"
Numbers:    db "0123456789ABCDEF"

FileEnd:
end Start






