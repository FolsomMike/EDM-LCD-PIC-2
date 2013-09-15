;--------------------------------------------------------------------------------------------------
; Project:  OPT EDM Notch Cutter -- LCD PIC software
; Date:     2/29/12
; Revision: 1.0
;
; IMPORTANT: When programming the PIC in the notch cutter, turn the Electrode Current switch to
; Off and the Electrode Motion switch to Setup.
;
; Normally, the programming header for the LCD PIC is not installed on the board.  It can be
; installed in the Main PIC socket, programmed, and then moved to the LCD PIC socket.
;
; Overview:
;
; This program reads serial data sent by the Main PIC and displays it on the LCD.
;
; There are two PIC controllers on the board -- the Main PIC and the LCD PIC.  This code is
; for the LCD PIC.  The Main PIC sends data to the LCD PIC via a serial data line for display
; on the LCD.
;
;--------------------------------------------------------------------------------------------------
;
; Revision History:
;
; 1.0   Some code and concepts used from source code disassembled from hex object code version 2.7 
;       from original author.
;
;--------------------------------------------------------------------------------------------------
;
;--------------------------------------------------------------------------------------------------
; LCD Notes for the OPT EDM Control Board I
;
; Optrex C-51847NFJ-SLW-ADN 20 characters by 4 lines
;
; The user manual specified for this display is Dmcman_full-user manual.pdf from www.optrex.com
; This manual does not list this exact part number, but seems to be the appropriate manual.
;
; The R/W line is tied permanently low on the board, so only writes to the LCD are allowed.
;
; The E line is used to strobe the read/write operations.
;
; NOTE: LCD addressing is screwy - the lines are not in sequential order:
; line 1 column 1 = 0x80  	(actually address 0x00)
; line 2 column 1 = 0xc0	(actually address 0x40)
; line 3 column 1 = 0x94	(actually address 0x14)
; line 4 column 1 = 0xd4	(actually address 0x54)
;
; To address the second column in each line, use 81, C1, 95, d5, etc.
;
; The two different columns of values listed above are due to the fact that the address
; is in bits 6:0 and control bit 7 must be set to signal that the byte is an address
; byte.  Thus, 0x00 byte with the control bit set is 0x80.  The 0x80 value is what is
; actually sent to the LCD to set address 0x00.
;
;  Line 3 is actually the continuation in memory at the end of line 1
;    (0x94 - 0x80 = 0x14 which is 20 decimal -- the character width of the display)
;  Line 4 is a similar extension of line 2.
;
; Note that the user manual offered by Optrex shows the line addresses
; for 20 character wide displays at the bottom of page 20.
;
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Configurations, etc. for the Assembler Tools and the PIC

	LIST p = PIC16F648a	;select the processor

    errorlevel  -306 ; Suppresses Message[306] Crossing page boundary -- ensure page bits are set.

    errorLevel  -302 ; Suppresses Message[302] Register in operand not in bank 0.

#INCLUDE <P16f648a.inc> 		; Microchip Device Header File

#INCLUDE <STANDARD.MAC>     	; include standard macros

; Specify Device Configuration Bits

  __CONFIG _INTOSC_OSC_CLKOUT & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF

  ; __CONFIG _INTOSC_OSC_CLKOUT & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF

;_INTOSC_OSC_CLKOUT = uses internal oscillator, clock is output on RA6
;_WDT_OFF = watch dog timer is off
;_PWRTE_ON = device will delay startup after power applied to ensure stable operation
;_MCLRE_OFF = RA5/MCLR/VPP pin function is digital input, MCLR internally to VDD
;_BOREN_ON = Brown Out Reset is on -- low supply voltage will cause device reset
;_LVP_OFF = RB4/PGM is digital I/O, HV on MCLR must be used for programming
;           (device cannot be programmed in system with low voltage)
;_CPD_OFF = data memory is not protected and can be read from the device
;_CP_OFF = code memory is not protected and can be read from the device
;
;for improved reliability, Watch Dog code can be added and the Watch Dog Timer turned on - _WDT_ON
;turn on code protection to keep others from reading the code from the chip - _CP_ON
;
; end of configurations
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Hardware Definitions

