/*
 * Projeto P3 - Concurso de perguntas de conhecimento (JOKER)
 * Microcontrolador: AT89S51 / 8051
 * Compilador: Keil C51
 * Cristal assumido: 11.0592 MHz
 *
 * Ligações usadas:
 *   P3.2 - BSTART / INT0, ativo a 0
 *   P3.3 - interrupção comum dos botões de resposta / INT1, ativo a 0
 *   P3.4 - BA, ativo a 0
 *   P3.5 - BB, ativo a 0
 *   P3.6 - BC, ativo a 0
 *   P3.7 - BD, ativo a 0
 *   P1.0 - Buzzer
 *   P2.7..P2.4 - BCD do display TEMPO
 *   P2.3..P2.0 - BCD do display JOKER
 *   P0.0..P0.7 - LEDs dos níveis 1..8
 */

#include <REGX51.H>

#define TEMPO_INICIAL        5u
#define JOKERS_INICIAIS      6u
#define NIVEL_INICIAL        1u
#define NIVEL_MAXIMO         8u

/* Ajustar este valor conforme o circuito/simulador para representar o símbolo da Figura 1.
 * Em muitos simuladores com descodificador/7 segmentos, 0x0A ou 0x0F é usado como estado especial.
 * Se o professor exigir apenas BCD válido, deixar como 0 para mostrar 0.
 */
#define CODIGO_NAO_RESPONDEU 0x0Au

/* Recarregamentos para cristal de 11.0592 MHz.
 * Timer incrementa a Fosc/12 = 921600 Hz.
 */
#define TH0_50MS 0x4Cu
#define TL0_50MS 0x00u
#define TH1_50MS 0x4Cu
#define TL1_50MS 0x00u
#define TH1_500US 0xFEu
#define TL1_500US 0x33u

sbit BUZZER = P1^0;
sbit BSTART = P3^2;
sbit INT_BOTOES = P3^3;
sbit BA = P3^4;
sbit BB = P3^5;
sbit BC = P3^6;
sbit BD = P3^7;

/* Estados globais alterados por interrupções. */
volatile bit contagem_ativa = 0;
volatile bit resposta_pendente = 0;
volatile bit timeout_pendente = 0;
volatile bit bloqueia_resposta = 0;

volatile unsigned char nivel = NIVEL_INICIAL;
volatile unsigned char jokers = JOKERS_INICIAIS;
volatile unsigned char tempo = TEMPO_INICIAL;
volatile unsigned int ticks_50ms = 0;
volatile unsigned char resposta = 0; /* 1=A, 2=B, 3=C, 4=D */

/* Tabela de respostas corretas por nível.
 * Alterar de acordo com as perguntas escolhidas no relatório/apresentação.
 * Neste exemplo: N1=A, N2=B, N3=C, N4=D, N5=A, N6=B, N7=C, N8=D.
 */
const unsigned char respostas_corretas[NIVEL_MAXIMO] = {1, 2, 3, 4, 1, 2, 3, 4};

void atualiza_displays(void);
void atualiza_leds(void);
void reinicia_concorrente(void);
void prepara_pergunta(void);
void processa_resposta_certa(void);
void processa_resposta_errada(void);
void processa_resposta(void);
void delay_50ms(void);
void delay_1s(void);
void delay_2s(void);
void delay_500us(void);
void buzzer_vitoria_5s(void);
void aguarda_libertar_botoes(void);
void configura_8051(void);

void atualiza_displays(void) {
    unsigned char t = (tempo & 0x0F) << 4;   /* TEMPO em P2.7..P2.4 */
    unsigned char j = (jokers & 0x0F);       /* JOKER em P2.3..P2.0 */
    P2 = t | j;
}

void atualiza_leds(void) {
    if (nivel >= NIVEL_MAXIMO) {
        P0 = 0x80;       /* LED8 durante o nível 8; vitória acende todos na rotina própria */
    } else {
        P0 = (1u << (nivel - 1));
    }
}

void reinicia_concorrente(void) {
    contagem_ativa = 0;
    resposta_pendente = 0;
    timeout_pendente = 0;
    bloqueia_resposta = 0;
    nivel = NIVEL_INICIAL;
    jokers = JOKERS_INICIAIS;
    tempo = TEMPO_INICIAL;
    ticks_50ms = 0;
    resposta = 0;
    BUZZER = 0;
    atualiza_leds();
    atualiza_displays();
}

void prepara_pergunta(void) {
    tempo = TEMPO_INICIAL;
    ticks_50ms = 0;
    resposta = 0;
    resposta_pendente = 0;
    timeout_pendente = 0;
    bloqueia_resposta = 0;
    atualiza_displays();
}

