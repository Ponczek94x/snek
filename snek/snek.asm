; co musi byc
; czytamy ostatni kierunek ruchu
; ruch z dana czestotliwoscia
; trzymamy kolejkę FIFO kolejnych pozycji, czyscimy z konca chyba ze w jablko wejdziemy
; losujemy pozycje jabłka


; kolejka FIFO przy użyciu stosu o maksymalnej dlugosci (na razie 128)
; masz poczatek i koniec kolejki modulo
; eax to indeks pierwszego elementu
; ebx to indeks ostatniego elementu

section	.text
   global _start 

make_raw:					; to ustawia terminal na niekanoniczny
    ; zapisuje oryginalny termios
    mov eax, 54         ; ioctl
    mov ebx, 0          ; stdin
    mov ecx, 0x5401     ; TCGETS
    mov edx, old_termios
    int 0x80
	; bierze nowy termios
    mov eax, 54
    mov ebx, 0
    mov ecx, 0x5401
    mov edx, termios
    int 0x80

    ; wyłącz kanoniczny i echo
    mov eax, [termios + 12]
    and eax, ~0x00000002     ; ~ICANON
    and eax, ~0x00000008     ; ~ECHO
    mov [termios + 12], eax

    ; zastosuj
    mov eax, 54
    mov ebx, 0
    mov ecx, 0x5402     ; TCSETS
    mov edx, termios
    int 0x80

    ret

	

mod:		;eax to liczba przed i po modulo, ebx to modulo, musi byc pow2
	dec ebx
	and eax, ebx
	inc ebx
	ret


queue_push:		;w ecx jest element do popchniecia, cl to mniejsza część ecx
	mov eax, [queue_end]
	inc eax
	mov ebx, [queue_size]
	call mod
	mov [queue_end], eax
	mov [fifo_queue + eax * 4], ecx

	mov ebx, ecx		;bierze wspolrzedne ostatniego elementu
	mov byte [tab + ebx], 35				;hash

	ret


queue_pop:		
	mov eax, [queue_beg]
	mov ebx, [fifo_queue + eax*4]		;bierze wspolrzedne pierwszego elementu
	mov byte [tab + ebx], 46				;kropka

	;mov byte [fifo_queue + eax], 0
	inc eax
	mov ebx, [queue_size]
	call mod
	mov [queue_beg], eax

	ret

select_input:				
	mov dword [tv_sec], 0        	; 0 s
    mov dword [tv_usec], 500000     ; to liczy w mikrosekundach

    mov dword [fds], 1         ; bit 0 ustawion, czekaj na stdin

    mov eax, 142                    ; syscall: select
    mov ebx, 1                      ; nfds = 1 
    mov ecx, fds                    ; readfds
    mov edx, 0                      ; writefds = null
    mov esi, 0                      ; exceptfds = null
    mov edi, tv                     ; timeout
    int 0x80

    cmp eax, 0
    jle .done                  ; bez inputu lub error, wtedy done


    ; czyta bajty inputu przez stdin
    mov eax, 3                 ; syscall read
    mov ebx, 0                 ; fd = stdin
    mov ecx, input_buf         ; bufor
    mov edx, 3                 ; czytaj max 3 bajty
    int 0x80

	mov al, [input_buf]
    cmp al, 27                 ; pierwszy bajt to ESC (27)
    jne .done                 ; ignoruj jeśli nie ESC

    mov al, [input_buf + 1]    ; drugi bajt
    cmp al, 91                 ; powinno być '['
    jne .done                 ; inaczej ignoruj

	mov al, [input_buf + 2]    ; trzeci bajt inputu
    cmp al, 65        ; góra
    je .up
    cmp al, 66        ; dół
    je .down
    cmp al, 67        ; prawo
    je .right
    cmp al, 68        ; lewo
    je .left
    jmp .done


; to ifuje strzałki
.up:
	cmp dword [diry], 1
	je .done

    mov dword [dirx], 0
    mov dword [diry], -1
    jmp .done

.down:
	cmp dword [diry], -1
	je .done

    mov dword [dirx], 0
    mov dword [diry], 1
    jmp .done

.left:
	cmp dword [dirx], 1 
	je .done

    mov dword [dirx], -1
    mov dword [diry], 0
    jmp .done

.right:
	cmp dword [dirx], -1 
	je .done

    mov dword [dirx], 1
    mov dword [diry], 0
    jmp .done

.done:
    ret




_start:	

	;inicjalizuje
	call make_raw

	mov ecx, 3
	call queue_push

	mov ecx, 4
	call queue_push

	mov ecx, 5
	call queue_push
	
	mov ecx, 6
	call queue_push

	mov ecx, 7
	call queue_push

	mov byte [tab+100], 64
	mov byte [tab+90], 64
	mov byte [tab+125], 64
	mov byte [tab+82], 64
	mov byte [tab+11], 64
	mov byte [tab+24], 64
	mov byte [tab+42], 64
	mov byte [tab+43], 64
	mov byte [tab+81], 64
	mov byte [tab+92], 64
	mov byte [tab+245], 64
	mov byte [tab+255], 64


	;czysci ekran na start
	mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, clear_screen
    mov edx, clear_len
    int 0x80

