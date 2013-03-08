@ CSC230 --  Traffic Light simulation program
@ Latest edition: Fall 2011
@ Author:  Micaela Serra 
@ Modified by: Ben Church V00732962

@===== STAGE 0
@  	Sets initial outputs and screen for INIT
@ Calls StartSim to start the simulation,
@	polls for left black button, returns to main to exit simulation

        .equ    SWI_EXIT, 		0x11		@terminate program
        @ swi codes for using the Embest board
        .equ    SWI_SETSEG8, 		0x200	@display on 8 Segment
        .equ    SWI_SETLED, 		0x201	@LEDs on/off
        .equ    SWI_CheckBlack, 	0x202	@check press Black button
        .equ    SWI_CheckBlue, 		0x203	@check press Blue button
        .equ    SWI_DRAW_STRING, 	0x204	@display a string on LCD
        .equ    SWI_DRAW_INT, 		0x205	@display an int on LCD  
        .equ    SWI_CLEAR_DISPLAY, 	0x206	@clear LCD
        .equ    SWI_DRAW_CHAR, 		0x207	@display a char on LCD
        .equ    SWI_CLEAR_LINE, 	0x208	@clear a line on LCD
        .equ 	SEG_A,	0x80		@ patterns for 8 segment display
		.equ 	SEG_B,	0x40
		.equ 	SEG_C,	0x20
		.equ 	SEG_D,	0x08
		.equ 	SEG_E,	0x04
		.equ 	SEG_F,	0x02
		.equ 	SEG_G,	0x01
		.equ 	SEG_P,	0x10                
        .equ    LEFT_LED, 	0x02	@patterns for LED lights
        .equ    RIGHT_LED, 	0x01
        .equ    BOTH_LED, 	0x03
        .equ    NO_LED, 	0x00       
        .equ    LEFT_BLACK_BUTTON, 	0x02	@ bit patterns for black buttons
        .equ    RIGHT_BLACK_BUTTON, 0x01
        @ bit patterns for blue keys 
        .equ    Ph1, 		0x0100	@ =8
        .equ    Ph2, 		0x0200	@ =9
        .equ    Ps1, 		0x0400	@ =10
        .equ    Ps2, 		0x0800	@ =11

		@ timing related
		.equ    SWI_GetTicks, 		0x6d	@get current time 
		.equ    EmbestTimerMask, 	0x7fff	@ 15 bit mask for Embest timer
											@(2^15) -1 = 32,767        										
        .equ	OneSecond,	1000	@ Time intervals
        .equ	TwoSecond,	2000
	@define the 2 streets
	@	.equ	MAIN_STREET		0
	@	.equ	SIDE_STREET		1
 
       .text           
       .global _start

@===== The entry point of the program
_start:		
	@ initialize all outputs
	BL Init				@ void Init ()
	@ Check for left black button press to start simulation
RepeatTillBlackLeft:
	swi     SWI_CheckBlack
	cmp     r0, #LEFT_BLACK_BUTTON	@ start of simulation
	beq		StrS
	cmp     r0, #RIGHT_BLACK_BUTTON	@ stop simulation
	beq     StpS

	bne     RepeatTillBlackLeft
StrS:	
	BL StartSim		@else start simulation: void StartSim()
	@ on return here, the right black button was pressed
StpS:
	BL EndSim		@clear board: void EndSim()
EndTrafficLight:
	swi	SWI_EXIT
	
@ === Init ( )-->void
@   Inputs:	none	
@   Results:  none 
@   Description:
@ 		both LED lights on
@		8-segment = point only
@		LCD = ID only
Init:
	stmfd	sp!,{r1-r10,lr}
	@ LCD = ID on line 1
	mov	r1, #0			@ r1 = row
	mov	r0, #0			@ r0 = column 
	ldr	r2, =lineID		@ identification
	swi	SWI_DRAW_STRING
	@ both LED on
	mov	r0, #BOTH_LED	@LEDs on
	swi	SWI_SETLED
	@ display point only on 8-segment
	mov	r0, #10			@8-segment pattern off
	mov	r1,#1			@point on
	BL	Display8Segment

DoneInit:
	LDMFD	sp!,{r1-r10,pc}

