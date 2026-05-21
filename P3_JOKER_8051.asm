;===============================================================================
; Projeto P3 - Concurso de perguntas de conhecimento (JOKER)
; Microcontrolador: AT89S51 / 8051
; Assembler: Keil A51 / uVision
; Cristal assumido: 11.0592 MHz
;
; Ligacoes conforme enunciado:
;   P3.2 / INT0  - BSTART, ativo a 0, interrupcao por flanco descendente
;   P3.3 / INT1  - interrupcao comum dos botoes BA/BB/BC/BD, ativo a 0
;   P3.4         - BA, resposta A, ativo a 0
;   P3.5         - BB, resposta B, ativo a 0
;   P3.6         - BC, resposta C, ativo a 0
;   P3.7         - BD, resposta D, ativo a 0
;   P1.0         - Buzzer
;   P2.7..P2.4  - BCD do display TEMPO
;   P2.3..P2.0  - BCD do display JOKER
;   P0.0..P0.7  - LEDs dos niveis 1..8
;
; Regras implementadas:
;   - BSTART inicia a contagem de 5 s.
;   - Timer0 gera uma base temporal de 50 ms; 20 ticks = 1 s.
;   - Resposta certa incrementa o nivel.
;   - Resposta errada com jokers disponiveis decrementa 3 jokers e mantem o nivel.
;   - Resposta errada sem jokers desce 3 niveis, nunca abaixo do nivel 1.
;   - Timeout e tratado como resposta errada.
;   - Ao atingir o nivel 8, todos os LEDs acendem e o buzzer emite 1 kHz por 5 s.
;
; Nota:
;   - Ajustar a tabela RESPOSTAS_CORRETAS de acordo com as perguntas usadas.
;   - CODIGO_NAO_RESPONDEU = 0AH pode depender do descodificador/simulador.
;===============================================================================

; Bits dos portos usados
BUZZER      BIT     090H        ; P1.0
BSTART      BIT     0B2H        ; P3.2 / INT0
INT_BOTOES  BIT     0B3H        ; P3.3 / INT1
BA          BIT     0B4H        ; P3.4
BB          BIT     0B5H        ; P3.5
BC          BIT     0B6H        ; P3.6
BD          BIT     0B7H        ; P3.7

;-------------------------------------------------------------------------------
; Constantes
;-------------------------------------------------------------------------------
TEMPO_INICIAL       EQU     05H
JOKERS_INICIAIS     EQU     06H
NIVEL_INICIAL       EQU     01H
NIVEL_MAXIMO        EQU     08H
CODIGO_NAO_RESPONDEU EQU    0AH

; Recarregamento para 50 ms com Fosc = 11.0592 MHz:
; Timer incrementa a Fosc/12 = 921600 Hz
; 50 ms = 46080 contagens; 65536 - 46080 = 19456 = 4C00H
TH_50MS             EQU     04CH
TL_50MS             EQU     000H

; Recarregamento para cerca de 500 us:
; 500 us * 921600 Hz = 460.8 contagens; 65536 - 461 = FE33H
TH_500US            EQU     0FEH
TL_500US            EQU     033H

;-------------------------------------------------------------------------------
; Variaveis em RAM interna
;-------------------------------------------------------------------------------
CONTAGEM_ATIVA      BIT     000H
RESPOSTA_PENDENTE   BIT     001H
TIMEOUT_PENDENTE    BIT     002H
BLOQUEIA_RESPOSTA   BIT     003H

NIVEL       DATA    030H
JOKERS      DATA    031H
TEMPO       DATA    032H
TICKS_50MS  DATA    033H
RESPOSTA    DATA    034H

;===============================================================================
; Vetores de interrupcao
;===============================================================================
            ORG     0000H
            LJMP    START

            ORG     0003H       ; INT0 - BSTART
            LJMP    ISR_START

            ORG     000BH       ; Timer0
            LJMP    ISR_TIMER0

            ORG     0013H       ; INT1 - botoes de resposta
            LJMP    ISR_RESPOSTA

;===============================================================================
; Programa principal
;===============================================================================
            ORG     0030H

START:
            MOV     SP,#06FH            ; pilha acima das variaveis
            LCALL   CONFIGURA_8051
            LCALL   REINICIA_CONCORRENTE

MAIN_LOOP:
            ; Se ha resposta pendente, processa-a fora da interrupcao.
            JNB     RESPOSTA_PENDENTE,CHECK_TIMEOUT

            LCALL   PROCESSA_RESPOSTA
            CLR     RESPOSTA_PENDENTE

            ; So repoe para a proxima pergunta depois do botao ser libertado
            ; e depois de passarem 2 segundos.
            LCALL   AGUARDA_LIBERTAR_BOTOES
            LCALL   DELAY_2S
            LCALL   PREPARA_PERGUNTA

