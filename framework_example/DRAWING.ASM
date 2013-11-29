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


; --- DATA SEGMENT -------------------------------------------------------------
.DATA        ; data segment, variables

oldVideoMode	db ?
hardOffset	dw 0
blocCounter dw 1
candyPos dw 305
movCandy dw 0
;0 if it has to be the last place as before (if it hasn't been eaten), 1 if it has to be the new place.
snake_size dw 4
snake dw 4 dup(0)

direction dw 1 ;0 for up, 1 for right, 2 for down, 3 for left
lastPlace dw 0 ;last known place of our block (should be a list later on?)
lastTime dw 0 ;last remembered time
delayTime dw 5

; --- SCREEN BUFFER ------------------------------------------------------------
.FARDATA?	; segment that contains the screenBuffer for mode 13h drawing
palette			db 768 dup(0)
screenBuffer	db 640 dup(?)	; the 64000 bytes for the screen

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
	mov snake[0], 200
	mov snake[2], 199
	mov snake[4], 198
	mov snake[6], 197
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
	mov		cx, 640 / 2 ;Het 'proces' moet 32k keer uitgevoerd worden
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
	mov bx, 32
	@divloop: ;kijkt simpelweg hoeveel keer bx in ax kan (gewoon div werkte niet)
	cmp ax, bx
	JL @done
	sub ax, bx
	inc cx
	jmp @divloop
	@done: ;na uitvoering hier: ax = 31, cx = 19 (want 639 = 32*19 + 31)
	xchg ax, cx ;ax krijgt uitkomt van deling en cx krijgt de rest
	mov bx, 3200
	push cx ;rest is 31
	xor dx, dx
	mul bx ;19*3200 = 60800
	pop cx
	push ax
	mov ax, 10
	xor dx, dx
	mul cx ;31 * 10 = 310
	pop bx
	add bx, ax ;60800 + 310 = 61110
	mov dx, ds:[si]
	mov ax, es:[bx]
	cmp dx, ax
	JE AFTERSTART
	xor dx, dx
	xor ax, ax
	xor ah, ah
	xor al, al
	START:
	mov	di, bx
	mov cx, 10
	mov	al, ds:[si]	; color
	cld
	rep	stosb	; draw 

	add bx, 320 ;lijn opschuiven naar beneden
	inc dx ;counter optellen
	mov ax, 10 ;hoogte van het vierkant
	cmp dx, ax
	JL START
	AFTERSTART:
	mov ax, 640
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

	;call CheckCollision

	call drawRandomRect

	; draw the screen buffer
	call 	updateScreen
	
	pop	ax
	ret	0
renderWorld ENDP

;Tekent een blokske van 10 bij 10
DrawSnake PROC NEAR ;USES: /, CHANGES: ax, bx, cx, dx, es, al
	push	bp
	mov	bp, sp

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
;
;	mov ax, [direction] ;0 for up, 1 for right, 2 for down, 3 for left
;	cmp ax, 0
;	jnz @F
;	sub [lastPlace], 32
;	@@:
;	cmp ax, 1
;	jnz @F
;	inc [lastPlace]
;	@@:
;	cmp ax, 2
;	jnz @F
;	add [lastPlace], 32
;	@@:
;	cmp ax, 3
;	jnz @F
;	dec [lastPlace]
;	@@:
;
;	mov di, [lastPlace]
;	add di, offset screenBuffer
;	mov al, 15
;    mov cx, [bp + 4][0]
;	cld
;	rep	stosb	; draw 
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

drawRandomRect PROC NEAR
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
	mov bx, 640
	div bx
	mov ax, dx
	mov [candyPos], ax
	mov bx, 0
	mov [movCandy], bx ;it's a new position now, reset to 0, so it doesn't change again
	mov di, ax
	JMP @draw

	@oldRand:
	mov di, [candyPos]

	@draw:
	add di, offset screenBuffer
	mov al, 15
    mov cx, 1
	cld
	rep	stosb	; draw 

	pop bx
	pop dx
	pop ax

	ret 0
drawRandomRect ENDP


; Reads keyboard buffer and acts (returns non-zero if loop should end, 0 otherwise)
handleInput PROC NEAR
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

	;mov	ax, 32
	;sub [hardOffset], ax
	;sub [hardOffset], ax
	mov [direction], 0
@@:
	mov	al, es:[__keyboardState][SCANCODE_DOWN]	; test DOWN key
	cmp	al, 0
	jz @F	; jump next

	;mov	ax, 32
	;add [hardOffset], ax
	;add [hardOffset], ax
	mov [direction], 2
@@:
	mov	al, es:[__keyboardState][SCANCODE_LEFT]	; test LEFT key
	cmp	al, 0
	jz @F	; jump next

	;dec [hardOffset]
	;dec [hardOffset]
	mov [direction], 3
@@:
	mov	al, es:[__keyboardState][SCANCODE_RIGHT]	; test RIGHT key
	cmp	al, 0
	jz @F	; jump next

	;inc [hardOffset]
	;inc [hardOffset]
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

	inc [blocCounter]

@@:
	; finally, let's put the ESC key status as return value in AX
	mov	al, es:[__keyboardState][SCANCODE_ESC]	; test ESC

@done:
	pop	es
	ret 0
handleInput ENDP	

; Draw a rectangle at the center of the screen buffer.
; W, H passed on stack.
drawRect PROC NEAR
	push	bp
	mov	bp, sp
	
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	es
	
	; set segment
	mov	ax, seg screenBuffer
	mov	es, ax
	
	; Calculate posX
	mov	ax, [bp + 4][2] ;bp + 4 vanwege static en dynamic link, maar [2]? volgens mij om gewoon 2 bytes verder te gaan, waar de breedte is gezet bij renderWorld
	neg	ax
	add	ax, SCREENW
	shr	ax, 1  
	;UNSIGNED bitwise shift right, dus delen door 2
	;niet hetzelfde als sar, want sar is SIGNED
	mov	bx, ax		; posX is in BX now
	
	; Calculate posY
	mov	ax, [bp + 4][0]  ;bp + 4 vanwege static en dynamic link, maar [0]? volgens mij om gewoon 0 byes verder gegaan, waar de hoogte is gezet bij renderWorld
	neg	ax
	add	ax, SCREENH
	shr	ax, 1		; and posY is in AX
	
	; Calculate offset of top-left corner
	mov	dx, SCREENW
	mul	dx		; AX = posY (in AX) * SCREENW
	add	ax, bx		; BX contains posX, AX now contains start offset of rectangle
	add	ax, offset screenBuffer
	add	ax, [hardOffset] ;standaard offset in het begin ingesteld (word dat op 0 is gezet)
	
	; Draw upper horizontal line
	mov	di, ax
	mov	cx, [bp + 4][2]	; rect W
	mov	al, 15	; color
	cld
	rep	stosb	; draw	
	;STOSB gaat de byte in AL (dus de kleur) 
	;naar [ES:DI] of [ES:EDI] (dus de offset van de rectangle) verplaatsen
	;en de direction flag aanpassen (increment als de flag clear is, zoals nu, anders decrement)
	;En dit gaat hij CX keer doen (de breedte van de rechthoek)
	
	; Draw right vertical line	
	mov		cx, [bp + 4][0]	; rect H
	dec	di
	@@:
	mov	es:[di], al	; set pixel
	add	di, SCREENW	; jump to next pixel (on next line)
	loop	@B
	
	; Draw bottom horizontal line
	mov	cx, [bp+4][2]	; rect W
	std	; set direction flag to decrement di and si
	rep	stosb	; draw
	;STOSB gaat de byte in AL (dus de kleur) 
	;naar [ES:DI] of [ES:EDI] (dus de offset van de rectangle) verplaatsen
	;en de direction flag aanpassen (increment als de flag clear is, zoals nu, anders decrement)
	;En dit gaat hij CX keer doen (de breedte van de rechthoek)
	
	; Draw left vertical line
	mov	cx, [bp + 4][0]	; rect H
	inc di
	@@:
	mov	es:[di], al	; set pixel
	sub	di, SCREENW	; jump to next pixel (on next line)
	loop	@B

	; We are done
	pop	es
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	; return
	pop	bp
	ret	4
drawRect ENDP


; _------------------------------- END OF CODE ---------------------------------
END main
