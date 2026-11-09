# Referências do ícone do Fiscal

- **Data:** 2026-10-25
- **Para:** o ciclo de design do ícone (brief, "Aparência pela Lente" › "Ícone do app")
- **Método:** navegador do app, sem login. Ícones vistos nas páginas da App Store (prévias `mzstatic` abertas na tela), páginas do Apple Design Award 2024–2026, a HIG e a documentação do Icon Composer. Nenhuma imagem foi copiada para o repositório.

## O que a Apple pede (regras que valem para os quatro conceitos)

| # | Fonte | O que diz | O que pegamos |
|---|---|---|---|
| 1 | [HIG · App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) (revisada em 8 jun. 2026) | Uma ideia central com poucas formas, fundo simples (cor ou degradê), bordas definidas, nada de linhas finas nem cantos vivos, sem texto além de um mnemônico. As aparências padrão, escura, clara e tingida mantêm os mesmos elementos; os ícones alternativos precisam das próprias variantes escura, clara e tingida. | Uma figura por conceito, traços de 58 a 92 pt no canvas de 1024, cantos arredondados, variantes clara, escura e tingida em todos, sem texto (o "F" do conceito Documento é o mnemônico permitido). |
| 2 | [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) | Camadas em SVG, no máximo quatro grupos, fundo definido no próprio Icon Composer (cor ou degradê), sem sombra, desfoque ou especular "pintados" na arte; o vidro, a translucidez e a sombra ficam por conta dos grupos. | Cada `.icon` tem de 2 a 3 grupos, SVGs de 1024×1024 sem efeitos, fundo como `linear-gradient` no `icon.json` e o vidro configurado por grupo. |
| 3 | [WWDC25 · Say hello to the new look of app icons](https://developer.apple.com/videos/play/wwdc2025/220/) | Vista frontal e plana em vez de 3D realista; o exemplo do Preview mostra a lupa com perspectiva só onde ela tem propósito. Linhas mais grossas sobrevivem ao tamanho pequeno. Degradês suaves do claro para o escuro e fundos coloridos (em vez de preto ou branco puros) separam melhor os modos claro e escuro. | Todos os conceitos são frontais, com fundo colorido em degradê e um modo escuro que escurece o fundo e clareia a figura. |
| 4 | [Configuring your app to use alternate app icons](https://developer.apple.com/documentation/xcode/configuring-your-app-to-use-alternate-app-icons) | Cada ícone alternativo é um arquivo do Icon Composer no projeto; o Xcode gera `CFBundleAlternateIcons` a partir de `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`; a troca é por `setAlternateIconName(_:)`. | Base do [wiring.md](wiring.md) e do `SystemAppIconSwitcher`. |

## Ícones de referência

| # | App | O que vi | O que trazer | O que não trazer |
|---|---|---|---|---|
| 5 | [Primary: News in Depth](https://apps.apple.com/us/app/primary-news-in-depth/id6751006185), vencedor de Impacto Social do [ADA 2026](https://developer.apple.com/design/awards/) | App de notícia sem sensacionalismo. O ícone é um olho: cápsula preta, losango branco e pupila com borda em três cores. | Um olho funciona como "olhar atento" para notícia e transparência, e foi premiado. | O desenho dele. O conceito Olhar usa amêndoa arredondada sobre creme e íris em duas metades, para não parecer derivado do Primary. |
| 6 | [Watch Duty](https://apps.apple.com/us/app/id1574452924), vencedor de Impacto Social do [ADA 2025](https://developer.apple.com/design/awards/2025/) | Uma chama escura e única sobre amarelo chapado. Lê-se de longe e em qualquer tamanho. | Fundo de cor única e figura escura e maciça: é o modelo do conceito Urna (mostarda + tinta). | O amarelo vivo de alerta: o Fiscal usa o mostarda da paleta retrô. |
| 7 | Vencedores do [ADA 2025](https://developer.apple.com/design/awards/2025/) (Play, Speechify, CapWords) | Uma figura só, centralizada, com muito respiro; o Play é um anel preto grosso sobre branco. | A lupa do conceito Lupa segue esse peso: anel grosso, cabo curto e um único detalhe dentro. | Sobrepor mais de uma metáfora no mesmo ícone. |
| 8 | [Apple Sports](https://apps.apple.com/us/app/apple-sports/id6446788829) | Campo de futebol em linhas brancas grossas sobre verde, vista de cima, sem perspectiva. | Linhas grossas e uma cor de fundo que identifica o app de longe. | O verde: no Brasil ele forma o verde-amarelo, disputado pelos dois campos. |
| 9 | [Apple News](https://apps.apple.com/us/app/apple-news/id1066498020) | O "N" desenhado com duas formas geométricas, vermelho sobre branco. | Monograma construído com formas, não com fonte: o "F" do conceito Documento é feito de três barras, como as linhas de um texto. | O vermelho como cor principal. |
| 10 | [Journal](https://apps.apple.com/us/app/journal/id6447391597) e [Stocks](https://apps.apple.com/us/app/stocks/id1069512882) | No Journal, formas translúcidas sobrepostas tiram partido do vidro. No Stocks, o dado vira a própria figura, sobre fundo escuro. | Vidro com translucidez onde a forma pede: a caixa da Urna é transparente (urna de acrílico, transparência) e o vidro da Lupa deixa ver o fundo. | Muitas camadas sobrepostas: a própria Apple reduziu a sobreposição no Fotos. |
| 11 | [Ground News](https://apps.apple.com/us/app/id1324203419), listado no [ADA 2025](https://developer.apple.com/design/awards/2025/) | App que compara a cobertura da esquerda e da direita. O ícone é só a marca em preto e branco, sem a cor de nenhum lado. | Neutralidade na cor do ícone; as cores de lado ficam dentro do app. O conceito Olhar leva os dois lados em metades iguais, em teal e ameixa, e nenhum deles é cor de partido. | Ícone só tipográfico (texto no ícone é proibido pelo brief). |
| 12 | [Resultado Eleições Politique](https://apps.apple.com/us/app/resultado-elei%C3%A7%C3%B5es-politique/id1438157402) e [Resultados (TSE)](https://apps.apple.com/us/app/resultados/id1136359313) (contraexemplos) | O Politique põe um losango verde e amarelo, tirado da bandeira, atrás da marca. O app do TSE usa um gráfico de barras genérico sobre verde. | Nada. Mostram o que diferenciar: a categoria no Brasil é verde, amarela e de bandeira. | Bandeira, losango, verde-amarelo e gráfico genérico. |

## Conceitos e rodadas

Folha de comparação: [concepts.png](concepts.png), com padrão, escuro, tingido claro e escuro, transparente claro e escuro, e 58 px, o tamanho de Ajustes. As prévias em 1024 e 58 px, claras e escuras, estão em [previews/](previews/).

| Conceito | Arquivo | Ideia | Cores (padrão · escuro) |
|---|---|---|---|
| Lupa | `FiscalIconLens.icon` | Lupa geométrica e frontal, com um check dentro do vidro: "conferido". | Fundo teal `#347D74`→`#1B4B46` · `#173B37`→`#0C1F1D`; lupa e check creme `#F4ECDC`/`#FFF8EA`; vidro teal claro `#8FD0C6` a 28%. |
| Olhar | `FiscalIconIris.icon` | Olho em amêndoa com a íris em duas metades espelhadas: o mesmo olhar para os dois lados. | Fundo creme `#F8F1E3`→`#E8DBC3` · `#2B241F`→`#161210`; olho tinta `#231D19` (no escuro, creme `#EDE3CF`); íris teal `#3E8C83` e ameixa `#8E5577` (no escuro, `#62ABA2` e `#B57FA0`). |
| Urna | `FiscalIconBallot.icon` | Urna transparente com a cédula marcada entrando, inclinada. | Fundo mostarda `#EDBE5A`→`#C98F25` · `#4A3714`→`#231A09`; tampa tinta `#231D19` (no escuro, creme `#F0E3C4`); caixa de vidro creme a 58%; cédula `#FBF5E8` com check tinta. |
| Documento | `FiscalIconMonogram.icon` | Página cujas linhas de texto formam o "F", com um selo de conferido. | Fundo ameixa `#8A5274`→`#5B2F4A` · `#33202C`→`#1C1118`; página creme `#F4ECDC`; F ameixa `#5B2F4A`; selo mostarda `#E3B04B` com check tinta. |

**Por que são neutros:** as cores saem da paleta retrô do app (teal, ameixa, mostarda, creme e tinta), e nenhuma é a cor principal de um partido grande. Não há vermelho nem azul puros, não há verde com amarelo e não há estrela, número, bandeira, brasão, mão ou texto. Os pares de cor aparecem espelhados: teal e ameixa na íris, em metades iguais.

**Rodadas (versões recusadas e por quê):**

1. **Primeira versão:** a Lupa era correta, mas genérica. Na Urna, a caixa chapada com o cartão em pé parecia uma impressora soltando recibo em 58 px. No Documento, o "F" com a barra do meio virando cabo de lupa parecia uma chave.
2. **Segunda versão:** a Urna ganhou a caixa de vidro e a cédula inclinada e passou a ler como urna, mas a fenda sumia, sobretudo no modo tingido. No Documento, a "barra ampliada" dentro da lente ficou parecendo "Fo".
3. **Terceira versão:** a Urna trocou a fenda por uma tampa maciça, e a cédula passa por trás dela. O Documento virou uma página com o F em linhas e um selo. Na Lupa, o check mostarda sobre teal podia ser lido como verde e amarelo, então o check passou a creme e ficou maior.
4. **Acabamento:** a caixa da Urna ficou mais opaca e a tampa mais alta, e a pupila do Olhar cresceu de 68 para 76.

Falta a etapa que decide: instalar os quatro como alternativos no iPhone e escolher vendo na tela de início ("agora sim").

## Não visto

- **Apple Invites:** a prévia do ícone não carregou na página da App Store e o ícone ficou de fora da comparação.
- **Pardal e e-Título (TSE):** a busca da App Store americana não achou as páginas. Para a leitura da categoria, os dois contraexemplos acima bastam.
