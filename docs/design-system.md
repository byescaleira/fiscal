# Design system

Os tokens, as cores retrô, a tipografia, o movimento, os modificadores, o layout adaptativo, os componentes básicos e os gráficos genéricos vêm do **byescaleira-kit** ([ADR 0010](adr/0010-byescaleira-kit.md)): `ByescaleiraDesign`, `ByescaleiraCharts`, `ByescaleiraAccessibility` e `ByescaleiraPlatform`, reexportados pelo `FiscalDesignSystem`, e `ByescaleiraUI` pelo `FeatureCore`. A referência completa está no kit (`docs/components.md`, `docs/platforms.md`) e na skill `byescaleira-sdd`. Número solto de espaçamento, raio, opacidade ou fonte nas features, no `AppShell` e no target do app continua sendo erro de lint (`design_token_*` em `.swiftlint.yml`).

O `FiscalDesignSystem` guarda só o que é do Fiscal:

| Grupo | Arquivos |
| --- | --- |
| Partidos | `PartyPalette`, `PartyMark`, `PartyBackdrop` |
| Placar e votos | `ScoreboardFigure`, `TallyBar`, `TallyChart`, `Color+Vote`, `Font.scoreboardNumber`, `Color.scoreboard`, `Color.scoreboardAccent` |
| Retratos | `PersonPortrait`, `PortraitArtwork`, `.portraitAnimated` (72; só retratos a partir daqui animam) |
| Compartilhar | `Share*Tokens`, `InvestigationTokens`, `ArtSize` |
| Telas | `MoneyChartTokens`, `MoneyPlaceTokens`, `RegionTokens`, `SettingsTokens`, `ChartSize`, `Size+Columns`, `Typography+Widgets`, `.railTitleMargin` |
| Comemoração | `CelebrationBurst`, `CelebrationConfetti` |

## Tipografia

Ênfase em **Bricolage Grotesque**, corpo em **SF Pro** ([ADR 0009](adr/0009-bricolage-emphasis-font.md)).

- **Títulos grandes:** `emphasisTitle(_:)` no lugar de `navigationTitle`. Telas com `.searchable` ou de título inline continuam com `navigationTitle`.
- **Seções e botões:** `sectionTitle()` e `primaryButton()` já usam a fonte de ênfase.
- **Destaques:** nomes e números em destaque usam os tokens acima ou `.font(.emphasis(.title3, weight: .bold))`. Corpo, linhas e legendas ficam nas fontes do sistema, sem `.fontDesign(.rounded)` na raiz da tela.
- **Um tipo só nos números:** placar, herói, cartazes, widgets e Live Activities usam a Bricolage; quando o tamanho segue a área, `Font.emphasis(fixed:weight:)` (tokens `scoreboard*`, `poster*`, `candidatePercent*`, `ballotNumber(_:)`). Nada de SF condensada, arredondada ou mono, nem SF heavy/black em tamanho fixo; algarismos alinhados com `.monospacedDigit()`. Os algarismos da Bricolage ExtraBold avançam ~0,57 do tamanho (a SF condensada, ~0,49), e `posterFigureAdvance` (0,6) já conta com isso.
- **A fonte:** é a `BricolageGrotesque.ttf` variável do kit, com o `OFL.txt` ao lado. É registrada uma vez por `FiscalAppearance.install()` (`EmphasisFont.register()`) e acompanha o Dynamic Type (`relativeTo:`).

## Movimento e energia

`MotionBudget.isConstrained` (do kit, por `LiteMode.systemIsConstrained`) fica verdadeiro com o Modo Pouca Energia ou com o aparelho quente (`thermalState` sério ou crítico). Nesse estado, e com Reduzir movimento:

- retratos ficam parados;
- `PartyMark` não anima, e nos outros casos anima uma vez ao aparecer;
- selo do partido, carrossel de arte e animações em loop ficam parados.

Retratos menores que `.portraitAnimated` são sempre imagem parada.

