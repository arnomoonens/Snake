; ==============================================================================
; Generic video functionality.
; ==============================================================================
.MODEL large	; multiple data segments and multiple code segments

; --- INCLUDES -----------------------------------------------------------------

INCLUDE video.inc

; --- MACROS AND CONSTANTS -----------------------------------------------------

; VGA DAC ports
PORT_VGA_DAC_READ	equ 03c7h	; write
PORT_VGA_DAC_WRITE	equ 03c8h	; write
PORT_VGA_DAC_DATA	equ 03c9h	; read/write

; --- CODE SEGMENT -------------------------------------------------------------
.CODE

; Set the video mode and returns the previous mode in AL.
setVideoMode PROC FAR
	push	bp				; save dynamic link
	mov		bp, sp			; update bp
	push	bx
	
	mov		ah, 0fh			; get current video mode in al
	int		10h
	
	mov		bx, ax
	
	mov		ax, [bp + 6][0]	; get requested mode
	xor		ah, ah			; function 0
	int		10h
	
	mov		ax, bx
	
	pop		bx
	pop		bp	
	retf	2				; return
setVideoMode ENDP

; _------------------------------- END OF CODE ---------------------------------
END
