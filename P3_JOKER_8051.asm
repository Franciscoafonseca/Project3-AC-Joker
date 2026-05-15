;===============================================================================
; Projeto P3 - Concurso de perguntas de conhecimento (JOKER)
; Microcontrolador: AT89S51 / 8051
; Montador: Keil A51
; Cristal assumido: 11.0592 MHz
;
; Ligações:
;   P3.2  - BSTART / INT0, ativo a 0
;   P3.3  - interrupção comum dos botões / INT1, ativo a 0
;   P3.4  - Botão A, ativo a 0
;   P3.5  - Botão B, ativo a 0
;   P3.6  - Botão C, ativo a 0
;   P3.7  - Botão D, ativo a 0
;   P1.0  - Buzzer
;   P2.7..P2.4 - BCD display TEMPO
;   P2.3..P2.0 - BCD display JOKER
;   P0.0..P0.7 - LEDs dos níveis 1..8
;===============================================================================

;-------------------------------
; Constantes
;-------------------------------
TEMPO_INICIAL       EQU 05H
JOKERS_INICIAIS     EQU 06H
NIVEL_INICIAL       EQU 01H
NIVEL_MAXIMO        EQU 08H
COD_NAO_RESPONDEU   EQU 0AH       ; ajustar se o circuito exigir outro código

TH0_50MS            EQU 04CH      ; 50 ms para 11.0592 MHz
TL0_50MS            EQU 000H
TH1_50MS            EQU 04CH
TL1_50MS            EQU 000H
TH1_500US           EQU 0FEH      ; 500 us para onda de 1 kHz
TL1_500US           EQU 033H

;-------------------------------
; Bits dos periféricos
;-------------------------------
BUZZER      BIT P1.0
BSTART      BIT P3.2
INT_BOTOES  BIT P3.3
BA          BIT P3.4
BB          BIT P3.5
BC          BIT P3.6
BD          BIT P3.7

;-------------------------------
; Variáveis em RAM interna
;-------------------------------
NIVEL       DATA 30H
JOKERS      DATA 31H
TEMPO       DATA 32H
TICKS       DATA 33H
RESPOSTA    DATA 34H
CNT1        DATA 35H
CNT2        DATA 36H

;-------------------------------
; Flags bit-addressable
;-------------------------------
CONTAGEM_ATIVA    BIT 20H
RESPOSTA_PEND     BIT 21H
TIMEOUT_PEND      BIT 22H
BLOQUEIA_RESP     BIT 23H

;===============================================================================
; Vetores de interrupção
;===============================================================================
            ORG 0000H
            LJMP START

            ORG 0003H          ; INT0 - botão START
            LJMP ISR_START

            ORG 000BH          ; Timer0
            LJMP ISR_TIMER0

            ORG 0013H          ; INT1 - botões de resposta
            LJMP ISR_RESPOSTA

;===============================================================================
; Programa principal
;===============================================================================
            ORG 0030H
START:
            MOV SP,#60H        ; pilha afastada das variáveis
            MOV P0,#00H        ; LEDs desligados inicialmente
            MOV P1,#00H        ; buzzer desligado
            MOV P2,#00H        ; displays
            MOV P3,#0FFH       ; P3 como entradas com pull-up

            MOV TMOD,#11H      ; Timer0 e Timer1 em modo 1, 16 bits
            MOV TH0,#TH0_50MS
            MOV TL0,#TL0_50MS

            SETB IT0           ; INT0 por flanco descendente
            SETB IT1           ; INT1 por flanco descendente
            SETB EX0           ; ativa INT0
            SETB EX1           ; ativa INT1
            SETB ET0           ; ativa interrupção do Timer0
            SETB EA            ; interrupções globais
            SETB TR0           ; Timer0 sempre ligado

            ACALL REINICIA_CONCORRENTE

MAIN_LOOP:
            JB RESPOSTA_PEND, TRATA_RESPOSTA
            JB TIMEOUT_PEND, TRATA_TIMEOUT
            SJMP MAIN_LOOP

TRATA_RESPOSTA:
            ACALL PROCESSA_RESPOSTA
            CLR RESPOSTA_PEND
            ACALL AGUARDA_LIBERTAR_BOTOES
            ACALL DELAY_2S
            ACALL PREPARA_PERGUNTA
            SJMP MAIN_LOOP