## Cores

- Paleta retrô do kit (`Color.retroMustard`, `.retroOrange`, `.retroRust`, `.retroOlive`, `.retroTeal`, `.retroDenim`, `.retroPlum`, `.retroBrown`, `.retroCream`), com variante escura; laranja, mostarda e oliva passam 4,5:1 como texto no claro.
- Semânticas: `.positive`, `.negative`, `.warning`, `.info`, `.companion`, `.disabled`.
- Cor de destaque escolhida pela pessoa: `RetroColor` (26 cores) do `ByescaleiraUI`, aplicada como `.tint` e `\.appTint`.

## Animações

Lottie gerada por `scripts/animations.py` (sem fundo, camadas nomeadas pela paleta), embutida em `FiscalResourceAnimation.swift` e tocada por `FiscalAnimationView(_:loops:isStill:)`. Prévia em `scripts/animations-preview.html`.

## Cartões com fundo preto

Quatro cartões tinham fundo preto também no modo claro: o placar da votação, "Na sua região agora", a conclusão da investigação e o cartão de cima de comparar. Eles usam `HeroSurface` ([ADR 0025](adr/0025-portrait-by-slug-and-hero-cards-follow-the-mode.md)):

- **Claro:** o cinza dos cartões, a cor suave nas laterais e o centro neutro, com o texto em `Color.heroInk` ou `HeroInk`.
- **Escuro:** o fundo de cada cartão, como antes.
- **Aumentar contraste:** só o cinza e um contorno.

Os cartões com a cor do partido ou do tema não usam essa peça e continuam iguais nos dois modos, por decisão do usuário.

## Efeitos

Os efeitos de shader seguem as seis regras do [ADR 0026](adr/0026-shader-effects-never-carry-data.md): o dado nunca vai em shader, o efeito é igual para todos, fica fora do conteúdo, para com Reduzir movimento e o modo leve, só roda quando precisa e, quando é genérico, vem do `ByescaleiraEffects` do `byescaleira-kit` ([FSC-023](../spdd/prompt/FSC-023-202611052151-[Feat]-plenary-and-holographic-card.md)).

- **Plenário:** `PlenaryChart`, no `FiscalDesignSystem`, desenha um ponto por cadeira em `Canvas` (513 na Câmara, 81 no Senado). A cor e a ordem vêm só do voto, e a linha de quórum aparece só onde a regra é conhecida (PEC). A contagem anima uma vez, em 2,2 s.
- **Carta colecionável:** o cartão do topo da página do político ganha a moldura metalizada (`collectibleFrame`), o retrato numa janela com a folha `.sparkle` e o giro com a inclinação (`cardTurn`). O texto e os botões ficam no fundo do partido, sem efeito. A carta é igual para todo político.
- **Degradação:** com Reduzir movimento ou o modo leve, a carta fica parada e o sensor não liga; com Aumentar contraste ou Reduzir transparência, a janela fica sem holográfico e a moldura vira prata liso. No Mac e no visionOS, a carta fica parada.
- **Onda:** `View.ripple(origin:trigger:)` existe no kit e entra no app com o curtir. Não vale sobre view do UIKit, como o retrato em Lottie.

## Barra ao rolar

Quando algo precisa continuar visível, `View.revealBar` e `ShortcutStrip`, do `byescaleira-kit`, põem uma barra sobre a rolagem. No app, `RevealPage` junta a barra, o herói e os capítulos ([ADR 0024](adr/0024-reveal-bar-following-and-ballots-screens.md)).

- **Onde entra:** página do político, detalhe da votação (proposta e placar), detalhe da corrida (corrida e apurado) e notas (nome, ano com o filtro e total). Essas telas não mostram o título na barra de ferramentas, para não repetir.
- **Onde não entra:** listas de abas, como Votações e Feed.
- **Como se comporta:** só muda de opacidade, sem mudar o layout, e os saltos não animam com Reduzir movimento.
