# SPDD Analysis: curtir no Feed com a onda

## Original Requirement

> depois cria a FSC-024 do curtir com a onda

**Contexto:**
- Na FSC-023, o usuário escolheu três efeitos: "Plenário, Onda do curtir, Cartão do político … como se fosse um card colecionável".
- O plenário e a carta foram entregues no [PR #18](https://github.com/byescaleira/fiscal/pull/18).
- A onda existe só no `byescaleira-kit` 0.10.0, como `View.ripple(origin:trigger:)`. O Fiscal ainda não tem curtir em lugar nenhum.

**Critérios de aceite** vindos da [análise](FSC-023-202611051933-[Analysis]-metal-in-fiscal.md) e do [canvas](../prompt/FSC-023-202611052151-[Feat]-plenary-and-holographic-card.md) da FSC-023 e do [ADR 0026](../../docs/adr/0026-shader-effects-never-carry-data.md):
1. A pessoa curte um item do Feed com um toque, e a onda sai do ponto tocado.
2. A onda roda só durante a animação e nunca envolve retrato animado (Lottie).
3. Com Reduzir movimento ou o Modo Pouca Energia, não há onda: o coração fica cheio e o iPhone dá o toque háptico.
4. O efeito nunca muda o significado do dado e é igual para todos.
5. O VoiceOver anuncia "Curtir" e "Curtido" como estado do botão.

**Tamanho:** L, porque o curtir é um dado novo da pessoa e pede migração do esquema (AGENTS.md, "Caminho rápido"). Mesmo assim cabe numa fase só, que segue como uma M. A linha do roadmap entra com o canvas.

## Domain Concept Identification

### Existing Concepts

- **Item do Feed** (`FeedItem` em `FiscalDomain/PublicData/FeedTimeline.swift`):
  - tem `id` estável e `kind`: `vote`, `proposal`, `speech`, `expenses`, `check`, `event` ou `highlight`;
  - vem dos arquivos públicos e é montado no aparelho.
- **Linha do Feed** (`FeedCard` em `FeatureFeed/FeedRows.swift`):
  - o cartão inteiro é o destino principal, por `RouteCard` ou por link externo;
  - o cabeçalho abre o perfil;
  - os votos de cada pessoa são linhas próprias.
- **Destaque e apuração no topo** (`FeedHighlightHero`, `FeedRaceHero`): cartões com o compartilhar no menu de contexto.
- **Seguir** (`FollowEntity`): vai para o iCloud (`cloudModels`) e para o Spotlight.
- **Meu apoio** (`SupportEntity`):
  - fica em `Device.store`, sem CloudKit e fora do backup, porque é opinião política, dado sensível pela LGPD (art. 5º, II) ([ADR 0021](../../docs/adr/0021-end-of-lens-support-on-device.md));
  - nunca vai para servidor, telemetria, widget, Siri, Spotlight nem cartaz.
- **Esquema** (`FiscalSchemaV4` e `FiscalMigrationPlan` em `FiscalData/Store/Schema/FiscalSchema.swift`):
  - `FollowEntity` e `InvestigationEntity` estão em `cloudModels`;
  - `SupportEntity` e `LensEntity` estão em `deviceModels`.
- **Onda** (`View.ripple(origin:trigger:)` no `ByescaleiraEffects` do kit):
  - liga o shader só durante a animação;
  - degrada sozinha com Reduzir movimento e `\.liteMode.reducesMotion`;
  - `EffectsWarmUp` compila o shader antes do primeiro toque.
- **Movimento** (`MotionBudget`, `@ReducesMotion`): a regra única de degradação que o plenário e a carta já usam.

### New Concepts Required

- **Curtida:** a marca da pessoa num item do Feed, com o identificador do item, o tipo, o título no momento da curtida e a data.
- **Botão de curtir:** um coração em cada linha do Feed e nos cartões do topo, com estado ligado ou desligado. É uma ação secundária, que não disputa com o destino principal do cartão.
- **Lista de curtidas:** onde a pessoa reencontra o que curtiu (ver a pergunta 3).

### Key Business Rules

- **Uma curtida por item:** tocar de novo desfaz.
- **Sem contagem:** o app nunca mostra quantas pessoas curtiram, nem do próprio aparelho, porque o número não existe (curtida privada).
- **A curtida não muda o Feed:** não muda a ordem, o filtro, o destaque nem as sugestões. Segue a regra do ADR 0021 para o apoio.
- **A curtida nunca sai do aparelho para:**
  - servidor;
  - telemetria;
  - notificação;
  - Spotlight;
  - widget;
  - Siri;
  - cartaz de compartilhar.

  Só sai na exportação pedida pela pessoa, como o apoio.
- **Onda:**
  - dura o tempo do `ripple` do kit e nada mais;
  - nunca envolve retrato animado. As linhas do Feed já usam o retrato parado;
  - nunca passa por cima de número.
- **Reduzir movimento e Modo Pouca Energia:** o coração preenche sem animação e o toque háptico continua.

## Strategic Approach

### Solution Direction

O curtir é uma marca privada, guardada como o "Meu apoio": só no aparelho, fora do iCloud e do backup, sem contagem e sem efeito no resto do app.

Cada linha do Feed ganha um coração pequeno no rodapé, separado do toque principal do cartão. Ao curtir, a onda do kit sai do coração e atravessa só aquele cartão, e o iPhone dá o toque háptico.

A pessoa reencontra o que curtiu numa lista "Curtidas" no menu do Feed, ao lado de "Meu apoio". O esquema ganha uma entidade só no aparelho, numa migração leve.

A FSC-024 depende da FSC-023, que traz o kit 0.11.0, e por isso sai da `feature/metal-exploration`.

### Key Design Decisions

| Decisão | Escolha | Trade-off | Porta |
| --- | --- | --- | --- |
| O que é o curtir | **Escolha do usuário (06/11/2026):** marca privada, sem contagem pública | Ganha: neutralidade, nada de opinião política em servidor, fase única. Perde: o sinal social de "quantos curtiram" | pergunta |
| Onde a curtida fica | **Escolha do usuário (06/11/2026):** só no aparelho (`deviceModels`), fora do iCloud e do backup, como o apoio | Ganha: o mesmo cuidado do ADR 0021 com dado sensível. Perde: não aparece nos outros aparelhos da pessoa e some ao trocar de iPhone sem exportar | pergunta |
| Onde a pessoa reencontra | **Escolha do usuário (06/11/2026):** lista "Curtidas" no menu do Feed, ao lado de "Meu apoio" | Ganha: o curtir tem uso além da animação. Perde: mais uma tela | pergunta |
| O que pode ser curtido | Todas as linhas do Feed e os cartões do topo (destaque e apuração) | Ganha: uma regra só. Perde: curtir um gasto ou uma checagem pode soar estranho | veto |
| Gesto | Só o botão do coração; sem dois toques no cartão | Ganha: o toque principal do cartão não espera para descobrir se vem um segundo toque, num Feed com 50 milhões de pessoas. Perde: o gesto famoso das redes | veto |
| Lugar do coração | Rodapé da linha, à direita, com alvo de 44 pt, separado do `RouteCard` | Ganha: um destino principal por cartão. Perde: a linha cresce um pouco | veto |
| Esquema | `FiscalSchemaV5` com uma entidade nova em `deviceModels`, numa migração leve | Ganha: o mesmo caminho da V4. Perde: mais uma versão no plano de migração | veto |
| Onde a onda roda | Só no cartão curtido, com origem no coração e duração do `ripple` do kit | Ganha: o shader desliga logo depois. Perde: nada visível | reversível |
| Toque háptico | `.sensoryFeedback` de impacto ao curtir, também com Reduzir movimento | Ganha: retorno sem movimento | reversível |
| Pré-compilação | `EffectsWarmUp` uma vez ao abrir o Feed | Ganha: o primeiro toque sem engasgo | reversível |
| Rótulo de privacidade | Não muda: a curtida não sai do aparelho | — | reversível |
| Base da branch | `feature/like` sai da `feature/metal-exploration` | Ganha: o kit 0.11.0 e o índice em dia. Perde: depende do merge do PR #18 | reversível |

### Alternatives Considered

- **Curtir com contagem pública:**
  - pede servidor, conta ou identificador do aparelho, proteção contra fraude e moderação;
  - guarda opinião política fora do aparelho, contra o ADR 0021;
  - vira uma L de várias fases e um ADR novo;
  - um número de curtidas numa votação seria lido como aprovação pública, o que fere o "só fatos".
- **Curtida no iCloud privado, como o seguir:** daria o curtir em todos os aparelhos, mas curtir uma votação é opinião política, e o apoio já ficou fora do iCloud pelo mesmo motivo.
- **"Salvar" no lugar de "Curtir":** tira o tom de aprovação, mas não é o que o usuário pediu, e a onda foi escolhida para o curtir. Fica como opção na pergunta 1.
- **Dois toques no cartão:** atrasa o toque principal de todo cartão e conflita com o `RouteCard`.
- **Partículas além da onda:** a FSC-023 escolheu a onda. Partículas ficam fora.

## Risk & Gap Analysis

| Critério de aceite | Coberto pela direção? | Lacuna ou risco |
| --- | --- | --- |
| 1. Curtir com um toque, onda do ponto tocado | sim | A origem é o coração, não o ponto exato do dedo: o toque acontece no próprio botão |
| 2. Onda só na animação, nunca sobre Lottie | sim | As linhas do Feed usam retrato parado. Os cartões do topo precisam ser conferidos no canvas |
| 3. Reduzir movimento e Pouca Energia | sim | Degradação do kit, mais o háptico |
| 4. Efeito sem significado, igual para todos | sim | Sem contagem; a onda é a mesma em todo item |
| 5. VoiceOver | sim | O botão "Curtir" ou "Curtido" fica como ação separada do rótulo do cartão. O cartão já junta os filhos, então o canvas define a ação de acessibilidade |

- **Riscos:**
  - "curtir" numa votação pode ser lido como apoio político → a curtida é privada, sem número, e não muda nada no app. O texto da lista diz que ela fica só no aparelho.
  - Custo da onda com rolagem rápida → o shader liga só no cartão tocado e só durante a animação. A medição no iPhone entra com a do backlog ("Custo dos efeitos medido").
  - Curtida de item que some do Feed (janela de dias) → a lista guarda o título e o tipo da hora da curtida e abre o destino quando ele ainda existe.
- **Lacunas:**
  - o limite de curtidas guardadas (proposta: sem limite, a lista mostra as mais recentes);
  - a exportação junto com a do apoio.

  As duas são de porta reversível e ficam no canvas.
- **Quebra:** nenhuma em versão publicada, porque o app ainda não saiu na loja. O esquema sobe para a V5 com migração leve, sem tocar nos dados que já existem.
