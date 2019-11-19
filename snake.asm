;Se hace una equivalencia a los siguientes terminos porque se usan varias veces en el codigo, es como un #define
izquierda equ 0
techo equ 2
fila equ 22
columna equ 79
derecha equ izquierda+columna
piso equ techo+fila

.model small
.data          
    bienvenida db "Bienvenido al juego SNAKE!",0
    instrucciones db 0AH,0DH,"Use W, A, S, y D para controlar la serpiente",0AH,0DH,"Use Q en cualquier momento para salir",0DH,0AH, "Presione cualquier tecla para continuar$"
    finjuego db "Gracias por jugar!",0
    muerto db "GAME OVER! Su serpiente ha muerto! :( ", 0
    scoremsg db "Score: ",0
    head db '^',10,10                   ;la cabeza cambia de caracter segun la direccion a la que se dirija, ver mas adelante
    body db '*',10,11, 200 DUP(0)
    bodylength db 1
    foodactive db 1
    food_x db 8
    food_y db 8
    gameover db 0
    salir db 0   
    veloc_delay db 2


.stack 128
.code

main proc far
    mov ax, @data
    mov ds, ax 
    
    mov ax, 0b800H              ;acceso al inicio de la memoria de video
    mov es, ax
    
    call cls
    
    lea bx, bienvenida
    mov dx,00
    call writestringat
    
    lea dx, instrucciones
    mov ah, 09H
    int 21h
    
    mov ah, 07h
    int 21h
    call cls
    call print_bordes      
       
mainloop:       
    call delay             
    lea bx, bienvenida
    mov dx, 00
    call writestringat
    call shiftsnake
    cmp gameover,1
    je gameover_mainloop
    
    call keyboardfunctions
    cmp salir, 1
    je quitpressed_mainloop
    call fruitgeneration
    call draw
    
    jmp mainloop
    
cls proc                    ;se limpia la pantalla (clear screen)
    mov ax, 03H
    int 10h
    ret 

cls endp
    
gameover_mainloop: 
    call cls
    mov veloc_delay, 70
    mov dx, 0000H
    lea bx, muerto
    call writestringat
    call delay    
    jmp quit_mainloop    
    
quitpressed_mainloop:
    call cls  
    mov veloc_delay, 70
    mov dx, 0000H
    lea bx, finjuego
    call writestringat
    call delay    
    jmp quit_mainloop    

quit_mainloop:
call cls    
mov AH, 4CH         ;funcion exit
int 21h  

delay proc 
    
    ;se usa la interrupcion 1A, sacado de:
    ;http://www.computing.dcu.ie/~ray/teaching/CA296/notes/8086_bios_and_dos_interrupts.html
    mov ah, 00
    int 1Ah
    mov bx, dx
    
jmp_delay:
    int 1Ah
    sub dx, bx
    ;hay 18 ticks en un segundo, 10 ticks son suficiente como delay
    cmp dl, veloc_delay                                                      
    jl jmp_delay    
    ret
    
delay endp

fruitgeneration proc
    mov ch, food_y
    mov cl, food_x
regenerate:
    
    cmp foodactive, 1
    je ret_fruitactive
    mov ah, 00
    int 1Ah
    ;dx contiene los ticks del reloj del cpu
    push dx
    mov ax, dx
    xor dx, dx
    xor bh, bh
    mov bl, fila
    dec bl
    div bx
    mov food_y, dl
    inc food_y
       
    pop ax
    mov bl, columna
    dec dl
    xor bh, bh
    xor dx, dx
    div bx
    mov food_x, dl
    inc food_x
    
    cmp food_x, cl
    jne nevermind
    cmp food_y, ch
    jne nevermind
    jmp regenerate             
nevermind:
    mov al, food_x
    ror al,1
    jc regenerate
      
    add food_y, techo
    add food_x, izquierda 
    
    mov dh, food_y
    mov dl, food_x
    call readcharat
    cmp bl, '*'
    je regenerate
    cmp bl, '^'
    je regenerate
    cmp bl, '<'
    je regenerate
    cmp bl, '>'
    je regenerate
    cmp bl, 'v'
    je regenerate    
    
