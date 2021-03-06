.MODEL large										; multiple data segments and multiple code segments
.STACK 2048  										; stack

; --- INCLUDES -----------------------------------------------------------------

include VIDEO.INC
include RAND.INC
include KEYB.INC
include DRAWNUMB.INC

; --- MACROS AND CONSTANTS -----------------------------------------------------
SCREENW				equ 320
SCREENH				equ 200
BLOCKSINROW 		equ 32
ROWS				equ 18
SIZEOFBLOCK			equ 10 							; width and height of a block
BLOCKS 				equ BLOCKSINROW * ROWS
SCREENBUFFERSIZE 	equ ROWS * BLOCKSINROW * SIZEOFBLOCK * SIZEOFBLOCK
TEXTBUFFERSIZE		equ 64000 - SCREENBUFFERSIZE

; --- DATA SEGMENT -------------------------------------------------------------
.DATA        ; data segment, variables

oldVideoMode	db ?

candyPos 		dw 0 
candyColor 		db 0
movCandy 		dw 1 								; 0 if it has to be the last place as before (if it hasn't been eaten), 1 if it has to be the new place.


snake_size 		dw 5
snake 			dw BLOCKS dup(0)

direction 		dw 1 								; 0 for up, 1 for right, 2 for down, 3 for left
newDirection	dw 1 								; new direction 'proposed' by handleInput
lastTime 		dw 0 								; last remembered time
delayTime 		dw 6

SCORE			dw 0
SCORECHANGED	dw 1 								; used to know if you have to (re)draw the score or not
CANDYVALUE		dw 1 								; number added to the score when colliding with a candy

; --- TEXT BUFFER ------------------------------------------------------------
textBuffer	db TEXTBUFFERSIZE dup(?)
snakeBuffer	db BLOCKS dup(?)						; the 64000 bytes for the screen

; --- SCREEN BUFFER ------------------------------------------------------------
.FARDATA?											; segment that contains the screenBuffer for mode 13h drawing
screenBuffer	db SCREENBUFFERSIZE dup(?)			; the 64000 bytes for the screen

; --- CODE SEGMENT -------------------------------------------------------------
.CODE        										; code segment
main PROC NEAR
	mov		ax, @data								; get data segment address
	mov		ds, ax									; set DS to data segment

	; Initialize random number generator
	call	randInit
	
	; Install our own keyboard handler
	call	installKeyboardHandler
	
	; clear video buffer
	call	clearScreenBuffer
	call 	clearSnakeBuffer

	; draw the screen buffer
	call 	snakeToScreenBuffer
	call 	updateScreen
	
	; set mode 13h
	mov		ax, 13h
	push	ax
	call	setVideoMode
	mov		[oldVideoMode], al

	;Voor het programma start, stel lastTime in
	mov 	ah, 00h
	int 	1Ah 									; get time since startup
	mov 	[lastTime], dx
@main_loop:	
	mov 	ah, 00h
    int 	1Ah 									; get time since startup

	push 	dx
	sub 	dx, [lastTime]
	cmp 	dx, delayTime 							; if the difference between the last recorded time and the current time...
	pop 	dx
	JL 		@nextloop 								; .. is less than delayTime, then only look for input
	mov 	[lastTime], dx 							; otherwise, change the lastTime and do your thing

	call	renderWorld								; draws the world

	call	handleInput								; handle user input
	cmp		al, 0
	jz		@main_loop 								; no signal to end the game, do another loop
	jmp 	@game_end  								; otherwise: end of the game
	
@nextloop: 											; Not enough time has passed to move the blocks, but look for input to react to in the next 'useful' loop
	call 	handleInput
	cmp 	al, 0
	jz 		@main_loop 								; no signal to end the game, do another loop

@game_end:
	; Restore original keyboard handler
	call	uninstallKeyboardHandler

	; Restore original video mode
	mov		al, [oldVideoMode]
	xor		ah, ah
	push	ax
	call	setVideoMode
	
	; Exit to DOS
	mov		ax, 4c00h								; exit to DOS function, return code 00h
	int		21h										; call DOS
main ENDP

													; Clears the screen buffer to color 0
clearScreenBuffer PROC NEAR
	push	ax
	push	cx
	push	di
	push	es
	
	cld 											; Clear direction flag
	mov		ax, seg screenBuffer 					; wijs met ax naar het segment van de screenBuffer
	mov		es, ax 									; zet es naar ax, dus de screenBuffer
	mov		di, offset screenBuffer
	mov		cx, SCREENBUFFERSIZE / 2 				; Het 'proces' moet 320 keer uitgevoerd worden
	xor		ax, ax 									; ax wordt op nul gezet, omdat deze waarde gebruikt wordt door stosw
	rep		stosw 									; herhaal stosw cx keer. Stosw zet es:di op ax
	
													; Haal de overschreven waarden terug
	pop		es
	pop		di
	pop		cx
	pop		ax
	ret		0
clearScreenBuffer ENDP

clearSnakeBuffer PROC NEAR
	push	ax
	push	cx
	push	di
	push	es
	
	cld 											; Clear direction flag
	mov		ax, seg snakeBuffer 					; wijs met ax naar het segment van de screenBuffer
	mov		es, ax 									; zet es naar ax, dus de screenBuffer
	mov		di, offset snakeBuffer
	mov		cx, BLOCKS / 2 							; Het 'proces' moet 320 keer uitgevoerd worden
	xor		ax, ax 									; ax wordt op nul gezet, omdat deze waarde gebruikt wordt door stosw
	rep		stosw 									; herhaal stosw cx keer. Stosw zet es:di op ax
	
													; Haal de overschreven waarden terug
	pop		es
	pop		di
	pop		cx
	pop		ax
	ret		0
clearSnakeBuffer ENDP

updateTextScreen PROC NEAR
	push	ax
	push	cx
	push	dx
	push	si
	push	di
	push	ds
	push	es
	
													; setup source and dest segments
	mov		ax, seg textBuffer
	mov		ds, ax
	mov		si, offset textBuffer
	mov		ax, 0a000h								; video memory
	mov		es, ax
	
	mov 	ax, ROWS
	xor 	dx, dx
	mov 	bx, BLOCKSINROW
	mul 	bx
	mov 	bx, SIZEOFBLOCK
	mul 	bx
	mul 	bx
	mov 	di, ax
	
	cld
	mov		cx, TEXTBUFFERSIZE / 2
	waitVBlank										; wait for a VB (modifies AX and DX)
	rep		movsw									; blit to screen	
	
	pop		es
	pop		ds
	pop		di
	pop		si
	pop		dx
	pop		cx
	pop		ax
	ret		0
updateTextScreen ENDP

drawScore PROC NEAR
	push 	bp
	mov 	bp, sp

	push 	ax
	push 	bx
	push 	cx
	push 	dx
	push 	ds
	push 	es

	mov		ax, @data								; get data segment address
	mov		ds, ax									; set DS to data segment

	mov 	ax, seg textBuffer
	mov 	es, ax

	mov 	ax, offset textBuffer					; begin position to draw a number
	add 	ax, 10
	push 	ax
		
	mov 	ax, [SCORE]
	mov 	cx, 10000
	mov 	bx, 10

@loop:
	cmp 	cx, 1 									; vergelijk cx met 1
	je 		@end 									; als cx 1 is, ga dan naar het laatste geval
	xor 	dx, dx 									; zet dx op 0, anders probleem met deling hieronder
	div 	cx 										; deel ax met cx, geeft 1 cijfer
	mov		bx, ax									; load offset address of msg (in data segment)
	pop 	ax
	push 	ax
	call	drawnumber
	push 	dx 										; zet dx op de stack (bevat de rest van de deling)
	xor 	dx, dx 									; zet dx op 0, anders probleem met deling hieronder
	mov 	ax, cx									; ax wordt de cx, wat 10, 100,... is
	mov 	bx, 10
	DIV 	bx 										; deel ax door 10
	mov 	cx, ax 									; resultaat komt terug in het originele
	pop 	dx 										; krijg dx terug
	pop 	ax
	add 	ax, 23
	push 	ax
	mov 	ax, dx 									; ax wordt de rest van de deling
	jmp 	@loop

@end: 												; printen van laatste karakter
	mov		bx, ax									; load offset address of msg (in data segment)
	pop 	ax
	call 	drawnumber

	pop 	es
	pop 	ds
	pop 	dx
	pop 	cx
	pop 	bx
	pop 	ax

	pop 	bp
	ret 	0
drawScore ENDP

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
	mov		ax, 0a000h								; video memory
	mov		es, ax
	xor		di, di									; start at pixel 0
	
	cld
	mov		cx, SCREENBUFFERSIZE / 2
	waitVBlank										; wait for a VB (modifies AX and DX)
	rep		movsw									; blit to screen	
	
	pop		es
	pop		ds
	pop		di
	pop		si
	pop		dx
	pop		cx
	pop		ax
	ret		0
updateScreen ENDP
													; Updates the screenBuffer (copies contents from snakeBuffer to screenBuffer)
snakeToScreenBuffer PROC NEAR
	push	ax
	push	cx
	push	dx
	push	si
	push	di
	push	ds
	push	es
	
													; setup source and dest segments
	mov		ax, seg snakeBuffer
	mov		ds, ax
	mov		si, offset snakeBuffer
	mov		ax, seg screenBuffer					; video memory
	mov		es, ax
	mov		di, offset screenBuffer					; start at pixel 0

@displayloop: 										; Bloknr
	mov 	ax, si
	sub 	ax, offset snakeBuffer 					; Formule bloknr->beginpixel (zie numbers file): (Afrondennaarbeneden(Bloknr/32) * 3200) + (rest(Bloknr/32) * 10)
	mov 	bx, BLOCKSINROW

	xor 	dx, dx
	div 	bx
	mov 	cx, dx
@done: 												
	mov 	bx, BLOCKSINROW * SIZEOFBLOCK * SIZEOFBLOCK
	push 	cx 									
	xor 	dx, dx
	mul 	bx 									
	pop 	cx
	push 	ax
	mov 	ax, SIZEOFBLOCK
	xor 	dx, dx
	mul 	cx 									
	pop 	bx
	add 	bx, ax 									

	xor 	dx, dx
	xor 	ax, ax
	xor 	ah, ah
	xor 	al, al
START:
	mov		di, bx
	add 	di, offset screenBuffer
	mov 	cx, SIZEOFBLOCK
	mov		al, ds:[si]								; color
	cld
	rep		stosb									; draw 

	add 	bx, SCREENW 							; go one line down
	inc 	dx 										; increase counter
	mov 	ax, SIZEOFBLOCK 						; SIZEOFBLOCK is the height and the width of one block
	cmp 	dx, ax
	JL 		START
AFTERSTART:
	mov 	ax, BLOCKS
	inc 	si
	mov 	bx, si
	sub 	bx, offset snakeBuffer
	cmp 	bx, ax
	JL 		@displayloop



	xor 	al, al
	pop		es
	pop		ds
	pop		di
	pop		si
	pop		dx
	pop		cx
	pop		ax
	ret		0
snakeToScreenBuffer ENDP

updateWorld PROC NEAR
	ret 	0
updateWorld ENDP

renderWorld PROC NEAR 								; zegt wat er allemaal in het scherm moet komen (hier does een rechthoek dmv call drawRect)
	call 	clearScreenBuffer
	call 	clearSnakeBuffer

	call 	updateSnake
	call 	DrawSnake 								; Tekent vierkant van 10 bij 10 erges vast op het scherm
	
	call 	CheckCandyCollision
	call 	CheckSelfCollision

	call 	drawCandy

	; draw the screen buffer
	call 	snakeToScreenBuffer

	call 	updateScreen

	cmp 	[SCORECHANGED], 0
	jz 		@dontdrawscore
	call 	drawScore
	call 	updateTextScreen
	mov 	[SCORECHANGED], 0 						; has to be 0 in fact
	
@dontdrawscore:
	ret		0
renderWorld ENDP

CheckCandyCollision PROC NEAR 						; checks between head & candy: draws another candy somewhere else and increases snake length by 1 (not done yet)
	push	bp
	mov 	bp, sp
	push 	ax

	mov 	ax, snake[0]							; set ax to the position of the head of the snake
	cmp 	[candyPos], ax 							; compare position of the candy with the position of the head of the snake
	jne 	@done 									; If their positions aren't equal: do nothing
	inc 	movCandy 								; else: move the candy to a random place
	mov 	ax, [CANDYVALUE]
	add 	[SCORE], ax
	mov 	[SCORECHANGED], 1
	call 	addToSnake								; and increase the snake length

@done:
	pop 	ax
	pop 	bp
	ret 	0
CheckCandyCollision ENDP

CheckSelfCollision PROC NEAR 						; check collision of the head with the rest of the snake body
	push 	bp
	mov 	bp, sp

	xor 	dx, dx
	mov 	bx, [snake_size]
	mov 	ax, 2
	mul 	bx
	mov 	dx, ax

	mov 	ax, snake[0] 							; position of the head
	mov 	cx, 2
@loop:
	mov 	bx, cx
	mov 	bx, snake[bx]
	cmp 	ax, bx
	je 		@collision
	add 	cx, 2
	cmp 	cx, dx
	jne 	@loop
	jmp 	@done
@collision:											; reset
	mov 	[SCORE], 0
	mov 	[SCORECHANGED], 1
	mov 	[newDirection], 1
	mov 	[movCandy], 1
	mov 	cx, [snake_size]
	dec 	cx
@resetloop:
	mov 	bx, cx
	mov 	snake[bx], 0
	dec 	cx
	cmp 	cx, 0
	jge 	@resetloop
	mov 	[snake_size], 5
	mov 	[delayTime], 6
@done:
	pop 	bp
	ret 	0
CheckSelfCollision ENDP

DrawSnake PROC NEAR
	push	bp
	mov		bp, sp

	push 	ax
	push 	dx
	push 	bx
	push 	es
	push 	cx
	push 	di

	mov 	ax, seg snakeBuffer
	mov 	es, ax
	xor 	bx, bx

	mov 	bx, 0
	mov 	cx, snake_size
@loop:
	mov 	di, snake[bx]
	add 	di, offset snakeBuffer
	mov 	al, 15
	mov 	es:[di], al
	dec 	cx
	add 	bx, 2
	cmp 	cx, 0
	jnz 	@loop

	pop 	di
	pop 	cx
	pop 	es
	pop 	bx
	pop 	dx
	pop 	ax

	pop		bp
	ret 	0										; zorgt ervoor dat de stack in orde gemaakt word bij returnen van functie
DrawSnake ENDP

updateSnake PROC NEAR
	push 	bp
	mov 	bp, sp
	push 	ax
	push 	cx
	push 	dx

	mov 	cx, [snake_size]
	xor 	dx, dx
													; Begin bij het laatste element = snake_size * 2 - 2
	mov 	ax, 2
	MUL 	cx
	mov 	cx, ax
	sub 	cx, 2
@changeloop:
	cmp 	cx, 0
	jz 		@endloop
	mov 	bx, cx
	push 	bx
	sub 	bx, 2
	mov 	ax, snake[bx]
	pop 	bx
	mov 	snake[bx], ax 							; zet het coordinaat van het huidg element op dat van het vorig element
	sub 	cx, 2
	jmp 	@changeloop
@endloop:
	mov 	ax, [newDirection]
	mov 	[direction], ax
													; Het eerste element bewegen wwe naargelang de [direction]
	mov 	ax, [direction] 						; 0 for up, 1 for right, 2 for down, 3 for left
	cmp 	ax, 0
	jne 	checkRight
	mov 	ax, snake[0]
	sub 	ax, BLOCKSINROW
	cmp 	ax, 0
	jge 	normalUp
	add 	ax, BLOCKS
	mov 	snake[0], ax
	jmp 	done
normalUp:
	sub 	snake[0], BLOCKSINROW
	jmp 	done

checkRight:
	cmp 	ax, 1
	jne 	checkDown
	mov 	ax, snake[0]
	mov 	cx, ax
	mov 	bx, 32
	xor 	dx, dx
	div 	bx
	mov 	ax, dx
	cmp 	ax, 31
	jne 	normalRight
	mov 	ax, cx
	mov 	bx, BLOCKSINROW
	dec 	bx
	sub 	ax, bx
	mov 	snake[0], ax
	jmp 	done
normalRight:
	inc 	snake[0]
	jmp 	done

checkDown:
	cmp 	ax, 2
	jne 	checkLeft
	mov 	ax, snake[0]
	add 	ax, BLOCKSINROW
	cmp 	ax, BLOCKS
	jle 	normalDown
	sub 	ax, BLOCKS
	mov 	snake[0], ax
	jmp 	done
normalDown:
	add 	snake[0], BLOCKSINROW
	jmp 	done

checkLeft:
	cmp 	ax, 3
	jne 	done
	mov 	ax, snake[0]
	mov 	cx, ax
	mov 	bx, BLOCKSINROW
	xor 	dx, dx
	div 	bx
	mov 	ax, dx
	cmp 	ax, 0
	jne 	normalLeft
	mov 	ax, cx
	mov 	bx, BLOCKSINROW
	dec 	bx
	add 	ax, bx
	mov 	snake[0], ax								; put head on new position
	jmp 	done
normalLeft:
	dec 	snake[0]

done:
	pop 	dx
	pop 	cx
	pop 	ax
	pop 	bp

	ret 	0
updateSnake ENDP
	
addToSnake PROC NEAR 									; add a block to the snake (= increase snake size)
	inc 	[snake_size] 								; simply increase the variable. In the next execution of updateSnake, the block will be placed where the previous block was before
	ret 	0
addToSnake ENDP

drawCandy PROC NEAR
	push 	ax
	push 	dx
	push 	bx

	mov 	ax, seg snakeBuffer
	mov 	es, ax

	mov 	ax, [movCandy]
	cmp 	ax, 0
	JE 		@oldRand

@newRand:
	call 	rand
	mov 	bx, BLOCKS
	div 	bx
	mov 	ax, dx
	mov 	[candyPos], ax
	mov 	bx, 0
	mov 	[movCandy], bx 								; it's a new position now, reset to 0, so it doesn't change again
	mov 	di, ax

	call 	rand 										; To get a random color for the candy
	mov 	bx, 14
	xor 	dx, dx
	div 	bx
	inc 	dx
	mov 	[candyColor], dl
	JMP 	@draw
@oldRand:
	mov 	di, [candyPos]
@draw:
	add 	di, offset snakeBuffer
	mov 	al, [candyColor]
    mov 	es:[di], al									; draw 

	pop 	bx
	pop 	dx
	pop 	ax

	ret 	0
drawCandy ENDP
														; Reads keyboard buffer and acts (returns non-zero if loop should end, 0 otherwise)
handleInput PROC NEAR 									; contains a bug: if, for example, the snake is going up and you press right and down between 2 "draws", the snake will go from up to down (which isn't allowed)
	push	es
	mov		ax, seg __keysActive
	mov		es, ax

	xor		ah, ah
	mov		al, es:[__keysActive]
	cmp		al, 0
	jz		@done		; no key pressed

	; handle keys
	mov		al, es:[__keyboardState][SCANCODE_UP]		; test UP key
	cmp		al, 0
	jz 		@F											; jump next
	cmp 	[direction], 2
	je 		@F
	mov 	[newDirection], 0
@@:
	mov		al, es:[__keyboardState][SCANCODE_DOWN]		; test DOWN key
	cmp		al, 0
	jz 		@F											; jump next
	cmp 	[direction], 0
	je 		@F
	mov 	[newDirection], 2
@@:
	mov		al, es:[__keyboardState][SCANCODE_LEFT]		; test LEFT key
	cmp		al, 0
	jz 		@F											; jump next

	cmp 	[direction], 1
	je 		@F
	mov 	[newDirection], 3
@@:
	mov		al, es:[__keyboardState][SCANCODE_RIGHT]	; test RIGHT key
	cmp		al, 0
	jz 		@F											; jump next
	cmp 	[direction], 3
	je 		@F
	mov 	[newDirection], 1
@@:			
	mov 	al, es:[__keyboardState][SCANCODE_TAB]
	cmp 	al, 0
	jz 		@F
	dec 	[delayTime]
@@:														; finally, let's put the ESC key status as return value in AX
	mov		al, es:[__keyboardState][SCANCODE_ESC]		; test ESC

@done:
	pop		es
	ret 	0
handleInput ENDP	

; _------------------------------- END OF CODE ---------------------------------
END main