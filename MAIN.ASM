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
msg	db "THIS IS A SNAKE GAME$"

; --- SCREEN BUFFER ------------------------------------------------------------
.FARDATA?	; segment that contains the screenBuffer for mode 13h drawing
palette			db 768 dup(0)
screenBuffer	db 64000 dup(?)	; the 64000 bytes for the screen

; --- VARIABLES ------------------------------------------------------------
length DW 0
a DB 640 DUP(0) ;Maak een array aan (genaamd a), met een grootte van 640 elementen, elk met standaardwaarde 0
;0 wordt gebruikt om aan te duiden dat er niks in zit, 1 voor dat het een slang is en 2 dat er een snoepje zit

; --- CODE SEGMENT -------------------------------------------------------------