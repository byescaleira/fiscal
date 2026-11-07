# Votações: filtros na toolbar e acabamento do detalhe

- **Data:** 2026-10-25
- **Branch:** `feature/app-1.0-votes-polish`
- **Origem:** retorno do usuário no iPhone sobre a lista e o detalhe de Votações.

## Crítica honesta do que existia

1. **Topo da lista empilhado.** O cabeçalho da primeira seção tinha três camadas verticais: o selo da Lente, o `Picker` segmentado de casa e uma faixa horizontal de chips de tema. Antes da primeira votação, a pessoa via cerca de 150 pt de controles, e o selo da Lente aparecia duas vezes (no topo e no cabeçalho "Nos seus temas").
2. **Filtro ativo sem resumo.** Com a faixa rolada, o tema escolhido sumia da tela, e nada dizia que a lista estava filtrada.
3. **Herói do detalhe estreito.** O placar ficava no `header:` da seção, que no `List` agrupado tem um recuo lateral próprio. O cartão ficava mais estreito que as outras seções, e o respiro interno era de só 16 pt.
4. **Voto na lista nominal.** O `BallotChip` desenhava um retângulo arredondado em volta do símbolo e do texto. Como `checkmark`, `xmark` e `minus` têm larguras diferentes, cada linha tinha um fundo de tamanho diferente, e a coluna de votos não ficava alinhada.

## Referências (capturas oficiais da App Store, iOS 26)

| App | O que vi | O que trouxe | Captura |
| --- | --- | --- | --- |
| **Apple Sports** (lista) | Um botão de escopo em cápsula de vidro no canto superior direito ("Home") com o símbolo e a seleção atual. O conteúdo começa logo abaixo do título, sem filtros empilhados. | Um único controle de filtro na toolbar. A lista começa direto na pauta e nas votações. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/bc/93/78/bc9378cf-f321-0649-e2b8-b079a8e008ba/Sports-iPhone6p9-iOS26-USEN-Wrapper2.png/460x998bb-60.jpg |
| **Mail** (Caixa de Entrada) | Título grande "Inbox" com o subtítulo "iCloud · Updated Just Now" logo embaixo. O filtro (`line.3.horizontal.decrease`) fica na barra, não na lista. | `navigationSubtitle` com o escopo atual ("Câmara e Senado · Todos os temas" ou "Senado · Saúde"). O filtro usa o mesmo símbolo do Mail. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/0a/0b/1b/0a0b1b47-c2a8-0136-ded2-1402e2d79f7e/App_Store_Screenshot_2026_Template_-_iPhone_-_Mail.003.jpeg/460x998bb-60.jpg |
| **Lembretes** (lista "Groceries") | Ações relacionadas juntas numa só cápsula de vidro (compartilhar · mais · buscar). As opções de exibição ficam no menu "…", fora do conteúdo. | Os filtros de casa e de tema ficam num `Menu` só, com `Picker` inline para a casa e um submenu para o tema. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/80/dd/b4/80ddb46d-d88f-72ad-e869-7baf6a502c9a/iPhone_3_Groceries.PNG/460x998bb-60.jpg |
| **Podcasts** (canal) | O par "favoritar · mais" forma um grupo, e o voltar fica isolado. A separação diz o que é parecido e o que é outra coisa. | `FixedToolbarSpacer` (`ToolbarSpacer(.fixed)`) separa o Filtro, que muda a lista, da Lente, que abre outra tela. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/7b/8b/1a/7b8b1a26-4812-970e-86ba-2e8c6290c47f/iPhone6p9-iOS26-USEN-Podcasts-Wrapper2.png/460x998bb-60.jpg |
| **WWDC25 · "Build a SwiftUI app with the new design"** (sessão 323) | `ToolbarSpacer(.fixed)` para separar grupos e `badge` aplicado ao conteúdo do item da toolbar para mostrar um indicador. | Selo numérico com o número de filtros ligados (1 ou 2) no botão de filtro. | https://developer.apple.com/videos/play/wwdc2025/323/ |