@===== EndSim()
@   Inputs:  none
@   Results: none
@   Description:
@      Clear the board and display the last message
EndSim:	
	stmfd	sp!, {r0-r2,lr}
	mov	r0, #10				@8-segment pattern off
	mov	r1,#0
	BL	Display8Segment		@Display8Segment(R0:number;R1:point)
	mov	r0, #NO_LED
	swi	SWI_SETLED
	swi	SWI_CLEAR_DISPLAY
	mov	r0, #5
	mov	r1, #7
	ldr	r2, =Goodbye
	swi	SWI_DRAW_STRING  	@ display goodbye message on line 7
	ldmfd	sp!, {r0-r2,pc}
	
@ === StartSim ( )-->void
@   Inputs:	none	
@   Results:  none 
@   Description:
@ 		XXX
StartSim:
	stmfd	sp!,{r1-r10,lr}
	@set state to I3 and start CarCycle
	mov r1, #3
	bl	CarCycle

DoneStartSim:
	LDMFD	sp!,{r1-r10,pc}

@ ==== void Wait(Delay:r10) 
@   Inputs:  R10 = delay in milliseconds
@   Results: none
@   Description:
@      Wait for r10 milliseconds using a 15-bit timer 
Wait:
	stmfd	sp!, {r0-r2,r7-r10,lr}
	ldr     r7, =EmbestTimerMask
	swi     SWI_GetTicks		@get time T1
	and		r1,r0,r7			@T1 in 15 bits
WaitLoop:
	swi SWI_GetTicks			@get time T2
	and		r2,r0,r7			@T2 in 15 bits
	cmp		r2,r1				@ is T2>T1?
	bge		simpletimeW
	sub		r9,r7,r1			@ elapsed TIME= 32,676 - T1
	add		r9,r9,r2			@    + T2
	bal		CheckIntervalW
simpletimeW:
		sub		r9,r2,r1		@ elapsed TIME = T2-T1
CheckIntervalW:
	cmp		r9,r10				@is TIME < desired interval?
	blt		WaitLoop
WaitDone:
	ldmfd	sp!, {r0-r2,r7-r10,pc}	