CHECK_TIMEOUT:
            ; Se o tempo chegou a zero sem resposta, mostra o simbolo de nao
            ; respondeu e aplica a penalizacao de resposta errada.
            JNB     TIMEOUT_PENDENTE,MAIN_LOOP

            LCALL   DELAY_1S
            MOV     TEMPO,#CODIGO_NAO_RESPONDEU
            LCALL   ATUALIZA_DISPLAYS
            LCALL   PROCESSA_RESPOSTA_ERRADA
            LCALL   DELAY_2S
            LCALL   PREPARA_PERGUNTA
            CLR     TIMEOUT_PENDENTE

            SJMP    MAIN_LOOP

;===============================================================================
; Rotina: CONFIGURA_8051
; Funcao: inicializa portos, timers e interrupcoes.
;===============================================================================
CONFIGURA_8051:
            MOV     P0,#00H             ; LEDs desligados inicialmente
            MOV     P1,#00H             ; buzzer desligado
            MOV     P2,#00H             ; displays a zero
            MOV     P3,#0FFH            ; entradas com pull-up

            MOV     TMOD,#011H          ; Timer0 e Timer1 em modo 1, 16 bits
            MOV     TH0,#TH_50MS
            MOV     TL0,#TL_50MS

            SETB    IT0                 ; INT0 por flanco descendente
            SETB    IT1                 ; INT1 por flanco descendente

            SETB    EX0                 ; ativa INT0
            SETB    EX1                 ; ativa INT1
            SETB    ET0                 ; ativa interrupcao do Timer0
            SETB    EA                  ; ativa interrupcoes globais

            SETB    TR0                 ; Timer0 sempre a correr
            RET

;===============================================================================
; Rotina: ATUALIZA_DISPLAYS
; Funcao: escreve TEMPO no nibble alto de P2 e JOKER no nibble baixo de P2.
; Entrada: TEMPO, JOKERS.
; Altera: A, R7.
;===============================================================================
ATUALIZA_DISPLAYS:
            MOV     A,TEMPO
            ANL     A,#0FH
            SWAP    A
            ANL     A,#0F0H
            MOV     R7,A                ; R7 = TEMPO << 4

            MOV     A,JOKERS
            ANL     A,#0FH
            ORL     A,R7
            MOV     P2,A
            RET

;===============================================================================
; Rotina: ATUALIZA_LEDS
; Funcao: acende o LED correspondente ao nivel atual.
;         Se NIVEL >= 8, acende apenas LED8; a rotina de vitoria acende todos.
; Entrada: NIVEL.
; Altera: A, R7.
;===============================================================================
ATUALIZA_LEDS:
            MOV     A,NIVEL
            CLR     C
            SUBB    A,#NIVEL_MAXIMO
            JNC     LED_NIVEL8          ; NIVEL >= 8

            MOV     A,#01H              ; LED1
            MOV     R7,NIVEL
            DEC     R7                  ; numero de deslocamentos = nivel - 1
            JZ      LED_ESCREVE

LED_SHIFT:
            RL      A
            DJNZ    R7,LED_SHIFT

LED_ESCREVE:
            MOV     P0,A
            RET

LED_NIVEL8:
            MOV     P0,#080H            ; LED8
            RET

;===============================================================================
; Rotina: REINICIA_CONCORRENTE
; Funcao: repoe o sistema para novo concorrente.
;===============================================================================
REINICIA_CONCORRENTE:
            CLR     CONTAGEM_ATIVA
            CLR     RESPOSTA_PENDENTE
            CLR     TIMEOUT_PENDENTE
            CLR     BLOQUEIA_RESPOSTA

            MOV     NIVEL,#NIVEL_INICIAL
            MOV     JOKERS,#JOKERS_INICIAIS
            MOV     TEMPO,#TEMPO_INICIAL
            MOV     TICKS_50MS,#00H
            MOV     RESPOSTA,#00H
            CLR     BUZZER

            LCALL   ATUALIZA_LEDS
            LCALL   ATUALIZA_DISPLAYS
            RET

;===============================================================================
; Rotina: PREPARA_PERGUNTA
; Funcao: repoe tempo e flags para uma nova pergunta. A contagem so inicia com
;         novo BSTART.
;===============================================================================
PREPARA_PERGUNTA:
            MOV     TEMPO,#TEMPO_INICIAL
            MOV     TICKS_50MS,#00H
            MOV     RESPOSTA,#00H

            CLR     RESPOSTA_PENDENTE
            CLR     TIMEOUT_PENDENTE
            CLR     BLOQUEIA_RESPOSTA

            LCALL   ATUALIZA_DISPLAYS
            RET

