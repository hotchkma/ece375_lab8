;***********************************************************
;*
;*	This is the RECEIVE skeleton file for Lab 8 of ECE 375
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
.def	motion = r17			; stores motion state (from controller)
.def	recCnt = r18			; stores number of transmission recieved
.def	freezeCnt = r19 		; stores number of times frozen

.def	waitcnt = r23			; stores the amount of time to be waited in cs
.def	ilcnt = r24				; inner loop count for waiting
.def	olcnt = r25				; outer loop count for waiting

.equ	WTime = 100				; Time to wait in wait loop

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

.equ	BotAddress = $1A		; bot address is 1A

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.g
;/////////////////////////////////////////////////////////////
.equ	MovFwd =  (1<<EngDirR|1<<EngDirL)	;0b01100000 Move Forward Action Code
.equ	MovBck =  $00						;0b00000000 Move Backward Action Code
.equ	TurnR =   (1<<EngDirL)				;0b01000000 Turn Right Action Code
.equ	TurnL =   (1<<EngDirR)				;0b00100000 Turn Left Action Code
.equ	Halt =    (1<<EngEnR|1<<EngEnL)		;0b10010000 Halt Action Code

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

;Should have Interrupt vectors for:
;- Left whisker
.org	$0002
		rcall HandleRight
		reti

;- Right whisker
.org	$0004
		rcall HandleLeft
		reti

;- USART receive
.org	$003C
		rcall HandleInput
		reti

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Initialize the Stack Pointer
		ldi XH, high(RAMEND)
		ldi XL, low(RAMEND)
		out SPH, XH
		out	SPL, XL

	;I/O Ports
		; Initialize Port B for output (LEDs)
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low

		;Initialize Port D for input (buttons)
		ldi		mpr, 0b00000000		; Set Port D Data Direction Register
		out		DDRD, mpr			; for input
		ldi		mpr, $FF			; Initialize Port D Data Register
		out		PORTD, mpr			; so all Port D inputs are Tri-State

	;USART1
		; bit 1: double data rate
		ldi mpr, 0b00000010
		sts UCSR1A, mpr		; extended I/O

		; bit 7: enable recieve interrupt
		; bit 6: disable transmit interrupt
		; bit 5: disable data reg. empty interrupt
		; bit 4: enable reciever
		; bit 3: enable transmitter
		; bit 2: character size bit 2 is 0 (8 = 011)
		ldi mpr, 0b10011000
		sts UCSR1B, mpr		; extended I/O

		; bit 6: asynchronous mode
		; bit 5 & 4: parity disabled 
		; bit 3: 2 stop bits
		; bit 2 & 1: 8 data bits
		ldi mpr, 0b00001110
		sts UCSR1C, mpr		; extended I/O

		; set buad rate to 2400 - on double data rate, calculated value is 834 = $0342
		ldi mpr, $03		; low byte
		sts UBRR1H, mpr		; extended I/O
		ldi mpr, $42		; high byte
		sts UBRR1L, mpr		; extended I/O

	;External Interrupts
		;Set the External Interrupt Mask
		ldi mpr, 0b00000011		; enable the INT0:1
		out EIMSK, mpr			; write to the mask
		
		;Set the Interrupt Sense Control to falling edge detection
		ldi mpr, 0b00001010		; 10 -> falling edge
		sts EICRA, mpr			; for INT1:0

	; Other
		ldi motion, 0b01100000; set the bot forward by default
		ldi recCnt, $00 ; clear the recieved count
		ldi freezeCnt, $00 ; clear the freeze counter

	;Set global interrupt
		sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		out		PORTB, motion	; write to output ports
		rjmp	MAIN			; loop

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;----------------------------------------------------------------
; Func:	HandleInput
; Desc:	HandleInput handles USART recieve signals. The ISR 
; depends on the particular inputs, as well as the state of the 
; bot. It might check the address sent, or the action code. Or, it
; might detect an incoming freeze attack. It responds to all the
; scenarios.
;----------------------------------------------------------------
 HandleInput:	
				push	mpr			; store the current program data on the stack
				in		mpr, SREG
				push	mpr

				; read the incoming and check for special cases
				lds mpr, UDR1		; read the signal recieved
				cpi mpr, 0b01010101 ; is this a freeze attack
				breq Freeze			; if so, then freeze!
				cpi recCnt, $00		; have we already recieved 1 signal out of 2?
				brne Respond		; if so, jump to our response
				
				; if both other checks did not pass, then this is an address
				cpi mpr, BotAddress	; is this my address?
				brne Abort			; if not, ignore it
				inc recCnt			; signal 1/2 recieved