**O que não trouxe:** as abas de categoria do Mail, porque são de novo uma faixa de chips sob o título (o problema relatado), nem o fundo colorido do Apple Sports, porque a cor de identidade do Fiscal é do partido e não vai para a barra.

## APIs conferidas (SDK do iOS 27, `SwiftUI.swiftinterface`, e a sessão 323 da WWDC25)

- `navigationSubtitle(_:)`: iOS 26+ e macOS 11+, **indisponível no visionOS** (fica atrás de `#if !os(visionOS)`).
- `ToolbarSpacer`: iOS 26+, indisponível no visionOS e no tvOS. Usamos o `FixedToolbarSpacer` do design system, que já faz esse desvio.
- `View.badge(_ count: Int)`: iOS 15+ e macOS 12+. Na toolbar do iOS 26+, aplicado ao conteúdo do item. Com 0, o selo some.
- `Menu` com `Picker` `.inline` (opções com check no próprio menu) e `Picker` `.menu` (submenu que mostra o valor atual).

## Desenho novo

- **Toolbar (`VotesToolbar`, `.primaryAction`):** `[Filtro] · espaço fixo · [Lente]`.
  - **Filtro:** `Menu` com o rótulo `line.3.horizontal.decrease`, sem `.fill`. Dentro dele: `Picker` inline "Casa" (Câmara e Senado / Câmara / Senado), submenu "Tema" ("Todos os temas"; seção "Nos seus temas" com os temas da Lente, quando há Lente; seção "Outros temas") e "Limpar filtros" (`eraser.line.dashed`) quando algum filtro está ligado. O botão fica desabilitado quando não há votações.
  - **Estado ativo:** o ícone muda para a `appTint` com `symbolEffect(.bounce)`, o selo mostra o número de filtros ligados (1 ou 2) e o subtítulo da navegação mostra o escopo. O VoiceOver lê o escopo como valor do botão.
  - **Lente:** botão `eyeglasses`, como na aba Hoje, que abre a rota `.lens`.
- **Subtítulo:** sempre presente, com a mesma altura, então a barra não pula ao filtrar. Mostra "Câmara e Senado · Todos os temas", "Senado · Todos os temas" ou "Câmara · Saúde".
- **Lista:** começa na pauta, depois "Nos seus temas" (a Lente como seção, com o selo da postura no cabeçalho) e depois os dias. Sem filtro, a lista fica igual à de antes. Com filtro e nenhum resultado, a seção "Limpar filtros" continua.
- **Vibração** de seleção ao trocar a casa ou o tema.

## Detalhe da votação

- **Herói (`VoteHeroSection`):** o placar saiu do `header:` e virou a linha da seção, com `listRowInsets(EdgeInsets())` e o degradê em `listRowBackground`. A margem externa passa a ser a mesma das outras seções, e o canto vem do próprio `List`. Nas colunas do iPad e do Mac (`isGroupedColumn`), o placar continua no cabeçalho com `padding(.horizontal, -.spaceInset)` para anular o recuo do cabeçalho, e o recorte usa `.radiusGroup` (26). O respiro interno foi de `.spaceL` (16) para `.spaceXL` (24).
- **Voto na lista nominal (`BallotMark`):** o texto do voto em `.chipLabel` na cor do dado e, à direita, o símbolo centrado num `Circle` de `.badgeS` (28 pt, escala com `@ScaledMetric` relativo a `.caption`), com fundo na cor do dado a `.opacityTint`. Todas as linhas têm o mesmo círculo, então a coluna fica alinhada pela borda direita. O rótulo de acessibilidade da linha não mudou.

## Rejeitados nesta rodada

- **Faixa de chips de tema sob o título**, mesmo que só uma: é a pilha vertical que o usuário recusou.
- **`Picker` segmentado de casa na `principal`:** ocupa o título e briga com o título grande.
