# Project3-AC-Joker

Projeto em Assembly e C para o microcontrolador 8051/AT89S51.  
O sistema simula um concurso de perguntas de conhecimento, denominado JOKER, com oito níveis, botões de resposta, displays de 7 segmentos, LEDs de nível, jokers e buzzer.

## Descrição

O participante começa no nível 1 e deve responder a perguntas até alcançar o nível 8.  
Cada pergunta é iniciada pelo botão `BSTART`, que ativa uma contagem decrescente de 5 segundos. Durante esse tempo, o participante pode escolher uma resposta através dos botões `BA`, `BB`, `BC` ou `BD`.

O sistema apresenta o tempo restante no display `TEMPO`, o número de jokers no display `JOKER`, o nível atual nos LEDs e sinaliza a vitória através do buzzer.

## Ficheiros principais

```text
Project3-AC-Joker/
│
├── P3_JOKER_8051.asm
├── P3_JOKER_8051.c
└── README.md
```

### `P3_JOKER_8051.asm`

Implementação em Assembly para 8051.

### `P3_JOKER_8051.c`

Implementação em C para 8051.

## Requisitos

Para compilar e testar o projeto é necessário:

- Keil uVision.
- Suporte C51/A51 para 8051.
- Microcontrolador AT89S51 ou compatível.
- Programador de microcontroladores, caso se pretenda gravar o chip.
- Circuito com botões, displays, LEDs e buzzer conforme o mapeamento do projeto.

## Como obter o projeto

```bash
git clone https://github.com/Franciscoafonseca/Project3-AC-Joker.git
cd Project3-AC-Joker
```

## Criar o projeto no Keil

1. Abrir o Keil uVision.
2. Criar um novo projeto:

```text
Project > New uVision Project
```

3. Escolher o microcontrolador:

```text
Atmel > AT89S51
```

ou outro compatível com a família 8051.

4. Adicionar ao projeto o ficheiro pretendido:

```text
P3_JOKER_8051.c
```

ou:

```text
P3_JOKER_8051.asm
```

5. Abrir as opções do projeto:

```text
Project > Options for Target
```

6. Confirmar o dispositivo `AT89S51`.
7. Definir o cristal usado no projeto, por exemplo:

```text
11.0592 MHz
```

8. No separador `Output`, ativar:

```text
Create HEX File
```

## Compilar

Para compilar o projeto:

```text
Project > Build Target
```

ou carregar em:

```text
F7
```

Se a compilação estiver correta, o Keil deve apresentar:

```text
0 Error(s), 0 Warning(s)
```

O ficheiro `.hex` gerado pode ser usado para gravar o microcontrolador.

## Simular no Keil

1. Compilar o projeto.
2. Entrar em modo debug:

```text
Debug > Start/Stop Debug Session
```

3. Executar:

```text
Run
```

4. Abrir os portos, se necessário:

```text
Peripherals > I/O Ports
```

5. Alterar manualmente os pinos para simular os botões e observar os resultados nas saídas.

## Funcionamento

### Estado inicial

```text
Nível inicial: 1
Jokers iniciais: 6
Tempo inicial: 5 segundos
```

### Iniciar pergunta

O botão `BSTART` está ligado a `P3.2`.

Para iniciar a contagem, simular uma transição descendente:

```text
P3.2: 1 -> 0
```

Depois o botão deve voltar a `1`.

### Responder

Os botões de resposta são ativos a `0`:

```text
BA -> P3.4
BB -> P3.5
BC -> P3.6
BD -> P3.7
```

A interrupção comum das respostas usa o pino:

```text
P3.3
```

Exemplo para responder A:

```text
P3.4 = 0
P3.3 = 0
```

Depois de largar o botão:

```text
P3.4 = 1
P3.3 = 1
```

### Sem resposta

Se o participante não responder em 5 segundos:

- O display `TEMPO` mostra `0`.
- Após 1 segundo, é apresentada a indicação de ausência de resposta.
- O sistema fica pronto para a próxima pergunta.

### Resposta correta

- O nível aumenta 1.
- O LED do novo nível é atualizado.
- Ao chegar ao nível 8, todos os LEDs acendem.
- O buzzer emite uma onda quadrada de 1 kHz durante 5 segundos.

### Resposta errada

Com jokers disponíveis:

```text
jokers = jokers - 3
```

O nível mantém-se.

Sem jokers disponíveis:

```text
nível = nível - 3
```

O nível nunca fica abaixo de 1.

## Mapeamento dos pinos

| Função | Pino |
|---|---|
| BSTART | `P3.2` |
| INT1 / resposta pressionada | `P3.3` |
| Botão A | `P3.4` |
| Botão B | `P3.5` |
| Botão C | `P3.6` |
| Botão D | `P3.7` |
| Buzzer | `P1.0` |

### Display TEMPO

| Bit BCD | Pino |
|---|---|
| A1 | `P2.4` |
| B1 | `P2.5` |
| C1 | `P2.6` |
| D1 | `P2.7` |

### Display JOKER

| Bit BCD | Pino |
|---|---|
| A2 | `P2.0` |
| B2 | `P2.1` |
| C2 | `P2.2` |
| D2 | `P2.3` |

### LEDs

| Nível | Pino |
|---:|---|
| 1 | `P0.0` |
| 2 | `P0.1` |
| 3 | `P0.2` |
| 4 | `P0.3` |
| 5 | `P0.4` |
| 6 | `P0.5` |
| 7 | `P0.6` |
| 8 | `P0.7` |

## Gravar no microcontrolador

Depois de gerar o ficheiro `.hex`:

1. Abrir o software do programador.
2. Selecionar o dispositivo `AT89S51`.
3. Carregar o ficheiro `.hex`.
4. Inserir corretamente o chip no socket.
5. Executar `Blank Check`, se necessário.
6. Executar `Program`.
7. Executar `Verify`.
8. Colocar o microcontrolador no circuito.

## Testes recomendados

- Verificar se o sistema inicia no nível 1, com 6 jokers e tempo 5.
- Testar `BSTART` com transição `1 -> 0`.
- Testar os botões `BA`, `BB`, `BC` e `BD`.
- Confirmar que o tempo decresce corretamente.
- Confirmar que a ausência de resposta é sinalizada.
- Confirmar que respostas corretas aumentam o nível.
- Confirmar que respostas erradas retiram jokers.
- Confirmar que sem jokers o nível desce 3 posições.
- Confirmar que ao atingir o nível 8 todos os LEDs acendem e o buzzer toca.

## Problemas comuns

### O projeto não compila

Verificar:

- Se foi selecionado o dispositivo `AT89S51`.
- Se o suporte C51/A51 está instalado.
- Se o ficheiro correto foi adicionado ao projeto.
- Se existem labels duplicadas no Assembly.
- Se a opção `Create HEX File` está ativa.

### O botão START não funciona

Verificar:

- Se `P3.2` começa em `1`.
- Se foi feita a transição `1 -> 0`.
- Se a interrupção `INT0` está ativa.

### As respostas não são detetadas

Verificar:

- Se os botões estão a ser colocados a `0`.
- Se `P3.3` também está a ser colocado a `0`.
- Se a interrupção `INT1` está ativa.

### O tempo está errado

Verificar:

- O valor do cristal configurado no Keil.
- Os valores dos timers no código.
- Se a simulação está a correr no modo correto.

## Comandos úteis no Keil

| Ação | Comando |
|---|---|
| Compilar | `F7` |
| Entrar/sair do debug | `Ctrl + F5` |
| Executar | `F5` |
| Passo a passo | `F11` |
| Ver portos | `Peripherals > I/O Ports` |
| Ver memória | `View > Memory Windows` |