ret_fruitactive:
    ret
fruitgeneration endp

dispdigit proc
    add dl, '0'
    mov ah, 02H
    int 21H
    ret
dispdigit endp   
   
dispnum proc    
    test ax,ax
    jz retz
    xor dx, dx
    ;ax contiene el numero a mostrar
    ;bx debe ser 10 para la division
    mov bx,10
    div bx
    ;dispnum(mostrar numero) ax primero
    push dx
    call dispnum  
    pop dx
    call dispdigit
    ret
retz:
    mov ah, 02  
    ret    
dispnum endp   

;setea la posicion del cursor, se usa ax y bx, dh=fila, dl = columna

setcursorpos proc
    mov ah, 02H
    push bx
    mov bh,0
    int 10h
    pop bx
    ret
setcursorpos endp

draw proc
    lea bx, scoremsg
    mov dx, 0109
    call writestringat
    
    
    add dx, 7
    call setcursorpos
    mov al, bodylength
    dec al
    xor ah, ah
    call dispnum
        
    lea si, head
draw_loop:
    mov bl, ds:[si]
    test bl, bl
    jz out_draw
    mov dx, ds:[si+1]
    call writecharat
    add si,3   
    jmp draw_loop 

out_draw:
    mov bl, 'C'
    mov dh, food_y
    mov dl, food_x
    call writecharat
    mov foodactive, 1
    
    ret 
draw endp

;dl contiene el codigo ascii si se presiono una tecla, de lo contrario su valor es 0
;se usa dx y ax, se preservan los demas registros
readchar proc
    mov ah, 01H
    int 16H
    jnz keybdpressed
    xor dl, dl
    ret
keybdpressed:
    ;extraer la tecla presionada del buffer
    mov ah, 00H
    int 16H
    mov dl,al
    ret

readchar endp                       

keyboardfunctions proc
    
    call readchar
    cmp dl, 0
    je next_14
    
    ;identificar la tecla que se presiono para mover la serpiente de acuerdo a esto o tomar otra decision
    cmp dl, 77H     ;tecla W
    jne next_11
    cmp head, 'v'
    je next_14
    mov head, '^'
    ret
next_11:
    cmp dl, 73H     ;tecla S
    jne next_12
    cmp head, '^'
    je next_14
    mov head, 'v'
    ret
next_12:
    cmp dl, 61H     ;tecla A
    jne next_13
    cmp head, '>'
    je next_14
    mov head, '<'
    ret
next_13:
    cmp dl, 64H     ;tecla D
    jne next_14
    cmp head, '<'
    je next_14
    mov head,'>'
next_14:    
    cmp dl, 'q'
    je quit_keyboardfunctions
    ret    
quit_keyboardfunctions:   
    ;aqui iran las condiciones para salir  
    inc salir
    ret
    
keyboardfunctions endp
    
shiftsnake proc     
    mov bx, offset head
    
    ;determinar la direccion de la cabeza
    ;preservar la cabeza
    xor ax, ax
    mov al, [bx]
    push ax
    inc bx
    mov ax, [bx]
    inc bx    
    inc bx
    xor cx, cx
l:      
    mov si, [bx]
    test si, [bx]
    jz outside
    inc cx     
    inc bx
    mov dx,[bx]
    mov [bx], ax
    mov ax,dx
    inc bx
    inc bx
    jmp l
    
outside:    
    ;la serpiente va a cambiar de direccion
    ;se cambia la cabeza de posicion y luego se borra el ultimo segmento para hacer la ilusion de que se mueve
    ;si la serpiente consumio la comida entonces el ultimo segmento no se borra
    pop ax
    ;al contiene la direccion de la cabeza de la serpiente
    
    push dx
    ;dx ahora tiene las coordenadas del ultimo segmento, se usa dx para borrar el ultimo segmento
    
    lea bx, head
    inc bx
    mov dx, [bx]
    
    cmp al, '<'
    jne next_1
    dec dl
    dec dl
    jmp done_checking_the_head