;===============================================================================
; Rotina: PROCESSA_RESPOSTA
; Funcao: compara RESPOSTA com a tabela de respostas corretas.
;===============================================================================
PROCESSA_RESPOSTA:
            MOV     A,NIVEL
            DEC     A                   ; indice = nivel - 1
            MOV     DPTR,#RESPOSTAS_CORRETAS
            MOVC    A,@A+DPTR           ; A = resposta correta

            CJNE    A,RESPOSTA,RESP_ERRADA
            LCALL   PROCESSA_RESPOSTA_CERTA
            RET

RESP_ERRADA:
            LCALL   PROCESSA_RESPOSTA_ERRADA
            RET

;===============================================================================
; Rotina: PROCESSA_RESPOSTA_CERTA
; Funcao: incrementa nivel. Se atingir o nivel 8, faz vitoria.
;===============================================================================
PROCESSA_RESPOSTA_CERTA:
            MOV     A,NIVEL
            CJNE    A,#NIVEL_MAXIMO,CERTA_TESTA_MENOR
            SJMP    CERTA_VERIFICA_VITORIA

CERTA_TESTA_MENOR:
            JNC     CERTA_VERIFICA_VITORIA     ; NIVEL > 8, protecao
            INC     NIVEL
            LCALL   ATUALIZA_LEDS

CERTA_VERIFICA_VITORIA:
            MOV     A,NIVEL
            CLR     C
            SUBB    A,#NIVEL_MAXIMO
            JC      CERTA_FIM                   ; ainda nao chegou ao nivel 8

            MOV     P0,#0FFH                    ; vitoria: todos os LEDs
            LCALL   BUZZER_VITORIA_5S           ; onda quadrada 1 kHz por 5 s
            LCALL   REINICIA_CONCORRENTE

CERTA_FIM:
            RET

;===============================================================================
; Rotina: PROCESSA_RESPOSTA_ERRADA
; Funcao: aplica penalizacao.
;         - Se JOKERS >= 3: decrementa 3 jokers e mantem nivel.
;         - Se JOKERS < 3: coloca jokers a 0 e desce 3 niveis, sem baixar de 1.
;===============================================================================
PROCESSA_RESPOSTA_ERRADA:
            MOV     A,JOKERS
            CLR     C
            SUBB    A,#03H
            JC      ERRADA_SEM_JOKERS

            MOV     JOKERS,A
            SJMP    ERRADA_ATUALIZA

ERRADA_SEM_JOKERS:
            MOV     JOKERS,#00H

            ; Se nivel < 4, ao descer 3 niveis fica no nivel 1.
            MOV     A,NIVEL
            CLR     C
            SUBB    A,#04H
            JC      ERRADA_NIVEL1

            MOV     A,NIVEL
            CLR     C
            SUBB    A,#03H
            MOV     NIVEL,A
            SJMP    ERRADA_ATUALIZA

ERRADA_NIVEL1:
            MOV     NIVEL,#01H

ERRADA_ATUALIZA:
            LCALL   ATUALIZA_LEDS
            LCALL   ATUALIZA_DISPLAYS
            RET

;===============================================================================
; Rotina: AGUARDA_LIBERTAR_BOTOES
; Funcao: espera ate BA/BB/BC/BD e a linha comum INT1 voltarem a 1.
;===============================================================================
AGUARDA_LIBERTAR_BOTOES:
            JNB     BA,AGUARDA_LIBERTAR_BOTOES
            JNB     BB,AGUARDA_LIBERTAR_BOTOES
            JNB     BC,AGUARDA_LIBERTAR_BOTOES
            JNB     BD,AGUARDA_LIBERTAR_BOTOES
            JNB     INT_BOTOES,AGUARDA_LIBERTAR_BOTOES
            RET

;===============================================================================
; Rotinas de atraso com Timer1
;===============================================================================
DELAY_50MS:
            MOV     TH1,#TH_50MS
            MOV     TL1,#TL_50MS
            CLR     TF1
            SETB    TR1

D50_ESPERA:
            JNB     TF1,D50_ESPERA

            CLR     TR1
            CLR     TF1
            RET

DELAY_1S:
            MOV     R6,#20

D1S_LOOP:
            LCALL   DELAY_50MS
            DJNZ    R6,D1S_LOOP
            RET

DELAY_2S:
            LCALL   DELAY_1S
            LCALL   DELAY_1S
            RET

