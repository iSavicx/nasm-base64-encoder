	;; Writen by: Nicol Sebastian
	;; Last change: 20.11.2020

SECTION .data           ; Section containing initialised data
	Base64Table: db "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

SECTION .bss            ; Section containing uninitialized data
	OutBufLen:	equ 4
	OutBuf:		resb OutBufLen 	; reserve 4 bytes for output

	InBufLen:	equ 3		
	InBuf:		resb InBufLen 	; reserve 3 bytes for input


	
	
SECTION .text           ; Section containing code

global _start           ; Linker needs this to find the entry point!

_start:

	;; r8 to r11 (4registers) are going to hold the 4*6 bits
	;; r15 is the byte input counter
	xor rax, rax	      	; making sure rax is 0
	xor r15, r15		; making sure counter is 0
	call read		; Jump to read and read 3 Bytes of input
	cmp rax, 0		; Check if there was any input
	je exit			; If there was no input exit the program
	mov r15, rax		; moving counter to r15

	;; checking if there were 3 bytes as input, if not -> jump to make sure that non input bytes are set to 0
	cmp r15, 2		; check if there were only 2 bytes as input
	je clear1input		; if true, clear the last byte incase previous input is still there
	
	cmp r15, 1		; check if there was only 1 byte as input
	je clear2input		; if true, clear the last two bytes incase previous input is still there
retclear:	
	;; preping the registers
	xor r8, r8		; 0ing r8
	xor r9, r9		; 0ing r9
	xor r10, r10		; 0ing r10
	xor r11, r11		; 0ing r11
	
	;; masking the bits and saving input to the 4 registers
	mov r8, [InBuf]			; moving  input to to r8
	shr r8, 2				; shift because binary is little endian (1,2,4,8,16,32,64,128) and we only want first 6 bits
	and r8, 0x00003f		; masking to have first 6 bits (just incase there was other in r8)

	
	mov r9b, byte [InBuf]		; moving 1st byte to r9b
	shl r9, 8					; making room for next byte
	mov r9b, byte [InBuf+1]		; adding next byte to r9b
	shr r9, 4					; moving next 6 bits to first 6 bits position
	and r9, 0x00003f			; masking to have only first 6 bits (incase other input was in r9)


	cmp r15, 1			; check if there was only 1 byte as input
	je move				; jump to writing to output buffer
	
	mov r10b, byte[InBuf+1]		; moving input to r10b
	shl r10, 8					; making space for next byte
	mov r10b, byte[InBuf+2]		; adding next byte
	shr r10, 6					; moving next 6 bits to first 6 bits position
	and r10, 0x00003f			; masking to have only first 6 bits (incase other input was in r10)

	cmp r15, 2			; check if there was only 2 byte as input
	je move				; jump to writting to output buffer

	mov r11b, byte [InBuf+2]	; moving input to r10
	and r11, 0x00003f			; masking to have first 6 bits (incase other input was in r11)


	;; and look up corresponing base64 char and writing to output buffer
move:	
	mov r8b, byte [Base64Table+r8] 	; geting the corresponsing base 64 char
	mov byte [OutBuf], r8b	      	; writing it to output buffe

	mov r9b, byte [Base64Table+r9] 	; geting the corresponsing base 64 char
	mov byte [OutBuf+1], r9b      	; writing it to output buffer

	cmp r15, 1						; check if there was only 1 byte instead of 3 for input
	je addtwoequals					; if true jump to addtwoequals to add == for last two output bytes
rettwo:	
	cmp r15, 1						; check again if input was only 1 byte
	je gowrite						; if true jump to go write
	
	mov r10b, byte [Base64Table+r10]	; geting the corresponsing base 64 char
	mov byte [OutBuf+2], r10b      		; writing it to output buffer
	
	cmp r15, 2						; check if there were two bytes instead of 3 as input
	je addoneequals					; if true jump to addtwoequals to add an = operator for the last byte
retone:	
	cmp r15, 2						; check again if input was only 2 bytes
	je gowrite						; if true jump to gowrite
	
	mov r11b, byte [Base64Table+r11]	; geting the corresponsing base 64 char
	mov byte [OutBuf+3], r11b	      	; writing it to output buffer
	
	
gowrite:	
	call write 			; write output buffer to standard output
	jmp _start 			; loop to check for more input 


exit:	
	mov rax, 60         		; Code for exit
	mov rdi, 0          		; Return a code of zero
	syscall             		; Make kernel call


;;;  Processes are written below

read:
	;;  Read from stdin to InBuf
	mov rax, 0                      ; sys_read
	mov rdi, 0                      ; file descriptor: stdin
	mov rsi, InBuf                  ; destination buffer
	mov rdx, InBufLen               ; maximum # of bytes to read
	syscall							; Make kernal call
	ret

write:
	mov rax, 1                      ; sys_write
	mov rdi, 1                      ; file descriptor: stdout
	mov rsi, OutBuf                 ; source buffer
	mov rdx, OutBufLen        		; # of bytes to write
	syscall							; make kernal call
	ret								; return to code right after the call

addoneequals: 						; you only jump here if 1 byte is missing
	mov byte [OutBuf+3], '='		; add one "=" sign to the last byte in the output buffer
	jmp retone						; jump to retone label
	
addtwoequals:						; you only jump here if 2 bytes are missing
	mov byte [OutBuf+2], '='		; add equals sign to second to last byte position of output
	mov byte [OutBuf+3], '='		; add equals sign to last byte position of output
	jmp rettwo						; jump to rettwo label

;;; if there are not 3 bytes as input, fill up the input buffer bytes
;;; to make sure there is no overflow from previous input
clear1input:
	push rcx						; saving rcx just incase
	xor rcx, rcx					; making rcx (and by that cl) = 0	 
	mov byte [InBuf+2], cl 			; fill up the last bye with 0
	pop rcx							; restoring rcx just incase
	jmp retclear					; jump to "retclear"

clear2input:
	push rcx			; saving rcx just in case
	xor rcx, rcx			; making rcx (and by that cl) = 0
	mov byte [InBuf+1], cl	 	; fill up the second to last byte with 0
	mov byte [InBuf+2], cl		; fill up the last byte with 0
	pop rcx				; restoring rcx just in case
	jmp retclear			; jump to "retclear"
