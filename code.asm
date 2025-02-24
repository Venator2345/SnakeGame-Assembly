; #################################
; #                               #
; # declaracao de variaveis       #
; #                               #
; #################################

section .data
	msg db 'ola mundo!',0xa
	msg_len equ $-msg
	
	posX db 0x20
	posY db 0x06
	
	player_body db '0'
	player_head db 'O'
	
	appleX db 0x30
	appleY db 0x7
	
	clear_char db ' '
	apple_char db 'M'
	border_char db '#'
	
	; y,x
	cursorPosTest db 27,'[10;20H',0
	
	timeval:
		tv_sec dd 0x0
		tv_nsec dd 0xbebc200 ;200000000
		
	snakeSize db 0x0
	snakeDirection db 0x0
	
	collisionMat db 0xffff dup(0)
	matXIndex db 0x0
	matYIndex db 0x0

segment .bss
	j resb 1
	i resb 2
	snakeBodyX resb 0xff
	snakeBodyY resb 0xff
	buffer resb 0x1
	
	term_settings resb 36
	
section .text
global _start

; #################################
; #                               #
; # funcoes para escrever na tela #
; #                               #
; #################################

; posiciona o cursor na coordenada desejada
; parametros: eax, ebx
goto_xy:
	mov esi,ebx
	;resolver y
	call number_to_string
	mov byte [cursorPosTest + 0x2],al
	mov byte [cursorPosTest + 0x3],ah
	
	;resolver x
	mov eax,esi
	call number_to_string
	mov byte [cursorPosTest + 0x5],al
	mov byte [cursorPosTest + 0x6],ah
	
	;posicionar cursor
	mov ecx, cursorPosTest
	mov edx,0x8
	call write
	ret

cursor_pos:
	mov eax,0x4
	mov ebx,0x1
	mov ecx, cursorPosTest
	mov edx,0x8
	int 0x80
	ret

; limpa a tela
clear_screen:
	mov word [i],0x0
	
	loop1:
	mov ax,[i]
	inc ax
	mov word [i],ax
	
	mov ecx, clear_char
	mov edx, 0x1
	call write
	
	mov ax,[i]
	cmp ax, 0x800
	jne loop1
	
	ret

; desenhar borda
draw_border:
	mov edi, 0x12
	loop_vertical:
	
	mov eax,edi 
	mov bl, 0x6
	call goto_xy
	mov ecx, border_char
	mov edx, 0x1
	call write
	
	mov eax,edi 
	mov bl, 0x40
	call goto_xy
	mov ecx, border_char
	mov edx, 0x1
	call write
	
	dec edi
	cmp edi,0x2
	jne loop_vertical
	
	mov edi, 0x40
	loop_horizontal:
	
	mov ebx,edi 
	mov al, 0x3
	call goto_xy
	mov ecx, border_char
	mov edx, 0x1
	call write
	
	mov ebx,edi 
	mov al, 0x12
	call goto_xy
	mov ecx, border_char
	mov edx, 0x1
	call write
	
	dec edi
	cmp edi,0x6
	jne loop_horizontal
	
	ret

; operacao de escrita na tela
write:
	mov eax,0x4
	mov ebx,0x1
	int 0x80
	ret

; #################################
; #                               #
; # procedimentos auxiliares      #
; #                               #
; #################################

; parametro: eax
; retorno: ah, al
number_to_string:
	mov bx,0xa
	div bl
	add al,'0'
	add ah,'0'
	ret

handler:
	mov eax, 0x3
	mov ebx, 0x0
	mov ecx, buffer
	mov edx, 0x1
	int 0x80
	
	ret
	