@ *** void Display8Segment (Number:R0; Point:R1) ***
@   Inputs:  R0=bumber to display; R1=point or no point
@   Results:  none
@   Description:
@ 		Displays the number 0-9 in R0 on the 8-segment
@ 		If R1 = 1, the point is also shown
Display8Segment:
	STMFD 	sp!,{r0-r2,lr}
	ldr 	r2,=Digits
	ldr 	r0,[r2,r0,lsl#2]
	tst 	r1,#0x01 @if r1=1,
	orrne 	r0,r0,#SEG_P 			@then show P
	swi 	SWI_SETSEG8
	LDMFD 	sp!,{r0-r2,pc}
	
@ *** void DrawScreen (PatternType:R10) ***
@   Inputs:  R10: pattern to display according to state
@   Results:  none
@   Description:
@ 		Displays on LCD screen the 5 lines denoting
@		the state of the traffic light
@	Possible displays:
@	1 => S1.1 or S2.1- Green High Street
@	2 => S1.2 or S2.2	- Green blink High Street
@	3 => S3 or P1 - Yellow High Street   
@	4 => S4 or S7 or P2 or P5 - all red
@	5 => S5	- Green Side Road
@	6 => S6 - Yellow Side Road
@	7 => P3 - all pedestrian crossing
@	8 => P4 - all pedestrian hurry
@	9 => P1
@	10 => P2
@	11 => P5
@	12 => S7
@	21 => S2.1
@	22 => S2.2
DrawScreen:
	STMFD 	sp!,{r0-r2,lr}
	
	bl DrawState	@call Drawstate(r10)
	
	cmp	r10,#1
	beq	S11
	cmp	r10,#2
	beq	S12
	cmp	r10,#3
	beq	S3
	cmp	r10,#4
	beq	S4
	cmp	r10,#5
	beq	S5
	cmp	r10,#6
	beq	S6
	cmp	r10,#7
	beq	P3
	cmp	r10,#8
	beq	P4
	
	cmp	r10,#21
	beq	S21
	cmp	r10,#22
	beq	S22
	
	cmp	r10,#9
	beq	P1
	cmp	r10,#10
	beq	P2
	cmp	r10,#11
	beq	P5
	
	cmp	r10,#12
	beq	S7
	
	bal	EndDrawScreen
S11:
	ldr	r2,=line1S11
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S11
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S11
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
S12:
	ldr	r2,=line1S12
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S12
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S12
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
	
S21:
	ldr	r2,=line1S21
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S21
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S21
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
	
S22:
	ldr	r2,=line1S22
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S22
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S22
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
S5:
	ldr	r2,=line1S5
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S5
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S5
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
S4:
	ldr	r2,=line1S4
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S4
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S4
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
S3:
	ldr	r2,=line1S3
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S3
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S3
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
S6:
	ldr	r2,=line1S6
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S6
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S6
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
	
S7:
	ldr	r2,=line1S7
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S7
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S7
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
P3:
	ldr	r2,=line1P3
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3P3
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5P3
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
P4:
	ldr	r2,=line1P4
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3P4
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5P4
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
	
P1:
	ldr	r2,=line1P1
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3P1
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5P1
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
	
P2:
	ldr	r2,=line1P2
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3P2
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5P2
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
	
P5:
	ldr	r2,=line1P5
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3P5
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5P5
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
@ more patterns to be implemented
EndDrawScreen:
	LDMFD 	sp!,{r0-r2,pc}

@CarCycle: INF LOOP UNTIL RIGHT BALCK BUTTON PUSHED
@calls ped cycle when blue button 8-11 is pushed	
CarCycle:
	stmfd	sp!, {r2-r10,lr}
	@state 1
	
	mov r9, #0		@counter variable
	

	
State1:
	@ Left LED on
	mov	r0, #LEFT_LED	@LEDs on
	swi	SWI_SETLED
	
	@8 segment clear, P = on
	mov	r1, #1
	mov r0, #10
	bl	Display8Segment
	
	mov r4, #1		@state = I1
	
	@DrawScreen(S1.1)
	mov r10, #1
	BL DrawScreen
	mov	r10,#TwoSecond
	bl	Wait
	add r9, r9, #2	@counter+2
	
	@DrawScreen(S1.2)
	mov r10, #2
	BL DrawScreen
	mov	r10,#OneSecond
	bl	Wait
	add r9, r9, #1	@counter+1
	
	cmp r9, #12
	BLT State1		@if counter < 12 go to State 1 (loop) i.e. loop for 12 seconds
	
	
	mov r9, #0		@counter = 0
	
State2:
	@ Left LED on
	mov	r0, #LEFT_LED	@LEDs on
	swi	SWI_SETLED
	
	@8 segment clear, P = on
	mov	r1, #1
	mov r0, #10
	bl	Display8Segment
	
	mov r4, #2		@state = I2
	
	@DrawScreen(S2.1)
	mov r10, #21
	BL DrawScreen
	
	@WaitAndPoll for 2seconds. If Right black pressed exit carcycle, if blue 8-11 pressed goto pedcycle
	mov	r10,#TwoSecond
	bl	WaitAndPoll
	cmp     r0, #RIGHT_BLACK_BUTTON	@ stop simulation
	beq     EndCarCycle
	
	cmp     r0, #Ph1	@ stop simulation
	beq     CallPedCycle
	
	cmp     r0, #Ph2	@ stop simulation
	beq     CallPedCycle
	
	cmp     r0, #Ps1	@ stop simulation
	beq     CallPedCycle
	
	cmp     r0, #Ps2	@ stop simulation
	beq     CallPedCycle
	
	add r9, r9, #2		@counter + 2
	
	@DrawScreen(s2.2)
	mov r10, #22
	BL DrawScreen
	
	@WaitAndPoll for 1 seconds. If Right black pressed exit carcycle, if blue 8-11 pressed goto pedcycle
	mov	r10,#OneSecond
	bl	WaitAndPoll
	
	cmp     r0, #RIGHT_BLACK_BUTTON	@ stop simulation
	beq     EndCarCycle
	
	cmp     r0, #Ph1	@ stop simulation
	beq     CallPedCycle
	
	cmp     r0, #Ph2	@ stop simulation
	beq     CallPedCycle
	
	cmp     r0, #Ps1	@ stop simulation
	beq     CallPedCycle
	
	cmp     r0, #Ps2	@ stop simulation
	beq     CallPedCycle
	
	add r9, r9, #1		@counter + 1
	
	cmp r9, #6		@ifcounter is less that 6 go to State 2 (loop) i.e. loop for 6 seconds
	BLT State2
	

FinalStates:
	@ Left LED on
	mov	r0, #LEFT_LED	@LEDs on
	swi	SWI_SETLED
	
	@clear 8 seg display, P = OFF
	mov	r1, #0
	mov r0, #10
	bl	Display8Segment
	
	@DrawScreen(s3) & wait 2 seconds
	mov r10, #3
	BL DrawScreen
	mov	r10,#TwoSecond
	bl	Wait

	@ BOTH LED on
	mov	r0, #BOTH_LED	@LEDs on
	swi	SWI_SETLED
	
	@clear 8 seg display, P = OFF	
	mov	r1, #0
	mov r0, #10
	bl	Display8Segment
	
	@DrawScreen(s4) & wait 1 seconds
	mov r10, #4
	BL DrawScreen
	mov	r10,#OneSecond
	bl	Wait
	

	
State5:
	@State = I3
	mov r4, #3
	
	@ Right LED on
	mov	r0, #RIGHT_LED	@LEDs on
	swi	SWI_SETLED
	
	@clear 8 seg display, P = ON
	mov	r1, #1
	mov r0, #10
	bl	Display8Segment
	
	@DrawScreen(s5) & wait 6 seconds
	mov r10, #5
	BL DrawScreen
	mov	r10,#TwoSecond
	bl	Wait
	mov	r10,#TwoSecond
	bl	Wait
	mov	r10,#TwoSecond
	bl	Wait
	
	@ Right LED on
	mov	r0, #RIGHT_LED
	swi	SWI_SETLED
	
	@clear 8 seg display, P = OFF
	mov	r1, #0
	mov r0, #10
	bl	Display8Segment
	
	@DrawScreen(s6) & wait 2 seconds
	mov r10, #6
	BL DrawScreen
	mov	r10,#TwoSecond
	bl	Wait

	@ BOTH LED on
	mov	r0, #BOTH_LED	@LEDs on
	swi	SWI_SETLED
	
	@clear 8 seg display, P = OFF
	mov	r1, #0
	mov r0, #10
	bl	Display8Segment
	
	@DrawScreen(s7) & wait and poll 1 seconds
	mov r10, #12
	BL DrawScreen
	mov	r10,#OneSecond
	bl	WaitAndPoll
	
	@If Right black pressed exit carcycle, if blue 8-11 pressed goto pedcycle
	cmp     r0, #RIGHT_BLACK_BUTTON	@ stop simulation
	beq     EndCarCycle
	
	cmp     r0, #Ph1	@ stop simulation
	beq     CallPedCycle
	
	cmp     r0, #Ph2	@ stop simulation
	beq     CallPedCycle
	
	cmp     r0, #Ps1	@ stop simulation
	beq     CallPedCycle
	
	cmp     r0, #Ps2	@ stop simulation
	beq     CallPedCycle
	
	@loop back to stack of carcycle if no buttons pushed
	BAL CarCycle

@calls pedcycle, upon return checks state
@state I1 & I2 goto State5
@State I3 goto State1
CallPedCycle:
	bl PedCycle
	
	cmp r4, #1
	beq State5
	cmp r4, #2
	beq State5
	bne State1
		
	
EndCarCycle:
	ldmfd	sp!, {r2-r10, pc}

PedCycle:
	stmfd	sp!, {r2-r3, r5-r10,lr}
	
	mov	r1,#0
	mov r0, #10
	bl	Display8Segment	@clear 8 display, point = off
	
	@if state = I3 go Ped3
	cmp	r4, #3
	beq	Ped3
	
	@P1
	@ Left LED on
	mov	r0, #LEFT_LED	@LEDs on
	swi	SWI_SETLED
	
	@DrawScreen(P1) for 2 sec
	mov r10, #9
	BL DrawScreen
	mov	r10,#TwoSecond
	bl	Wait
	
	@p2
	@ BOTH LED on
	mov	r0, #BOTH_LED	@LEDs on
	swi	SWI_SETLED
	
	@DrawScreen(P2) for 2 sec
	mov r10, #10
	BL DrawScreen
	mov	r10,#OneSecond
	bl	Wait
	
	
Ped3:
	@ BOTH LED on
	mov	r0, #BOTH_LED	@LEDs on
	swi	SWI_SETLED
	
	@DrawScreen(P7) & wait one second
	mov r10, #7
	BL DrawScreen
	mov	r10,#OneSecond
	
	@8seg variable = 6
	mov r0, #6
	
@countdown 6,4,3 on 8 segment. wait 1 second between each deincrement
countdown1:
	bl	Display8Segment
	mov	r10,#OneSecond
	bl	Wait
	sub r0,r0, #1
	cmp r0, #2		@if countdown != 2 loop to countdown1
	bne countdown1
	
	@DrawScreen(P4)
	mov r10, #8
	BL DrawScreen
	
@countdown 2,1 on 8 segment, wait 1 second between each deincrement	
countdown2:
	bl	Display8Segment
	sub r0,r0, #1
	mov	r10,#OneSecond
	bl	Wait
	
	cmp r0, #0		@if countdown != 0 loop to countdown2
	BNE countdown2
	
	bl	Display8Segment
	mov	r10,#OneSecond
	bl	Wait
	
EndPedCycle:
	mov r0, #10
	bl	Display8Segment		@clear 8 segment display
	mov r0, #0
	ldmfd	sp!, {r2-r3,r5-r10, pc}
	
@WaitandPoll: waits for set time (R10) and returns 0 via R0 if no button is pressed
WaitAndPoll:
	stmfd	sp!, {r1-r3,r7-r9,lr}
	ldr     r7, =EmbestTimerMask
	swi     SWI_GetTicks		@get time T1
	and		r1,r0,r7			@T1 in 15 bits
WPLoop:
	@if right_black or blue 8-11 pressed. exit
	swi     SWI_CheckBlack
	cmp     r0, #RIGHT_BLACK_BUTTON	@ stop simulation
	beq     WPDone
	
	swi     SWI_CheckBlue
	cmp     r0, #Ph1	@ stop simulation
	beq     WPDone
	
	cmp     r0, #Ph2	@ stop simulation
	beq     WPDone
	
	cmp     r0, #Ps1	@ stop simulation
	beq     WPDone
	
	cmp     r0, #Ps2	@ stop simulation
	beq     WPDone
	
	
	swi SWI_GetTicks			@get time T2
	and		r2,r0,r7			@T2 in 15 bits
	cmp		r2,r1				@ is T2>T1?
	bge		simpletimeW2
	sub		r9,r7,r1			@ elapsed TIME= 32,676 - T1
	add		r9,r9,r2			@    + T2
	bal		CheckIntervalW2
simpletimeW2:
		sub		r9,r2,r1		@ elapsed TIME = T2-T1
CheckIntervalW2:
	cmp		r9,r10				@is TIME < desired interval?
	blt		WPLoop
	mov		r0, #0
WPDone:
	ldmfd	sp!, {r1-r3,r7-r9,pc}
	
@ *** void DrawState (PatternType:R10) ***
@   Inputs:  R10: number to display according to state
@   Results:  none
@   Description:
@ 		Displays on LCD screen the state number
@		on top right corner
DrawState:
	STMFD 	sp!,{r0-r2,lr}
	cmp	r10,#1
	beq	S11Draw
	cmp	r10,#2
	beq	S12Draw
	cmp	r10,#3
	beq	S3Draw
	cmp	r10,#4
	beq	S4Draw
	cmp	r10,#5
	beq	S5Draw
	cmp	r10,#6
	beq	S6Draw
	cmp	r10,#7
	beq	P3Draw
	cmp	r10,#8
	beq	P4Draw
	
	cmp	r10,#21
	beq	S21Draw
	cmp	r10,#22
	beq	S22Draw
	
	cmp	r10,#9
	beq	P1Draw
	cmp	r10,#10
	beq	P2Draw
	cmp	r10,#11
	beq	P5Draw
	
	cmp	r10,#12
	beq	S7Draw
	@ MORE TO IMPLEMENT......
	bal	EndDrawScreen
S11Draw:
	ldr	r2,=S1.1label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S12Draw:
	ldr	r2,=S1.2label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S21Draw:
	ldr	r2,=S2.1label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S22Draw:
	ldr	r2,=S2.2label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S3Draw:
	ldr	r2,=S3label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S4Draw:
	ldr	r2,=S4label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S5Draw:
	ldr	r2,=S5label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S6Draw:
	ldr	r2,=S6label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S7Draw:
	ldr	r2,=S7label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
P1Draw:
	ldr	r2,=P1label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
P2Draw:
	ldr	r2,=P2label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
P3Draw:
	ldr	r2,=P3label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
P4Draw:
	ldr	r2,=P4label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
P5Draw:
	ldr	r2,=P5label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
EndDrawState:
	LDMFD 	sp!,{r0-r2,pc}
	
@@@@@@@@@@@@=========================
	.data
	.align
Digits:							@ for 8-segment display
	.word SEG_A|SEG_B|SEG_C|SEG_D|SEG_E|SEG_G 	@0
	.word SEG_B|SEG_C 							@1
	.word SEG_A|SEG_B|SEG_F|SEG_E|SEG_D 		@2
	.word SEG_A|SEG_B|SEG_F|SEG_C|SEG_D 		@3
	.word SEG_G|SEG_F|SEG_B|SEG_C 				@4
	.word SEG_A|SEG_G|SEG_F|SEG_C|SEG_D 		@5
	.word SEG_A|SEG_G|SEG_F|SEG_E|SEG_D|SEG_C 	@6
	.word SEG_A|SEG_B|SEG_C 					@7
	.word SEG_A|SEG_B|SEG_C|SEG_D|SEG_E|SEG_F|SEG_G @8
	.word SEG_A|SEG_B|SEG_F|SEG_G|SEG_C 		@9
	.word 0 									@Blank 
	.align
lineID:		.asciz	"Traffic Light -- Ben Church, V00732962"
@ patterns for all states on LCD
line1S11:		.asciz	"        R W        "
line3S11:		.asciz	"GGG W         GGG W"
line5S11:		.asciz	"        R W        "

line1S12:		.asciz	"        R W        "
line3S12:		.asciz	"  W             W  "
line5S12:		.asciz	"        R W        "

line1S21:		.asciz	"        R W        "
line3S21:		.asciz	"GGG W         GGG W"
line5S21:		.asciz	"        R W        "

line1S22:		.asciz	"        R W        "
line3S22:		.asciz	"  W             W  "
line5S22:		.asciz	"        R W        "

line1S3:		.asciz	"        R W        "
line3S3:		.asciz	"YYY W         YYY W"
line5S3:		.asciz	"        R W        "

line1S4:		.asciz	"        R W        "
line3S4:		.asciz	" R W           R W "
line5S4:		.asciz	"        R W        "

line1S5:		.asciz	"       GGG W       "
line3S5:		.asciz	" R W           R W "
line5S5:		.asciz	"       GGG W       "

line1S6:		.asciz	"       YYY W       "
line3S6:		.asciz	" R W           R W "
line5S6:		.asciz	"       YYY W       "

line1S7:		.asciz	"        R W        "
line3S7:		.asciz	" R W           R W "
line5S7:		.asciz	"        R W        "

line1P3:		.asciz	"       R XXX       "
line3P3:		.asciz	"R XXX         R XXX"
line5P3:		.asciz	"       R XXX       "

line1P4:		.asciz	"       R !!!       "
line3P4:		.asciz	"R !!!         R !!!"
line5P4:		.asciz	"       R !!!       "

line1P1:		.asciz	"        R W        "
line3P1:		.asciz	"YYY W         YYY W"
line5P1:		.asciz	"        R W        "

line1P2:		.asciz	"        R W        "
line3P2:		.asciz	"R W             R W"
line5P2:		.asciz	"        R W        "

line1P5:		.asciz	"        R W        "
line3P5:		.asciz	"R W             R W"
line5P5:		.asciz	"        R W        "

S1.1label:		.asciz	"S1"
S1.2label:		.asciz	"S1"
S2.1label:		.asciz	"S2"
S2.2label:		.asciz	"S2"
S3label:		.asciz	"S3"
S4label:		.asciz	"S4"
S5label:		.asciz	"S5"
S6label:		.asciz	"S6"
S7label:		.asciz	"S7"
P1label:		.asciz	"P1"
P2label:		.asciz	"P2"
P3label:		.asciz	"P3"
P4label:		.asciz	"P4"
P5label:		.asciz	"P5"

Goodbye:
	.asciz	"*** Traffic Light program ended ***"

	.end

