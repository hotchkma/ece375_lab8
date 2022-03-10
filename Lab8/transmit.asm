;***********************************************************
;*
;*	This is the TRANSMIT skeleton file for Lab 8 of ECE 375
;*
;*	 Author: Matthew Hotchkiss, Michael Burlachenko
;*	   Date: 2/24/2022
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	data = r17				; Data to be sent register
.def	waitcnt = r23				; Wait Loop Counter
.def	ilcnt = r24				; Inner Loop Counter
.def	olcnt = r25				; Outer Loop Counter
	
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
.equ	FreezeCode = 0b01010101	;Freeze code
.equ	address = $1A	;Bot address
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
		ldi		mpr, 0b00001100		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, 0b11110011		; Initialize Port D Data Register
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
		ldi	waitcnt, 1	;load 1 to waitcnt to wait 10ms in WaitM loop
		
	;Other

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		in		mpr, PIND	;read PIND to mprt
		sbrs	mpr, PIND0	;if PIND0 is set
		rcall	HitRight	;jump to HitRight
		sbrs	mpr, PIND1	;if PIND1 is set
		rcall	HitLeft		;jump to HitLeft
		sbrs	mpr, PIND4	;if PIND4 is set
		rcall	HitForward	;jump to HitForward
		sbrs	mpr, PIND5	;if PIND5 is set
		rcall	HitBack		;jump to HitBack
		sbrs	mpr, PIND6	;if PIND6 is set
		rcall	Stop		;jump to Stop
		sbrs	mpr, PIND7	;if PIND7 is set
		rcall	Freeze	;jump to Freeze
		rjmp	MAIN	;return to main. infinite loop

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
Transmit:	;USART transmit
		push	mpr	;save program state
		in		mpr, SREG
		push	mpr
		lds		mpr, UCSR1A	;read UCSR1A register
		sbrs	mpr, UDRE1	;if UDRE1 is set (buffer if empty) jump to sts instruction
		rjmp	Transmit	;wait until the the buffer is empty 
		sts		UDR1, data	;write data to be transmitted to data register
		pop		mpr	;restore program state
		out		SREG, mpr
		pop		mpr
		ret

		
HitRight:	
		push	mpr
		in		mpr, SREG
		push	mpr
		ldi		data, address ;load address to data register 
		rcall	Transmit ;transmit address
		rcall	WaitM	
		ldi		data, TurnR ;load hitright action code to data register
		rcall	Transmit ;transmit data 
		pop		mpr ;restore program state
		out		SREG, mpr
		pop		mpr
		ret
HitLeft:
		push	mpr
		in		mpr, SREG
		push	mpr
		ldi		data, address;load address to data register
		rcall	Transmit;transmit address
		rcall	WaitM
		ldi		data, TurnL ;load hitleft action code to data register
		rcall	Transmit;transmit data 
		pop		mpr
		out		SREG, mpr
		pop		mpr
		ret
HitForward:
		push	mpr
		in		mpr, SREG
		push	mpr
		ldi		data, address;load address to data register
		rcall	Transmit;transmit address
		rcall	WaitM
		ldi		data, MovFwd ;load hitforward action code to data register
		rcall	Transmit;transmit data 
		pop		mpr
		out		SREG, mpr
		pop		mpr
		ret
HitBack:
		push	mpr
		in		mpr, SREG
		push	mpr
		ldi		data, address;load address to data register
		rcall	Transmit;transmit address
		rcall	WaitM
		ldi		data, MovBck ;load hitback action code to data register
		rcall	Transmit;transmit data 
		pop		mpr
		out		SREG, mpr
		pop		mpr
		ret
Stop:
		push	mpr
		in		mpr, SREG
		push	mpr
		ldi		data, address;load address to data register
		rcall	Transmit;transmit address
		rcall	WaitM
		ldi		data, Halt ;load hitstop action code to data register
		rcall	Transmit;transmit data 
		pop		mpr
		out		SREG, mpr
		pop		mpr
		ret
Freeze:
		push	waitcnt
		in		mpr, SREG
		push	mpr
		ldi		data, FreezeCode	;load freeze action code to data register
		rcall	Transmit	;transmit data
		ldi		waitcnt, 100	;wait 1 sec
		rcall   WaitM	;wait 1 sec to prevent sending multiple freeze action codes 
		pop		mpr
		out		SREG, mpr
		pop		mpr
		pop		waitcnt
WaitM:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine
;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************
