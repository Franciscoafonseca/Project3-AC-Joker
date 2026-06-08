$MOD51

;==============================================================
; Projeto P3 - Concurso JOKER
; Microcontrolador: AT89S51 / 8051
; Cristal: 12 MHz
;
; Versão sem espera ativa:
; - Timer0: interrupção a cada 50 ms
; - Timer1: interrupção a cada 500 us para buzzer de 1 kHz
; - INT0: botão START
; - INT1: botões de resposta
; - Programa principal entra em Idle Mode
;==============================================================

;==============================================================
; Pinos personalizados
;==============================================================

BUZZER  BIT 090H       ; P1.0

BSTART  BIT 0B2H       ; P3.2 / INT0
INTBOT  BIT 0B3H       ; P3.3 / INT1
BA      BIT 0B4H       ; P3.4
BB      BIT 0B5H       ; P3.5
BC      BIT 0B6H       ; P3.6
BD      BIT 0B7H       ; P3.7

TEMPO_INICIAL        EQU 05H
JOKERS_INICIAIS      EQU 06H
NIVEL_INICIAL        EQU 01H
NIVEL_MAXIMO         EQU 08H

CODIGO_NAO_RESP      EQU 0AH

TH0_50MS             EQU 03CH
TL0_50MS             EQU 0B0H

TH1_500US            EQU 0FEH
TL1_500US            EQU 00CH

TICKS_1S             EQU 20
TICKS_2S             EQU 40

; Estados
EST_PRONTO           EQU 00H
EST_CONTAGEM         EQU 01H
EST_ESPERA_LIB       EQU 02H
EST_DELAY_RESP       EQU 03H
EST_TIMEOUT_ZERO     EQU 04H
EST_DELAY_TIMEOUT    EQU 05H
EST_VITORIA          EQU 06H

;---------------- RAM interna ----------------

STATE       DATA 30H
NIVEL       DATA 31H
JOKERS      DATA 32H
TEMPO       DATA 33H
TICKS50     DATA 34H
TICKS_EST   DATA 35H
RESPOSTA    DATA 36H
BUZZ_L      DATA 37H
BUZZ_H      DATA 38H

;==============================================================
; Vetores de interrupção
;==============================================================

ORG 0000H
    LJMP START

ORG 0003H
    LJMP ISR_INT0

ORG 000BH
    LJMP ISR_TIMER0

ORG 0013H
    LJMP ISR_INT1

ORG 001BH
    LJMP ISR_TIMER1

;==============================================================
; Programa principal
;==============================================================

ORG 0030H

START:
    MOV SP, #6FH
    LCALL CONFIGURA_8051
    LCALL REINICIA_CONCORRENTE

    SETB EX0
    SETB EX1
    SETB ET0
    SETB ET1
    SETB EA

MAIN:
    ORL PCON, #01H          ; Idle Mode, sem espera ativa
    SJMP MAIN

;==============================================================
; Configuração
;==============================================================

CONFIGURA_8051:
    MOV P0, #00H
    MOV P1, #00H
    MOV P2, #00H
    MOV P3, #0FFH

    MOV TMOD, #11H          ; Timer0 e Timer1 em modo 1

    MOV TH0, #TH0_50MS
    MOV TL0, #TL0_50MS

    MOV TH1, #TH1_500US
    MOV TL1, #TL1_500US

    SETB IT0                ; INT0 por flanco descendente
    SETB IT1                ; INT1 por flanco descendente

    SETB TR0                ; Timer0 sempre ativo
    CLR TR1                 ; Timer1 só na vitória

    RET

;==============================================================
; Reinício do concorrente
;==============================================================

REINICIA_CONCORRENTE:
    MOV STATE, #EST_PRONTO

    MOV NIVEL, #NIVEL_INICIAL
    MOV JOKERS, #JOKERS_INICIAIS
    MOV TEMPO, #TEMPO_INICIAL
    MOV RESPOSTA, #00H

    MOV TICKS50, #00H
    MOV TICKS_EST, #00H

    MOV BUZZ_L, #00H
    MOV BUZZ_H, #00H

    CLR TR1
    CLR BUZZER

    LCALL ATUALIZA_LEDS
    LCALL ATUALIZA_DISPLAYS

    RET

;==============================================================
; Preparação de nova pergunta
;==============================================================

PREPARA_PERGUNTA:
    MOV TEMPO, #TEMPO_INICIAL
    MOV RESPOSTA, #00H

    MOV TICKS50, #00H
    MOV TICKS_EST, #00H

    LCALL ATUALIZA_DISPLAYS

    RET

;==============================================================
; Atualização dos displays
; P2.7..P2.4 = TEMPO
; P2.3..P2.0 = JOKER
;==============================================================

ATUALIZA_DISPLAYS:
    MOV A, TEMPO
    ANL A, #0FH
    SWAP A
    ANL A, #0F0H
    MOV R7, A

    MOV A, JOKERS
    ANL A, #0FH
    ORL A, R7

    MOV P2, A
    RET