void processa_resposta_certa(void) {
    if (nivel < NIVEL_MAXIMO) {
        nivel++;
        atualiza_leds();
    }

    if (nivel >= NIVEL_MAXIMO) {
        P0 = 0xFF;              /* vitória: todos os LEDs ligados */
        buzzer_vitoria_5s();    /* onda quadrada de 1 kHz durante 5 s */
        reinicia_concorrente(); /* pronto para novo concorrente */
    }
}

void processa_resposta_errada(void) {
    if (jokers >= 3) {
        jokers -= 3;
    } else {
        jokers = 0;
        if (nivel > 3) {
            nivel -= 3;
        } else {
            nivel = 1;
        }
    }
    atualiza_leds();
    atualiza_displays();
}

void processa_resposta(void) {
    unsigned char correta = respostas_corretas[nivel - 1];

    if (resposta == correta) {
        processa_resposta_certa();
    } else {
        processa_resposta_errada();
    }
}

void aguarda_libertar_botoes(void) {
    while (BA == 0 || BB == 0 || BC == 0 || BD == 0 || INT_BOTOES == 0) {
        /* espera ativa para cumprir a regra: só repõe 2 s após libertar */
    }
}

void delay_50ms(void) {
    TH1 = TH1_50MS;
    TL1 = TL1_50MS;
    TF1 = 0;
    TR1 = 1;
    while (TF1 == 0) {
        ;
    }
    TR1 = 0;
    TF1 = 0;
}

void delay_1s(void) {
    unsigned char i;
    for (i = 0; i < 20; i++) {
        delay_50ms();
    }
}

void delay_2s(void) {
    delay_1s();
    delay_1s();
}

void delay_500us(void) {
    TH1 = TH1_500US;
    TL1 = TL1_500US;
    TF1 = 0;
    TR1 = 1;
    while (TF1 == 0) {
        ;
    }
    TR1 = 0;
    TF1 = 0;
}

void buzzer_vitoria_5s(void) {
    unsigned int i;
    for (i = 0; i < 10000; i++) { /* 10000 semi-períodos de 0,5 ms = 5 s */
        BUZZER = !BUZZER;
        delay_500us();
    }
    BUZZER = 0;
}

void configura_8051(void) {
    P0 = 0x00;  /* LEDs */
    P1 = 0x00;  /* buzzer desligado */
    P2 = 0x00;  /* displays */
    P3 = 0xFF;  /* entradas com pull-up */

    /* Timer0 e Timer1 em modo 1, 16 bits. */
    TMOD = 0x11;
    TH0 = TH0_50MS;
    TL0 = TL0_50MS;

    /* INT0 e INT1 por flanco descendente. */
    IT0 = 1;
    IT1 = 1;

    EX0 = 1;
    EX1 = 1;
    ET0 = 1;
    EA = 1;

    TR0 = 1; /* Timer0 corre sempre; ISR só decrementa se contagem_ativa=1. */
}

/* INT0: botão START em P3.2, flanco descendente. */
void isr_start(void) interrupt 0 {
    if (!contagem_ativa && !resposta_pendente && !timeout_pendente) {
        prepara_pergunta();
        contagem_ativa = 1;
    }
}

/* Timer0: base temporal de 50 ms; decrementa o display de 1 em 1 segundo. */
void isr_timer0(void) interrupt 1 {
    TH0 = TH0_50MS;
    TL0 = TL0_50MS;

    if (contagem_ativa) {
        ticks_50ms++;
        if (ticks_50ms >= 5000) {
            ticks_50ms = 0;
            if (tempo > 0) {
                tempo--;
                atualiza_displays();
            }
            if (tempo == 0) {
                contagem_ativa = 0;
                bloqueia_resposta = 1;
                timeout_pendente = 1;
            }
        }
    }
}

/* INT1: qualquer botão de resposta em P3.3, flanco descendente. */
void isr_resposta(void) interrupt 2 {
    if (contagem_ativa && !bloqueia_resposta) {
        if (BA == 0) {
            resposta = 1;
        } else if (BB == 0) {
            resposta = 2;
        } else if (BC == 0) {
            resposta = 3;
        } else if (BD == 0) {
            resposta = 4;
        } else {
            resposta = 0;
        }

        if (resposta != 0) {
            contagem_ativa = 0;
            bloqueia_resposta = 1;
            resposta_pendente = 1;
            atualiza_displays(); /* mantém visível o tempo remanescente */
        }
    }
}

void main(void) {
    configura_8051();
    reinicia_concorrente();

    while (1) {
        if (resposta_pendente) {
            processa_resposta();
            resposta_pendente = 0;
            aguarda_libertar_botoes();
            delay_2s();
            prepara_pergunta();
        }

        if (timeout_pendente) {
            /* O participante não respondeu dentro dos 5 s. */
            delay_1s();
            tempo = CODIGO_NAO_RESPONDEU;
            atualiza_displays();
            processa_resposta_errada(); /* timeout tratado como resposta errada */
            delay_2s();
            prepara_pergunta();
            timeout_pendente = 0;
        }
    }
}
