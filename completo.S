; ============================================================================
; ARCHIVO: completo.S
; DESCRIPCIÓN: Driver de Motores y Lectura RC (Versión Diagnóstico Serial)
; ============================================================================

#include <avr/io.h>

; --- VARIABLES GLOBALES (Compartidas con C++) ---
.global rc_throttle
.section .bss
    rc_throttle: .skip 2    ; Variable de 16 bits para guardar la lectura del mando
    rc_start:    .skip 2    ; Variable interna para medir el inicio del pulso

.section .text

; ----------------------------------------------------------------------------
; FUNCIÓN: system_init
; Inicializa Timers para PWM y la Interrupción externa para el Mando.
; NOTA: NO INICIALIZA UART (Para evitar conflicto con Serial Monitor)
; ----------------------------------------------------------------------------
.global system_init
system_init:
    ; --- 1. CONFIGURACIÓN TIMER 1 (Motores Delanteros - 16 bits) ---
    ; Pines 9 (PB1) y 10 (PB2) como SALIDA
    sbi _SFR_IO_ADDR(DDRB), 1
    sbi _SFR_IO_ADDR(DDRB), 2
    
    ; Configurar Fast PWM, TOP = ICR1 (Modo 14)
    ; Prescaler = 8 (0.5us por tick -> 2MHz)
    ; COM1A1/COM1B1 para salida no invertida
    
    ldi r16, 0
    sts TCNT1H, r16
    sts TCNT1L, r16     ; Reset contador

    ; ICR1 = 39999 (20ms periodo a 50Hz)
    ldi r16, 0x9F
    ldi r17, 0x9C
    sts ICR1L, r16
    sts ICR1H, r17

    ; TCCR1A: COM1A1=1, COM1B1=1, WGM11=1
    ldi r16, (1 << COM1A1) | (1 << COM1B1) | (1 << WGM11)
    sts TCCR1A, r16

    ; TCCR1B: WGM13=1, WGM12=1, CS11=1 (Prescaler 8)
    ldi r16, (1 << WGM13) | (1 << WGM12) | (1 << CS11)
    sts TCCR1B, r16

    ; --- 2. CONFIGURACIÓN TIMER 2 (Motores Traseros - 8 bits) ---
    ; Pin 11 (PB3/OC2A) y Pin 3 (PD3/OC2B) como SALIDA
    sbi _SFR_IO_ADDR(DDRB), 3  ; Pin 11
    sbi _SFR_IO_ADDR(DDRD), 3  ; Pin 3

    ; Fast PWM, Prescaler 128 (Frecuencia 488Hz aprox)
    ; TCCR2A: COM2A1=1, COM2B1=1, WGM21=1, WGM20=1
    ldi r16, (1 << COM2A1) | (1 << COM2B1) | (1 << WGM21) | (1 << WGM20)
    sts TCCR2A, r16

    ; TCCR2B: CS22=1, CS20=1 (Prescaler 128)
    ldi r16, (1 << CS22) | (1 << CS20)
    sts TCCR2B, r16

    ; --- 3. CONFIGURACIÓN LECTURA RC (Pin 2 / INT0) ---
    cli                 ; Desactivar interrupciones momentáneamente
    sbi _SFR_IO_ADDR(DDRD), 2 ; Pin 2 como entrada (por si acaso)
    cbi _SFR_IO_ADDR(DDRD), 2 ; Asegurar que es entrada
    
    ; EICRA: ISC00=1 (Cualquier cambio lógico en INT0)
    lds r16, EICRA
    ori r16, (1 << ISC00)
    sts EICRA, r16
    
    ; EIMSK: Habilitar INT0
    sbi _SFR_IO_ADDR(EIMSK), INT0

    ; --- 4. UART (SENSOR) ---
    ; COMENTADO PARA DIAGNÓSTICO:
    ; rcall uart_init   <-- ANULADO PARA USAR SERIAL MONITOR

    sei                 ; Habilitar interrupciones globales
    ret

; ----------------------------------------------------------------------------
; FUNCIONES DE CONTROL DE MOTORES
; ----------------------------------------------------------------------------

; set_motor_fl (Pin 9 - Timer 1 A)
; Entrada: r24, r25 (uint16_t)
.global set_motor_fl
set_motor_fl:
    sts OCR1AL, r24
    sts OCR1AH, r25
    ret

; set_motor_fr (Pin 10 - Timer 1 B)
; Entrada: r24, r25 (uint16_t)
.global set_motor_fr
set_motor_fr:
    sts OCR1BL, r24
    sts OCR1BH, r25
    ret

; set_motor_bl (Pin 3 - Timer 2 B)
; Entrada: r24 (uint8_t)
.global set_motor_bl
set_motor_bl:
    sts OCR2B, r24
    ret

; set_motor_br (Pin 11 - Timer 2 A)
; Entrada: r24 (uint8_t)
.global set_motor_br
set_motor_br:
    sts OCR2A, r24
    ret

; ----------------------------------------------------------------------------
; RUTINA DE INTERRUPCIÓN: LECTURA RC (INT0 / Pin 2)
; Mide el ancho del pulso usando el Timer 1 (0.5us precisión)
; ----------------------------------------------------------------------------
.global INT0_vect
INT0_vect:
    push r16
    in r16, _SFR_IO_ADDR(SREG)
    push r16
    push r24
    push r25

    ; Verificar estado del Pin 2 (PIND & 0x04)
    sbis _SFR_IO_ADDR(PIND), 2
    rjmp rc_falling

rc_rising:
    ; Flanco de SUBIDA: Guardamos el tiempo actual (TCNT1)
    lds r24, TCNT1L
    lds r25, TCNT1H
    sts rc_start, r24
    sts rc_start+1, r25
    rjmp rc_end

rc_falling:
    ; Flanco de BAJADA: Calculamos Duración = TCNT1 - Start
    lds r24, TCNT1L
    lds r25, TCNT1H
    
    lds r16, rc_start
    sub r24, r16      ; Low - StartLow
    
    lds r16, rc_start+1
    sbc r25, r16      ; High - StartHigh - Carry

    ; Guardar resultado en variable global 'rc_throttle'
    sts rc_throttle, r24
    sts rc_throttle+1, r25

rc_end:
    pop r25
    pop r24
    pop r16
    out _SFR_IO_ADDR(SREG), r16
    pop r16
    reti

; ----------------------------------------------------------------------------
; RUTINA DE INTERRUPCIÓN: UART RX (SENSOR)
; --- DESACTIVADA/RENOMBRADA PARA EVITAR CONFLICTO CON SERIAL.PRINT ---
; ----------------------------------------------------------------------------
.global USART_RX_vect_OFF 
USART_RX_vect_OFF:
    ; Esta rutina ya no se llama porque no inicializamos el UART.
    ; La dejamos aquí con otro nombre para que no moleste.
    reti