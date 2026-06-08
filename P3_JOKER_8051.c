/*
 * Projeto P3 - Concurso JOKER
 * Microcontrolador: AT89S51 / 8051
 * Compilador: Keil C51
 * Cristal: 11.0592 MHz
 */

#include <REGX51.H>

/* Constantes do jogo */
#define TEMPO_INICIAL        5u      /* tempo inicial de cada pergunta */
#define JOKERS_INICIAIS      6u      /* número inicial de jokers */
#define NIVEL_INICIAL        1u      /* primeiro nível do jogo */
#define NIVEL_MAXIMO         8u      /* nível de vitória */

/* Código especial para indicar que não houve resposta */
#define CODIGO_NAO_RESPONDEU 0x0Au

/* Valores de recarga dos timers */
#define TH0_50MS 0x4Cu
#define TL0_50MS 0x00u
#define TH1_50MS 0x4Cu
#define TL1_50MS 0x00u
#define TH1_500US 0xFEu
#define TL1_500US 0x33u

/* Pinos usados */
sbit BUZZER = P1^0;        /* buzzer ligado ao P1.0 */

sbit BSTART = P3^2;        /* botão START / INT0 */
sbit INT_BOTOES = P3^3;    /* interrupção dos botões / INT1 */

sbit BA = P3^4;            /* botão resposta A */
sbit BB = P3^5;            /* botão resposta B */
sbit BC = P3^6;            /* botão resposta C */
sbit BD = P3^7;            /* botão resposta D */

/* Flags usadas entre interrupções e main */
volatile bit contagem_ativa = 0;      /* indica se o tempo está a contar */
volatile bit resposta_pendente = 0;   /* indica que há resposta para processar */
volatile bit timeout_pendente = 0;    /* indica que o tempo acabou */
volatile bit bloqueia_resposta = 0;   /* impede aceitar mais respostas */

/* Variáveis principais do jogo */
volatile unsigned char nivel = NIVEL_INICIAL;       /* nível atual */
volatile unsigned char jokers = JOKERS_INICIAIS;    /* jokers atuais */
volatile unsigned char tempo = TEMPO_INICIAL;       /* tempo no display */
volatile unsigned int ticks_50ms = 0;               /* contador de 50 ms */
volatile unsigned char resposta = 0;                /* resposta dada */

/* Respostas corretas dos níveis: 1=A, 2=B, 3=C, 4=D */
const unsigned char respostas_corretas[NIVEL_MAXIMO] = {
    1, 2, 3, 4, 1, 2, 3, 4
};

/* Protótipos das funções */
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

/* Atualiza os displays TEMPO e JOKER na porta P2 */
void atualiza_displays(void) {
    unsigned char t = (tempo & 0x0F) << 4;   /* TEMPO nos 4 bits altos */
    unsigned char j = (jokers & 0x0F);       /* JOKER nos 4 bits baixos */

    P2 = t | j;                              /* junta tempo e jokers em P2 */
}

/* Atualiza os LEDs conforme o nível atual */
void atualiza_leds(void) {
    if (nivel >= NIVEL_MAXIMO) {
        P0 = 0x80;                           /* liga o LED8 */
    } else {
        P0 = (1u << (nivel - 1));            /* liga o LED do nível atual */
    }
}

/* Reinicia o jogo para um novo concorrente */
void reinicia_concorrente(void) {
    contagem_ativa = 0;                      /* para a contagem */
    resposta_pendente = 0;                   /* limpa resposta pendente */
    timeout_pendente = 0;                    /* limpa timeout */
    bloqueia_resposta = 0;                   /* desbloqueia respostas */

    nivel = NIVEL_INICIAL;                   /* volta ao nível 1 */
    jokers = JOKERS_INICIAIS;                /* repõe os jokers */
    tempo = TEMPO_INICIAL;                   /* repõe o tempo */
    ticks_50ms = 0;                          /* limpa contador auxiliar */
    resposta = 0;                            /* limpa resposta */

    BUZZER = 0;                              /* desliga buzzer */

    atualiza_leds();                         /* atualiza LEDs */
    atualiza_displays();                     /* atualiza displays */
}