LCD_CTRL        EQU     0x05		; PORTA
SERIAL_IN		EQU		0x00		; RA0
LCD_E           EQU     0x01		; RA1 - data read/write strobe
LCD_RS			EQU		0x02		; RA2 - instruction/data register select
UNUSED1			EQU		0x03
UNUSED2			EQU		0X04

LCD_DATA        EQU     0x06		; PORTB

; end of Hardware Definitions
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Variables in RAM
;
; Note that you cannot use a lot of the data definition directives for RAM space (such as DB)
; unless you are compiling object files and using a linker command file.  The cblock directive is
; commonly used to reserve RAM space or Code space when producing "absolute" code, as is done here.
; 

; Assign variables in RAM - Bank 0 - must set RP0:RP1 to 0:0 to access

 cblock 0x20                ; starting address

    flags                   ; bit 0: 0 = ??, 1 = ??
                            ; bit 1:
                            ; bit 2:
                            ; bit 3:
                            ; bit 4:
                            ; bit 5:
							; bit 6:
							; bit 7:

	lcdData					; stores data byte to be written to the LCD
	newSerialByte			; each serial data byte is stored here upon being received
	controlByte				; the first byte of each serial data byte pair is stored here

	smallDelayCnt			; used to count down for small delay
	bigDelayCnt				; used to count down for big delay
	bitCount				; used to count number of bits received
	scratch0				; scratch pad variable

 endc


; Assign variables in RAM - Bank 1 - must set RP0:RP1 to 0:1 to access

 cblock 0xa0                ; starting address

	Block2Var1

 endc
 
; Define variables in the memory which is mirrored in all 4 RAM banks.  This area is usually used
; by the interrupt routine for saving register states because there is no need to worry about
; which bank is current when the interrupt is invoked.
; On the PIC16F628A, 0x70 thru 0x7f is mirrored in all 4 RAM banks.

 cblock	0x70
    W_TEMP
    FSR_TEMP
    STATUS_TEMP
    PCLATH_TEMP	
 endc

; end of Variables in RAM
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Power On and Reset Vectors
;

	org	0x00				; Start of Program Memory

; none of the other vectors are used, so the program just starts executing at the reset vector
; location

;--------------------------------------------------------------------------------------------------
; Main Code
;
; Sets up the PIC, the LCD, displays a greeting, then monitors the serial data input line from
; the main PIC for data and instructions to be passed on to the LCD display.
;

Start:

    clrf    INTCON          ; disable all interrupts

	movlw	0x07			; turn off comparator, PortA pins set for I/O                              
 	movwf	CMCON           ; 7 -> Comparator Control Register to disable comparator inputs

 	bsf 	STATUS,RP0		; select bank 1

	movlw 	0x01                              
 	movwf 	TRISA			; 0x01 -> TRISA = PortA I/O 0000 0001 (1=input, 0=output)
    						;	RA0 - Input : receives serial input data
							;	RA1 - Output: E strobe to initiate LCD R/W
							;	RA2 - Output: Register Select for LCD
							;	RA3 - Output: unused (tied high for some reason)
							;	RA4 - Output: unused (tied high for some reason)
							;	RA5 - Vpp for PIC programming, unused otherwise
							;	RA6 - unused (unconnected)
							;	RA7 - unused (unconnected)
 	movlw 	0x00
 	movwf	TRISB			; 0x00 -> TRISB = PortB I/O 0000 0000 (1=input, 0=output)
							;	port B outputs data to the LCD display
							; 	RB6 is also used for programming the PIC
							; 	RB7 is also used for programming the PIC

 	bcf 	STATUS,RP0		; select bank 0                          

 	movlw	0x00			                                
 	movwf	PORTB			; set Port B outputs low                              

 	bcf		PORTA,LCD_E     ; set LCD E strobe low (inactive)
	bcf		PORTA,LCD_RS	; set LCD Register Select low (chooses instruction register)
	bsf		PORTA,UNUSED1	; set high to match pullup (unused)
	bcf		PORTA,UNUSED2   ; set high to match pullup (unused)
                    
   	call    bigDelay		; should wait more than 15ms after Vcc = 4.5V
    call    initLCD
	call	displayGreeting


