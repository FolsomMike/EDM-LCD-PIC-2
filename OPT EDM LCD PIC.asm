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
; 1.0   Some code and concepts used from source code disassembled from hex object code version ?.? 
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
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Configurations, etc. for the Assembler Tools and the PIC

	LIST p = PIC16F648a	;select the processor

    errorlevel  -306 ; Suppresses Message[306] Crossing page boundary -- ensure page bits are set.

    errorLevel  -302 ; Suppresses Message[302] Register in operand not in bank 0.

#INCLUDE <P16f648a.inc> 		; Microchip Device Header File

#INCLUDE <STANDARD.MAC>     	; include standard macros

; Specify Device Configuration Bits

  __CONFIG _INTOSC_OSC_CLKOUT & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF

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
; Power On and Reset Vectors
;

	org	0x00				; Start of Program Memory

; none of the other vectors are used, so the program just starts executing at the reset vector
; location

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

	movlw	0x80                             
	movwf	0x6e                             
    call    L2b        ;(0xa0)
	movlw	0x4f                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x50                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x54                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x20                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x45                             
	movwf 	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x44                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x4d                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0xc1                             
	movwf	0x6e                             
    call    L2b        ;(0xa0)
	movlw	0x4e                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x6f                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x74                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x63                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x68                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x65                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x72                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x96                             
	movwf	0x6e                             
    call    L2b        ;(0xa0)
	movlw	0x62                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x79                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x20                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x43                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x4d                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x50                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0xd7                             
	movwf	0x6e                             
    call    L2b        ;(0xa0)
	movlw	0x52                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x65                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x76                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x20                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x32                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
 	movlw	0x2e                             
	movwf	0x6e                             
    call    L3b        ;(0x98)
	movlw	0x36                             
	movwf	0x6e                             
    call    L3b        ;(0x98)

L5b:
	clrf	0x6a                              
    call    L4b        ;(0xb9)
	movf	0x6a,w                           
	movwf	0x6d                             
	clrf	0x6a                              
    call    L4b        ;(0xb9)
	movf	0x6a,w                           
	movwf	0x6e                             
	movf	0x6d,w                       
 	sublw	0                                
 	btfsc	0x3,0x2                         
    call    L3b        ;(0x98)
 	movf	0x6d,w                           
 	sublw	0x1                              
 	btfsc	0x3,0x2                         
    call    L2b        ;(0xa0)
    goto    L5b        ;(0x6d)

;--------------------------------------------------------------------------------------------------
; initLCD
;
; Initialize the LCD display.
;
; See Dmcman_full-user manual.pdf from www.optrex.com for details.
;

zzz

LCD_CTRL        EQU     0x05		; PORTA
SERIAL_IN		EQU		0x00		; RA0
LCD_E           EQU     0x01		; RA1 - data read/write strobe
LCD_RS			EQU		0x02		; RA2 - instruction/data register select
UNUSED1			EQU		0x03
UNUSED2			EQU		0X04

LCD_DATA        EQU     0x06		; PORTB

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

	movlw	0x30				; 1st send of Function Set Command: (8-Bit interface)(BF can be checked after this command)
	movwf	LCD_DATA			; prepare to write	(BF busy flag cannot be checked on this board because R/W line is tied low)
    call    strobeE				; write to LCD
    call    smallDelay			; wait for a bit because BF (busy flag) cannot be checked on this board

	movlw	0x38				; write 0011 1000 Function Set Command -- multi line display with 5x7 dot font
	movwf	LCD_DATA			;  0011 in upper nibble specifies Function Set Command
    call    strobeE				;  bit 3: 0 = 1 line display, 1 = multi-line display
								;  bit 2: 0 = 5x7 dot font, 1 = 5 x 10 dot font

	movlw	0x0c				; write 0000 1100
	movwf	LCD_DATA
    call    strobeE

	movlw	0x6
	movwf	LCD_DATA
    call    strobeE

    call    bigDelay        ;(0xae)

	return

; end of initLCD
;--------------------------------------------------------------------------------------------------

                                 
L3b:
	bcf		0x5,0x1                           
	bsf		0x5,0x2                           
    call    smallDelay
	movf	0x6e, w                           
	movwf	0x6                              
    call    strobeE
    call    smallDelay
	return
                                 
L2b:
	bcf 	0x5,0x1                           
	bcf 	0x5,0x2                           
    call    smallDelay
	movf 	0x6e,w                           
	movwf	0x6                              
    call    strobeE
	bsf		0x5,0x2                           
    call    smallDelay
	return

;--------------------------------------------------------------------------------------------------
; smallDelay
;
; Creates a small delay.
;
                                 
smallDelay:
	movlw	0x2a                             
	movwf	0x68
                             
L8b:
	decfsz	0x68, f                         
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
	movwf	0x69                             
    call	smallDelay

L9b:
	decfsz	0x69,f                         
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

                                 
L4b:
	bcf		0xb,0x5                           
	bcf		0xb,0x7                           
	clrf	0x1                               
	clrwdt                                 
	bsf		0x3,0x5                           
	movlw	0x58                             
	movwf	0x1                              
	bcf		0x3,0x5                           
	movlw	0x8                              
	movwf	0x6b                             
	
L10b:
 	btfsc	0x5,0                           
    goto    L10b        ;(0xc3)
 	movlw	0xe2                             
 	movwf	0x1                              
 	bcf		0xb,0x2                           

L11b:
	btfss	0xb,0x2                         
    goto    L11b        ;(0xc8)
	btfsc	0x5,0                           
    goto    L10b        ;(0xc3)

L13b:
	movlw	0xce                             
	movwf	0x1                              
	bcf		0xb,0x2

L12b:
	btfss	0xb,0x2                         
    goto    L12b        ;(0xcf)
	bcf		0xb,0x2                           
	movf	0x5,w                            
	movwf	0x6c                             
	rrf		0x6c,f                            
	rlf		0x6a,f                            
 	decfsz	0x6b,f                         
    goto    L13b        ;(0xcc)
 
	return                                 
 
    END
