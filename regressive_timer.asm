; ============================================================
; Exercício 3 - TIMER REGRESSIVO 99 → 00 COM INTERRUPÇÃO
; Placa: EXSTO118 | PIC: PIC18F4550
; Simulação: MPLAB 5.15
;
; Descrição:
;   - Botão em RB0 (INT0): DISPARA a contagem regressiva
;   - Botão em RB1:        ZERA o valor e para a contagem
;   - Display dezena:      PORTD (7seg dígito mais significativo)
;   - Display unidade:     PORTC (7seg dígito menos significativo)
;   - Contagem de 99 até 00, decremento a cada 1 segundo
;
; Timer1 gera base de tempo de 1 segundo (Fosc = 4MHz)


    LIST P=18F4550
    #include <P18F4550.INC>

; --- Configuração dos Fuses ---
    CONFIG FOSC = XT_XT
    CONFIG WDT  = OFF
    CONFIG LVP  = OFF
    CONFIG PBADEN = OFF

; --- Constantes ---
#define BTN_START   PORTB, 0    ; Botão disparo (INT0)
#define BTN_ZERO    PORTB, 1    ; Botão zerar

; Timer1 para 1 segundo com Fosc=4MHz, prescaler 1:8
; Fóssil = 4MHz → Ftimer = 1MHz → com prescaler 8 = 125kHz
; 65536 - 125000 = -59464 → overflow a cada 1s
; Valor de recarga: 65536 - 15625 = 49911 = 0xC2F7
; (prescaler 1:8, Fosc/4 = 1MHz → 1MHz/8 = 125kHz → 125000 ciclos/s)
; Recarga: 65536 - 62500 = 3036 = 0x0BDC  (prescaler 1:2, Fosc/4)
; Usando prescaler 1:8: recarga = 65536 - 15625 = 49911 = 0xC2F7
#define TMR1H_RELOAD 0xC2
#define TMR1L_RELOAD 0xF7

; --- Variáveis na RAM ---
    CBLOCK 0x000
        dezena          ; Dígito das dezenas (0-9)
        unidade         ; Dígito das unidades (0-9)
        flag_ativo      ; 0=parado, 1=contando
        w_temp          ; Salva W na interrupção
        status_temp     ; Salva STATUS na interrupção
        bsr_temp        ; Salva BSR na interrupção
    ENDC

; Vetor de Reset
    ORG 0x0000
    GOTO inicio

; Vetor de Interrupção Alta Prioridade → Timer1 (1 segundo)
    ORG 0x0008
isr_alta:
    ; Salva contexto
    MOVWF   w_temp
    MOVFF   STATUS, status_temp
    MOVFF   BSR, bsr_temp

    ; Verifica se é interrupção do Timer1
    BTFSS   PIR1, TMR1IF
    GOTO    fim_isr

    ; Recarrega Timer1
    BCF     PIR1, TMR1IF
    MOVLW   TMR1H_RELOAD
    MOVWF   TMR1H
    MOVLW   TMR1L_RELOAD
    MOVWF   TMR1L

    ; Só decrementa se estiver ativo
    BTFSS   flag_ativo, 0
    GOTO    fim_isr

    ; Decrementa unidade
    MOVF    unidade, W
    BNZ     dec_unidade     ; Se unidade != 0, decrementa

    ; Unidade == 0: verifica dezena
    MOVF    dezena, W
    BNZ     dec_dezena      ; Se dezena != 0, vai decrementar

    ; dezena e unidade == 0: chegou em 00, para contagem
    BCF     flag_ativo, 0
    BCF     T1CON, TMR1ON   ; Para Timer1
    GOTO    fim_isr

dec_dezena:
    ; Unidade volta para 9, decrementa dezena
    MOVLW   0x09
    MOVWF   unidade
    DECF    dezena, F
    GOTO    atualiza_display

dec_unidade:
    DECF    unidade, F

atualiza_display:
    ; Atualiza display dezena (PORTD)
    MOVF    dezena, W
    CALL    tabela_7seg
    MOVWF   PORTD

    ; Atualiza display unidade (PORTC)
    MOVF    unidade, W
    CALL    tabela_7seg
    MOVWF   PORTC

fim_isr:
    ; Restaura contexto
    MOVFF   bsr_temp, BSR
    MOVFF   status_temp, STATUS
    MOVF    w_temp, W
    RETFIE  FAST

; Vetor de Interrupção Baixa Prioridade → INT0 (botão start)
    ORG 0x0018