; begin monitoring the serial data input line from the main PIC for data and instructions
; to be passed on to the LCD display

; data/instructions are received as two byte pairs
; if the first byte (the control byte) is a 

mainLoop:

	clrf	newSerialByte			
    call    receiveSerialData		; wait for and receive the first byte of the next instruction/data byte pair
	movf	newSerialByte,w         ; store the first byte (control)
	movwf	controlByte
                             
	clrf	newSerialByte                       
    call    receiveSerialData
	movf	newSerialByte,w			; store the second byte (could be instruction or data for the LCD)
	movwf	lcdData                             
	
	movf	controlByte,w			; if the control byte is 0, then the second byte is data for the LCD
 	sublw	0
 	btfsc	STATUS,Z
    call    writeLCDData
 	
	movf	controlByte,w			; if the control byte is 1, then the second byte is an instruction for the LCD
 	sublw	0x1
 	btfsc	STATUS,Z
    call    writeLCDInstruction

    goto    mainLoop

; end of Main Code
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; displayGreeting
;
; Displays a greeting string, version info, etc.
;

displayGreeting:

	movlw	0x80			; move cursor to line 1 column 1 (address 00h)
	movwf	lcdData         ;   (bit 7 = 1 specifies address set command, bits 6:0 are the address)
    call    writeLCDInstruction

	movlw	'O'				; display "OPT EDM" on the first line
	movwf	lcdData                             
    call    writeLCDData

	movlw	'P'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	'T'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	' '
	movwf	lcdData                             
    call    writeLCDData

	movlw	'E'                             
	movwf 	lcdData                             
    call    writeLCDData

	movlw	'D'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	'M'                     
	movwf	lcdData                             
    call    writeLCDData

	movlw	0xc1			; move cursor to line 2 column 2 (address 41h)
	movwf	lcdData         ;   (bit 7 = 1 specifies address set command, bits 6:0 are the address)
    call    writeLCDInstruction

	movlw	'N'				; display "Notcher" on the second line
	movwf	lcdData                             
    call    writeLCDData

	movlw	'o'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	't'                            
	movwf	lcdData                             
    call    writeLCDData

	movlw	'c'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	'h'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	'e'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	'r'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	0x96			; move cursor to line 3 column 7 (address 16h)
	movwf	lcdData			;   (bit 7 = 1 specifies address set command, bits 6:0 are the address)
    call    writeLCDInstruction

	movlw	'b'				; display "by CMP" on the third line
	movwf	lcdData                             
    call    writeLCDData

	movlw	'y'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	' '  
	movwf	lcdData                             
    call    writeLCDData

	movlw	'C'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	'M'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	'P'
	movwf	lcdData                             
    call    writeLCDData

	movlw	0xd7			; move cursor to line 4 column 8 (address 57h)
	movwf	lcdData			;   (bit 7 = 1 specifies address set command, bits 6:0 are the address)
    call    writeLCDInstruction

	movlw	'R'				; display "Rev 2.7" on the fourth line
	movwf	lcdData                             
    call    writeLCDData

	movlw	'e'                            
	movwf	lcdData                             
    call    writeLCDData

	movlw	'v'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	' '                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	'3'                             
	movwf	lcdData                             
    call    writeLCDData

 	movlw	'.'                             
	movwf	lcdData                             
    call    writeLCDData

	movlw	'0'                             
	movwf	lcdData                             
    call    writeLCDData

	return

; end of displayGreeting
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; initLCD
;
; Initialize the LCD display.
;
; See Dmcman_full-user manual.pdf from www.optrex.com for details.
;

