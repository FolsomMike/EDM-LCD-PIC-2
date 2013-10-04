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
; This program reads serial data sent by the Main PIC and displays it on the LCD. All data is
; first stored in a local buffer which is then repeatedly transmitted to the LCD display. This
; constant refreshing corrects errors which occur in the displayed text due to electrical noise
; from the cutting current causing spikes in the LCD display control lines.
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
; 1.1	Major change to methodolgy. The data from the master PIC is now written to a local buffer
;		which is then continuously and repeatedly transmitted to the LCD display. All control codes
; 		received from the master except address change codes are transmitted straight to the display.
;		The constant refreshing of the display serves to correct errors caused by noise from the
;		cutting current. The errors manifested as changed or missing characters in the display.
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
; LCD ADDRESSING NOTE: LCD addressing is screwy - the lines are not in sequential order:
;
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

	__CONFIG _INTOSC_OSC_CLKOUT & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF

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
; Constant Definitions
;

; bits in flags variable

ADDRESS_SET_BIT	EQU		7		; set in LCD control codes to specify an address change byte

MAX_COLUMN      EQU     .19		; highest column number (20 columns)
PAST_MAX_COLUMN EQU		.20		; one past the highest column number
MAX_LINE		EQU		.3		; highest line number (4 lines)
PAST_MAX_LINE	EQU		.4		; one past the highest line number

; actual bytes to write to LCD to address the different columns
; see "LCD ADDRESSING NOTE" in header notes at top of page for addressing explanation

LCD_COLUMN0_START	EQU		0x80
LCD_COLUMN0_END		EQU		0x93
LCD_COLUMN1_START	EQU		0xc0
LCD_COLUMN1_END		EQU		0xd3
LCD_COLUMN2_START	EQU		0x94
LCD_COLUMN2_END		EQU		0xa7
LCD_COLUMN3_START	EQU		0xd4
LCD_COLUMN3_END		EQU		0xe7

LCD_BUFFER_SIZE		EQU		.80

; LCD Display Commands

CLEAR_SCREEN_CMD	EQU		0x01

; LCD Display On/Off Command bits

;  bit 3: specifies that this is a display on/off command if 1
;  bit 2: 0 = display off, 1 = display on
;  bit 1: 0 = cursor off, 1 = cursor on
;  bit 0: 0 = character blink off, 1 = blink on

DISPLAY_ONOFF_CMD_FLAG	EQU		0x08
DISPLAY_ON_FLAG			EQU		0x04
CURSOR_ON_FLAG			EQU		0x02
BLINK_ON_FLAG			EQU		0x01

; end of Constant Definitions
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

    lcdFlags                ; bit 0: 0 = not used, 1 = not used
                            ; bit 1: 
                            ; bit 2:
                            ; bit 3:
                            ; bit 4:

    lcdScratch0             ; scratch pad variables
    lcdScratch1

	lcdOutLine				; current line being written to the display
	lcdOutColumn			; current column to be written to the display
    lcdBufOutPtr			; read from buffer to write to LCD pointer


	lcdInColumn				; current column being written to in the buffer
	lcdBufInPtr				; write to buffer from master PIC pointer
	
	; LCD character buffer -- 4 lines x 20 characters each
	; see "LCD ADDRESSING NOTE" in header notes at top of page for addressing explanation

	; line 1

	lcd0			; LCD address 0x00 (send 0x80 to LCD with address control bit 7 set)
	lcd1
	lcd2
	lcd3
	lcd4
	lcd5
	lcd6
	lcd7
	lcd8
	lcd9
	lcd10
	lcd11
	lcd12
	lcd13
	lcd14
	lcd15
	lcd16
	lcd17
	lcd18
	lcd19

	; line 2

	lcd20				; LCD address 0x40 (send 0xc0 to LCD with address control bit 7 set)
	lcd21
	lcd22
	lcd23
	lcd24
	lcd25
	lcd26
	lcd27
	lcd28
	lcd29
	lcd30
	lcd31
	lcd32
	lcd33
	lcd34
	lcd35
	lcd36
	lcd37
	lcd38
	lcd39

	; line 3

	lcd40			; LCD address 0x14 (send 0x94 to LCD with address control bit 7 set)
	lcd41
	lcd42
	lcd43
	lcd44
	lcd45
	lcd46
	lcd47
	lcd48
	lcd49
	lcd50
	lcd51
	lcd52
	lcd53
	lcd54
	lcd55
	lcd56
	lcd57
	lcd58
	lcd59

	; line 4

	lcd60		; LCD address 0x54 (send 0xd4 to LCD with address control bit 7 set)
	lcd61
	lcd62
	lcd63
	lcd64
	lcd65
	lcd66
	lcd67
	lcd68
	lcd69
	lcd70
	lcd71
	lcd72
	lcd73
	lcd74
	lcd75
	lcd76
	lcd77
	lcd78
	lcd79

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

	bcf 	STATUS,RP0		; select bank 0

	call	setUpLCDCharacterBuffer

	call	clearLCDLocalBuffer

 	bcf 	STATUS,RP0		; select bank 0

	call	displayGreeting

	bcf 	STATUS,RP0		; select bank 0

