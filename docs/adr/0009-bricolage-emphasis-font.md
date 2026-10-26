# 0009. Bricolage Grotesque como fonte de ênfase

- **Estado:** Aceito pelo usuário em 2026-10-26, depois de ver no iPhone
- **Data:** 2026-10-26
- **Mudança:** [`app-1.0`](../changes/app-1.0/proposal.md)

## Contexto

A constituição pedia `.fontDesign(.rounded)` na raiz de cada tela, então quase todo texto do app saía em SF Pro Rounded: corpo, títulos e números. O arredondado era a forma de dar ênfase, mas, aplicado à tela inteira, não diferenciava o que é ênfase do que é leitura. O Rafael decidiu trocar a ênfase de todos os projetos do byescaleira-workspace para a Bricolage Grotesque e testar primeiro no Fiscal. Ele viu o teste no aparelho e aprovou ("vai ser isso mesmo").

## Decisão

- Use **Bricolage Grotesque** (Google Fonts, licença SIL OFL 1.1) só na ênfase:
  - títulos grandes das telas, via `emphasisTitle(_:)`, que põe o título num `ToolbarItem(placement: .largeTitle)` no iOS 26+;
  - títulos de seção, com `sectionTitle()`;
  - botões principais, com `primaryButton()`;
  - nomes e números em destaque, com os tokens `titleLarge`, `titleMedium`, `amount*` e `caseQuestion`, ou `Font.emphasis(_:weight:)`.
- Use **SF Pro** (fonte do sistema) em todo o resto. Nunca `.fontDesign(.rounded)` na raiz de tela.
- A fonte é a variável `BricolageGrotesque.ttf` (eixos opsz, wdth e wght), em `FiscalDesignSystem/Fonts/` com o `OFL.txt`. Ela é registrada uma vez, no início do app, por `FiscalAppearance.install()`, que chama `EmphasisFont.register()`. `Font.emphasis` usa `relativeTo:`, então acompanha o Dynamic Type.
- Exceções:
  - telas com `.searchable` e telas de título inline mantêm `navigationTitle`, porque o título personalizado espreme o campo de busca no iOS 27 e não se aplica ao modo inline;
  - o título pequeno, depois de rolar, fica na fonte do sistema;
  - widgets, cartazes de compartilhamento e retratos seguem arredondados até a migração deles.

## Consequências

- **O que melhora:** a ênfase fica clara, porque só o que importa muda de fonte, e o corpo fica mais legível.
- **Peso:** o app ganha uma fonte de cerca de 400 KB.
- **Obrigação:** a licença OFL vai junto no bundle.
- **No iOS 27:** a barra de navegação ignora `UINavigationBar.appearance()` e `UINavigationBarAppearance` no título grande; `ToolbarItem(placement: .title)` duplica o título e não deve ser usado.
- **Constituição:** a regra 5 muda neste mesmo commit.
- **Mídia da App Store:** as capturas montadas em `docs/app-store/media/source/style.css` precisam trocar SF Pro Rounded pela Bricolage nos títulos antes do envio.
- **Workspace:** a regra da skill `byescaleira-sdd` muda no `byescaleira-workspace`, no branch `feature/bricolage-emphasis-font`.

## Alternativas consideradas

- **Manter SF Pro Rounded:** não diferencia ênfase de leitura, e o Rafael quis outra voz para a ênfase.
- **Bricolage no app inteiro, inclusive no corpo:** a fonte é de display e cansa em texto longo.
- **Mudar a fonte da barra pelo `UINavigationBarAppearance`:** não funciona no título grande da SwiftUI no iOS 27.