isr_baixa:
    MOVWF   w_temp
    MOVFF   STATUS, status_temp
    MOVFF   BSR, bsr_temp

    ; Verifica se é INT0
    BTFSS   INTCON, INT0IF
    GOTO    fim_isr_b

    BCF     INTCON, INT0IF  ; Limpa flag INT0

    ; Inicia contagem apenas se estiver parado e valor != 00
    BTFSC   flag_ativo, 0
    GOTO    fim_isr_b       ; Já está ativo, ignora

    MOVF    dezena, W
    IORWF   unidade, W
    BZ      fim_isr_b       ; Está em 00, não inicia

    ; Ativa contagem
    BSF     flag_ativo, 0
    ; Reinicia Timer1
    MOVLW   TMR1H_RELOAD
    MOVWF   TMR1H
    MOVLW   TMR1L_RELOAD
    MOVWF   TMR1L
    BSF     T1CON, TMR1ON

fim_isr_b:
    MOVFF   bsr_temp, BSR
    MOVFF   status_temp, STATUS
    MOVF    w_temp, W
    RETFIE  FAST

; Tabela 7 segmentos (cátodo comum: segmentos ativos em alto)
; Segmentos gfedcba em bits 6:0
    ORG 0x0100             ; Página alinhada para ADDWF PCL funcionar
tabela_7seg:
    ADDWF   PCL, F
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


; Programa Principal
    ORG 0x0200
inicio:
    ; --- Configura portas ---
    CLRF    TRISD           ; PORTD = saída (display dezena)
    CLRF    TRISC           ; PORTC = saída (display unidade)
    MOVLW   0xFF
    MOVWF   TRISB           ; PORTB = entrada (botões)

    ; Desabilita A/D
    MOVLW   0x0F
    MOVWF   ADCON1

    ; --- Inicia variáveis ---
    MOVLW   0x09
    MOVWF   dezena          ; Inicia em 99
    MOVLW   0x09
    MOVWF   unidade
    CLRF    flag_ativo      ; Começa parado

    ; --- Exibe 99 nos displays ---
    MOVLW   0x09
    CALL    tabela_7seg
    MOVWF   PORTD           ; Dezena = 9
    MOVLW   0x09
    CALL    tabela_7seg
    MOVWF   PORTC           ; Unidade = 9

    ; --- Configura Timer1 ---
    ; T1CON: prescaler 1:8, fonte interna, Timer1 OFF
    MOVLW   b'00110000'     ; Prescaler 1:8, Fosc/4, TMR1ON=0
    MOVWF   T1CON
    MOVLW   TMR1H_RELOAD
    MOVWF   TMR1H
    MOVLW   TMR1L_RELOAD
    MOVWF   TMR1L

    ; --- Configura Interrupções ---
    ; Timer1: alta prioridade
    BSF     IPR1, TMR1IP    ; Timer1 = alta prioridade
    BCF     PIR1, TMR1IF    ; Limpa flag Timer1
    BSF     PIE1, TMR1IE    ; Habilita interrupção Timer1

    ; INT0: baixa prioridade (borda de descida em RB0)
    BCF     INTCON2, INTEDG0 ; INT0 na borda de descida
    BCF     INTCON, INT0IF   ; Limpa flag INT0
    BSF     INTCON, INT0IE   ; Habilita INT0
    BCF     INTCON3, INT1IP  ; (garante prioridade baixa p/ INT0)

    ; Habilita interrupções globais
    BSF     RCON, IPEN      ; Habilita prioridades
    BSF     INTCON, GIEH    ; Habilita interrupções alta prioridade
    BSF     INTCON, GIEL    ; Habilita interrupções baixa prioridade


; Loop principal: monitora botão de ZERAR (RB1)
loop_principal:
    ; Verifica botão de zerar (RB1, polling)
    BTFSC   BTN_ZERO        ; Pula se RB1 = 0 (pressionado)
    GOTO    loop_principal

    ; Debounce simples
    CALL    delay_debounce

    BTFSC   BTN_ZERO
    GOTO    loop_principal

    ; Para a contagem
    BCF     T1CON, TMR1ON   ; Para Timer1
    BCF     flag_ativo, 0   ; Marca como inativo

    ; Volta para 99
    MOVLW   0x09
    MOVWF   dezena
    MOVLW   0x09
    MOVWF   unidade

    ; Atualiza display
    MOVLW   0x09
    CALL    tabela_7seg
    MOVWF   PORTD
    MOVLW   0x09
    CALL    tabela_7seg
    MOVWF   PORTC

    ; Aguarda soltar o botão
aguarda_soltar_zero:
    BTFSS   BTN_ZERO
    GOTO    aguarda_soltar_zero

    GOTO    loop_principal


; Delay debounce ~20ms
delay_debounce:
    MOVLW   0xFF
    MOVWF   unidade         ; reutiliza temporariamente? Não!
    ; Usaremos w_temp como temporário (não está em ISR agora)
    MOVLW   0x50
    MOVWF   w_temp
deb_loop2:
    MOVLW   0xFF
    MOVWF   status_temp
deb_loop1:
    DECFSZ  status_temp, F
    GOTO    deb_loop1
    DECFSZ  w_temp, F
    GOTO    deb_loop2
    RETURN

    END
