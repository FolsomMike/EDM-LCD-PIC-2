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

;--------------------------------------------------------------------------------------------------
; Power On and Reset Vectors
;

	org	0x00				; Start of Program Memory

; none of the other vectors are used, so the program just starts executing at the reset vector
; location

Start:

	movlw	0x7                    
 	movwf	0x1f
 	bsf 	0x3,0x5                           
	movlw 	0x1                              
 	movwf 	0x5                              
 	movlw 	0                                
 	movwf	0x6                              
 	bcf 	0x3,0x5                           
 	movlw	0                                
 	movwf	0x6                              
 	bcf		0x5,0x1                           
	bcf		0x5,0x2                           
	bsf		0x5,0x3                           
	bcf		0x5,0x4                           
   	call    L0b        ;(0xae)
    call    L1b        ;(0x7e)
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

L1b:
	bcf		0x5,0x1                           
	bcf		0x5,0x2                           
    call    L6b        ;(0xa9)
	movlw	0x30                             
	movwf	0x6                              
    call    L7b        ;(0xb4)
    call    L0b        ;(0xae)
	movlw	0x30                             
	movwf	0x6                              
    call    L7b        ;(0xb4)
    call    L6b        ;(0xa9)
	movlw	0x30                             
	movwf	0x6                              
    call    L7b        ;(0xb4)
    call    L6b        ;(0xa9)
	movlw	0x38                             
	movwf	0x6                              
    call    L7b        ;(0xb4)
	movlw	0xc                              
	movwf	0x6                              
    call    L7b        ;(0xb4)
	movlw	0x6                              
	movwf	0x6                              
    call    L7b        ;(0xb4)
    call    L0b        ;(0xae)
	return
                                 
L3b:
	bcf		0x5,0x1                           
	bsf		0x5,0x2                           
    call    L6b        ;(0xa9)
	movf	0x6e, w                           
	movwf	0x6                              
    call    L7b        ;(0xb4)
    call    L6b        ;(0xa9)
	return
                                 
L2b:
	bcf 	0x5,0x1                           
	bcf 	0x5,0x2                           
    call    L6b        ;(0xa9)
	movf 	0x6e,w                           
	movwf	0x6                              
    call    L7b        ;(0xb4)
	bsf		0x5,0x2                           
    call    L6b        ;(0xa9)
	return
                                 
L6b:
	movlw	0x2a                             
	movwf	0x68
                             
L8b:
	decfsz	0x68, f                         
    goto    L8b        ;(0xab)
	return
                                 
L0b:
	movlw	0x28                             
	movwf	0x69                             
    call	L6b        ;(0xa9)

L9b:
	decfsz	0x69,f                         
    goto    L9b        ;(0xb0)
	return

L7b:
	bsf		0x5,0x1                           
	nop                                    
	bcf		0x5,0x1                           
    call    L6b        ;(0xa9)
	return
                                 
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