TRATA_TIMEOUT:
            ; Sem resposta: mostra 0 durante 1 s, depois símbolo da Figura 1.
            ACALL DELAY_1S
            MOV TEMPO,#COD_NAO_RESPONDEU
            ACALL ATUALIZA_DISPLAYS
            ACALL PROCESSA_ERRADA      ; timeout tratado como resposta errada
            ACALL DELAY_2S
            ACALL PREPARA_PERGUNTA
            CLR TIMEOUT_PEND
            SJMP MAIN_LOOP

;===============================================================================
; Rotinas de inicialização/estado
;===============================================================================
REINICIA_CONCORRENTE:
            CLR CONTAGEM_ATIVA
            CLR RESPOSTA_PEND
            CLR TIMEOUT_PEND
            CLR BLOQUEIA_RESP
            MOV NIVEL,#NIVEL_INICIAL
            MOV JOKERS,#JOKERS_INICIAIS
            MOV TEMPO,#TEMPO_INICIAL
            MOV TICKS,#00H
            MOV RESPOSTA,#00H
            CLR BUZZER
            ACALL ATUALIZA_LEDS
            ACALL ATUALIZA_DISPLAYS
            RET

PREPARA_PERGUNTA:
            CLR CONTAGEM_ATIVA
            CLR RESPOSTA_PEND
            CLR TIMEOUT_PEND
            CLR BLOQUEIA_RESP
            MOV TEMPO,#TEMPO_INICIAL
            MOV TICKS,#00H
            MOV RESPOSTA,#00H
            ACALL ATUALIZA_DISPLAYS
            RET

;===============================================================================
; Saídas: displays e LEDs
;===============================================================================
ATUALIZA_DISPLAYS:
            ; P2.7..P2.4 = TEMPO, P2.3..P2.0 = JOKERS
            MOV A,TEMPO
            ANL A,#0FH
            SWAP A
            ANL A,#0F0H
            MOV R7,A
            MOV A,JOKERS
            ANL A,#0FH
            ORL A,R7
            MOV P2,A
            RET

ATUALIZA_LEDS:
            ; LED correspondente ao nível atual.
            MOV A,NIVEL
            CJNE A,#01H, LED_N2
            MOV P0,#00000001B
            RET
LED_N2:     CJNE A,#02H, LED_N3
            MOV P0,#00000010B
            RET
LED_N3:     CJNE A,#03H, LED_N4
            MOV P0,#00000100B
            RET
LED_N4:     CJNE A,#04H, LED_N5
            MOV P0,#00001000B
            RET
LED_N5:     CJNE A,#05H, LED_N6
            MOV P0,#00010000B
            RET
LED_N6:     CJNE A,#06H, LED_N7
            MOV P0,#00100000B
            RET
LED_N7:     CJNE A,#07H, LED_N8
            MOV P0,#01000000B
            RET
LED_N8:     MOV P0,#10000000B
            RET

;===============================================================================
; Lógica do jogo
;===============================================================================
PROCESSA_RESPOSTA:
            ; Compara RESPOSTA com a resposta correta do nível atual.
            MOV DPTR,#TABELA_RESPOSTAS
            MOV A,NIVEL
            DEC A                  ; índice 0..7
            MOVC A,@A+DPTR
            CJNE A,RESPOSTA, RESP_ERRADA
            ACALL PROCESSA_CERTA
            RET
RESP_ERRADA:
            ACALL PROCESSA_ERRADA
            RET

PROCESSA_CERTA:
            MOV A,NIVEL
            CJNE A,#NIVEL_MAXIMO, INC_NIVEL
            SJMP VITORIA
INC_NIVEL:
            INC NIVEL
            ACALL ATUALIZA_LEDS
            MOV A,NIVEL
            CJNE A,#NIVEL_MAXIMO, FIM_CERTA
VITORIA:
            MOV P0,#0FFH           ; todos os LEDs acesos
            ACALL BUZZER_5S        ; onda quadrada de 1 kHz durante 5 s
            ACALL REINICIA_CONCORRENTE
FIM_CERTA:
            RET

PROCESSA_ERRADA:
            ; Se ainda há jokers, retira 3. Caso contrário, desce 3 níveis, sem baixar de 1.
            MOV A,JOKERS
            CLR C
            SUBB A,#03H
            JC SEM_JOKERS
            MOV JOKERS,A
            ACALL ATUALIZA_DISPLAYS
            RET

SEM_JOKERS:
            MOV JOKERS,#00H
            MOV A,NIVEL
            CLR C
            SUBB A,#03H
            JC NIVEL_MINIMO
            JZ NIVEL_MINIMO
            MOV NIVEL,A
            SJMP ERRO_ATUALIZA
