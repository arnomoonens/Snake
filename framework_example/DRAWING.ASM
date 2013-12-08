; ==============================================================================
; Example for buffered drawing in mode 13h.
; Example showing palette manipulation via port IO.
; Example for a very generic game-loop.
; ==============================================================================
.MODEL large	; multiple data segments and multiple code segments
.STACK 2048  	; stack

; --- INCLUDES -----------------------------------------------------------------

include VIDEO.INC
include RAND.INC
include KEYB.INC

; --- MACROS AND CONSTANTS -----------------------------------------------------

; Other constants	
SCREENW		equ 320
SCREENH		equ 200
BLOCKSINROW equ 32
ROWS		equ 18
SIZEOFBLOCK	equ 10
BLOCKS equ BLOCKSINROW * ROWS


; --- DATA SEGMENT -------------------------------------------------------------
.DATA        ; data segment, variables

oldVideoMode	db ?
hardOffset	dw 0
blocCounter dw 1
candyPos dw 0
candyColor db 0
movCandy dw 1
;0 if it has to be the last place as before (if it hasn't been eaten), 1 if it has to be the new place.
snake_size dw 5
snake dw BLOCKS dup(0)

direction dw 1 ;0 for up, 1 for right, 2 for down, 3 for left
lastPlace dw 100 ;last known place of our block (should be a list later on?)
lastTime dw 0 ;last remembered time
delayTime dw 5

; --- SCREEN BUFFER ------------------------------------------------------------
.FARDATA?	; segment that contains the screenBuffer for mode 13h drawing
palette			db 768 dup(0)
screenBuffer	db BLOCKS dup(?)	; the 64000 bytes for the screen

; --- CODE SEGMENT -------------------------------------------------------------
.CODE        ; code segment
main PROC NEAR
	mov	ax, @data	; get data segment address
	mov	ds, ax		; set DS to data segment

	; Initialize random number generator
	call	randInit
	
	; Install our own keyboard handler
	call	installKeyboardHandler

	; fade to black
	call	fadeToBlack
	
	; clear video buffer
	call	clearScreenBuffer

	; draw the screen buffer
	call 	updateScreen
	
	; set mode 13h
	mov		ax, 13h
	push	ax
	call	setVideoMode
	mov		[oldVideoMode], al

	;Voor het programma start, stel lastTime in
	mov ah, 00h
	int 1Ah
	mov [lastTime], dx
	;mov snake[0], 200
	;mov snake[2], 199
	;mov snake[4], 198
	;mov snake[6], 197
@main_loop:	
	;call	updateWorld	; this would contain the game code (like AI)

	mov ah, 00h
    int 1Ah ;get time since startup

	push dx
	sub dx, [lastTime]
	cmp dx, delayTime ;if the difference between the last recorded time and the current time...
	pop dx
	JL @nextloop ;.. is less than delayTime, then only look for input
	mov [lastTime], dx ;otherwise, change the lastTime and do your thing

	call	renderWorld	; draws the world

	call	handleInput	; handle user input
	cmp		al, 0
	jz		@main_loop ;no signal to end the game, do another loop
	jmp 	@game_end  ;otherwise: end of the game
	
	@nextloop: ;Not enough time has passed to move the blocks, but look for input to react to in the next 'useful' loop
	call handleInput
	cmp al, 0
	jz @main_loop ;no signal to end the game, do another loop

	@game_end:
	; Restore original keyboard handler
	call	uninstallKeyboardHandler

	; Restore original video mode
	mov		al, [oldVideoMode]
	xor		ah, ah
	push	ax
	call	setVideoMode
	
	; Exit to DOS
	mov		ax, 4c00h	; exit to DOS function, return code 00h
	int		21h			; call DOS
main ENDP

; Fades the active colors to black
fadeToBlack PROC NEAR
	push	ax

	mov	ax, seg palette
	push	ax
	mov	ax, offset palette
	push	ax
	call	paletteInitFade
@@:
	waitVBlank
	call	paletteNextFade
	test	ax, ax
	jnz	@B

	pop	ax
	ret 0
fadeToBlack ENDP

; Clears the screen buffer to color 0
clearScreenBuffer PROC NEAR
	push	ax
	push	cx
	push	di
	push	es
	
	cld ;Clear direction flag
	mov		ax, seg screenBuffer ; wijs met ax naar het segment van de screenBuffer
	mov		es, ax ;zet es naar ax, dus de screenBuffer
	mov		di, offset screenBuffer
	mov		cx, BLOCKS / 2 ;Het 'proces' moet 32k keer uitgevoerd worden
	xor		ax, ax ;ax wordt op nul gezet, omdat deze waarde gebruikt wordt door stosw
	rep		stosw ;herhaal stosw cx keer. Stosw zet es:di op ax
	
	;Haal de overschreven waarden terug
	pop	es
	pop	di
	pop	cx
	pop	ax
	ret	0
clearScreenBuffer ENDP

; Updates the screen (copies contents from screenBuffer to screen)
updateScreen PROC NEAR
	push	ax
	push	cx
	push	dx
	push	si
	push	di
	push	ds
	push	es
	
	; setup source and dest segments
	mov		ax, seg screenBuffer
	mov		ds, ax
	mov		si, offset screenBuffer
	mov		ax, 0a000h	; video memory
	mov		es, ax
	xor		di, di	; start at pixel 0
	waitVBlank
	mov ax, 0a000h
	mov es, ax
	@displayloop: ;Bloknr
	mov ax, si
	sub ax, offset screenBuffer ;Formule bloknr->beginpixel (zie numbers file): (Afrondennaarbeneden(Bloknr/32) * 3200) + (rest(Bloknr/32) * 10)
	mov bx, BLOCKSINROW
	@divloop: ;kijkt simpelweg hoeveel keer bx in ax kan (gewoon div werkte niet)
	cmp ax, bx
	JL @done
	sub ax, bx
	inc cx
	jmp @divloop
	@done: ;na uitvoering hier: ax = 31, cx = 19 (want 639 = 32*19 + 31)
	xchg ax, cx ;ax krijgt uitkomt van deling en cx krijgt de rest
	mov bx, BLOCKSINROW * SIZEOFBLOCK * SIZEOFBLOCK
	push cx ;rest is 31
	xor dx, dx
	mul bx ;19*3200 = 60800
	pop cx
	push ax
	mov ax, SIZEOFBLOCK
	xor dx, dx
	mul cx ;31 * 10 = 310
	pop bx
	add bx, ax ;60800 + 310 = 61110
	;mov dx, ds:[si]
	;mov ax, es:[bx]
	;cmp dx, ax
	;JE AFTERSTART
	xor dx, dx
	xor ax, ax
	xor ah, ah
	xor al, al
	START:
	mov	di, bx
	mov cx, SIZEOFBLOCK
	mov	al, ds:[si]	; color
	cld
	rep	stosb	; draw 

	add bx, SCREENW ;lijn opschuiven naar beneden
	inc dx ;counter optellen
	mov ax, SIZEOFBLOCK ;hoogte van het vierkant
	cmp dx, ax
	JL START
	AFTERSTART:
	mov ax, BLOCKS
	inc si
	mov bx, si
	sub bx, offset screenBuffer
	cmp bx, ax
	JL @displayloop

	xor al, al
	pop		es
	pop		ds
	pop		di
	pop		si
	pop		dx
	pop		cx
	pop		ax
	ret		0
updateScreen ENDP

renderWorld PROC NEAR ;zegt wat er allemaal in het scherm moet komen (hier does een rechthoek dmv call drawRect)
	push	ax
	
	call clearScreenBuffer

	mov ax, [blocCounter]
	push ax
	call updateSnake
	call DrawSnake ;Tekent vierkant van 10 bij 10 erges vast op het scherm

	call CheckCandyCollision
	call CheckSelfCollision

	call drawCandy

	; draw the screen buffer
	call 	updateScreen
	
	pop	ax
	ret	0
renderWorld ENDP

CheckCandyCollision PROC NEAR ;checks between head & candy: draws another candy somewhere else and increases snake length by 1 (not done yet)
	push	bp
	mov 	bp, sp

	mov ax, snake[0] ;set ax to the position of the head of the snake
	cmp [candyPos], ax ;compare position of the candy with the position of the head of the snake
	jne @done ;If their positions aren't equal: do nothing
	inc movCandy ;else: move the candy to a random place
	call addToSnake;and increase the snake length

	@done:
	pop bp
	ret 0
CheckCandyCollision ENDP

CheckSelfCollision PROC NEAR ;check collision of the head with the rest of the snake body
	push 	bp
	mov 	bp, sp

	xor dx, dx
	mov bx, [snake_size]
	mov ax, 2
	mul bx
	mov dx, ax

	mov ax, snake[0] ;position of the head
	mov cx, 2
	@loop:
	mov bx, cx
	mov bx, snake[bx]
	cmp ax, bx
	je @collision
	add cx, 2
	cmp cx, dx
	jne @loop
	jmp @done

	@collision:
	mov movCandy, 1 ;do something

	@done:
	pop 	bp
	ret 	0
CheckSelfCollision ENDP
;Tekent een blokske van 10 bij 10
DrawSnake PROC NEAR ;USES: /, CHANGES: ax, bx, cx, dx, es, al
	push	bp
	mov		bp, sp

	push ax
	push dx
	push bx
	push es
	push cx
	push di

	mov ax, seg screenBuffer
	mov es, ax
	mov dx, offset palette
	xor bx, bx
	mov cx, 2
	mov ax, 13h
	int 10h

	mov bx, 0
	mov cx, snake_size
	@loop:
	mov di, snake[bx]
	add di, offset screenBuffer
	mov al, 15
	mov es:[di], al
	dec cx
	add bx, 2
	cmp cx, 0
	jnz @loop

	pop di
	pop cx
	pop es
	pop bx
	pop dx
	pop ax

	pop	bp
	ret 2 ;zorgt ervoor dat de stack in orde gemaakt word bij returnen van functie
DrawSnake ENDP

updateSnake PROC NEAR
	push 	bp
	mov bp, sp
	push ax
	push cx
	push dx

	mov cx, [snake_size]
	xor dx, dx
	;Begin bij het laatste element = snake_size * 2 - 2
	mov ax, 2
	MUL cx
	mov cx, ax
	sub cx, 2
	@changeloop:
	cmp cx, 0
	jz @endloop
	mov bx, cx
	push bx
	sub bx, 2
	mov ax, snake[bx]
	pop bx
	mov snake[bx], ax ;zet het coordinaat van het huidg element op dat van het vorig element
	sub cx, 2
	jmp @changeloop
	@endloop:
	;Het eerste element bewegen wwe naargelang de [direction]
	mov ax, [direction] ;0 for up, 1 for right, 2 for down, 3 for left
	cmp ax, 0
	jnz @F
	mov bx, cx
	sub snake[bx], 32
	@@:
	cmp ax, 1
	jnz @F
	mov bx, cx
	inc snake[bx]
	@@:
	cmp ax, 2
	jnz @F
	mov bx, cx
	add snake[bx], 32
	@@:
	cmp ax, 3
	jnz @F
	mov bx, cx
	dec snake[bx]
	@@:

	pop dx
	pop cx
	pop ax
	pop bp

	ret 0
updateSnake ENDP

addToSnake PROC NEAR ;add a block to the snake (= increase snake size)
	inc [snake_size] ;simply increase the variable. In the next execution of updateSnake, the block will be placed where the previous block was before
	ret 0
addToSnake ENDP

drawCandy PROC NEAR
	push ax
	push dx
	push bx

	mov ax, seg screenBuffer
	mov es, ax
	mov dx, offset palette
	xor bx, bx
	mov cx, 2
	mov ax, 13h
	int 10h

	mov ax, [movCandy]
	cmp ax, 0
	JE @oldRand

	@newRand:
	call rand
	mov bx, BLOCKS
	div bx
	mov ax, dx
	mov [candyPos], ax
	mov bx, 0
	mov [movCandy], bx ;it's a new position now, reset to 0, so it doesn't change again
	mov di, ax

	call rand ;To get a random color for the candy
	mov bx, 14 ;Is this the right number (highest number for a color)? and does this include black color(s)?
	xor dx, dx
	div bx
	inc dx
	mov [candyColor], dl
	JMP @draw

	@oldRand:
	mov di, [candyPos]

	@draw:
	add di, offset screenBuffer
	mov al, [candyColor]
    mov es:[di], al	; draw 

	pop bx
	pop dx
	pop ax

	ret 0
drawCandy ENDP


; Reads keyboard buffer and acts (returns non-zero if loop should end, 0 otherwise)
handleInput PROC NEAR ;contains a bug: if, for example, the snake is going up and you press right and down between 2 "draws", the snake will go from up to down (which isn't allowed)
	push	es

	mov	ax, seg __keysActive
	mov	es, ax

	xor	ah, ah
	mov	al, es:[__keysActive]
	cmp	al, 0
	jz	@done		; no key pressed

	; handle keys
	mov	al, es:[__keyboardState][SCANCODE_UP]	; test UP key
	cmp	al, 0
	jz @F	; jump next
	cmp [direction], 2
	je @F
	mov [direction], 0
@@:
	mov	al, es:[__keyboardState][SCANCODE_DOWN]	; test DOWN key
	cmp	al, 0
	jz @F	; jump next

	cmp [direction], 0
	je @F
	mov [direction], 2
@@:
	mov	al, es:[__keyboardState][SCANCODE_LEFT]	; test LEFT key
	cmp	al, 0
	jz @F	; jump next

	cmp [direction], 1
	je @F
	mov [direction], 3
@@:
	mov	al, es:[__keyboardState][SCANCODE_RIGHT]	; test RIGHT key
	cmp	al, 0
	jz @F	; jump next

	cmp [direction], 3
	je @F
	mov [direction], 1
@@:
	mov	al, es:[__keyboardState][SCANCODE_TAB]	; test TAB key
	cmp	al, 0
	jz @F	; jump next

	inc [movCandy]
@@:
	mov	al, es:[__keyboardState][SCANCODE_BACKSPACE]	; test BACKSPACE key
	cmp	al, 0
	jz @F	; jump next

	call addToSnake
@@:
	; finally, let's put the ESC key status as return value in AX
	mov	al, es:[__keyboardState][SCANCODE_ESC]	; test ESC

@done:
	pop	es
	ret 0
handleInput ENDP	


; _------------------------------- END OF CODE ---------------------------------
END main