Abort:			rcall ClearQ		; clear EIMSK
				pop		mpr			; restore the contents of the program from the stack
				out		SREG, mpr
				pop		mpr
				ret

Respond:
				ldi recCnt, $00		; clear the count so the next signal is considered not as action code
				cpi mpr, 0b11111000	; is this telling me to attack?
				breq FreezeAttack	; then attack!
				lsl mpr				; or convert this to something for LEDs
				mov motion, mpr		; put this into motion register
				rcall ClearQ		; clear any outstanding signals
				pop		mpr			; restore the contents of the program from the stack
				out		SREG, mpr	
				pop		mpr			
				ret

FreezeAttack:	
				clr		recCnt			; clear the count so the next signal is considered not as action code
				ldi		mpr, 0b01010101 ; send out a freeze attack
				sts		UDR1, mpr		; remember to write to the data register
				rcall	ClearQ			; clear the external interrupt queue
				pop		mpr				; restore the contents of the program from the stack
				out		SREG, mpr
				pop		mpr
				ret

Freeze:
				clr recCnt			; clear the reciever count - a freeze has interrupted us
				inc freezeCnt		; increment the freeze count
				ldi mpr, Halt		; halt while frozen
				out	PORTB, mpr		; write to the LEDs
Forever:		cpi freezeCnt, 3	; is this the third freeze?
				breq Forever		; loop forever if it is
				rcall WaitT			; otherwise, wait 5 seconds (1 second times 5)
				rcall WaitT
				rcall WaitT
				rcall WaitT
				rcall WaitT
				rcall ClearQ		; clear the external interrupt queue
				pop		mpr			; restore the contents of the program from the stack
				out		SREG, mpr
				pop		mpr
				ret

;----------------------------------------------------------------
; Func:	ClearQ
; Desc: ClearQ simply clears the external interrupt queue
;----------------------------------------------------------------
ClearQ:
				ldi		mpr, 0b00000011	; clear the queue
				out		EIFR, mpr
				ret

;----------------------------------------------------------------
; Func:	HandleRight
; Desc:	HandleRight handles a right whisker trigger. This function
;		carries out the bump bot behavior to represent a response to the
;		trigger. So, it adds to the trigger count, reverses, then turns left
;		then returns to the main function in which it continues walking forward
;----------------------------------------------------------------
HandleRight:	;turns left for a second
				push	mpr			; store the current program data on the stack
				push	waitcnt
				in		mpr, SREG
				push	mpr

				rcall	MoveBack	; move backwards first
				ldi		mpr, TurnL	; load our turn left bits
				out		PORTB, mpr	; write to the output PORTB
				ldi		waitcnt, WTime	; make sure the waitcnt has the wait time
				rcall	WaitT		; wait for that time

				rcall	ClearQ		; clear the interrupts queue

				pop		mpr			; restore the contents of the program from the stack
				out		SREG, mpr
				pop		waitcnt
				pop		mpr

				ret					; return

;----------------------------------------------------------------
; Func:	HandleLeft
; Desc:	HandleLeft handles a left whisker trigger. This function
;		carries out the bump bot behavior to represent a response to the
;		trigger. So, it adds to the trigger count, reverses, then turns right
;		then returns to the main function in which it continues walking forward
;----------------------------------------------------------------
HandleLeft:		;turn right for a second
				push	mpr			; everything in HandleLeft mirrors HandleRight, except of course we turn right instead of turning left and increment our left counter instead of our right counter
				push	waitcnt		; thus, refer to the HandleRight function for comments to avoid redundancy
				in		mpr, SREG
				push	mpr

				rcall	MoveBack
				ldi		mpr, TurnR
				out		PORTB, mpr
				ldi		waitcnt, WTime
				rcall   WaitT

				rcall	ClearQ

				pop		mpr
				out		SREG, mpr
				pop		Waitcnt
				pop		mpr

				ret

;----------------------------------------------------------------
; Func:	MoveBack
; Desc:	MoveBack serves as a helper to the HandleLeft and HandleRight functions
;		It simply causes the bumpbot to mov backwards for the time WTime
;----------------------------------------------------------------
MoveBack:		;Move backwards for a second
				ldi		mpr, MovBck		; load the move backwards bits
				out		PORTB, mpr		; write them to the output PORTB
				ldi		Waitcnt, WTime	; make sure the wait time is loaded into the wait count
				rcall	WaitT			; wait for that amount of time
				ret						; return

;----------------------------------------------------------------
; Sub:	WaitT
; Desc:	A WaitT loop that is 16 + 159975*WaitTcnt cycles or roughly 
;		WaitTcnt*10ms.  Just initialize WaitT for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
WaitT:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

		ldi		waitcnt, WTime
Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt			; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt			; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret					; Return from subroutine


;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************