/* Prepara uma nova pergunta */
void prepara_pergunta(void) {
    tempo = TEMPO_INICIAL;                   /* repõe tempo para 5 s */
    ticks_50ms = 0;                          /* reinicia contador */
    resposta = 0;                            /* limpa resposta */

    resposta_pendente = 0;                   /* limpa flag de resposta */
    timeout_pendente = 0;                    /* limpa flag de timeout */
    bloqueia_resposta = 0;                   /* permite nova resposta */

    atualiza_displays();                     /* mostra tempo inicial */
}

/* Trata uma resposta correta */
void processa_resposta_certa(void) {
    if (nivel < NIVEL_MAXIMO) {
        nivel++;                             /* sobe um nível */
        atualiza_leds();                     /* mostra novo nível */
    }

    if (nivel >= NIVEL_MAXIMO) {
        P0 = 0xFF;                           /* liga todos os LEDs */
        buzzer_vitoria_5s();                 /* toca buzzer por 5 s */
        reinicia_concorrente();              /* prepara novo concorrente */
    }
}

/* Trata uma resposta errada ou ausência de resposta */
void processa_resposta_errada(void) {
    if (jokers >= 3) {
        jokers -= 3;                         /* perde 3 jokers */
    } else {
        jokers = 0;                          /* fica sem jokers */

        if (nivel > 3) {
            nivel -= 3;                      /* recua 3 níveis */
        } else {
            nivel = 1;                       /* nunca desce abaixo do nível 1 */
        }
    }

    atualiza_leds();                         /* atualiza LEDs */
    atualiza_displays();                     /* atualiza displays */
}

/* Verifica se a resposta dada está correta */
void processa_resposta(void) {
    unsigned char correta = respostas_corretas[nivel - 1];

    if (resposta == correta) {
        processa_resposta_certa();           /* resposta certa */
    } else {
        processa_resposta_errada();          /* resposta errada */
    }
}

/* Espera até todos os botões serem libertados */
void aguarda_libertar_botoes(void) {
    while (BA == 0 || BB == 0 || BC == 0 || BD == 0 || INT_BOTOES == 0) {
        ;                                    /* espera ativa */
    }
}

/* Atraso de cerca de 50 ms usando Timer1 */
void delay_50ms(void) {
    TH1 = TH1_50MS;                          /* carrega byte alto */
    TL1 = TL1_50MS;                          /* carrega byte baixo */

    TF1 = 0;                                 /* limpa overflow */
    TR1 = 1;                                 /* inicia Timer1 */

    while (TF1 == 0) {
        ;                                    /* espera overflow */
    }

    TR1 = 0;                                 /* para Timer1 */
    TF1 = 0;                                 /* limpa flag */
}

/* Atraso de cerca de 1 segundo */
void delay_1s(void) {
    unsigned char i;

    for (i = 0; i < 20; i++) {
        delay_50ms();                        /* 20 x 50 ms = 1 s */
    }
}

/* Atraso de cerca de 2 segundos */
void delay_2s(void) {
    delay_1s();                              /* primeiro segundo */
    delay_1s();                              /* segundo segundo */
}

/* Atraso de cerca de 500 us */
void delay_500us(void) {
    TH1 = TH1_500US;                         /* carrega byte alto */
    TL1 = TL1_500US;                         /* carrega byte baixo */

    TF1 = 0;                                 /* limpa overflow */
    TR1 = 1;                                 /* inicia Timer1 */

    while (TF1 == 0) {
        ;                                    /* espera overflow */
    }

    TR1 = 0;                                 /* para Timer1 */
    TF1 = 0;                                 /* limpa flag */
}

/* Gera onda quadrada de 1 kHz durante 5 segundos */
void buzzer_vitoria_5s(void) {
    unsigned int i;

    for (i = 0; i < 10000; i++) {
        BUZZER = !BUZZER;                    /* inverte o buzzer */
        delay_500us();                       /* meio período de 1 kHz */
    }

    BUZZER = 0;                              /* desliga buzzer no fim */
}

