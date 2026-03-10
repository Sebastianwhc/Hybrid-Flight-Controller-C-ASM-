#include <avr/io.h>

.global init_motors
.global write_motors_asm

; --- INICIALIZACIÓN DE MOTORES (HARDWARE PWM) ---
init_motors:
    ; 1. CONFIGURACIÓN PINES (SALIDAS)
    ; Pines PB1 (9), PB2 (10), PB3 (11) como SALIDA
    in r24, _SFR_IO_ADDR(DDRB)
    ori r24, (1<<1) | (1<<2) | (1<<3)
    out _SFR_IO_ADDR(DDRB), r24
    
    ; Pin PD3 (3) como SALIDA
    sbi _SFR_IO_ADDR(DDRD), 3

    ; 2. CONFIGURACIÓN TIMER 1 (Pines 9 y 10 - 16 Bits)
    ; Fast PWM, TOP=ICR1, Prescaler 8 (0.5us ticks)
    ldi r24, (1<<COM1A1)|(1<<COM1B1)|(1<<WGM11)
    sts TCCR1A, r24
    ldi r24, (1<<WGM13)|(1<<WGM12)|(1<<CS11) 
    sts TCCR1B, r24
    
    ; TOP = 40000 (20ms) -> CORRECCIÓN: Escribir HIGH primero
    ldi r25, 0x9C  ; High Byte de 40000
    sts ICR1H, r25
    ldi r24, 0x40  ; Low Byte de 40000
    sts ICR1L, r24

    ; 3. CONFIGURACIÓN TIMER 2 (Pines 3 y 11 - 8 Bits)
    ; Fast PWM, Prescaler 128 (8us ticks) -> Periodo ~2.04ms
    ldi r24, (1<<COM2A1)|(1<<COM2B1)|(1<<WGM21)|(1<<WGM20)
    sts TCCR2A, r24
    ldi r24, (1<<CS22)|(1<<CS20) 
    sts TCCR2B, r24

    ret

; --- ESCRITURA DE MOTORES ---
; write_motors_asm(int FL_pin9, int BL_pin10, int BR_pin3, int FR_pin11)
; Convierte microsegundos a ticks del timer y escribe en registros PWM.

write_motors_asm:
    ; --- PIN 9 (Timer 1 A) - FL ---
    ; Entrada r24:r25. Formula: Val * 2
    movw r30, r24
    lsl r30
    rol r31
    ; CORRECCIÓN: Escribir HIGH primero
    sts OCR1AH, r31
    sts OCR1AL, r30

    ; --- PIN 10 (Timer 1 B) - BL ---
    ; Entrada r22:r23. Formula: Val * 2
    movw r30, r22
    lsl r30
    rol r31
    ; CORRECCIÓN: Escribir HIGH primero
    sts OCR1BH, r31
    sts OCR1BL, r30

    ; --- PIN 3 (Timer 2 B) - BR ---
    ; Entrada r20:r21. Formula: Val / 8
    lsr r21
    ror r20
    lsr r21
    ror r20
    lsr r21
    ror r20
    sts OCR2B, r20

    ; --- PIN 11 (Timer 2 A) - FR ---
    ; Entrada r18:r19. Formula: Val / 8
    lsr r19
    ror r18
    lsr r19
    ror r18
    lsr r19
    ror r18
    sts OCR2A, r18

    ret