next_1:
    cmp al, '>'
    jne next_2                
    inc dl 
    inc dl
    jmp done_checking_the_head
    
next_2:
    cmp al, '^'
    jne next_3 
    dec dh               
    jmp done_checking_the_head
    
next_3:
    ;debe ser 'v'
    inc dh
    
done_checking_the_head:    
    mov [bx],dx
    ;dx contiene la nueva posicion de la cabeza, se chequea que hay en esa posicion
    call readcharat ;dx
    ;bl contiene el resultado
    
    cmp bl, 'C'
    je i_ate_fruit
    
    ;si la comida no se consumio, entonces hay que borrar el ultimo segmento del cuerpo

    mov cx, dx
    pop dx 
    cmp bl, '*'    ;la serpiente choco con su propio cuerpo
    je game_over
    mov bl, 0
    call writecharat
    mov dx, cx

    ;verificar si la serpiente esta dentro de los limites o si esta chocando
    cmp dh, techo
    je game_over
    cmp dh, piso
    je game_over
    cmp dl,izquierda
    je game_over
    cmp dl, derecha
    je game_over
    
    ret
game_over:
    inc gameover
    ret
i_ate_fruit:    

    ; se agrega un nuevo segmento (se incrementa)
    mov al, bodylength
    xor ah, ah
    
    
    lea bx, body
    mov cx, 3
    mul cx
    
    pop dx
    add bx, ax
    mov byte ptr ds:[bx], '*'
    mov [bx+1], dx
    inc bodylength 
    mov dh, food_y
    mov dl, food_x
    mov bl, 0
    call writecharat
    mov foodactive, 0   
    ret 
shiftsnake endp
   
;Se imprimen los bordes o limitantes
print_bordes proc

    mov dh, techo
    mov dl, izquierda
    mov cx, columna
    mov bl, '*'
l1:                 
    call writecharat
    inc dl
    loop l1
    
    mov cx, fila
l2:
    call writecharat
    inc dh
    loop l2
    
    mov cx, columna
l3:
    call writecharat
    dec dl
    loop l3

    mov cx, fila     
l4:
    call writecharat    
    dec dh 
    loop l4    
    
    ret
print_bordes endp

;dx contiene fila, columna
;bl contiene el caracter que se va a escribir
;se usa di para la indicar la posicion 

writecharat proc
    ;80x25
    push dx
    mov ax, dx
    and ax, 0FF00H
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    
    push bx
    mov bh, 160
    mul bh 
    pop bx
    and dx, 0FFH
    shl dx,1
    add ax, dx
    mov di, ax
    mov es:[di], bl
    pop dx
    ret    
writecharat endp

;dx contiene fila, columna
;se retorna o se hace el caracter en BL
;se usa di para la indicar la posicion 

readcharat proc
    push dx
    mov ax, dx
    and ax, 0FF00H
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1    
    push bx
    mov bh, 160
    mul bh 
    pop bx
    and dx, 0FFH
    shl dx,1
    add ax, dx
    mov di, ax
    mov bl,es:[di]
    pop dx
    ret
readcharat endp        

;dx contiene fila, columna
;bx contiene el offset del string a imprimir
writestringat proc
    push dx
    mov ax, dx
    and ax, 0FF00H
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    
    push bx
    mov bh, 160
    mul bh
    
    pop bx
    and dx, 0FFH
    shl dx,1
    add ax, dx
    mov di, ax
loop_writestringat:
    
    mov al, [bx]
    test al, al
    jz exit_writestringat
    mov es:[di], al
    inc di
    inc di
    inc bx
    jmp loop_writestringat

exit_writestringat:
    pop dx
    ret
  
writestringat endp

main endp
end main