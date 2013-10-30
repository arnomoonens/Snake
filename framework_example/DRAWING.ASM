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

hardOffset	dw 0 ; test variable

; --- SCREEN BUFFER ------------------------------------------------------------
.FARDATA?	; segment that contains the screenBuffer for mode 13h drawing
palette			db 768 dup(0)
screenBuffer	db 64000 dup(?)	; the 64000 bytes for the screen

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
	
@main_loop:	
	;call	updateWorld	; this would contain the game code (like AI)

	call	renderWorld	; draws the world
	
	call	handleInput	; handle user input
	cmp		al, 0
	jz		@main_loop
	
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
	mov		cx, 64000 / 2 ;Het 'proces' moet 32k keer uitgevoerd worden
	xor		ax, ax ;ax wordt op nul gezet, omdat deze waarde gebruikt wordt door stosw
	rep		stosw ;herhaal stosw cx keer. Stosw zet ex:di op ax
	
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
	
	cld
	mov		cx, 64000 / 2
	waitVBlank	; wait for a VB (modifies AX and DX)
	rep		movsw	; blit to screen	
	;Move word at address DS:(E)SI to address ES:(E)DI  
	;(ESI or SI depending on the address-size attribute of the instruction, 32 or 16, respectively)
	
	pop		es
	pop		ds
	pop		di
	pop		si
	pop		dx
	pop		cx
	pop		ax
	ret		0
updateScreen ENDP

renderWorld PROC NEAR
	push	ax
	
	call	clearScreenBuffer

	; draw a random rectangle
	call	rand ;laat een willekeurige waarde in AX achter
	and		ax, 0ffh ;0FFh = grootste nummer in HEX, nl 255
	push	ax
	call	rand ;laat een willekeurige waarde in AX achter
	and		ax, 07fh ;O7Fh = 127 in HEX, de helft van 0FFh
	push	ax
	;push 2 waarden op de stack en roep drawRect
	;deze 2 waarden zullen lengte en breedte zijn!
	call 	drawRect

	; draw the screen buffer
	call 	updateScreen
	
	pop	ax
	ret	0
renderWorld ENDP

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
	; call some function to handle this key
	mov	ax, SCREENW
	sub [hardOffset], ax
	sub [hardOffset], ax
@@:
	mov	al, es:[__keyboardState][SCANCODE_DOWN]	; test DOWN key
	cmp	al, 0
	jz @F	; jump next
	; call some function to handle this key
	mov	ax, SCREENW
	add [hardOffset], ax
	add [hardOffset], ax
@@:
	mov	al, es:[__keyboardState][SCANCODE_LEFT]	; test LEFT key
	cmp	al, 0
	jz @F	; jump next
	; call some function to handle this key
	dec [hardOffset]
	dec [hardOffset]
@@:
	mov	al, es:[__keyboardState][SCANCODE_RIGHT]	; test RIGHT key
	cmp	al, 0
	jz @F	; jump next
	; call some function to handle this key
	inc [hardOffset]
	inc [hardOffset]
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
	mov	ax, [bp + 4][2] ;bp + 4 vanwege static en dynamic link, maar [2]?????
	neg	ax
	add	ax, SCREENW
	shr	ax, 1  
	;UNSIGNED bitwise shift right, dus delen door 2
	;niet hetzelfde als sar, want sar is SIGNED
	mov	bx, ax		; posX is in BX now
	
	; Calculate posY
	mov	ax, [bp + 4][0]  ;bp + 4 vanwege static en dynamic link, maar [0]?????
	neg	ax
	add	ax, SCREENH
	shr	ax, 1		; and posY is in AX
	
	; Calculate offset of top-left corner
	mov	dx, SCREENW
	mul	dx		; AX = posY (in AX) * SCREENW
	add	ax, bx		; BX contains posX, AX now contains start offset of rectangle
	add	ax, offset screenBuffer
	add	ax, [hardOffset]
	
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
