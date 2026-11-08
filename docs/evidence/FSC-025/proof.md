# Prova da FSC-025, fase 1: medição no iPhone

Medido em 2026-11-06 às 17:01 no iPhone 17 Pro Max do usuário (iOS 27.3), com o botão "Medir" do laboratório: cada motor sozinho por 20 s com 3 bonequinhos de 120 pt, uma ação a cada 3 s, três rodadas com 5 s de pausa e a mediana. [Captura da tabela](iphone-measure-debug.png).

| Motor | CPU do processo | Memória acrescentada | Quadros perdidos | GPU por quadro, 3 bonecos | Temperatura |
| --- | --- | --- | --- | --- | --- |
| Lottie | 14,0% | +0,0 MB | 0,6% | não medida | normal |
| Canvas | 42,4% | +5,9 MB | 1,6% | não medida | normal |
| Metal | 41,3% | +0,0 MB | 0,2% | 0,48 ms (p95 1,00 ms) | normal |

## Régua do canvas

| Critério para seguir com Metal | Resultado |
| --- | --- |
| CPU pelo menos 30% menor que o Lottie | **não passou**: 41,3% contra 14,0%, quase o triplo |
| Memória acrescentada não maior | passou |
| No máximo 1% de quadros perdidos | passou (0,2%, o menor dos três) |
| GPU p95 de no máximo 2 ms para os 3 | passou (1,00 ms) |
| Energia não maior no Power Profiler | não medida: o `xctrace` não conseguiu falar com o iPhone ("Timed out waiting for device to boot"), e o usuário dispensou nova gravação |
| Paridade dentro do limite | passou (média 0,2%, percentil fora da borda 0,8%) |

O Canvas também não passa: CPU 42,4%, memória +5,9 MB e 1,6% de quadros perdidos.

**Pela régua, a decisão é parar.**

## Segunda medição, com o Swift otimizado

Às 17:20, mesma tela e mesmo roteiro, com a build de desenvolvimento compilada com `SWIFT_OPTIMIZATION_LEVEL=-O` ([captura](iphone-measure-optimized.png)).

| Motor | CPU do processo | Memória acrescentada | Quadros perdidos | GPU por quadro, 3 bonecos |
| --- | --- | --- | --- | --- |
| Lottie | 14,3% | +0,0 MB | 4,8% | não medida |
| Canvas | 42,9% | +6,6 MB | 0,1% | não medida |
| Metal | 40,8% | +0,0 MB | 0,1% | 0,43 ms (p95 0,81 ms) |

A otimização quase não mudou a CPU (41,3% para 40,8%). O custo não vem só do Swift sem otimização. A explicação mais provável, que não foi medida à parte: durante as ações, que na medição acontecem a cada 3 s, o Metal e o Canvas pedem 120 quadros por segundo (ProMotion), enquanto o rig do Lottie anda a 30. Somado ao trabalho de cada quadro na CPU, isso dá cerca de três vezes a CPU do Lottie. A segunda rodada confirma que este motor não serve como motor geral, com vários bonecos na tela.

## Decisão do usuário (2026-11-06)

O Metal não vira o motor geral do bonequinho: o Lottie continua em todas as telas. O Metal fica num contexto só, o cabeçalho da página do político, com um bonequinho grande e as ações (tocar, segurar, olhar para o dedo e inclinar). Lá há um boneco por vez, e não três, e ele só desenha com a tela à vista. É onde as ações valem o custo. O custo de um boneco sozinho não foi medido; ele entra na régua da fase que fizer essa troca.

## O que pesa na leitura

- **A otimização não era a causa.** A primeira medição foi com `-Onone`, porque o laboratório só existe no Debug. A segunda, com `-O`, deu quase a mesma CPU. O motor novo faz o trabalho de cada quadro na CPU (lê as trilhas, monta os contornos, triangula e aloca listas) e, nas ações, a 120 quadros por segundo.
- **O Lottie quase não usa a CPU do app por quadro.** O motor de Core Animation do Lottie entrega as animações prontas ao servidor de renderização do sistema. Para ganhar dele, o motor novo precisa levar o trabalho de cada quadro para a GPU: malha montada uma vez, só a pose mudando. É o desenho da fase 8 (traços mínimos e rig paramétrico), não o desta prova, que ainda triangula na CPU.
- **Onde o Metal já ganhou:** menos quadros perdidos (0,2% contra 0,6%), nenhuma memória a mais, GPU abaixo de 1 ms para três bonecos, ações vivas (tocar, segurar, olhar, inclinar) e shader no próprio retrato, que o Lottie não deixa.

## O que não foi medido

- Energia (Power Profiler) e o Metal System Trace.
- Um aparelho de 4 a 6 anos: não havia um disponível.
- Os motores novos presos a 30 quadros por segundo, o mesmo ritmo do rig do Lottie.
- O repouso com movimento restrito, em que os motores não pedem quadro.