;==============================================================
; Atualização dos LEDs
;==============================================================

ATUALIZA_LEDS:
    MOV A, NIVEL
    CJNE A, #NIVEL_MAXIMO, LED_COMPARA

    MOV P0, #080H
    RET

LED_COMPARA:
    JNC LED_NIVEL_8

    MOV A, #01H
    MOV R7, NIVEL
    DEC R7
    JZ LED_GRAVA

LED_LOOP:
    RL A
    DJNZ R7, LED_LOOP

LED_GRAVA:
    MOV P0, A
    RET

LED_NIVEL_8:
    MOV P0, #080H
    RET

;==============================================================
; INT0 - START
;==============================================================

ISR_INT0:
    PUSH ACC
    PUSH PSW

    MOV A, STATE
    JNZ FIM_INT0

    LCALL PREPARA_PERGUNTA
    MOV STATE, #EST_CONTAGEM

FIM_INT0:
    POP PSW
    POP ACC
    RETI

;==============================================================
; INT1 - Resposta A/B/C/D
;==============================================================

ISR_INT1:
    PUSH ACC
    PUSH PSW

    MOV A, STATE
    CJNE A, #EST_CONTAGEM, FIM_INT1

    JNB BA, RESP_A
    JNB BB, RESP_B
    JNB BC, RESP_C
    JNB BD, RESP_D
    SJMP FIM_INT1

RESP_A:
    MOV RESPOSTA, #01H
    SJMP RESP_OK

RESP_B:
    MOV RESPOSTA, #02H
    SJMP RESP_OK

RESP_C:
    MOV RESPOSTA, #03H
    SJMP RESP_OK

RESP_D:
    MOV RESPOSTA, #04H

RESP_OK:
    MOV STATE, #EST_ESPERA_LIB
    MOV TICKS_EST, #00H
    LCALL ATUALIZA_DISPLAYS

FIM_INT1:
    POP PSW
    POP ACC
    RETI

;==============================================================
; Timer0 - base temporal de 50 ms
;==============================================================

ISR_TIMER0:
    PUSH ACC
    PUSH PSW

    MOV TH0, #TH0_50MS
    MOV TL0, #TL0_50MS

    MOV A, STATE

    CJNE A, #EST_CONTAGEM, T0_TESTA_LIB
    LCALL T0_CONTAGEM
    SJMP FIM_TIMER0

T0_TESTA_LIB:
    CJNE A, #EST_ESPERA_LIB, T0_TESTA_DELAY_RESP
    LCALL T0_ESPERA_LIBERTAR
    SJMP FIM_TIMER0

T0_TESTA_DELAY_RESP:
    CJNE A, #EST_DELAY_RESP, T0_TESTA_TIMEOUT_ZERO
    LCALL T0_DELAY_RESPOSTA
    SJMP FIM_TIMER0

T0_TESTA_TIMEOUT_ZERO:
    CJNE A, #EST_TIMEOUT_ZERO, T0_TESTA_DELAY_TIMEOUT
    LCALL T0_TIMEOUT_ZERO
    SJMP FIM_TIMER0

T0_TESTA_DELAY_TIMEOUT:
    CJNE A, #EST_DELAY_TIMEOUT, FIM_TIMER0
    LCALL T0_DELAY_TIMEOUT

FIM_TIMER0:
    POP PSW
    POP ACC
    RETI

;==============================================================
; Estado: contagem decrescente
;==============================================================

T0_CONTAGEM:
    INC TICKS50

    MOV A, TICKS50
    CJNE A, #TICKS_1S, T0_CONTAGEM_FIM

    MOV TICKS50, #00H

    MOV A, TEMPO
    JZ T0_PASSA_TIMEOUT

    DEC TEMPO
    LCALL ATUALIZA_DISPLAYS

    MOV A, TEMPO
    JNZ T0_CONTAGEM_FIM

T0_PASSA_TIMEOUT:
    MOV STATE, #EST_TIMEOUT_ZERO
    MOV TICKS_EST, #00H

T0_CONTAGEM_FIM:
    RET

;==============================================================
; Estado: esperar libertar botões, sem while
;==============================================================

T0_ESPERA_LIBERTAR:
    JNB BA, T0_LIB_FIM
    JNB BB, T0_LIB_FIM
    JNB BC, T0_LIB_FIM
    JNB BD, T0_LIB_FIM
    JNB INTBOT, T0_LIB_FIM

    MOV STATE, #EST_DELAY_RESP
    MOV TICKS_EST, #00H

T0_LIB_FIM:
    RET

;==============================================================
; Estado: esperar 2 s após resposta
;==============================================================

T0_DELAY_RESPOSTA:
    INC TICKS_EST

    MOV A, TICKS_EST
    CJNE A, #TICKS_2S, T0_DELAY_RESP_FIM

    MOV TICKS_EST, #00H

    LCALL PROCESSA_RESPOSTA

    MOV A, STATE
    CJNE A, #EST_VITORIA, T0_PREPARA_PROXIMA
    RET