NIVEL_MINIMO:
            MOV NIVEL,#01H
ERRO_ATUALIZA:
            ACALL ATUALIZA_LEDS
            ACALL ATUALIZA_DISPLAYS
            RET

;===============================================================================
; Interrupções
;===============================================================================
ISR_START:
            PUSH ACC
            JB CONTAGEM_ATIVA, FIM_ISR_START
            JB RESPOSTA_PEND, FIM_ISR_START
            JB TIMEOUT_PEND, FIM_ISR_START
            ACALL PREPARA_PERGUNTA
            SETB CONTAGEM_ATIVA
FIM_ISR_START:
            POP ACC
            RETI

ISR_TIMER0:
            PUSH ACC
            PUSH PSW
            MOV TH0,#TH0_50MS
            MOV TL0,#TL0_50MS

            JNB CONTAGEM_ATIVA, FIM_ISR_T0
            INC TICKS
            MOV A,TICKS
            CJNE A,#20, FIM_ISR_T0 ; 20 x 50 ms = 1 s
            MOV TICKS,#00H

            MOV A,TEMPO
            JZ TEMPO_ESGOTADO
            DEC TEMPO
            ACALL ATUALIZA_DISPLAYS
            MOV A,TEMPO
            JNZ FIM_ISR_T0

TEMPO_ESGOTADO:
            CLR CONTAGEM_ATIVA
            SETB BLOQUEIA_RESP
            SETB TIMEOUT_PEND

FIM_ISR_T0:
            POP PSW
            POP ACC
            RETI

ISR_RESPOSTA:
            PUSH ACC
            JNB CONTAGEM_ATIVA, FIM_ISR_RESP
            JB BLOQUEIA_RESP, FIM_ISR_RESP

            JNB BA, RESP_A
            JNB BB, RESP_B
            JNB BC, RESP_C
            JNB BD, RESP_D
            SJMP FIM_ISR_RESP

RESP_A:     MOV RESPOSTA,#01H
            SJMP GUARDA_RESP
RESP_B:     MOV RESPOSTA,#02H
            SJMP GUARDA_RESP
RESP_C:     MOV RESPOSTA,#03H
            SJMP GUARDA_RESP
RESP_D:     MOV RESPOSTA,#04H

GUARDA_RESP:
            CLR CONTAGEM_ATIVA
            SETB BLOQUEIA_RESP
            SETB RESPOSTA_PEND
            ACALL ATUALIZA_DISPLAYS ; mantém o tempo remanescente visível

FIM_ISR_RESP:
            POP ACC
            RETI

;===============================================================================
; Delays e buzzer
;===============================================================================
AGUARDA_LIBERTAR_BOTOES:
            JNB BA, AGUARDA_LIBERTAR_BOTOES
            JNB BB, AGUARDA_LIBERTAR_BOTOES
            JNB BC, AGUARDA_LIBERTAR_BOTOES
            JNB BD, AGUARDA_LIBERTAR_BOTOES
            JNB INT_BOTOES, AGUARDA_LIBERTAR_BOTOES
            RET

DELAY_50MS:
            MOV TH1,#TH1_50MS
            MOV TL1,#TL1_50MS
            CLR TF1
            SETB TR1
D50_WAIT:   JNB TF1,D50_WAIT
            CLR TR1
            CLR TF1
            RET

DELAY_1S:
            MOV CNT1,#20
D1_LOOP:    ACALL DELAY_50MS
            DJNZ CNT1,D1_LOOP
            RET

DELAY_2S:
            ACALL DELAY_1S
            ACALL DELAY_1S
            RET

DELAY_500US:
            MOV TH1,#TH1_500US
            MOV TL1,#TL1_500US
            CLR TF1
            SETB TR1
D500_WAIT:  JNB TF1,D500_WAIT
            CLR TR1
            CLR TF1
            RET

BUZZER_5S:
            ; 10000 semi-períodos de 0,5 ms = 5 s.
            MOV R6,#40             ; 40 * 250 = 10000
B5_OUTER:   MOV R7,#250
B5_INNER:   CPL BUZZER
            ACALL DELAY_500US
            DJNZ R7,B5_INNER
            DJNZ R6,B5_OUTER
            CLR BUZZER
            RET

;===============================================================================
; Tabela de respostas corretas por nível
; 1=A, 2=B, 3=C, 4=D. Alterar de acordo com as perguntas escolhidas.
;===============================================================================
TABELA_RESPOSTAS:
            DB 01H,02H,03H,04H,01H,02H,03H,04H

            END