; begin monitoring the serial data input line from the main PIC for data and instructions
; to be passed on to the LCD display

; in between each check for incoming data on the serial line, write one character from the local
; LCD buffer to the LCD display

mainLoop:

	bcf		STATUS,RP0			; select bank 0

 	btfss	PORTA,SERIAL_IN		; skip if serial is not low to signal start bit of incoming data
	call	receiveAndHandleSerialWord

	bcf		STATUS,RP0		; select bank 0

	call	writeNextCharInBufferToLCD ;write one character in the buffer to the LCD

    goto    mainLoop

; end of Main Code
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; receiveAndHandleSerialWord
;
; Waits for and reads a word of data from the serial in port and then processes the data.
;
; Control codes other than address changes and clear screen commands are written to the LCD
; display immediately. Address changes and data values are used to address and store in the local
; LCD character buffer.
;
; Data bank 0 should be selected on entry.
;

receiveAndHandleSerialWord:

	; the receiveSerialByte function will wait until data is present on the serial line

	clrf	newSerialByte			
    call    receiveSerialByte		; wait for and receive the first byte of the next instruction/data byte pair
	movf	newSerialByte,W         ; store the first byte (control)
	movwf	controlByte
                             
	clrf	newSerialByte                       
    call    receiveSerialByte
	movf	newSerialByte,W			; store the second byte (could be instruction or data for the LCD)
	movwf	lcdData                             
	
	movf	controlByte,W			; if the control byte is 0, then the second byte is data for the LCD
 	sublw	0
 	btfsc	STATUS,Z
    call    writeToLCDBuffer		; store byte in the local LCD character buffer

	bcf		STATUS,RP0				; select bank 0
	movf	controlByte,W			; if the control byte is 1, then the second byte is an instruction for the LCD
 	sublw	0x1
 	btfsc	STATUS,Z
    call    handleLCDInstruction

	return

; end of receiveAndHandleSerialWord
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; handleLCDInstruction
;
; Handles LCD instruction codes received from the master PIC. If the control code is an address
; change or clear screen code, the command is directed to the local LCD character buffer. The LCD
; display itself is not changed -- that is handled by the code which transmits the buffer contents
; to the display.
;
; All other control codes are transmitted directly to the LCD display.
;
; Data bank 0 should be selected on entry.
;

handleLCDInstruction:

	; catch clear screen command

	movf	lcdData,W
 	sublw	CLEAR_SCREEN_CMD
 	btfss	STATUS,Z
	goto	notClearScreenCmd

	call	clearLCDLocalBuffer
	return	

notClearScreenCmd:

	; check for address change code

    btfss   lcdData,ADDRESS_SET_BIT	
	goto	notAddressChangeCmd

	; change the local LCD buffer write address
	
	; the buffer is transmitted to the display by another function which sets the address
	; register in the actual display as needed during the transmission

	call	setLCDBufferWriteAddress
	
	return

