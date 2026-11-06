# SPDD Analysis: bonequinhos em Metal e ações sobre eles

## Original Requirement

> vamos analisar a viabilidade de implementar os bonequinhos dos politicos com o metal? de forma inteligente e performaticas. além de podermos colocar varias ações sobre eles

**Contexto:**
- A [FSC-023](FSC-023-202611051933-[Analysis]-metal-in-fiscal.md) (PR #18, em aberto) trouxe o primeiro shader ao app pelo `ByescaleiraEffects` do kit e achou que **shader não passa por cima do retrato animado**: o Lottie é uma view do UIKit e vira o símbolo 🚫 sob `colorEffect` ou `layerEffect`. Por isso o [ADR 0026](../../docs/adr/0026-shader-effects-never-carry-data.md) proíbe efeito em volta do retrato.
- A [FSC-024](FSC-024-202611061413-[Analysis]-like-with-ripple.md) (rascunho, `feature/like`) só põe a onda em cartão com retrato parado pelo mesmo motivo.

**Critérios de aceite** tirados do pedido:
1. O bonequinho é desenhado por Metal, com o mesmo traço, as mesmas cores de partido e a mesma regra de identificador de hoje ([ADR 0025](../../docs/adr/0025-portrait-by-slug-and-hero-cards-follow-the-mode.md)).
2. É mais leve que o Lottie no iPhone, medido: CPU, GPU, memória, energia e quadros por segundo.
3. A pessoa pode fazer várias ações sobre o bonequinho, que responde na hora.
4. Funciona em iOS, iPadOS, macOS e visionOS, e continua alimentando widget, alerta e cartaz com imagem parada.

**Tamanho:** L. Troca o motor de desenho de uma peça usada em 42 pontos, muda o formato do arquivo do rig, mexe no gerador (`scripts/avatars.py`) e nas quatro plataformas. Vai para o roadmap em fases, e cada fase segue como uma M.

## Domain Concept Identification

### Existing Concepts

- **Gerador do rig** (`scripts/avatars.py`, 1.058 linhas):
  - desenha as partes em Python e calcula cada pose por função do quadro (`compute(frame)`);
  - a pose é um vetor de **22 canais** (`breath`, `headX`, `headY`, `roll`, `turn`, `smile`, `squint`, `blink`, `eyeX`, `eyeY`, as sobrancelhas, `frown`, `open`, `blush`, `bodyY`, `sway` e outros) mais o movimento dos braços;
  - depois **assa** esses valores em quadros-chave de Lottie (`track`, `shape_track`).
- **Rig Lottie** (`fiscal-portrait-rig.json`, 356 KB): 200×200 a 30 qps, 939 quadros, 90 camadas (80 de forma), 749 itens de forma, 20 pares de cor de partido. As variações de rosto, cabelo, barba, sobrancelha e óculos são camadas com seletor `fx`.
- **Marcadores**: `idle` em loop, 8 expressões (`PortraitExpression`: `wave`, `thumbsUp`, `nodYes`, `shakeNo`, `smile`, `celebrate`, `think`, `sad`), 5 gestos (`PortraitGesture`: `lookAround`, `tilt`, `browRaise`, `doubleBlink`, `settle`) e 8 poses paradas (`…Pose`).
- **Traços** (`fiscal-portrait-traits.json`, 383 KB): 8.059 pessoas, 10 campos por índice (`partido`, `pele` 9, `rosto` 4, `cabelo` 7, `cor do cabelo` 8, `sobrancelha` 3, `barba` 3, `cor da barba` 9, `óculos` 2).
- **Montagem** (`PortraitRig` e `PortraitStore` em `FeatureCore/Portraits`): para cada par identificador e partido, copia o dicionário do rig, filtra as camadas pelos traços, tinge as cores e cria um `LottieAnimation` novo. Guarda até 160 animações e 160 imagens paradas, e esvazia tudo quando enche.
- **Desenho** (`PortraitArtView`): `LottieView` com marcador, pausa fora da tela (`onScrollVisibilityChange`) e gesto sorteado a cada 6 a 14 s.
- **Regra de movimento** (`PersonPortrait`): abaixo de 72 pt (`portraitAnimated`), com Reduzir movimento, Pouca Energia ou aparelho quente (`MotionBudget`), o retrato é imagem parada. Na prática, há de 1 a 3 retratos vivos na tela: herói do perfil, cabeçalho fixo, vencedor, investigação e votos.
- **Imagem parada** (`PortraitStill`): o Lottie é desenhado no motor `mainThread` num `CGContext` de 480 px. A prateleira (`PortraitStore+Shelf`) grava PNG de 120 px no App Group para o widget e o alerta de destaque.
- **Ações de hoje**: aceno ao seguir, `celebrate` no vencedor, `think` enquanto a investigação carrega, `nodYes` ou `shakeNo` conforme o voto (`BallotChoice`) e o gesto por capítulo do perfil (`ProfilePortraitChoreography`). Nenhuma é disparada pelo toque da pessoa.
- **Selo do partido** (`PartySeal`, `fiscal-party-seal.json`): outro Lottie, fora deste pedido.

### New Concepts Required

- **Rig em malha:** o mesmo desenho do `avatars.py` exportado como triângulos por parte, com os ossos (cabeça, tronco, braços) e alvos de forma para boca, olhos e sobrancelhas, em vez de quadros-chave assados.
- **Pose viva:** os 22 canais calculados no aparelho a cada quadro, não lidos de uma linha do tempo. Assim duas ações se misturam (acenar enquanto olha para o dedo) e uma ação pode ser interrompida sem salto.
- **Motor de retrato:** um só lugar que guarda a malha na GPU uma vez e desenha cada bonequinho com poucos números (traços, duas cores de partido, pele, cabelo e pose).
- **Ação:** um gesto da pessoa sobre o bonequinho (tocar, segurar, arrastar) que vira uma pose, com háptico e rótulo de acessibilidade.
- **Imagem parada pelo mesmo motor:** desenho fora da tela para o widget, o alerta, o cartaz e os retratos pequenos, com o mesmo resultado do retrato vivo.

### Key Business Rules

- **Mesmo bonequinho:** o traço, as cores e a regra do identificador não mudam. Quem não tem traços continua com o rosto neutro. A conferência do `portrait-check.py` continua valendo.
- **Igual para todos:** toda ação e todo efeito têm os mesmos parâmetros para qualquer político, partido, lado ou resultado (ADR 0026).
- **Ação não é opinião:** nenhuma ação humilha, ridiculariza ou julga a pessoa retratada. Nada de jogar coisa, bater, vaiar, chorar por dado ruim ou "reagir" a um gasto. As reações ligadas a dado continuam sendo só as de fato: o voto Sim ou Não e a vitória numa disputa.
- **Sem fala:** o bonequinho nunca mexe a boca como se dissesse algo, nem com texto, nem com áudio. Evita conteúdo que pareça declaração da pessoa, e o perto da eleição pesa mais (regra das 72 h antes e 24 h depois no backlog).
- **Retrato vivo só onde já é vivo:** de 72 pt para cima, com a tela à vista e sem restrição de movimento ou energia. O resto continua parado.
- **Teto de desempenho**, medido no iPhone do usuário e num aparelho de 4 a 6 anos: o retrato vivo não pode custar mais que o Lottie de hoje em nenhuma das cinco medidas, e precisa manter 60 qps (120 com ProMotion) com 3 na tela.

## Strategic Approach

### Solution Direction

É viável, e o melhor argumento não é velocidade bruta, é o formato. Hoje o `avatars.py` já calcula cada pose como 22 números e depois congela isso em quadros-chave de Lottie, que o app descongela, copia e tinge a cada pessoa. Com Metal, o desenho de todas as partes sobe para a GPU uma vez, e cada bonequinho passa a ser só um punhado de números por quadro. Isso abre três coisas que o Lottie não deixa: misturar e interromper ações sem salto, seguir o dedo da pessoa e aplicar efeito de shader no próprio retrato, o que hoje vira 🚫. Para não arriscar a peça mais vista do app, a direção começa por uma prova de viabilidade com medição contra o Lottie e uma porta de seguir ou parar. Só depois vem a troca em todo o app e, por fim, as ações.

### Key Design Decisions

| Decisão | Escolha | Trade-off | Porta |
| --- | --- | --- | --- |
| Começar por prova de viabilidade | Fase 1: um bonequinho em Metal, lado a lado com o Lottie, medido no iPhone, com decisão de seguir ou parar | Uma fase a mais antes de algo visível, em troca de não reescrever 42 pontos às cegas | pergunta |
| Quais ações entram | Ver a pergunta da parada; recomendado: olhar para o dedo, tocar para reagir e segurar para pensar | Mais ações custam desenho de pose e teste de acessibilidade cada | pergunta |
| Formato do rig | Malha de triângulos por parte, ossos e alvos de forma, exportados pelo próprio `avatars.py`; as poses viram funções no app, não quadros | Duas saídas do gerador durante a transição; ganha mistura, interrupção e arquivo menor | veto |
| Onde fica o motor | No Fiscal, em `FeatureCore/Portraits`, atrás do `PortraitArtwork` de hoje; a parte genérica (desenhar malha vetorial com Metal) vai para o kit só se outro app pedir | Contraria em parte "genérico vai para o kit", mas o rig é do Fiscal e evita uma API de kit prematura | veto |
| Quantas camadas Metal na tela | Uma view Metal por retrato vivo (no máximo 3 na tela), com o motor e a malha compartilhados; retratos pequenos continuam imagem parada | Mais simples que um atlas único para a lista toda; o teto de 3 mantém o custo de drawable baixo | veto |
| Imagem parada | Desenhada pelo mesmo motor fora da tela, para widget, alerta, cartaz e retratos pequenos | Um só desenho de verdade; o `ImageRenderer` não captura view Metal, então o cartaz usa a imagem pronta, como já faz hoje | veto |
| Transição | O Lottie fica como reserva até a paridade ser conferida em todas as combinações de traço; depois sai o rig Lottie do retrato (o selo continua em Lottie) | Dois motores por algumas fases; tira o risco de rosto quebrado em produção | veto |
| Regra de movimento | A mesma de hoje (`MotionBudget`, `@ReducesMotion`, pausa fora da tela, 72 pt); a view Metal para de pedir quadro quando nada se mexe | Nenhuma regra nova; exige que o motor durma de verdade em repouso | veto |
| Efeito no retrato | Liberado só depois da troca, e só os efeitos já aprovados (holográfico da carta), iguais para todos | Revoga a restrição do 🚫 do ADR 0026 para o retrato desenhado em Metal; exige ADR novo | veto |
| Ações iguais para todos e sem fala | Regras de negócio acima | Corta ideias divertidas que viram juízo ou falsa declaração | veto |
| Plataformas | iOS, iPadOS, macOS e visionOS com o mesmo motor; no visionOS, só em janela, sem 3D | Metal existe nos quatro; o visionOS em volume fica fora | veto |
| Antisserrilhado | Começar com multiamostragem 4× e medir; borda por campo de distância só se a prova mostrar serrilhado nas imagens de 480 px | Reversível na prova | reversível |
| Ritmo de quadros | Seguir a tela (60 ou 120 qps) só durante ação; em `idle`, 30 qps como o Lottie de hoje | Ajustado com a medição | reversível |
| Teto do cache | Malha única na GPU; imagens paradas com o teto de 160 de hoje, mas por despejo do mais antigo em vez de esvaziar tudo | Detalhe interno | reversível |

### Alternatives Considered

- **Ficar no Lottie e só ligar ações aos marcadores:** é o caminho mais barato e dá tocar para acenar já. Mas não mistura ações, não segue o dedo, salta ao interromper e continua sem efeito de shader no retrato. Fica como plano B se a prova reprovar o Metal.
- **SwiftUI `Canvas` com o rig procedural:** dá a mistura e o seguir o dedo, aceita shader e o `ImageRenderer`, sem Metal próprio. Mas refaz os caminhos na CPU a cada quadro e a cada bonequinho, que é justamente o custo que se quer tirar. Entra na prova como segunda comparação, porque pode bastar para 3 retratos.
- **Um atlas único em Metal para a lista inteira:** desenha centenas de bonequinhos vivos de uma vez, mas briga com a rolagem e com a regra de que abaixo de 72 pt o retrato é parado. Sem caso de uso hoje.
- **RealityKit ou SceneKit em 3D:** muda o estilo do bonequinho, pede modelo 3D por traço e não é o que foi pedido.
- **Rive:** tem máquina de estados para ações, mas é dependência nova, de terceiro, com o rig refeito à mão fora do `avatars.py`.

## Risk & Gap Analysis

| Critério de aceite | Coberto pela direção? | Lacuna ou risco |
| --- | --- | --- |
| Mesmo traço, cores e regra de identificador | sim | Paridade conferida por comparação de imagem em todas as combinações de traço (9×4×7×8×3×3×9×2) e nas 20 cores de partido |
| Mais leve que o Lottie, medido | parcial | Nenhuma medição existe ainda, nem do Lottie de hoje; a fase 1 mede os dois com Instruments (SwiftUI, Metal System Trace, Energy) |
| Várias ações com resposta na hora | sim | Quais ações é pergunta; cada uma precisa de pose, háptico, rótulo e alternativa sem gesto |
| Quatro plataformas | parcial | macOS com ponteiro (olhar para o cursor) e visionOS com olhar e pinça precisam de conferência própria |
| Widget, alerta e cartaz com imagem parada | sim | O widget não roda Metal: continua lendo o PNG da prateleira, gerado pelo motor novo |

- **Riscos:**
  - Rosto diferente do de hoje numa combinação rara → comparação de imagem automática por combinação e Lottie como reserva até zerar a diferença.
  - Metal mais caro em repouso que o Lottie pausado → o motor só pede quadro durante movimento, medido em repouso na fase 1.
  - Primeiro quadro lento (compilar pipeline, subir malha) → preparar no início do app, como o `EffectsWarmUp` do kit faz com os shaders.
  - Gesto da pessoa disputar com o toque do cartão (o cartão inteiro é o destino principal) → ação só por gesto que não conflita, ou só nos retratos grandes do perfil, decidido no canvas.
  - Ação ser lida como deboche ou opinião → regra "igual para todos, sem fala, sem juízo" e revisão de cada ação contra ela.
  - Acessibilidade: o VoiceOver não faz gesto de arrastar → toda ação tem uma ação de acessibilidade com nome, e nenhuma informação depende dela.
  - Dois motores por algumas fases → prazo para tirar o rig Lottie definido no roadmap.
- **Lacunas:**
  - Quais ações e onde (perfil, votos, Feed); ver a parada.
  - Se a ação da pessoa é só local ou se algum dia vira dado (contagem, compartilhar a reação): fica fora; nada sai do aparelho.
  - Como o `avatars.py` exporta malha: o desenho das partes já é em Python, mas a triangulação é trabalho novo.
- **Quebra:** nenhuma para quem usa o app: o retrato continua igual e os arquivos de traço não mudam. O arquivo do rig ganha um formato novo e, quando o Lottie sair, o caminho remoto `avatars/rig.json` muda de conteúdo, o que pede um `rigVersion` novo para não quebrar quem estiver numa versão antiga.

### Decisões do usuário (parada 1, 2026-11-06)

- **Prova primeiro:** a fase 1 mede Metal e `Canvas` contra o Lottie e termina com a decisão de seguir ou parar.
- **Ações da primeira leva:** olhar para o dedo, tocar para reagir, segurar para pensar e inclinar o iPhone (a cabeça acompanha a inclinação, com a mesma regra do sensor do holográfico: só com a tela à vista e parado com Reduzir movimento, Pouca Energia ou aparelho quente).
- **Seguir para o roadmap e o canvas da fase 1.** Nenhum veto.
- **Estilo (2026-11-06, durante a fase 1):** o bonequinho fica mais parecido com o Memoji da Apple no desenho (formatos, proporções e características de estilo), continua plano e ganha uma luz suave. É a fase 7, com análise própria; o estilo é próprio, sem usar assets nem o nome da Apple.

### Fases propostas para o roadmap

1. **Prova de viabilidade:** um bonequinho (Riedel e um rosto neutro) em Metal e em `Canvas`, ao lado do Lottie, no iPhone; medição das cinco grandezas e decisão de seguir ou parar.
2. **Exportação do rig em malha** pelo `avatars.py`, com a conferência de paridade por imagem em todas as combinações.
3. **Motor no app** atrás do `PortraitArtwork`, com poses vivas, imagem parada e prateleira; Lottie como reserva.
4. **Troca nas quatro plataformas** e saída do rig Lottie do retrato, com ADR.
5. **Ações da pessoa** escolhidas na parada, com háptico e acessibilidade.
6. **Efeito no retrato** (holográfico da carta por dentro), revendo o ADR 0026.
7. **Estilo inspirado no Memoji**, plano e com luz suave, no `avatars.py` e no motor.
8. **Traços mínimos e rig paramétrico** (pedido de 2026-11-06): registro compacto por pessoa, partes com parâmetros e montagem no Metal com malha compartilhada; substitui a fase 2.
