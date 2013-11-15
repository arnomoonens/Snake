mov ax, 0 ;Ik wil blokje 0 vullen, maw coordinaat 0-9 op de 10 eerste lijnen (0->2889)
SIZE equ 10
SCREENW equ 320
SCREENH equ 200

CalculateCoordinate PROC NEAR
	mul ax, SIZE 
	push ax ;dit is de linksboven in origineel

	mov bx, SCREENW
	mul bx, SIZE ;10 lijntjes lager, dus 10*320, resultaat in AX
	mov bx, ax ;Zet AX in BX
	pop ax ;Vraag de vorige AX (linksboven)
	push ax ;Zet die terug op de stack maar..
	add ax, bx ;Tel er ook de 10 lijntes bij op
	push ax ;dit is linksonder in origineel

	mov bx, SIZE
	dec bx
	add ax, bx
	push ax ;dit is rechtsonder in origineel

	mov bx, SCREENW
	mul bx, SIZE ;Terug 10 lijntjes hoger, dus 10*320, result in AX
	mov bx, ax ; AX in BX zetten
	pop ax ;Vraag de vorige AX
	push ax ; Zet die terug op de stack maar
	sub ax, bx ;Trek er ook de 10 lijntjes vanaf
	push ax ;dit is rechtsboven in origineel

CalculateCoordinate ENDP