notAddressChangeCmd:

	; transmit all other control codes straight to the display

    call    writeLCDInstruction

	return

; end of handleLCDInstruction
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; writeNextCharInBufferToLCD
;
; Writes the next character in the current line to the LCD display. If the end of the line is
; reached, the line pointer is incremented to the next line.
;
; Bank selection not important on entry.
;

writeNextCharInBufferToLCD:

	bsf     STATUS,RP0      ; select data bank 1 to access LCD buffer variables

    movf    lcdBufOutPtr,W  ; get pointer to next character to be written to LCD
    movwf   FSR             ; point indirect register FSR at the character    

	movf	INDF,W			; load the character

	bcf		STATUS,RP0		; select bank 0
	movwf	lcdData         ; store for use by writeLCDData function
    call    writeLCDData

	bsf     STATUS,RP0      ; back to bank 1 
	call	incrementLCDOutBufferPointers

	return

; end of writeNextCharInBufferToLCD
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; incrementLCDOutBufferPointers
;
; Increments the pointers used to track the next character to be written to the LCD from the
; character buffer -- the buffer location, line number, and column number are all incremented.
;
; When the last column is reached, the line number is incremented while the column rolls back to 0;
; when the last line is reached the line number rolls back to 0.
;
; Data bank 1 should be selected on entry.
;

incrementLCDOutBufferPointers:

	incf	lcdBufOutPtr,F	; point to next character in buffer

	incf	lcdOutColumn,F	; track column number
	movf	lcdOutColumn,W	; check if highest column number reached
 	sublw	MAX_COLUMN
 	btfss	STATUS,Z
    goto	noRollOver

	clrf	lcdOutColumn	; start over at column 0

	incf	lcdOutLine,F	; track line number
	movf	lcdOutLine,W	; check if highest line number reached
 	sublw	PAST_MAX_LINE
 	btfsc	STATUS,Z
    clrf	lcdOutLine

	call	setLCDVariablesPerLineNumber

noRollOver:

	return

; end of incrementLCDOutBufferPointers
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; setLCDVariablesPerLineNumber
;
; Sets the lcdBufOutPtr and the write address currently stored in the LCD display appropriate to
; the current buffer line number being written.
;
; Data bank 1 should be selected on entry.
;

setLCDVariablesPerLineNumber:

	movf	lcdOutLine,W	; handle line 0
 	sublw	0
 	btfss	STATUS,Z
    goto	notLine0

	movlw   lcd0			; start of line 0
    movwf   lcdBufOutPtr

	movlw	LCD_COLUMN0_START
	goto	writeLCDInstructionAndExit

notLine0:

	movf	lcdOutLine,W	; handle line 1
 	sublw	1
 	btfss	STATUS,Z
    goto	notLine1

	movlw   lcd20			; start of line 1
    movwf   lcdBufOutPtr

	movlw	LCD_COLUMN1_START
	goto	writeLCDInstructionAndExit

notLine1:

	movf	lcdOutLine,W	; handle line 2
 	sublw	2
 	btfss	STATUS,Z
    goto	notLine2

	movlw   lcd40			; start of line 2
    movwf   lcdBufOutPtr

	movlw	LCD_COLUMN2_START
	goto	writeLCDInstructionAndExit

notLine2:

	; don't check if line 3 -- any number not caught above is either 3 or illegal; if illegal then default
	; to line 3 to get things back on track

	movlw   lcd60			; start of line 3
    movwf   lcdBufOutPtr

	movlw	LCD_COLUMN3_START

writeLCDInstructionAndExit:

	bcf		STATUS,RP0				; select bank 0
	movwf	lcdData					; save set address instruction code for writing
    call    writeLCDInstruction		

	return

; end of setLCDVariablesPerLineNumber
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; clearLCDLocalBuffer
;
; Sets all data in the local LCD character buffer to spaces. The LCD display will be cleared
; when the local buffer is next transmitted to the display.
;
; Bank selection not important on entry.
;