initLCD:

	bcf		LCD_CTRL,LCD_E		; LCD E strobe low                          
	bcf		LCD_CTRL, LCD_RS    ; LCD RS low (instruction register selected)                       
    call    smallDelay			; wait a bit

	movlw	0x30				; 1st send of Function Set Command: (8-Bit interface)(BF cannot be checked before this command.)
	movwf	LCD_DATA			; prepare to write                   
    call    strobeE				; write to LCD
    call    bigDelay			; should wait more than 4.1ms

	movlw	0x30				; 2nd send of Function Set Command: (8-Bit interface)(BF cannot be checked before this command.)
	movwf	LCD_DATA			; prepare to write                   
    call    strobeE				; write to LCD
    call    smallDelay			; should wait more than 100us

	movlw	0x30				; 3rd send of Function Set Command: (8-Bit interface)(BF can be checked after this command)
	movwf	LCD_DATA			; prepare to write	(BF busy flag cannot be checked on this board because R/W line is tied low)
    call    strobeE				; write to LCD
    call    smallDelay			; wait for a bit because BF (busy flag) cannot be checked on this board

	movlw	0x38				; write 0011 1000 Function Set Command ~ multi line display with 5x7 dot font
	movwf	LCD_DATA			;  0011 in upper nibble specifies Function Set Command
    call    strobeE				;  bit 3: 0 = 1 line display, 1 = multi-line display
								;  bit 2: 0 = 5x7 dot font, 1 = 5 x 10 dot font
	call    smallDelay			; wait for a bit because BF (busy flag) cannot be checked on this board

	movlw	0x08				; write 0000 1000 ~ Display Off
	movwf	LCD_DATA			;  bit 3: specifies display on/off command
    call    strobeE				;  bit 2: 0 = display off, 1 = display on
	call    smallDelay			; wait for a bit because BF (busy flag) cannot be checked on this board
								; NOTE: display off added by MKS to match suggested setup in LCD user manual

	movlw	0x01				; write 0000 0001 ~ Clear Display
	movwf	LCD_DATA
    call    strobeE
	call    smallDelay			; wait for a bit because BF (busy flag) cannot be checked on this board
								; NOTE: clear display added by MKS to match suggested setup in LCD user manual

	movlw	0x06				; write 0000 0110 ~ Entry Mode Set, increment mode, no display shift
	movwf	LCD_DATA			; bits 3:2 = 0:1 : specifies Entry Mode Set
    call    strobeE				; bit 1: 0 = no increment, 1 = increment mode; bit 0: 0 = no shift, 1 = shift display
	call    smallDelay			; wait for a bit because BF (busy flag) cannot be checked on this board
								; NOTE: Entry Mode Set was being done after display on -- moved by MKS to match
								;		suggested setup in LCD user manual

	movlw	0x0c				; write 0000 1100 ~ Display On, cursor off, blink off
	movwf	LCD_DATA			;  bit 3: specifies display on/off command
    call    strobeE				;  bit 2: 0 = display off, 1 = display on
								;  bit 1: 0 = cursor off, 1 = cursor on
								;  bit 0: 0 = blink off, 1 = blink on

; Note: BF should be checked before each of the instructions starting with Display OFF.
;   Since this board design does not allow BF (LCD busy flag) to be checked, a delay is inserted after each
;	instruction to allow time for completion.

    call    bigDelay

	return

; end of initLCD
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; writeLCDData
;
; Writes a data byte from variable lcdData to the LCD.  The data is a character to be displayed.
;
                                 
writeLCDData:

	bcf		LCD_CTRL,LCD_E			; init E to low
	bsf		LCD_CTRL,LCD_RS			; select data register in LCD
    call    smallDelay

	movf	lcdData,w				; place data on output port
	movwf	LCD_DATA                          
    call    strobeE					; write the data
    call    smallDelay

	return

; end of writeLCDData
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; writeLCDInstruction
;
; Writes an instruction byte from variable lcdData to the LCD.  The instruction is one of several
; recognized by the LCD display for clearing the screen, moving the cursor, etc.
;
                                 
