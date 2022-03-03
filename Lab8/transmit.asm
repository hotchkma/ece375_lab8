;***********************************************************
;*
;*	This is the TRANSMIT skeleton file for Lab 8 of ECE 375
;*
;*	 Author: Matthew Hotchkiss, Michael <Last Name?>
;*	   Date: 2/24/2022
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register

.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit
; Use these action codes between the remote and robot
; MSB = 1 thus:
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBck =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnR =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnL =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	Halt =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt
.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
		ldi XH, high(RAMEND)
		ldi XL, low(RAMEND)
		out SPH, XH
		out	SPL, XL
	;I/O Ports
	;Initialize Port D for input (buttons)
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State
	;USART1
		; bit 1: double data rate
		ldi mpr, 0b00000010
		sts UCSR1A, mpr

		; bit 7: disable recieve interrupt
		; bit 6: enable transmit interrupt
		; bit 5: enable data reg. empty interrupt
		; bit 4: disable reciever
		; bit 3: enable transmitter
		; bit 2: character size bit 2 is 0 (8 = 011)
		ldi mpr, 0b01101000
		sts UCSR1B, mpr

		; bit 6: asynchronous mode
		; bit 5 & 4: parity disabled 
		; bit 3: 2 stop bits
		; bit 2 & 1: 8 data bits
		ldi mpr, 0b00001110
		sts UCSR1C, mpr

		; set buad rate to 2400 - on double data rate, calculated value is 834 = $0342
		ldi mpr, $03
		sts UBRR1H, mpr
		ldi mpr, $42
		sts UBRR1L, mpr
		
	;Other

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
	;TODO: ???
		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************