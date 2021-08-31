;****************** main.s ***************
; Program written by: **-UUU-*Your Names**update this***
; Date Created: 2/14/2017
; Last Modified: 1/17/2021
; You are given a simple stepper motor software system with one input and
; four outputs. This program runs, but you are asked to add minimally intrusive
; debugging instruments to verify it is running properly. 
; Touch and release PA2 and the motor cycles between 3 states
;   1) the stepper motor outputs cycle 10,6,5,9,..., every 11.1ms or 1 rps
;   2) the stepper motor output remains fixed
;   3) the stepper motor outputs cycle 5,6,10,9,...  every 11.1ms or -1 rps
;   Implement debugging instruments which gather data (state and timing)
;   to verify that the system is functioning as expected.
; Hardware connections (External: One button and four outputs to stepper motor)
;  PA2 is Button input  (1 means pressed, 0 means not pressed)
;  PB3-0 are stepper motor outputs (you do not need to add actual motor)
;  PF3 is Green LED on Launchpad used as a heartbeat
; Instrumentation data to be gathered is as follows:
; After every output to Port B, collect one state and time entry. 
; The state information is the 5 bits on Port A bit 2 and Port B PB3-0
;   place one 8-bit entry in your Data Buffer  
; The time information is the 24-bit time difference between this output and the previous (in us units)
;   place one 32-bit entry in the Time Buffer
;    calculate elasped time in usec from previous to this capture
;    you must handle the roll over as Current goes 3,2,1,0,0x00FFFFFF,0xFFFFFE,
; Note: The size of both buffers is 100 entries. Once you fill these
;       entries you should stop collecting data
; The heartbeat is an indicator of the running of the program. 
; On each iteration of the main loop of your Debug_Beat function is called 
; LED to indicate that your code(system) is live (not stuck or dead).

SYSCTL_RCGCGPIO_R  EQU 0x400FE608
NVIC_ST_CURRENT_R  EQU 0xE000E018
GPIO_PORTA_DATA_R  EQU 0x400043FC
GPIO_PORTA_DIR_R   EQU 0x40004400
GPIO_PORTA_DEN_R   EQU 0x4000451C
GPIO_PORTA_PDR_R   EQU 0x40004514
GPIO_PORTB_DATA_R  EQU 0x400053FC
GPIO_PORTB_DIR_R   EQU 0x40005400
GPIO_PORTB_DEN_R   EQU 0x4000551C
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_DEN_R   EQU 0x4002551C
; RAM Area
          AREA    DATA, ALIGN=2
Index     SPACE 4 ; index into Stepper table 0,1,2,3
Direction SPACE 4 ; -1 for CCW, 0 for stop 1 for CW

;place your debug variables in RAM here


; ROM Area
        IMPORT TExaS_Init
        IMPORT SysTick_Init
;-UUU-Import routine(s) from other assembly files (like SysTick.s) here
        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
Stepper DCB 5,6,10,9
        EXPORT  Start

Start
      CPSID  I    ; disable interrrupts until initialization complete
 ; TExaS_Init sets bus clock at 80 MHz
; PF3, PA2, PB3-PE0 out logic analyzer to TExasDisplay
      LDR  R0,=SendDataToLogicAnalyzer
      ORR  R0,R0,#1   ;T-bit must be 1
      BL   TExaS_Init ; logic analyzer, 80 MHz
 ;place your initializations here
      BL   Stepper_Init ; initialize stepper motor
      BL   Switch_Init  ; initialize switch input
;---Your Initialization------------
      BL   Debug_Init ;(you write this)
;**********************
      CPSIE  I    ; TExaS logic analyzer runs on interrupts
      MOV  R5,#0  ; last PA4
loop  
;----- Your HeartBeat------------
;toggle PF3 every 11th call
      BL   Debug_Beat ;(you write this)
;**********************
      LDR  R1,=GPIO_PORTA_DATA_R
      LDR  R4,[R1]  ;current value of switch
      ANDS R4,R4,#0x04 ; select just bit 2
      BEQ  no     ; skip if not pushed
      CMP  R5,#0
      BNE  no     ; skip if pushed last time
      ; this time yes, last time no
      LDR  R1,=Direction
      LDR  R0,[R1]  ; current direction
      ADD  R0,R0,#1 ;-1,0,1 to 0,1,2
      CMP  R0,#2
      BNE  ok
      MOV  R0,#-1  ; cycles through values -1,0,1
ok    STR  R0,[R1] ; Direction=0 (CW)  
no    MOV  R5,R4   ; setup for next time
      BL   Stepper_Step               
      LDR  R0,=146874 ;about 11.1ms
      BL   Wait  ; time delay fixed but not accurate   
      B    loop
;Initialize stepper motor interface
Stepper_Init
      MOV R0,#1
      LDR R1,=Direction
      STR R0,[R1] ; Direction=0 (CW)
      MOV R0,#0
      LDR R1,=Index
      STR R0,[R1] ; Index=0
    ; activate clock for Port E
      LDR R1, =SYSCTL_RCGCGPIO_R
      LDR R0, [R1]
      ORR R0, R0, #0x02  ; Clock for B
      STR R0, [R1]
      NOP
      NOP                 ; allow time to finish activating
    ; set direction register
      LDR R1, =GPIO_PORTB_DIR_R
      LDR R0, [R1]
      ORR R0, R0, #0x0F    ; Output on PB0-PB3
       STR R0, [R1]
    ; enable digital port
      LDR R1, =GPIO_PORTB_DEN_R
      LDR R0, [R1]
      ORR R0, R0, #0x0F    ; enable PB3-0
      STR R0, [R1]
      BX  LR
      POP {R0,LR}
      POP {R0,PC}