DELAY_500US:
            MOV     TH1,#TH_500US
            MOV     TL1,#TL_500US
            CLR     TF1
            SETB    TR1

D500_ESPERA:
            JNB     TF1,D500_ESPERA

            CLR     TR1
            CLR     TF1
            RET

;===============================================================================
; Rotina: BUZZER_VITORIA_5S
; Funcao: gera onda quadrada de cerca de 1 kHz durante 5 s.
;         10000 semi-periodos de 0,5 ms = 5 s.
; Altera: R4, R5.
;===============================================================================
BUZZER_VITORIA_5S:
            MOV     R4,#100

BUZ_OUTER:
            MOV     R5,#100

BUZ_INNER:
            CPL     BUZZER
            LCALL   DELAY_500US
            DJNZ    R5,BUZ_INNER
            DJNZ    R4,BUZ_OUTER

            CLR     BUZZER
            RET

;===============================================================================
; ISR: INT0 / BSTART
; Funcao: inicia a contagem se nao houver outra acao pendente.
;===============================================================================
ISR_START:
            PUSH    ACC
            PUSH    PSW
            PUSH    07H

            JB      CONTAGEM_ATIVA,ISR_START_FIM
            JB      RESPOSTA_PENDENTE,ISR_START_FIM
            JB      TIMEOUT_PENDENTE,ISR_START_FIM

            LCALL   PREPARA_PERGUNTA
            SETB    CONTAGEM_ATIVA

ISR_START_FIM:
            POP     07H
            POP     PSW
            POP     ACC
            RETI

;===============================================================================
; ISR: Timer0
; Funcao: a cada 50 ms incrementa TICKS_50MS. A cada 20 ticks decrementa 1 s.
;===============================================================================
ISR_TIMER0:
            PUSH    ACC
            PUSH    PSW
            PUSH    07H

            MOV     TH0,#TH_50MS
            MOV     TL0,#TL_50MS

            JNB     CONTAGEM_ATIVA,ISR_T0_FIM

            INC     TICKS_50MS
            MOV     A,TICKS_50MS
            CJNE    A,#20,ISR_T0_FIM

            MOV     TICKS_50MS,#00H

            MOV     A,TEMPO
            JZ      ISR_T0_TIMEOUT

            DEC     TEMPO
            LCALL   ATUALIZA_DISPLAYS

            MOV     A,TEMPO
            JNZ     ISR_T0_FIM

ISR_T0_TIMEOUT:
            CLR     CONTAGEM_ATIVA
            SETB    BLOQUEIA_RESPOSTA
            SETB    TIMEOUT_PENDENTE

ISR_T0_FIM:
            POP     07H
            POP     PSW
            POP     ACC
            RETI

;===============================================================================
; ISR: INT1 / botoes de resposta
; Funcao: identifica BA/BB/BC/BD e guarda resposta 1..4.
;===============================================================================
ISR_RESPOSTA:
            PUSH    ACC
            PUSH    PSW
            PUSH    07H

            JNB     CONTAGEM_ATIVA,ISR_RESP_FIM
            JB      BLOQUEIA_RESPOSTA,ISR_RESP_FIM

            JNB     BA,RESP_A
            JNB     BB,RESP_B
            JNB     BC,RESP_C
            JNB     BD,RESP_D

            MOV     RESPOSTA,#00H
            SJMP    RESP_TESTA

RESP_A:
            MOV     RESPOSTA,#01H
            SJMP    RESP_TESTA

RESP_B:
            MOV     RESPOSTA,#02H
            SJMP    RESP_TESTA

RESP_C:
            MOV     RESPOSTA,#03H
            SJMP    RESP_TESTA

RESP_D:
            MOV     RESPOSTA,#04H

RESP_TESTA:
            MOV     A,RESPOSTA
            JZ      ISR_RESP_FIM

            CLR     CONTAGEM_ATIVA
            SETB    BLOQUEIA_RESPOSTA
            SETB    RESPOSTA_PENDENTE
            LCALL   ATUALIZA_DISPLAYS        ; mantem visivel o tempo remanescente

ISR_RESP_FIM:
            POP     07H
            POP     PSW
            POP     ACC
            RETI

;===============================================================================
; Tabela de respostas corretas por nivel
; Exemplo: N1=A, N2=B, N3=C, N4=D, N5=A, N6=B, N7=C, N8=D.
; Alterar estes valores conforme as perguntas do relatorio/apresentacao.
;===============================================================================
RESPOSTAS_CORRETAS:
            DB      01H,02H,03H,04H,01H,02H,03H,04H

            END