clearLCDLocalBuffer:

   	bsf     STATUS,RP0      ; select data bank 1 to access LCD buffer variables

	movlw	LCD_BUFFER_SIZE	; set up loop counter
	movwf	lcdScratch0

	movlw	lcd0			; point indirect register FSR at buffer start
    movwf   FSR             

	movlw	' '				; fill with spaces

clearLCDLoop:
	
	movwf	INDF			; store to each buffer location
	incf	FSR,F
	decfsz	lcdScratch0,F
	goto	clearLCDLoop
	
	call	setUpLCDCharacterBuffer

	return

; end of clearLCDLocalBuffer
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; setUpLCDCharacterBuffer
;
; Prepares the LCD character buffer for use.
;
; Bank selection not important on entry.
;

setUpLCDCharacterBuffer:

   	bsf     STATUS,RP0      ; select data bank 1 to access LCD buffer variables

	movlw   lcd0
	movwf	lcdBufInPtr		; set write to buffer pointer from master PIC to line 0 column 0

    clrf    lcdOutLine    	; start at line 0 for writing buffer to LCD
	clrf	lcdOutColumn	; start a column 0 for writing buffer to LCD

	call	setLCDVariablesPerLineNumber	; set up buffer out to LCD variables

	return

; end of setUpLCDCharacterBuffer
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; setLCDBufferWriteAddress
;
; Sets the LCD buffer write pointer according to the address in lcdData. This value is the
; control code that would be written to the LCD display to set an address. 
;
; see "LCD ADDRESSING NOTE" in header notes at top of page for addressing explanation
;
; Bank 0 should be selected on entry.
;
; REMEMBER: Borrow flag is inverse: 0 = borrow, 1 = no borrow
;

setLCDBufferWriteAddress:

	movf	lcdData,W		; load address control code from bank 0

   	bsf     STATUS,RP0      ; select data bank 1 to access LCD buffer variables

	movwf	lcdScratch0		; store address control code in bank 1 for easy access

	call	getLCDLineContainingAddress	; find which line contains the specified address

	return

; end of setLCDBufferWriteAddress
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; setLCDBufferWriteAddress
;
; Writes the byte in lcdData to the local LCD character buffer at memory location stored in
; lcdBufInPtr. Pointer lcdBufInPtr is then incremented.
;
; The number of characters written to each line is tracked via lcdInColumn. If the maximum
; number of characters has been stored for a line, all further attempts to write will be ignored
; until the address is reset.
;
; Bank 0 should be selected on entry.
;

writeToLCDBuffer:

	movf	lcdData,W		; get the byte to be stored

   	bsf     STATUS,RP0      ; select data bank 1 to access LCD buffer variables

	movwf	lcdScratch0		; store byte in bank 1 for easy access

	movf	lcdInColumn,W	; bail out if already one past the max column number
 	sublw	PAST_MAX_COLUMN	
 	btfsc	STATUS,Z	
	return

	incf	lcdInColumn,f	; track number of bytes written to the line
	
    movf    lcdBufInPtr,W  	; get pointer to next memory location to be used
    movwf   FSR             ; point FSR at the character    

	movf	lcdScratch0,W	; retrieve the byte and store it in the buffer
    movwf	INDF

    incf   lcdBufInPtr,F	; increment the pointer

	return

; end of writeToLCDBuffer
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; getLCDLineContainingAddress
;
; Returns in the W register the line containing the address specified by the control code in
; lcdScratch0. The control byte is the value which would be sent to the LCD display to set the
; address.
;
; The lcdBufInPtr will be set to the proper memory location for storing at the specified address.
;
; An illegal address outside the range of any line defaults to line 3.
;
; see "LCD ADDRESSING NOTE" in header notes at top of page for addressing explanation
;
; Bank 1 should be selected on entry.
;
; REMEMBER: Borrow flag is inverse: 0 = borrow, 1 = no borrow
;

