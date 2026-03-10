#include <avr/io.h>

; --- Variables Globales  ---
.section .bss
.global raw_roll
.global raw_pitch
.global raw_yaw

raw_roll:  .space 2  ; 2 bytes (Low, High)
raw_pitch: .space 2
raw_yaw:   .space 2

; Variables internas
rx_state:   .byte 0  ; Máquina de estados
byte_count: .byte 0 

.section .text
.global uart_init
.global uart_send_byte
.global USART_RX_vect ; Vector de interrupción

; --- Inicialización UART ---
uart_init:
    ; Configuración 9600 Baud @ 16MHz (UBRR = 103)
    ldi r24, 103
    sts UBRR0L, r24
    ldi r24, 0
    sts UBRR0H, r24

    ; Habilitar RX, INT RX y TX
    ldi r24, (1 << RXEN0) | (1 << RXCIE0) | (1 << TXEN0)
    sts UCSR0B, r24

    ; 8N1
    ldi r24, (1 << UCSZ01) | (1 << UCSZ00)
    sts UCSR0C, r24

    sei  ; Habilitar interrupciones globales
    ret

; --- Enviar Byte (r24) ---
uart_send_byte:
wait_tx:
    lds r25, UCSR0A
    sbrs r25, UDRE0
    rjmp wait_tx
    sts UDR0, r24
    ret

; --- ISR de Recepción ---
USART_RX_vect:
    push r16
    in r16, _SFR_IO_ADDR(SREG)
    push r16
    push r17
    push r18
    push r26
    push r27
    push r1 ; Guardamos r1 por seguridad

    ; Leer dato
    lds r16, UDR0 
    lds r17, rx_state 

    ; Estado 0: Esperando 0x55
    cpi r17, 0
    brne check_state_1
    cpi r16, 0x55 
    brne exit_isr 
    ldi r17, 1 
    sts rx_state, r17
    rjmp exit_isr

check_state_1:
    ; Estado 1: Esperando 0x53
    cpi r17, 1
    brne check_data
    cpi r16, 0x53 
    brne reset_state 
    ldi r17, 2 
    sts rx_state, r17
    rjmp exit_isr

check_data:
    ; Estados 2-7: Guardando datos
    ; Puntero base a raw_roll
    ldi r26, lo8(raw_roll)
    ldi r27, hi8(raw_roll)
    
    ; Calcular offset: (rx_state - 2)
    mov r18, r17
    subi r18, 2
    
    ; Sumar offset al puntero X (r26:r27)
    add r26, r18
    clr r1          ; Aseguramos que r1 sea 0 para el acarreo
    adc r27, r1     
    
    st X, r16       ; Guardar dato

    inc r17         ; Siguiente estado
    sts rx_state, r17

    cpi r17, 8      ; ¿Terminamos los 6 bytes?
    brne exit_isr
    
reset_state:
    ldi r17, 0
    sts rx_state, r17

exit_isr:
    pop r1
    pop r27
    pop r26
    pop r18
    pop r17
    pop r16
    out _SFR_IO_ADDR(SREG), r16
    pop r16
    reti