T0_PREPARA_PROXIMA:
    LCALL PREPARA_PERGUNTA
    MOV STATE, #EST_PRONTO

T0_DELAY_RESP_FIM:
    RET

;==============================================================
; Estado: mostrar 0 durante 1 s após timeout
;==============================================================

T0_TIMEOUT_ZERO:
    INC TICKS_EST

    MOV A, TICKS_EST
    CJNE A, #TICKS_1S, T0_TIMEOUT_ZERO_FIM

    MOV TICKS_EST, #00H
    MOV TEMPO, #CODIGO_NAO_RESP

    LCALL PROCESSA_RESPOSTA_ERRADA

    MOV STATE, #EST_DELAY_TIMEOUT

T0_TIMEOUT_ZERO_FIM:
    RET

;==============================================================
; Estado: manter símbolo sem resposta durante 2 s
;==============================================================

T0_DELAY_TIMEOUT:
    INC TICKS_EST

    MOV A, TICKS_EST
    CJNE A, #TICKS_2S, T0_DELAY_TIMEOUT_FIM

    MOV TICKS_EST, #00H

    LCALL PREPARA_PERGUNTA
    MOV STATE, #EST_PRONTO

T0_DELAY_TIMEOUT_FIM:
    RET

;==============================================================
; Processar resposta
;==============================================================

PROCESSA_RESPOSTA:
    MOV A, NIVEL
    DEC A

    MOV DPTR, #TABELA_RESPOSTAS
    MOVC A, @A+DPTR

    CJNE A, RESPOSTA, RESPOSTA_ERRADA

    LCALL PROCESSA_RESPOSTA_CERTA
    RET

RESPOSTA_ERRADA:
    LCALL PROCESSA_RESPOSTA_ERRADA
    RET

;==============================================================
; Resposta certa
;==============================================================

PROCESSA_RESPOSTA_CERTA:
    MOV A, NIVEL
    CJNE A, #NIVEL_MAXIMO, AINDA_NAO_MAXIMO
    SJMP ATINGIU_VITORIA

AINDA_NAO_MAXIMO:
    INC NIVEL
    LCALL ATUALIZA_LEDS

    MOV A, NIVEL
    CJNE A, #NIVEL_MAXIMO, RESPOSTA_CERTA_FIM

ATINGIU_VITORIA:
    MOV P0, #0FFH
    LCALL INICIA_BUZZER

RESPOSTA_CERTA_FIM:
    RET

;==============================================================
; Resposta errada ou ausência de resposta
;==============================================================

PROCESSA_RESPOSTA_ERRADA:
    MOV A, JOKERS
    CLR C
    SUBB A, #03H
    JC SEM_JOKERS

    MOV JOKERS, A
    SJMP ERRO_ATUALIZA

SEM_JOKERS:
    MOV JOKERS, #00H

    MOV A, NIVEL
    CLR C
    SUBB A, #04H
    JC NIVEL_VOLTA_1

    MOV A, NIVEL
    CLR C
    SUBB A, #03H
    MOV NIVEL, A
    SJMP ERRO_ATUALIZA

NIVEL_VOLTA_1:
    MOV NIVEL, #01H

ERRO_ATUALIZA:
    LCALL ATUALIZA_LEDS
    LCALL ATUALIZA_DISPLAYS

    RET

;==============================================================
; Iniciar buzzer de vitória
; 5 s a 1 kHz = 10000 interrupções de 500 us
; 10000 decimal = 2710H
;==============================================================

INICIA_BUZZER:
    MOV STATE, #EST_VITORIA

    MOV BUZZ_H, #027H
    MOV BUZZ_L, #010H

    CLR BUZZER

    MOV TH1, #TH1_500US
    MOV TL1, #TL1_500US

    CLR TF1
    SETB TR1

    RET

;==============================================================
; Timer1 - buzzer de 1 kHz
;==============================================================

ISR_TIMER1:
    PUSH ACC
    PUSH PSW

    MOV TH1, #TH1_500US
    MOV TL1, #TL1_500US

    CPL BUZZER

    MOV A, BUZZ_L
    JNZ DEC_BUZZ_LOW

    DEC BUZZ_H

DEC_BUZZ_LOW:
    DEC BUZZ_L

    MOV A, BUZZ_H
    ORL A, BUZZ_L
    JNZ FIM_TIMER1

    CLR TR1
    CLR BUZZER

    LCALL REINICIA_CONCORRENTE

FIM_TIMER1:
    POP PSW
    POP ACC
    RETI

;==============================================================
; Tabela de respostas certas
; 1=A, 2=B, 3=C, 4=D
;==============================================================

TABELA_RESPOSTAS:
    DB 01H, 02H, 03H, 04H, 01H, 02H, 03H, 04H

END
