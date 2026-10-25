# Gráficos de Temas na aba Fiscalizar

- **Data:** 2026-10-25
- **Tela:** Fiscalizar › Temas (`FeatureSearch/ThemesSection.swift`, `ThemeCharts.swift`)

## Crítica da versão anterior

- Não era gráfico: era uma nuvem de chips (`Label` dentro de `FlowLayout`). No iOS 27, o `Label` dentro de uma linha de `List` mede errado com `sizeThatFits(.unspecified)` e cada chip virava uma cápsula alta, sem texto, que parecia um gráfico de barras quebrado (`charts/antes.png`). O mesmo defeito aparecia nas cápsulas de turno em Eleições.
- Nenhum número: o tema não dizia quantas votações teve nem quando.

## Referências

| Referência | O que pegar |
|---|---|
| Apple Health, Destaques e tendências | Frase factual acima do gráfico ("Economia e emprego teve mais votações"); toque mostra o valor num balão que cobre o título. |
| Screen Time (Mais usados) | Lista de categorias com símbolo, nome, valor e uma barra horizontal proporcional, cada linha tocável. |
| Stocks | Linha de seleção (`RuleMark`) que acompanha o dedo, e o valor no topo do gráfico. |
| Weather, gráficos de hora em hora | Barras curtas por período, eixo enxuto com poucos rótulos, média como referência. |
| Fitness, tendências | Cor própria por categoria, mantida entre telas; entrada animada das barras. |
| WWDC22 "Hello Swift Charts" e "Swift Charts: Raise the bar" | `BarMark` com `xStart`/`xEnd`, `foregroundStyle` com `.gradient`, `RuleMark` de média, rótulos e acessibilidade por marca. |
| WWDC23 "Explore pie charts and interactivity in Swift Charts" | `chartXSelection`, `RuleMark` com `annotation(overflowResolution:)` como balão, `chartScrollableAxes` + `chartXVisibleDomain` + `chartScrollPosition` para série longa. |
| WWDC22 "Design app experiences with charts" | Título que explica o gráfico, poucos rótulos de eixo, cor com significado e não decoração. |

Não entrou: `SectorMark` em rosca (a constituição proíbe anéis e progresso circular; o manual de referências também recusa rosca de categorias). WWDC24 (vectorized/function plots) e WWDC25 (gráficos 3D) não servem a estes dados.

## Gráficos

1. **Votações por tema** (barras horizontais): uma linha por tema da Lente (ou os 6 padrão), ordenada por contagem e, no empate, pela ordem dos temas. Rótulo com símbolo, nome, contagem e "Aprovadas: N" quando nem todas foram aprovadas. Toque leva ao filtro do tema, como antes, com háptico leve. Cada linha é um `Button` (VoiceOver ativa direto) com um `Chart` de `BarMark` no mesmo domínio; entrada em cascata de 40 ms, desligada com Reduzir movimento.
2. **Votações nestes temas por dia/semana** (barras verticais): por dia quando o período tem menos de 14 dias, por semana acima disso; dias sem votação aparecem como zero. `RuleMark` tracejado com a média (explicada no subtítulo), `chartXSelection` com linha de seleção, balão (data, "Votações: N" e os símbolos dos temas daquele período nas cores deles) e háptico de seleção. Rola na horizontal acima de 12 períodos, abrindo nos mais recentes.

## Cor

Paleta categórica nova em `FiscalDesignSystem/Charts/ChartPalette.swift`, das famílias retrô (petróleo, laranja, roxo, mostarda, ameixa, jeans) com croma suficiente para gráfico. A cor segue o tema pela posição na lista da Lente, nunca pela ordem do ranking. Validada com o validador da skill dataviz (adjacente, claro em `#FFFFFF` e escuro em `#1C1C1E`): passa faixa de luminosidade, croma ≥ 0,10, CVD (pior 10,8 claro / 8,2 escuro), visão normal (pior 16,7 / 16,2) e contraste ≥ 3:1.

| Slot | Claro | Escuro |
|---|---|---|
| 1 | `#008B9A` | `#0191A0` |
| 2 | `#B06436` | `#B86838` |
| 3 | `#7C58A3` | `#9976C1` |
| 4 | `#AA8B2E` | `#A0832A` |
| 5 | `#9B4A6C` | `#BF6A8D` |
| 6 | `#4665AE` | `#607EC2` |

Nenhuma é cor de partido nem de voto, mas a distância mínima (ΔE OKLab×100) para o `PartyPalette` fica entre 4 e 7 (jeans perto de PSDB/Republicanos, petróleo perto de Rede): com 20 partidos ocupando o círculo de matiz não há como ir além sem cair abaixo do croma mínimo. O gráfico de cadência usa `Color.info` (jeans), como `MonthlyBarsChart`.

## Dado que falta

- `votes/recent.json` traz só as 60 últimas votações do Plenário. Para uma tendência de verdade por tema (meses, ano) falta uma série histórica agregada por tema e por casa (ex.: `votes/themes-<ano>.json` com contagem semanal por tema, aprovadas/rejeitadas e Câmara/Senado).
- O cenário de teste `normal` tem só 6 votações em 3 dias, por isso as barras em `charts/` são curtas.

## Capturas

`charts/antes.png`, `charts/depois-claro.png`, `charts/depois-escuro.png`, `charts/depois-selecao.png`, `charts/depois-vazio.png`, `charts/depois-offline.png`, `charts/depois-acessibilidade.png` (as capturas "depois" foram feitas antes das strings irem para o catálogo, por isso parte do texto aparece em inglês, e, salvo a de acessibilidade, antes da troca para uma linha `Button` por tema, que mantém o mesmo visual).