writeLCDInstruction:

	bcf 	LCD_CTRL,LCD_E			; init E to low  
	bcf 	LCD_CTRL,LCD_RS			; select instruction register in LCD
    call    smallDelay

	movf 	lcdData,w				; place instruction on output port
	movwf	LCD_DATA                         
    call    strobeE					; write the instruction
	bsf		LCD_CTRL,LCD_RS			; set the instruction/data register select back to data register
    call    smallDelay

	return

; end of writeLCDInstruction
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; smallDelay
;
; Creates a small delay.
;
                                 
smallDelay:
	movlw	0x2a                             
	movwf	smallDelayCnt
                             
L8b:
	decfsz	smallDelayCnt,f                         
    goto    L8b
	return

; end of smallDelay
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; bigDelay
;
; Creates a big delay.
;
                                 
bigDelay:

	movlw	0x28                             
	movwf	bigDelayCnt                             
    call	smallDelay

L9b:
	decfsz	bigDelayCnt,f                         
    goto    L9b
	return

; end of bigDelay
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; strobeE
;
; Strobes LCD E line to read/write data to the LCD and then delays for a bit.
;

strobeE:

	bsf		LCD_CTRL,LCD_E
	nop                                    
	bcf		LCD_CTRL,LCD_E
    call    smallDelay
	return

; end of strobeE
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; receiveSerialData
;
; Waits for incoming data to appear on the serial input line and then converts it into two bytes.
;
                                 
receiveSerialData:

	bcf		INTCON,T0IE			; disable TMR0 interrupt
	bcf		INTCON,GIE			; disable all interrupts
	clrf	TMR0				; set Timer 0 to zero
                              
	clrwdt						; clear the watchdog timer in case it is being used
                                 
	bsf		STATUS,RP0			; select bank 2
	
	movlw	0x58				; set options 0101 1000
	movwf	OPTION_REG			; bit 7: PORTB pull-ups are enabled by individual port latch values
     							; bit 6: Interrupt on rising edge of RB0/INT pin
								; bit 5: Timer 0 run by internal instruction cycle clock (CLKOUT)
								; bit 4: Timer 0 increment on high-to-low transition on RA4/T0CKI/CMP2 pin
								; bit 3: Prescaler is assigned to the WDT
								; bits 2:0 : WDT rate is 1:1 

	bcf		STATUS,RP0			; select bank 1

	movlw	0x8					; preset bit counter to 8 bits to make a byte
	movwf	bitCount
	
L10b:
 	btfsc	PORTA,SERIAL_IN		; loop until serial in data line gloes low to signal new bit
    goto    L10b				;  this first low is the start bit and will be tossed

 	movlw	0xe2				; set Timer 0 to delay a bit to center sampling near the center of the bit
 	movwf	TMR0
 	bcf		INTCON,T0IF			; clear Timer 0 overflow flag

L11b:
	btfss	INTCON,T0IF			; loop until Timer 0 overflow flag is set
    goto    L11b

	btfsc	PORTA,SERIAL_IN		; check serial input again -- if it is not still low then                         
    goto    L10b				;  assume it was noise and start over looking for start bit

L13b:
	movlw	0xce				; set Timer 0 to delay until first data bit
	movwf	TMR0
	bcf		INTCON,T0IF			; clear Timer 0 overflow flag

L12b:
	btfss	INTCON,T0IF			; loop until Timer 0 overflow flag is set
    goto    L12b

	bcf		INTCON,T0IF			; clear Timer 0 overflow flag
	
	movf	PORTA,w				; get Port A, bit 0 of which is the serial in data line
	movwf	scratch0			; save it so rrf can be performed
	rrf		scratch0,f			; rotate bit 0 (serial data in) into the Carry bit                            
	rlf		newSerialByte,f		; rotate the Carry bit into the new data byte being constructed
      
 	decfsz	bitCount,f			; loop for 8 bits                         
    goto    L13b
 
	return                                 

; end of receiveSerialData
;--------------------------------------------------------------------------------------------------
 
    END
