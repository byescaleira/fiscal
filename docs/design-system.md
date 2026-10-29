# Design system

O `FiscalDesignSystem` é o único lugar com valores visuais. As features usam só os tokens; número solto de espaçamento, raio, opacidade ou fonte nas features, no `AppShell` e no target do app é erro de lint (`design_token_*` em `.swiftlint.yml`). Os valores, componentes e regras completos estão na skill `byescaleira-sdd` (`references/design-tokens.md`, `design-components.md`, `motion-and-lottie.md`, `adaptive-layout.md`).

## Tokens

| Grupo | Arquivo | Tokens |
| --- | --- | --- |
| Espaçamento | `Tokens/Spacing.swift` | `.spaceHairline` 2, `.space2XS` 4, `.spaceXS` 6, `.spaceS` 8, `.spaceM` 12, `.spaceL` 16, `.spaceInset` 20, `.spaceXL` 24, `.space2XL` 32 |
| Raio | `Tokens/Radius.swift` | `.radiusS` 8, `.radiusM` 16, `.radiusL` 22, `.radiusGroup` 26 |
| Opacidade | `Tokens/Opacity.swift` | `.opacityHidden` 0,02, `.opacityFill` 0,12, `.opacityTint` 0,2, `.opacitySoft` 0,35, `.opacityStrong` 0,8 |
| Tamanho | `Tokens/Size.swift` | `.badgeS` 28, `.badgeM` 36, `.badgeL` 44, `.badgeXL` 56, `.portraitAnimated` 72 (só retratos a partir daqui animam), `.ring` 76, `.medallion` 112, `.barHeight` 10, `.rowHeight` 44 |
| Ícone | `Tokens/IconSize.swift` | `.icon(.xs/.s/.m/.l/.xl/.hero, weight:)` |
| Tipografia | `Tokens/Typography.swift`, `Tokens/Typography+Emphasis.swift` | `.amountHero`, `.amountTitle`, `.amountRow`, `.amountInput`, `.chipLabel`, `.rowTitle`, `.buttonLabel`, `.titleLarge`, `.titleMedium`, `.rowDetail`; ênfase com `Font.emphasis(_:weight:)` |

## Tipografia

Ênfase em **Bricolage Grotesque**, corpo em **SF Pro** ([ADR 0009](adr/0009-bricolage-emphasis-font.md)).

- **Títulos grandes:** `emphasisTitle(_:)` no lugar de `navigationTitle`. Telas com `.searchable` ou de título inline continuam com `navigationTitle`.
- **Seções e botões:** `sectionTitle()` e `primaryButton()` já usam a fonte de ênfase.
- **Destaques:** nomes e números em destaque usam os tokens acima ou `.font(.emphasis(.title3, weight: .bold))`. Corpo, linhas e legendas ficam nas fontes do sistema, sem `.fontDesign(.rounded)` na raiz da tela.
- **Um tipo só nos números:** placar, herói, cartazes, widgets e Live Activities usam a Bricolage; quando o tamanho segue a área, `Font.emphasis(fixed:weight:)` (tokens `scoreboard*`, `poster*`, `candidatePercent*`, `ballotNumber(_:)`). Nada de SF condensada, arredondada ou mono, nem SF heavy/black em tamanho fixo; algarismos alinhados com `.monospacedDigit()`. Os algarismos da Bricolage ExtraBold avançam ~0,57 do tamanho (a SF condensada, ~0,49), e `posterFigureAdvance` (0,6) já conta com isso.
- **A fonte:** é a `Fonts/BricolageGrotesque.ttf` variável, com o `OFL.txt` ao lado. É registrada uma vez por `FiscalAppearance.install()` e acompanha o Dynamic Type (`relativeTo:`).

## Movimento e energia

`MotionBudget.isConstrained` fica verdadeiro com o Modo Pouca Energia ou com o aparelho quente (`thermalState` sério ou crítico). Nesse estado, e com Reduzir movimento:

- retratos ficam parados;
- `PartyMark` não anima, e nos outros casos anima uma vez ao aparecer;
- selo do partido, carrossel de arte e animações em loop ficam parados.

Retratos menores que `.portraitAnimated` são sempre imagem parada.

## Cores

- Paleta retrô do sistema visual (`Color.retroMustard`, `.retroOrange`, `.retroRust`, `.retroOlive`, `.retroTeal`, `.retroDenim`, `.retroPlum`, `.retroBrown`, `.retroCream`), com variante escura.
- Semânticas: `.positive`, `.negative`, `.warning`, `.info`, `.companion`, `.disabled`.
- Cor de destaque escolhida pela pessoa: `RetroColor` (26 cores) em `FeatureCore`, aplicada como `.tint` e `\.appTint`.

## Animações

Lottie gerada por `scripts/animations.py` (sem fundo, camadas nomeadas pela paleta), embutida em `FiscalResourceAnimation.swift` e tocada por `FiscalAnimationView(_:loops:isStill:)`. Prévia em `scripts/animations-preview.html`.