getLCDLineContainingAddress:

	; check for address any where on line 0 (between *_START and *_END

	movlw	LCD_COLUMN0_START	; compare address with *_START
    subwf	lcdScratch0,W		; address >= *_START?
    btfss   STATUS,C			; c = 0 = borrow = address<*_START
    goto	notLine0_GL

	movf	lcdScratch0,W		; compare address	
	sublw	LCD_COLUMN0_END		; address <= *_END?
    btfss   STATUS,C			; c = 0 = borrow = address>*_END
    goto	notLine0_GL

	movlw	LCD_COLUMN0_START	; calculate the buffer index for the address
	subwf	lcdScratch0,W		; by finding the column number first by
								; subtracting the line's start address
	movwf	lcdInColumn			; store the column
	addlw	lcd0				; add column to the line start's memory location
	movwf	lcdBufInPtr			; to get the address's memory location

	movlw	0					; the address is in line 0
	return

notLine0_GL:

	movlw	LCD_COLUMN1_START	; compare address with *_START
    subwf	lcdScratch0,W		; address >= *_START?
    btfss   STATUS,C			; c = 0 = borrow = address<*_START
    goto	notLine1_GL

	movf	lcdScratch0,W		; compare address	
	sublw	LCD_COLUMN1_END		; address <= *_END?
    btfss   STATUS,C			; c = 0 = borrow = address>*_END
    goto	notLine1_GL

	movlw	LCD_COLUMN1_START	; calculate the buffer index for the address
	subwf	lcdScratch0,W		; by finding the column number first by
								; subtracting the line's start address
	movwf	lcdInColumn			; store the column
	addlw	lcd20				; add column to the line start's memory location
	movwf	lcdBufInPtr			; to get the address's memory location

	movlw	1					; the address is in line 1
	return

notLine1_GL:

	movlw	LCD_COLUMN2_START	; compare address with *_START
    subwf	lcdScratch0,W		; address >= *_START?
    btfss   STATUS,C			; c = 0 = borrow = address<*_START
    goto	notLine2_GL

	movf	lcdScratch0,W		; compare address	
	sublw	LCD_COLUMN2_END		; address <= *_END?
    btfss   STATUS,C			; c = 0 = borrow = address>*_END
    goto	notLine2_GL

	movlw	LCD_COLUMN2_START	; calculate the buffer index for the address
	subwf	lcdScratch0,W		; by finding the column number first by
								; subtracting the line's start address
	movwf	lcdInColumn			; store the column
	addlw	lcd40				; add column to the line start's memory location
	movwf	lcdBufInPtr			; to get the address's memory location

	movlw	2					; the address is in line 2
	return

notLine2_GL:

	; all addresses not caught so far returned as line 3
	; illegal addresses end up here as well and default to line 3

	movlw	LCD_COLUMN3_START	; calculate the buffer index for the address
	subwf	lcdScratch0,W		; by finding the column number first by
								; subtracting the line's start address
	movwf	lcdInColumn			; store the column
	addlw	lcd60				; add column to the line start's memory location
	movwf	lcdBufInPtr			; to get the address's memory location

	movlw	3					; the address is in line 3
	return

; end of getLCDLineContainingAddress
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; displayGreeting
;
; Displays a greeting string, version info, etc.
;
; The text is written to the local LCD character buffer so it will be transmitted to the display.
;
; Bank 0 should be selected on entry.
;
; wip mks -- convert this to the write string method used in "OPT EDM Main PIC.asm"
;

displayGreeting:

	movlw	0x80			; move cursor to line 1 column 1 (address 0x00 / code 0x80)
	movwf	lcdData         ;   (bit 7 = 1 specifies address set command, bits 6:0 are the address)
    call	setLCDBufferWriteAddress
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'O'				; display "OPT EDM" on the first line
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'P'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'T'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	' '
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'E'                             
	movwf 	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'D'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'M'                     
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	0xc1			; move cursor to line 2 column 2 (address 41h)
	movwf	lcdData         ;   (bit 7 = 1 specifies address set command, bits 6:0 are the address)
    call	setLCDBufferWriteAddress
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'N'				; display "Notcher" on the second line
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'o'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	't'                            
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'c'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'h'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'e'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'r'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	0x96			; move cursor to line 3 column 7 (address 16h)
	movwf	lcdData			;   (bit 7 = 1 specifies address set command, bits 6:0 are the address)
    call	setLCDBufferWriteAddress
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'b'				; display "by CMP" on the third line
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'y'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	' '  
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'M'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'K'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'S'
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	0xd7			; move cursor to line 4 column 8 (address 57h)
	movwf	lcdData			;   (bit 7 = 1 specifies address set command, bits 6:0 are the address)
    call	setLCDBufferWriteAddress
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'R'				; display "Rev 2.7" on the fourth line
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'e'                            
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'v'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	' '                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'3'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

 	movlw	'.'                             
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

	movlw	'1'       
	movwf	lcdData                             
    call    writeToLCDBuffer
 	bcf 	STATUS,RP0		; select bank 0

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

	movlw	0x0c				; write 0000 1000 ~ Display Off
	movwf	LCD_DATA			;  bit 3: specifies display on/off command
    call    strobeE				;  bit 2: 0 = display off, 1 = display on
	call    smallDelay			; wait for a bit because BF (busy flag) cannot be checked on this board
								; NOTE: LCD user manual instructs to turn off display here with 0x08
								;  but this did NOT work. Unknown why.

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
								;		suggested setup in LCD user manual.
								; NOTE2: See above regarding not working when display turned off before this --
								; does display need to be on when this command given regardless of LCD manual
								; suggestions?

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
; Data bank 0 should be selected on entry.
;
                                 
writeLCDData:

	bcf		LCD_CTRL,LCD_E			; init E to low
	bsf		LCD_CTRL,LCD_RS			; select data register in LCD
    call    smallDelay

	movf	lcdData,W				; place data on output port
	movwf	LCD_DATA                          
    call    strobeE					; write the data
    call    smallDelay

	return

; end of writeLCDData
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; writeLCDInstruction
;
; Writes an instruction byte from variable lcdData to the LCD.  An instruction is one of several
; codes recognized by the LCD display for clearing the screen, moving the cursor, etc.
;
; Data bank 0 should be selected on entry.
;
                                 
writeLCDInstruction:

	bcf 	LCD_CTRL,LCD_E			; init E to low  
	bcf 	LCD_CTRL,LCD_RS			; select instruction register in LCD
    call    smallDelay

	movf 	lcdData,W				; place instruction on output port
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
	decfsz	smallDelayCnt,F                         
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
	decfsz	bigDelayCnt,F                         
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
; receiveSerialByte
;
; Waits for incoming data to appear on the serial input line and then converts it into a byte.
;
                                 
receiveSerialByte:

	bcf		INTCON,T0IE			; disable TMR0 interrupt
	bcf		INTCON,GIE			; disable all interrupts
	clrf	TMR0				; set Timer 0 to zero
                              
	clrwdt						; clear the watchdog timer in case it is being used
                                 
	bsf		STATUS,RP0			; select bank 1
	
	movlw	0x58				; set options 0101 1000
	movwf	OPTION_REG			; bit 7: PORTB pull-ups are enabled by individual port latch values
     							; bit 6: Interrupt on rising edge of RB0/INT pin
								; bit 5: Timer 0 run by internal instruction cycle clock (CLKOUT)
								; bit 4: Timer 0 increment on high-to-low transition on RA4/T0CKI/CMP2 pin
								; bit 3: Prescaler is assigned to the WDT
								; bits 2:0 : WDT rate is 1:1 

	bcf		STATUS,RP0			; select bank 0

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
	
	movf	PORTA,W				; get Port A, bit 0 of which is the serial in data line
	movwf	scratch0			; save it so rrf can be performed
	rrf		scratch0,F			; rotate bit 0 (serial data in) into the Carry bit                            
	rlf		newSerialByte,F		; rotate the Carry bit into the new data byte being constructed
      
 	decfsz	bitCount,F			; loop for 8 bits                         
    goto    L13b
 
	return                                 

; end of receiveSerialByte
;--------------------------------------------------------------------------------------------------
 
    END