iter:
	; czyści klatkę

	mov eax, 4
	mov ebx, 1
	mov ecx, move_cursor_home  ; ESC[H
	mov edx, move_cursor_home_len
	int 0x80

    ;drukuje ekran

    xor esi, esi
	print_loop_y:				; wypisywanie w pętli

		xor edi, edi
		print_loop_x:

			mov eax, esi
			mov ebx, [tab_size]
			mul ebx
			add eax, edi

			
			
			lea ecx, [tab+eax]
			mov edx, 1
			cmp eax, [head_place]
			jne .skip
				mov ecx, head_symbol
				mov edx, head_len
			.skip:
			mov eax, 4
			mov ebx, 1 
			int 0x80		
			

			inc edi
		cmp edi, [tab_size]
		jl print_loop_x
		
		mov eax, 4
		mov ebx, 1 
		mov ecx, newline
		mov edx, 1
		int 0x80 

		inc esi
	cmp esi, [tab_size]
	jl print_loop_y

	; ustawia kierunek

	
	;mov eax, 162          	; syscall na nanosleep
    ;mov ebx, sleeptime		; wskaźnik na
    ;mov ecx, 0            	; rem = NULL (nie obchodzi nas pozostały czas)
    ;int 0x80              	

    call select_input

		
	; ruch

	mov eax, [queue_end]
	mov ebx, [fifo_queue + eax * 4]

	mov eax, ebx
	mov ecx, ebx
	mov ebx, [tab_size]
	call mod
	shr ecx, 4 			;do zmiany na 4, przesuniecie bitowe

	add eax, [dirx]		;eax to x, ecx to y
	call mod
	mov edx, eax
	mov eax, ecx		;eax to y
	add eax, [diry]
	call mod
	shl eax, 4   		;do zmiany na 4, przesuniecie bitowe
	add edx, eax			;edx to nowa pozycja
	mov ecx, edx

	mov [head_place], ecx

	mov eax, [tab + ecx]

	; sprawdza czy głowa uderza w ciało
	cmp al, 35
	jne _endif

		;mov eax, 54
    	;mov ebx, 0
    	;mov ecx, 0x5401
    	;mov edx, termios
    	;int 0x80
		mov eax, 54         ; ioctl			;przywraca domyślny tryb
		mov ebx, 0          ; stdin
		mov ecx, 0x5402     ; TCSETS
		mov edx, old_termios
		int 0x80

		mov eax, 1     ; syscall: exit
		xor ebx, ebx   ; exit code 0
		int 0x80


	_endif:


	; sprawdza czy głowa uderza w jabłko, jesli nie to nie wykonuje popa

	cmp al, 64
	jne endif3
		push eax
		push ebx
		push ecx
		push edx

		mov eax, 355      ; syscall na getrandom
    	mov ebx, buffer   ; bufor na dane
    	mov ecx, 8        ; 8 bajtów
   	 	mov edx, 0        ; blokuj na read
    	int 0x80         

		

		pop edx
		pop ecx
		pop ebx
		pop eax

	endif3:

	cmp al, 64
	je _endif2
		call queue_pop

	_endif2:
	call queue_push
	


jmp iter



; TODO: zmiana kierunku i jabłka

section .bss
    fds:			resd 1
    tv:				resq 1
	tv_sec:			equ tv
    tv_usec: 		equ tv + 4
    termios:        resb 36       	; bufor na nowe ustawienia terminala
	old_termios:    resb 36       	; bufor na stare ustawienia
	input_buf:	   	resb 3
	buffer:			resb 8     			; 8 bajtów na losowanie


section .data
	move_cursor_home: 		db 27, '[', 'H'
	move_cursor_home_len: 	equ $ - move_cursor_home
	clear_screen: 			db 0x1B, '[', '2', 'J', 0x1B, '[', 'H'
    clear_len:				equ $ - clear_screen

	red_color:			    db 27, '[', '1', ';', '3', '1', 'm', 0   ; ESC[31m
	green_color:			db 27, '[', '1', ';', '3', '2', 'm', 0   ; ESC[32m
	yellow_color:			db 27, '[', '1', ';', '3', '3', 'm', 0   ; ESC[33m
	reset_color:  			db 27, '[', '0', 'm'        ; ESC[0m

	queue_size: 			dd 512 							;powinno byc 128 ale na razie debug
	tab_power:				dd 4
	tab_size: 				dd 16
	fifo_queue:				times 512 dd 0
	queue_beg:				dd 0
	queue_end:				dd 0
	tab:					times 256 db 46	;tab size do kwadratu
	newline: 				db 10
	dirx:					dd 0
	diry:					dd -1

	head_symbol: 			db 0xE2, 0x98, 0xBB
	head_len:				equ $ - head_symbol

	grass:					db 46
	body:					db 35
	apple:					db 64

	head_place:				dd 7
	sleeptime:
		dd 1
		dd 0


 		
 