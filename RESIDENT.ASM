.model tiny
.code
org 100h

;-=-=-=-==--=-=-=-=-=-=-=-==-=
VIDEOSEG  equ 0b800h
Y_POS     equ 1d
X_POS     equ 72d
TBL_HGHT  equ 13d
TBL_WDTH  equ 7d
CLR_PRMS  equ 00101110b
NUM_REGS  equ 13d
TTL_REGS  equ 13d
;-=-=-=-==--=-=-=-=-=-=-=-==-=

;------------------------------------------------------------------------------------------------------

;-----------
    Start:
;-----------

;___________________________________________________________
;              09H Int Handler Intializer
;___________________________________________________________
        xor ax, ax
        mov es, ax              ; es = 0
        mov bx, 09h * 4         ; bx = 8 * 4, each int handler addr is made of 4 bytes

        cli                     ; do not allow to interrupt during these lines
        mov ax, es:[bx]         ; save old handler addr
        mov Old09HdlrAddr, ax
        mov ax, es:[bx+2]
        mov Old09HdlrSeg, ax

        mov es:[bx], offset KeyboardHandler
        push cs
        pop ax
        mov es:[bx+2], ax
        sti

;___________________________________________________________



;___________________________________________________________
;              08H Int Handler Intializer
;___________________________________________________________
        xor ax, ax
        mov es, ax              ; es = 0
        mov bx, 08h * 4         ; bx = 8 * 4, each int handler addr is made of 4 bytes

        cli                     ; do not allow to interrupt during these lines
        mov ax, es:[bx]         ; save old handler addr
        mov Old08HdlrAddr, ax
        mov ax, es:[bx+2]
        mov Old08HdlrSeg, ax

        mov es:[bx], offset TimerHandler
        push cs
        pop ax
        mov es:[bx+2], ax
        sti

;___________________________________________________________
;                           Exit
;___________________________________________________________

        mov ax, 3100h            ; exit and stay resident
        mov dx, offset FileEnd   ; set mem size
        shr dx, 4h               ; size /= 4
        inc dx                   ; size++
        int 21h                  ; dos_func




;______________________________________________________________________________________________________________________


;======================================================================================================
;Keyboard interupt handler
;Comm:
;Entry:
;Exit: -
;Destr:
;======================================================================================================
KeyboardHandler proc

    push ax bx cx dx si di ds                   ; save condition of registers

    push cs
    pop ds                                      ; ds in command segment

    mov ax, 0200h
    int 16h                                     ; get BIOS keyboard info
    and al, 04h                                 ; leaving only ctrl byte

    mov ah, al

    in al, 60h                                  ; get symbol from PPI port

;---------------------
    mov bl, byte ptr cs:Active

    cmp ax, 040fh                               ; 0fh == 'CTRL + Tab' scancode
    jne CheckEnd

    cmp bl, 1h                                  ;                   if (active == 1) active = 0;
    jne ActivateFrame

    mov byte ptr cs:Active, 0h                  ; Deactivate frame
    je CheckEnd

    ActivateFrame:                              ;                   else active = 1;
    mov byte ptr cs:Active, 1h                  ; Activate frame
;---------------------
CheckEnd:

    in al, 61h
    mov ah, al
    or al, 80h
    out 61h, al
    mov al, ah
    out 61h, al

    mov al, 20h
    out 20h, al

    pop ds di si dx cx bx ax                    ; load condition of registers


                 db 0eah                        ; jmp to next handler
    Old09HdlrAddr  dw 0h                        ; space for addr to next handler
    Old09HdlrSeg   dw 0h


    iret
    endp
;======================================================================================================


;======================================================================================================
;Timer interupt handler
;Comm:
;Entry:
;Exit: -
;Destr:
;======================================================================================================
TimerHandler proc

    push ax bx cx dx si di bp sp ds es ss       ; save condition of registers

    push cs
    pop ds                                      ; ds in command segment

    mov al, byte ptr cs:Active                  ; check run condition
    cmp al, 0h
    je HandlerEnd

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


    HandlerEnd:

    mov al, 20h
    out 20h, al

    pop ss es ds sp bp di si dx cx bx ax        ; load condition of registers

                 db 0eah                        ; jmp to next handler
    Old08HdlrAddr  dw 0h                        ; space for addr to next handler
    Old08HdlrSeg   dw 0h


    iret
    endp
;======================================================================================================





;======================================================================================================
;Comm: Print registers to ES:DI, DS:SI addr to reg name, color params AH, CX - num regs to print
;Entry: ES:DI, DS:SI, CX
;Exit: -
;Destr: DI, SI, CX
;======================================================================================================
PrintRegs proc

LOOP_REG:

    call PrintReg

    push si                   ; save si
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

    shl cx, 1d
    add bx, cx              ; bx += counter * 2      (ss:[bx] == x[i])
    shr cx, 1d


;-----------------------
    cmp cx, 2h              ; is printing cs?
    jne EndPrValueCS

    add bx, 26d             ; then move further

    EndPrValueCS:
;-----------------------

;-----------------------
    cmp cx, 1h              ; is printing ip?
    jne EndPrValueIP

    add bx, 26d             ; then move further

    EndPrValueIP:
;-----------------------


    mov word ptr dx, ss:[bx] ; load reg value
    mov bx, dx

;-----------------------
    cmp cx, 5d              ; is printing sp?
    jne EndPrValueSP

    add bx, 16d             ; then move further

    EndPrValueSP:
;-----------------------

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
Registers:  db "ax:bx:cx:dx:si:di:bp:sp:ds:es:ss:cs:ip:"
Numbers:    db "0123456789ABCDEF"
Active:     db 0

FileEnd:
end Start






