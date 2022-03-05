;Archivo: Post-laboratorio_6.s
;Dispositivo: PIC16F887
;Autor: Sergio Alejandro Boch Ixén
; Compilador: pic-as (v2.31), MPLABX v5.45
; 
; Programa: TMR01 Y TMR02
; Hardware: 7 SEGMENTOS EN PUERTO C Y LED EN PUERTO D, TRANSISTORES PARA MULTIPLEX
;
;Creado: 28 feb, 2022
;Ultima Modificacion:    5 mar, 2022
    
PROCESSOR 16F887

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)
;--------------macros---------------------------------------------------

// config statements should precede project file includes.
#include <xc.inc>
  
; -------------- MACROS --------------- 
  ; Macro para reiniciar el valor del TMR0
  ; *Recibe el valor a configurar en TMR_VAR*
  RESET_TMR0 MACRO TMR_VAR
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuración del tiempo de retardo
    BCF	    T0IF	    ; limpiamos flag de interrupción
    ENDM
  RESET_TMR1 MACRO TMR1_H, TMR1_L
    MOVLW   TMR1_H
    MOVWF   TMR1H	    ; 50ms retardo
    MOVLW   TMR1_L	    ; limpiamos flag de interrupción
    MOVWF   TMR1L
    BCF	    TMR1IF
    ENDM
  
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		    ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
PSECT udata_bank0	    ;banco de variables
    segs:      DS 1
    var:	   DS 1
    flag:	   DS 1
    UNI:	   DS 1
    DECENA:	   DS 1
    disp:	   DS 2
PSECT resVect, class=CODE, abs, delta=2
ORG 00h			    ; posición 0000h para el reset
;------------ VECTOR RESET --------------
resetVec:
    PAGESEL MAIN	    ; Cambio de pagina
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h			    ; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
PUSH:
    MOVWF   W_TEMP	    ; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP	    ; Guardamos STATUS
    
ISR:
    BTFSC   T0IF
    CALL    int_tmr0
    BTFSC   TMR1IF
    CALL    INCREMENTO
    
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS	    ; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W	    ; Recuperamos valor de W
    RETFIE		    ; Regresamos a ciclo principal
    
INCREMENTO:
    RESET_TMR1 0x0B, 0xCD
    INCF segs
    MOVF segs, W
    MOVWF  PORTB
    MOVLW 61
    SUBWF segs, w
    btfsc ZERO
    clrf segs
    RETURN
int_tmr0:
    RESET_TMR0 237
    clrf PORTD
    BTFSC   flag, 0
    goto dis2
dis1:
    movf    disp, w
    movwf   PORTA
    BSF	    PORTD, 0
    goto    next
dis2:
    movf    disp+1, w
    movwf   PORTA
    BSF	    PORTD, 1
    goto    next
next:
    movlw 1
    xorwf   flag, F
    return
PSECT code, delta=2, abs
ORG 100h		    ; posición 100h para el codigo
;------------- CONFIGURACION ------------
Tabla:			    ;TABLA DEL PROGRAM COUNTER
    CLRF PCLATH
    BSF PCLATH, 0
    ANDLW 0x0f
    ADDWF PCL 
    RETLW 00111111B ;0
    RETLW 00000110B ;1
    RETLW 01011011B ;2
    RETLW 01001111B ;3
    RETLW 01100110B ;4
    RETLW 01101101B ;5
    RETLW 01111101B ;6
    RETLW 00000111B ;7
    RETLW 01111111B ;8
    RETLW 01101111B ;9
    RETLW 00111111B ;0
    
MAIN:
    CALL    SETUP_IO	    ; Configuración de I/O
    CALL    SETUP_RELOJ    ; Configuración de Oscilador
    CALL    SETUP_TMR0
    CALL    SETUP_TMR1	    ; Configuración de TMR0
    CALL    SETUP_INTERRUPCION	    ; Configuración de interrupciones
    BANKSEL PORTD	    ; Cambio a banco 00
    
