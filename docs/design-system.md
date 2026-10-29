# Design system

Os tokens, as cores retrô, a tipografia, o movimento, os modificadores, o layout adaptativo, os componentes básicos e os gráficos genéricos vêm do **byescaleira-kit** ([ADR 0010](adr/0010-byescaleira-kit.md)): `ByescaleiraDesign`, `ByescaleiraCharts`, `ByescaleiraAccessibility` e `ByescaleiraPlatform`, reexportados pelo `FiscalDesignSystem`, e `ByescaleiraUI` pelo `FeatureCore`. A referência completa está no kit (`docs/components.md`, `docs/platforms.md`) e na skill `byescaleira-sdd`. Número solto de espaçamento, raio, opacidade ou fonte nas features, no `AppShell` e no target do app continua sendo erro de lint (`design_token_*` em `.swiftlint.yml`).

O `FiscalDesignSystem` guarda só o que é do Fiscal:

| Grupo | Arquivos |
| --- | --- |
| Partidos | `PartyPalette`, `PartyMark`, `PartyBackdrop` |
| Placar e votos | `ScoreboardFigure`, `TallyBar`, `TallyChart`, `Color+Vote`, `Font.scoreboardNumber`, `Color.scoreboard`, `Color.scoreboardAccent` |
| Retratos | `PersonPortrait`, `PortraitArtwork`, `.portraitAnimated` (72; só retratos a partir daqui animam) |
| Lente e compartilhar | `LensPaletteSwatch`, `LensLookTokens`, `Share*Tokens`, `InvestigationTokens`, `ArtSize` |
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