handle_inputs:
	mov eax, 0x3
	mov ebx, 0x0
	mov ecx, buffer
	mov edx, 1
	int 0x80
	
	cmp byte [buffer], 0x64 ;d
	jz right
	cmp byte [buffer], 0x73 ;s
	jz down
	cmp byte [buffer], 0x61 ;a
	jz left
	cmp byte [buffer], 0x77 ;w
	jz up
	jmp end_input_check
	
	right:
	mov byte [snakeDirection],0x0
	jmp end_input_check
	down:
	mov byte [snakeDirection],0x1
	jmp end_input_check
	left:
	mov byte [snakeDirection],0x2
	jmp end_input_check
	up:
	mov byte [snakeDirection],0x3
	
	end_input_check:
	
	ret;
	
move_head:
	cmp byte [snakeDirection], 0x0
	jz move_right
	cmp byte [snakeDirection], 0x1
	jz move_down
	cmp byte [snakeDirection], 0x2
	jz move_left
	cmp byte [snakeDirection], 0x3
	jz move_up
	jmp move_end_input_check
	
	move_right:
	inc byte [posX]
	jmp move_end_input_check
	move_down:
	inc byte [posY]
	jmp move_end_input_check
	move_left:
	dec byte [posX]
	jmp move_end_input_check
	move_up:
	dec byte [posY]
	
	move_end_input_check:
	
	
	; verificar colisao com corpo
	xor eax,eax
	xor ecx,ecx
	mov al, byte [posX]
	mov cl, byte [posY]
	mov byte [matXIndex], al
	mov byte [matYIndex], cl
	call calc_index
	mov al, byte[esi]
	cmp al, 0x1
	je end_game
	
	
	ret

; retorno ah = cobra comeu?
check_eat_apple:
	
	mov bh, byte[appleX]
	mov ch, byte[appleY]
	
	cmp bh, byte[posX]
	jne snake_hungry
	cmp ch, byte[posY]
	jne snake_hungry
	mov eax, 0x1
	jmp end_check_eat
	
	snake_hungry:
	xor eax, eax
	end_check_eat:
	ret
	
; verifica as condicoes de game over
check_game_over:
	; verificar bordas
	xor eax,eax
	xor ecx,ecx
	mov al, byte [posX]
	mov cl, byte [posY]
	
	cmp eax, 0x4
	jle end_game
	
	cmp eax, 0x40
	jge end_game
	
	cmp ecx, 0x3
	jle end_game
	
	cmp ecx, 0x12
	jge end_game
	
	ret
	
; calcula indice na matriz de colisao, retorno = esi
calc_index:
	mov esi, collisionMat 
	xor eax, eax
	xor ebx, ebx
	mov al, byte [matXIndex]
	mov ecx, 0x50
	mul cx
	add esi, eax
	mov bl, byte [matYIndex]
	add esi, ebx
	ret
	
; ajusta valor da matriz de colisao para 1, parametros matXIndex, matYIndex
set_collision_mat:
	call calc_index
	mov byte [esi], 0x1 
	ret
	
; ajusta valor da matriz de colisao para 0, parametros matXIndex, matYIndex
clear_collision_mat:
	call calc_index
	mov byte [esi], 0x0
	ret

; #################################
; #                               #
; # procedimentos para controle   #
; # do corpo da cobra             #
; #                               #
; #################################

; retorno ah = x, bh = y
front:
	mov ah, byte [snakeBodyX]
	mov bh, byte [snakeBodyY]
	ret

; parametros ah = novo x, bh = novo y
enqueue:
	xor edx, edx
	mov dl, byte [snakeSize]
	mov byte [snakeBodyX + edx], ah 
	mov byte [snakeBodyY + edx], bh 

	inc byte [snakeSize]
	ret
	
; retorno ah = x, bh = y
dequeue:
	call front
	push eax ; salvar registrador eax com o elemento da frente
	
	mov esi, snakeBodyX
	xor eax, eax
	mov al, byte [snakeSize]
	call rearrenge
	
	mov esi, snakeBodyY
	xor eax, eax
	mov al, byte [snakeSize]
	call rearrenge
	
	pop eax
	dec byte [snakeSize]
	ret

