# Design system

O `FiscalDesignSystem` é o único lugar com valores visuais. As features usam só os tokens; número solto de espaçamento, raio, opacidade ou fonte nas features, no `AppShell` e no target do app é erro de lint (`design_token_*` em `.swiftlint.yml`). Os valores, componentes e regras completos estão na skill `byescaleira-sdd` (`references/design-tokens.md`, `design-components.md`, `motion-and-lottie.md`, `adaptive-layout.md`).

## Tokens

| Grupo | Arquivo | Tokens |
| --- | --- | --- |
| Espaçamento | `Tokens/Spacing.swift` | `.spaceHairline` 2, `.space2XS` 4, `.spaceXS` 6, `.spaceS` 8, `.spaceM` 12, `.spaceL` 16, `.spaceInset` 20, `.spaceXL` 24, `.space2XL` 32 |
| Raio | `Tokens/Radius.swift` | `.radiusS` 8, `.radiusM` 16, `.radiusL` 22, `.radiusGroup` 26 |
| Opacidade | `Tokens/Opacity.swift` | `.opacityHidden` 0,02, `.opacityFill` 0,12, `.opacityTint` 0,2, `.opacitySoft` 0,35, `.opacityStrong` 0,8 |
| Tamanho | `Tokens/Size.swift` | `.badgeS` 28, `.badgeM` 36, `.badgeL` 44, `.badgeXL` 56, `.ring` 76, `.medallion` 112, `.barHeight` 10, `.rowHeight` 44 |
| Ícone | `Tokens/IconSize.swift` | `.icon(.xs/.s/.m/.l/.xl/.hero, weight:)` |
| Tipografia | `Tokens/Typography.swift` | `.amountHero`, `.amountTitle`, `.amountRow`, `.amountInput`, `.chipLabel`, `.rowTitle`, `.buttonLabel`, `.titleLarge`, `.titleMedium`, `.rowDetail` |

## Cores

- Paleta retrô do sistema visual (`Color.retroMustard`, `.retroOrange`, `.retroRust`, `.retroOlive`, `.retroTeal`, `.retroDenim`, `.retroPlum`, `.retroBrown`, `.retroCream`), com variante escura.
- Semânticas: `.positive`, `.negative`, `.warning`, `.info`, `.companion`, `.disabled`.
- Cor de destaque escolhida pela pessoa: `RetroColor` (26 cores) em `FeatureCore`, aplicada como `.tint` e `\.appTint`.

## Animações

Lottie gerada por `scripts/animations.py` (sem fundo, camadas nomeadas pela paleta), embutida em `FiscalResourceAnimation.swift` e tocada por `FiscalAnimationView(_:loops:isStill:)`. Prévia em `scripts/animations-preview.html`.