LOOP:
    ; Código que se va a estar ejecutando mientras no hayan interrupciones
    MOVF    segs, w
    MOVWF   var
    call DIVIDE
    call CARGA
    GOTO    LOOP	    
    
;------------- SUBRUTINAS ---------------
DIVIDE:
    CALL DECC
    RETURN

CARGA:
    movf    UNI, w
    call    Tabla
    movwf   disp
    movf    DECENA, w
    call    Tabla
    movwf   disp+1
    return
    
SETUP_RELOJ:
    BANKSEL OSCCON	    ; cambiamos a banco 1
    BSF	    OSCCON, 0	    ; SCS -> 1, Usamos reloj interno
    BSF	    OSCCON, 6
    BCF	    OSCCON, 5
    BSF	    OSCCON, 4	    ; IRCF<2:0> -> 101 2MHz
    RETURN
    
 ;Configuramos el TMR0 para obtener un retardo de 50ms
SETUP_TMR0:
    BANKSEL OPTION_REG	    ; camMR0 como temporizador
    BCF	    PSA		    ; prescaler biamos de banco
    BCF	    T0CS	    ; TMR0 como temporizador
    BCF	    PSA		    ; prescaler a TMR0
    BSF	    PS2
    BSF	    PS1
    BSF	    PS0		    
    
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   237
    MOVWF   TMR0	    ; 2ms retardo
    BCF	    T0IF	    ; limpiamos flag de interrupción
    RETURN
    
SETUP_TMR1:
    BANKSEL T1CON	    ; cambiamos de banco
    BCF	    TMR1GE	    ; TMR1 Siempre cuenta
    BSF	    T1CKPS1		    ; prescaler a TMR1
    BSF	    T1CKPS0		    
    BCF	    T1OSCEN		    ; OSC tmr1 desactivado
    BCF	    TMR1CS
    BSF	    TMR1ON
    
    RESET_TMR1 0x0B, 0xCD
    RETURN 
    
 SETUP_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	        ; I/O digitales
    BANKSEL TRISD
    CLRF    TRISB	    ; PORTD como salida
    CLRF    TRISA
    BCF     TRISD, 0
    BCF     TRISD, 1
    BANKSEL PORTD
    CLRF    PORTB	    ; Apagamos PORTB
    CLRF    PORTA
    BCF	    PORTD, 0
    BCF	    PORTD, 1
    RETURN
    
SETUP_INTERRUPCION:
    BANKSEL PIE1 
    BSF	    TMR1IE
    BANKSEL INTCON
    BSF	    PEIE	    ; Habilitamos interrupciones
    BSF	    GIE		    ; Habilitamos interrupcion TMR0
    BSF	    T0IE	    ; Habilitamos interrupcion TMR0
    BCF	    T0IF	    ; Limpiamos flag de TMR0
    BCF	    TMR1IF
    RETURN

    DECC:
	clrf DECENA	    ;limpuiar la variable donde se guardan las DECC	
	movlw	10	    ;mover 10 a w
	subwf	var, W    ;restar 10 al valor del PORT A
	btfsc	STATUS, 0   ;skip if el carry esta en 0
	incf	DECENA	    ; incrementar el contador de la variable DECC
	btfsc	STATUS, 0   ;skip if el carry esta en 0
	movwf	var	    ; mover el valor de la resta a w
	btfsc	STATUS, 0   ;skip if el carry esta en 0
	goto	$-7	    ; si se puede seguir restando 10 entonces realizar todo el proceso
	call UNII	    ; si ya no se puede restar 10, por que la flag de carry se encendio entonces ir a unidades
	return
	
    UNII:
	clrf UNI	    ;limpiar la variable donde se guardan las unidades
	movlw	1	    ;mover 1 a w
	subwf	var, F    ; restar 1 al valor del PORT A
	btfsc	STATUS, 0   ;skip if el carry esta en 0
	incf	UNI	    ; incrementar el contador de la variable unidades
	btfss	STATUS, 0   ; si tenemos un carry en el valor entonces realizar otra vez el proceso
	return		    ; si no se puede seguir restando 1 erntonces se regresa al stack 
	goto $-6
end