; parametro: esi = array, al = tamanho
rearrenge:
	mov word [i],0x0
	
	push ecx
	rearrenge_loop:
	mov ch, byte [esi+0x1]
	mov byte [esi], ch
	inc esi
	inc word [i]
	cmp ax, word [i]
	jne rearrenge_loop
	pop ecx
	
	ret

; #################################
; #                               #
; # procedimento principal        #
; #                               #
; #################################

_start:
	call clear_screen
	
	mov ah, 0x0
	mov al, byte [posY]
	mov bh, 0x0
	mov bl, byte [posX]
	call goto_xy

	;preencher corpo
	mov word[i], 0x4
	loop_preencher:
	mov al, 0x0
	mov ah, byte [posX]
	mov bl, 0x0
	mov bh, byte [posY]
	
	call enqueue
	
	mov ecx, player_head
	mov edx, 0x1
	call write
	inc byte[posX]
	
	xor eax, eax
	xor ebx, ebx
	mov al, byte[posX]
	mov bl, byte[posY]
	mov byte[matXIndex], al
	mov byte[matYIndex], bl
	call set_collision_mat
	
	dec word[i]
	xor cx,cx
	mov cx, word[i]
	cmp cx, 0x0
	jne loop_preencher
	
	; desenhar borda
	call draw_border
	
	; ativar modo nao bloqueante
	mov eax, 0x37
	mov ebx, 0x0
	mov ecx, 0x4
	mov edx, 0x800
	int 0x80
	
	;sem enter
	mov eax, 0x36
	mov ebx, 0x0
	mov ecx, 0x5402
	mov dword [term_settings], 0x0
	and dword [term_settings + 0xc], ~0x2
	mov edx, term_settings
	int 0x80
	
	;########################## logica principal ##########################
	game_loop:
	
	call check_game_over
	
	; desenhar cobra
	mov ah, 0x0
	mov al, byte [posY]
	mov bh, 0x0
	mov bl, byte [posX]
	call goto_xy
	mov ecx, player_head
	mov edx, 1
	call write
	
	; atualizar matriz de colisao
	xor eax, eax
	xor ebx, ebx
	mov al, byte[posX]
	mov bl, byte[posY]
	mov byte[matXIndex], al
	mov byte[matYIndex], bl
	call set_collision_mat
	
	; desenhar maca
	mov ah, 0x0
	mov al, byte [appleY]
	mov bh, 0x0
	mov bl, byte [appleX]
	call goto_xy
	mov ecx, apple_char
	mov edx, 0x1
	call write
	
	xor eax, eax
	xor ebx, ebx
	mov ah, [posX]
	mov bh, [posY]
	call enqueue
	
	; verificar se comeu a maca
	call check_eat_apple
	cmp eax, 0x1
	je ate_apple
	
	
	; atualizar matriz de colisao
	xor eax, eax
	xor ebx, ebx
	mov al, byte [snakeBodyX]
	mov bl, byte [snakeBodyY]
	mov byte[matXIndex], al
	mov byte[matYIndex], bl
	call clear_collision_mat
	
	; remover ultimo caractere
	xor eax, eax
	xor ebx, ebx
	mov bl, byte [snakeBodyX]
	mov al, byte [snakeBodyY]
	call goto_xy
	mov ecx, clear_char
	mov edx, 1
	call write
	call dequeue
	
	jmp did_not_eat_appe
	
	ate_apple:
	rdtsc
	and eax,0x19
	add eax,0x8
	mov byte [appleX],al
	rdtsc
	and eax,0x0a
	add eax,0x4
	mov byte [appleY],al
	
	did_not_eat_appe:
	
	; posicionar cursor fora da area do jogo e obter inputs
	mov ah, 0x0
	mov al, 0x17
	mov bh, 0x0
	mov bl, 0x1
	call goto_xy
	call handle_inputs
	
	call move_head
	
	mov eax, 0xa2
	mov ebx, timeval
	mov ecx, timeval
	int 0x80
	
	jmp game_loop
	;########################## fim do game loop ##########################
	
	end_game:
	mov eax,0x1
	xor ebx,ebx
	int 0x80
	