;Initialize switch interface, PA2
Switch_Init
    ; activate clock for Port A
      LDR R1, =SYSCTL_RCGCGPIO_R
      LDR R0, [R1]
      ORR R0, R0, #0x01  ; Clock for A
      STR R0, [R1]
      NOP
      NOP                 ; allow time to finish activating
    ; set direction register
      LDR R1, =GPIO_PORTA_DIR_R
      LDR R0, [R1]
      BIC R0, R0, #0x04    ; Input on PA2
      STR R0, [R1]
    ; set pulldown register
      LDR R1, =GPIO_PORTA_PDR_R
      LDR R0, [R1]
      ORR R0, R0, #0x04    ; pull down on PA2
      STR R0, [R1]
    ; 5) enable digital port
      LDR R1, =GPIO_PORTA_DEN_R
      LDR R0, [R1]
      ORR R0, R0, #0x04    ; enable PA2
      STR R0, [R1]
      BX  LR
; Step the motor clockwise
; Direction determines the rotational direction
; Input: None
; Output: None
Stepper_Step
      PUSH {R4,LR}
      LDR  R1,=Index
      LDR  R2,[R1]     ; old Index
      LDR  R3,=Direction
      LDR  R0,[R3]     ; -1 for CCW, 0 for stop 1 for CW
      ADD  R2,R2,R0
      AND  R2,R2,#3    ; 0,1,2,3,0,1,2,...
      STR  R2,[R1]     ; new Index
      LDR  R3,=Stepper ; table
      LDRB R0,[R2,R3]  ; next output: 5,6,10,9,5,6,10,...
      LDR  R1,=GPIO_PORTB_DATA_R ; change PE3-PE0
      STR  R0,[R1]
;---Your capture ------------
      BL   Debug_Capture  ;(you write this)
;**********************
      POP {R4,PC}
; inaccurate and inefficient time delay
Wait 
      SUBS R0,R0,#1  ; outer loop
      BNE  Wait
      BX   LR
 

;------------PortF_Init------------
; Activate Port F and initialize PF1-3 for built-in LEDs.
; Input: none
; Output: none
; Modifies: R0, R1
PortF_Init
    ; activate clock for Port F
    LDR R1, =SYSCTL_RCGCGPIO_R      ; R1 = SYSCTL_RCGCGPIO_R
    LDR R0, [R1]                    ; R0 = [R1]
    ORR R0, R0, #0x00000020         ; bit 5
    STR R0, [R1]                    ; [R1] = R0
    NOP
    NOP                             ; allow time to finish activating
    ; set direction register
    LDR R1, =GPIO_PORTF_DIR_R       ; R1 = GPIO_PORTF_DIR_R
    LDR R0, [R1]                    ; R0 = [R1]
    ORR R0, R0, #0x0E               ; make PF3 output; PF1-3 built-in LEDs
    STR R0, [R1]                    ; [R1] = R0
    ; enable digital port
    LDR R1, =GPIO_PORTF_DEN_R       ; R1 = GPIO_PORTF_DEN_R
    LDR R0, [R1]                    ; R0 = [R1]
    ORR R0, R0, #0x0E               ; enable digital I/O on PF1-3
    STR R0, [R1]
    BX  LR                          ; return
; edit the following only if you need to move pins from PF3, PA2, PB3-0      
; logic analyzer on the real board
PA2  equ  0x40004010
PF3  equ  0x40025020
PB30 equ  0x4000503C
UART0_DR_R equ 0x4000C000
SendDataToLogicAnalyzer
     LDR  R1,=PA2  
     LDR  R1,[R1]  ; read PA2
     LDR  R0,=PB30 ; read PB3-PB0
     LDR  R0,[R0]
     ORR  R0,R0,R1,LSL #2 ;combine into one 5-bit value
     LDR  R1,=PF3  
     LDR  R1,[R1]  ; read PF3
     ORR  R0,R0,R1,LSL #2 ;combine into one 6-bit value
     ORR  R0,R0,#0x80 ; bit 7=1 means logic analyzer data
     LDR  R1,=UART0_DR_R
     STR  R0,[R1] ; send data at 10 kHz
     BX   LR
     
;---------------Your code for Lab 4----------------
;Debug initialization, save all registers (not just R4-R11)
; you will call existing PortF_Init 
; you need to implement SysTick_Init in SysTick.s
; you will call SysTick_Init here
Debug_Init 
      PUSH {R0,R1,R2,LR}
      BL   PortF_Init ; PF3 output to green LED
;you write this
      
      
      POP {R0,R1,R2,PC}
;Debug capture, save all registers (not just R4-R11)
;Save PA2,PB3-0 as 5 bit value in DataBuf
;Save elapsed time difference as 32-bit time in usec in TimeBuf
Debug_Capture 
;you write this
;assume capture is called every 11.1ms
;Let N = number of instructions in Debug_Capture
;Calculate T = N instructions * 2cycles/instruction * 12.5ns/cycle
;Calculate intrusiveness is T/11.1ms 
      PUSH {R0-R6,LR}
      
      POP  {R0-R6,PC}
;Heartbeat, save all registers (not AAPCS) 
;toggle PF3 (green LED) every 11th call
Debug_Beat
;you write this     
        
      POP  {R0-R2,PC}

    ALIGN      ; make sure the end of this section is aligned
    END        ; end of file