/* Configura portas, timers e interrupções */
void configura_8051(void) {
    P0 = 0x00;                               /* LEDs desligados */
    P1 = 0x00;                               /* buzzer desligado */
    P2 = 0x00;                               /* displays limpos */
    P3 = 0xFF;                               /* entradas com pull-up */

    TMOD = 0x11;                             /* Timer0 e Timer1 em modo 1 */

    TH0 = TH0_50MS;                          /* recarga inicial Timer0 */
    TL0 = TL0_50MS;

    IT0 = 1;                                 /* INT0 por flanco descendente */
    IT1 = 1;                                 /* INT1 por flanco descendente */

    EX0 = 1;                                 /* ativa INT0 */
    EX1 = 1;                                 /* ativa INT1 */
    ET0 = 1;                                 /* ativa interrupção Timer0 */
    EA = 1;                                  /* ativa interrupções globais */

    TR0 = 1;                                 /* inicia Timer0 */
}

/* INT0: botão START */
void isr_start(void) interrupt 0 {
    if (!contagem_ativa && !resposta_pendente && !timeout_pendente) {
        prepara_pergunta();                  /* prepara pergunta */
        contagem_ativa = 1;                  /* inicia contagem */
    }
}

/* Timer0: base temporal de 50 ms */
void isr_timer0(void) interrupt 1 {
    TH0 = TH0_50MS;                          /* recarrega Timer0 */
    TL0 = TL0_50MS;

    if (contagem_ativa) {
        ticks_50ms++;                        /* conta mais 50 ms */

        if (ticks_50ms >= 20) {              /* passou 1 segundo */
            ticks_50ms = 0;                  /* reinicia ticks */

            if (tempo > 0) {
                tempo--;                     /* decrementa tempo */
                atualiza_displays();         /* atualiza display */
            }

            if (tempo == 0) {
                contagem_ativa = 0;          /* para contagem */
                bloqueia_resposta = 1;       /* bloqueia respostas */
                timeout_pendente = 1;        /* marca timeout */
            }
        }
    }
}

/* INT1: botão de resposta */
void isr_resposta(void) interrupt 2 {
    if (contagem_ativa && !bloqueia_resposta) {
        if (BA == 0) {
            resposta = 1;                    /* resposta A */
        } else if (BB == 0) {
            resposta = 2;                    /* resposta B */
        } else if (BC == 0) {
            resposta = 3;                    /* resposta C */
        } else if (BD == 0) {
            resposta = 4;                    /* resposta D */
        } else {
            resposta = 0;                    /* nenhuma resposta válida */
        }

        if (resposta != 0) {
            contagem_ativa = 0;              /* para contagem */
            bloqueia_resposta = 1;           /* impede nova resposta */
            resposta_pendente = 1;           /* main vai processar */
            atualiza_displays();             /* mantém tempo visível */
        }
    }
}

/* Programa principal */
void main(void) {
    configura_8051();                        /* configura o 8051 */
    reinicia_concorrente();                  /* inicia estado do jogo */

    while (1) {
        if (resposta_pendente) {
            processa_resposta();             /* verifica resposta */
            resposta_pendente = 0;           /* limpa flag */

            aguarda_libertar_botoes();       /* espera largar botão */
            delay_2s();                      /* espera 2 segundos */

            prepara_pergunta();              /* prepara próxima pergunta */
        }

        if (timeout_pendente) {
            delay_1s();                      /* mantém 0 por 1 segundo */

            tempo = CODIGO_NAO_RESPONDEU;    /* mostra símbolo especial */
            atualiza_displays();             /* atualiza display */

            processa_resposta_errada();      /* timeout conta como erro */

            delay_2s();                      /* espera 2 segundos */
            prepara_pergunta();              /* prepara próxima pergunta */

            timeout_pendente = 0;            /* limpa flag */
        }
    }
}
