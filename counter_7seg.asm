; ============================================================
; Exercício 2 - CONTADOR + DISPLAY DE SETE SEGMENTOS
; Placa: EXSTO118 | PIC: PIC18F4550
; Simulação: MPLAB 5.15
; Descrição: Ao pressionar o botão em RB0, incrementa o
;            contador de 0 a 9 e exibe no display 7seg em PORTD


    LIST P=18F4550
    #include <P18F4550.INC>

; --- Configuração dos Fuses ---
    CONFIG FOSC = XT_XT
    CONFIG WDT  = OFF
    CONFIG LVP  = OFF
    CONFIG PBADEN = OFF

; --- Variáveis na RAM ---
    CBLOCK 0x000
        contador        ; Valor atual do contador (0-9)
        temp_w          ; Salva W no acesso à tabela
        delay1
        delay2
    ENDC

; --- Vetor de Reset ---
    ORG 0x0000
    GOTO inicio


; Tabela de segmentos para display de ânodo comum
; Segmentos: gfedcba → PORTD<6:0>
;   Dígito:  0     1     2     3     4     5     6     7     8     9
;   Hex:    3Fh   06h   5Bh   4Fh   66h   6Dh   7Dh   07h   7Fh   6Fh

    ORG 0x0020
tabela_7seg:
    ADDWF   PCL, F          ; Salta W posições na tabela
    RETLW   0x3F            ; 0
    RETLW   0x06            ; 1
    RETLW   0x5B            ; 2
    RETLW   0x4F            ; 3
    RETLW   0x66            ; 4
    RETLW   0x6D            ; 5
    RETLW   0x7D            ; 6
    RETLW   0x07            ; 7
    RETLW   0x7F            ; 8
    RETLW   0x6F            ; 9

; --- Programa Principal ---
inicio:
    ; Configura portas
    CLRF    TRISD           ; PORTD = saída (display 7seg)
    MOVLW   0xFF
    MOVWF   TRISB           ; PORTB = entrada (botão em RB0)

    ; Desabilita conversores A/D para usar PORTB digital
    MOVLW   0x0F
    MOVWF   ADCON1

    ; Inicia contador em zero
    CLRF    contador
    MOVLW   0x00
    CALL    tabela_7seg
    MOVWF   PORTD           ; Exibe "0" no display

loop_principal:
    ; Aguarda botão em RB0 ser pressionado (nível baixo)
    BTFSC   PORTB, 0        ; Pula se RB0 = 0 (pressionado)
    GOTO    loop_principal

    ; Debounce - aguarda estabilizar
    CALL    delay_debounce

    ; Verifica se ainda está pressionado
    BTFSC   PORTB, 0
    GOTO    loop_principal

    ; Incrementa contador
    INCF    contador, F
    MOVLW   0x0A
    CPFSEQ  contador        ; Pula se contador == 10
    GOTO    exibe
    CLRF    contador        ; Volta para 0

exibe:
    ; Busca código do display na tabela
    MOVF    contador, W
    CALL    tabela_7seg
    MOVWF   PORTD           ; Envia para o display

aguarda_soltar:
    ; Aguarda botão ser solto
    BTFSS   PORTB, 0        ; Pula se RB0 = 1 (solto)
    GOTO    aguarda_soltar

    GOTO    loop_principal


; Delay para debounce (~20ms)
delay_debounce:
    MOVLW   0xFF
    MOVWF   delay2
loop_deb2:
    MOVLW   0x1A
    MOVWF   delay1
loop_deb1:
    DECFSZ  delay1, F
    GOTO    loop_deb1
    DECFSZ  delay2, F
    GOTO    loop_deb2
    RETURN

    END
