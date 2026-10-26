# Referências visuais do Fiscal (app 1.0)

- **Data:** 2026-10-25
- **Para:** o agente que vai desenhar cada tela
- **Método:** capturas oficiais da App Store (URLs `mzstatic` abaixo, abertas e vistas no navegador), páginas da HIG (Widgets, Charting data) e Dribbble. Sem login, sem formulários.
- **Escopo:** o app é **gratuito**. Nenhuma referência de paywall, Pro ou assinatura entra aqui.

> **Nota de fonte.** O pedido mandava ler as seções "Ciclo de design por seção" e "Referência visual" de `byescaleira-sdd/references/design-principles.md`, mas elas **não existem** nesse arquivo (versão de hoje: §1 Hierarquia, §2 Direção, §3 Rejeitados, §4 Método, §5 Regras de view, Checklist). Este documento segue o que existe: §4.2 ("pesquise referência de **estrutura**, nunca de identidade") e a lista de rejeitados da §3.

---

## 0. Regras que valem para todas as telas

Estas regras vêm do brief, do contrato e do manual. Nenhuma referência abaixo passa por cima delas.

1. **Estrutura nativa.** `List`/`AdaptiveList`/`Form`, `TabView` com Liquid Glass só nos controles, SF Pro com `.fontDesign(.rounded)` na raiz da tela, SF Symbols. As referências mudam a **composição**, não a identidade.
2. **Cor tem três donos, sem mistura:**
   - **Partido:** `PartyPalette`. Aparece só na identidade do político ou do partido: listra de 4 pt, ponto de 8 pt, chip da sigla, barra do partido.
   - **Dado:** Sim, Não, Abstenção e Ausente, sempre com símbolo e texto. Proposta: oliva + `checkmark`, ferrugem + `xmark`, mostarda + `minus`, `.tertiary` tracejado + `circle.dashed`.
   - **Lente/aparência da pessoa:** `appTint`. Só em chips de tema, botões e realces de navegação, nunca em gráfico, placar ou lista de políticos.
   - **Verificar:** que nenhuma cor de dado fique perto demais (ΔE) das cores dos partidos grandes no `PartyPalette`, porque vermelho e verde são disputados. O símbolo resolve a acessibilidade, mas não resolve a confusão visual.
3. **Fonte e data em cada bloco.** Linha `caption` `.secondary` no rodapé da seção, por exemplo "Fonte: Câmara dos Deputados · atualizado 25/10, 06:00". Quando falta o dado, mostrar "—", nunca 0.
4. **Sem ranking, nota ou adjetivo.** A ordem é por voto (apuração), tamanho da bancada (placar) ou alfabética. Nunca "mais faltoso", "top gastadores" ou "fidelidade".
5. **Herói do manual.** Chip do período em caixa alta, depois o número em `.amountHero` com `.contentTransition(.numericText())`, depois uma legenda `.subheadline`. Um número aparece uma vez por tela.
6. **Barras, nunca anéis.** `ProgressBar` (`Gauge` `.linearCapacity`) e `SegmentedBar`, preenchendo com `.smooth(duration: 1)` ao abrir.
7. **Arte de artista** só onde o brief pede: setup da Lente, cards de compartilhar, galeria de artistas e prévia das coleções em Aparência. Sempre com nome, @ e licença visíveis. Não entra nas listas nem nos gráficos (o manual rejeita ilustração estática na interface; a arte com crédito é a exceção do brief e fica nessas quatro superfícies).
8. **Sem logotipo de partido nem brasão.** O partido é a sigla em texto sobre a cor dele.

---

## 1. Hoje (resumo do dia)

### Referências

| App | O que vi | Captura |
|---|---|---|
| **Apple Health** (Resumo) | Grade de cartões fixados. Cada um tem rótulo colorido + símbolo no canto superior esquerdo, hora e `›` no direito, valor grande (~28 pt) + unidade pequena à esquerda e minigráfico à direita. Abaixo, "Highlights": uma frase em linguagem simples sobre um gráfico ("Last night, you went to bed 31 minutes earlier…"). | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/3b/ce/bd/3bcebd6c-f9d0-3026-d357-340765e3896c/Health_1.png/600x1300bb.jpg · https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/ff/99/e2/ff99e220-f400-337f-10b8-098e4a67e1b4/Health_2.png/600x1300bb.jpg |
| **Apple News** (Today/Esportes) | Título grande com a data embaixo. Faixa horizontal de placares no topo da seção (sigla, número e "FINAL"). Toda manchete leva o logotipo do veículo **acima** do título. Rodapé "Selected by the Apple News editors". | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/66/f8/f1/66f8f192-3d64-3e3c-1ae1-8cdb1888cabe/iPhone6p9-LuckD-USEN-News-Wrapper4.png/600x1300bb.jpg |
| **Flighty** (alertas) | Notificações densas e factuais numa linha: rota, hora, portão, "22m early". Sem adjetivo, só o fato e o quanto mudou. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/c0/50/32/c05032e5-e829-1101-f85a-c04d69f1f3b0/Flight_Alerts.png/600x1300bb.jpg |

**Por que marcam:** o Health resolve o "muita coisa, pouco espaço" com o mesmo molde de cartão para dados diferentes. O News deixa a fonte visível sem pesar. O Flighty fala só o fato.

### Direção

- **Topo:** `navigationTitle("Hoje")` large. Logo abaixo, `.subheadline` `.secondary` com a data por extenso ("sábado, 25 de outubro"). Botão de Ajustes/Lente na toolbar (`slider.horizontal.3`, sem `.fill`).
- **Evento ao vivo** (só quando existe): primeira seção, uma linha alta (~88 pt) que espelha a Live Activity. Chip "AO VIVO" ferrugem, título da votação, placar SIM × NÃO em `.title` bold rounded com `numericText` e "faltam 41 para 308" em `.caption`. Toque abre o detalhe.
- **"Nos seus temas":** linhas no molde Health. Chip do tema na `appTint` com símbolo do tema (rótulo `caption` bold caixa alta), hora à direita. Título da votação em `.headline` (até 2 linhas) e mini `SegmentedBar` de 6 pt com Sim/Não/Abst. Um "o que muda para você" de 1 linha em `.subheadline` `.secondary`. No máximo 5, depois "Ver todas".
- **"Seus representantes votaram":** linha com foto oficial de 36 pt (borda de 2 pt na cor do partido), nome, chip da sigla, e à direita o chip do voto (símbolo + "Sim"). Uma linha por pessoa, nada de grade.
- **Destaque em frase** (padrão Health Highlights): um bloco por dia com uma frase factual gerada do dado ("A Câmara votou 3 projetos de Saúde nesta semana; seus 2 deputados estiveram em todas") e um gráfico pequeno de 80 pt de altura. Botão "Outra lente" `.borderless` no rodapé.
- **Fonte:** cada seção fecha com o `footer:` de fonte e hora da carga.

### Não fazer

- Feed infinito de cartões grandes com foto: o Fiscal é resumo, não jornal.
- Manchete com adjetivo ("polêmica", "derrota do governo").
- Cartão colorido inteiro na cor da paleta da pessoa; a cor vai só no chip do tema.
- Repetir o placar do card ao vivo numa linha da seção de temas.

---

## 2. Meus (meus representantes por lugar)

### Referências

| App | O que vi | Captura |
|---|---|---|
| **Apple Weather** (lista de locais) | Cada local é um cartão: nome do lugar em `.title3` bold, subtítulo pequeno ("My Location") e o número grande fino (~44 pt light) alinhado à direita. A lista inteira dá para ler pela coluna de números. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/c5/0f/4e/c50f4e8c-bd95-e763-3fea-6ba8afcdc737/iPhone-List-1320x2868.png/600x1300bb.jpg |
| **Apple Weather** (local) | "MY LOCATION" em caixa alta pequena, cidade, número gigante e a linha de resumo, depois as seções. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/cc/32/f3/cc32f3d4-1dc8-16c4-e806-92e515fe2b77/iPhone-Location-1320x2868.png/600x1300bb.jpg |
| **Apple News** (local) | Seção local com o nome da cidade em título grande sobre fundo levemente tingido, abrindo o conteúdo daquele lugar. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/38/e7/4f/38e74f43-48f0-3fa4-4061-7987822725b6/iPhone6p9-LuckD-USEN-News-Wrapper5.png/600x1300bb.jpg |

**Por que marcam:** o lugar organiza tudo, e o número à direita deixa comparar níveis sem ler tudo.

### Direção

- **Herói do lugar:** chip "SEU ENDEREÇO" em caixa alta, "Campo Grande · MS" em `.largeTitle` bold rounded e legenda "27 representantes, do vereador ao presidente". O botão "Trocar" fica na toolbar (`mappin.and.ellipse`).
- **Uma seção por nível,** na ordem Cidade › Estado › Brasil. O cabeçalho da seção é o cargo no plural ("Vereadores · 29"). A contagem fica no cabeçalho, não num herói repetido.
- **Linha do representante:** foto oficial de 44 pt (círculo com borda de 2 pt na cor do partido), nome `.headline`, "PSD · Deputada federal" `.subheadline` `.secondary`. À direita, um único número de presença em `.title3` semibold rounded ("94%"), no lugar da temperatura do Weather, com "—" se não houver dado.
- **Ordem:** alfabética dentro do cargo. Para executivo com um só ocupante (prefeito, governador, presidente), uma linha mais alta de 72 pt com foto de 56 pt.
- **"Quem você segue":** seção final com a mesma linha. O estado vazio mostra 2 linhas de exemplo e o botão "Seguir alguém" (`primaryButton()`).
- **iPad:** `AdaptiveList` em colunas, um nível por coluna.

### Não fazer

- Mapa como tela principal. Endereço e lista resolvem e o mapa vira decoração.
- Ordenar por presença ou gasto: isso é ranking.
- Fundo da tela tingido com a cor da paleta ou com a bandeira do estado (brasão e bandeira não entram).

---

## 3. Perfil do político

### Referências

| App | O que vi | Captura |
|---|---|---|
| **Apple Stocks** (detalhe) | Nome curto enorme (SBUX ~34 pt heavy) com o nome completo ao lado em `.secondary`, depois o valor e a variação. Gráfico com seletor de período (1D 1W 1M 3M 6M YTD 1Y). Grade 3×3 de estatísticas pequenas. **Fonte explícita no fim:** "More Data from Yahoo Finance". | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/b9/e7/cb/b9e7cb28-de9e-d11d-1c10-c3c6ad7b3796/Stocks_iPhone_2_Alt.png/600x1300bb.jpg |
| **Ground News** (ADA Social Impact) | Manchete condensada gigante e, abaixo, 2×2 de blocos de metadado (Coverage, Bias, Factuality, Ownership), cada um com rótulo minúsculo, valor curto e um glifo. Depois "Full Analysis →". | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/03/3d/e8/033de860-b3b2-808a-d4cb-d533703a44ce/6.9_screen_one.png/600x1300bb.jpg |
| **Apple Health** (destaques) | Frase-resumo em cima de cada gráfico, com o valor-chave em cor. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/7c/f9/22/7cf922b8-51ec-f3ec-dcf6-83a780ef85d0/Health_3.png/600x1300bb.jpg |
| **Dribbble · Nixtio, "Football Player Profile"** (contraexemplo) | Nome gigante em vermelho atrás da foto recortada, citação em caixa alta. Parece cartaz de campanha. | https://dribbble.com/shots/26907788-Sports-Mobile-App-Design-Football-Player-Profile |

### Direção

- **Cabeçalho:** foto oficial de 88 pt (círculo, borda de 3 pt na cor do partido), nome parlamentar em `.title` bold rounded e linha "PL · SP · Deputado federal desde 2023" em `.subheadline`. Chip da sigla na cor do partido (fundo a 20%). Botões "Seguir" (`primaryButton()`) e Compartilhar (`square.and.arrow.up`) na toolbar.
- **Grade 2×2 no molde Ground News,** ~76 pt de altura por bloco, `.groupedRow`: Presença "94%" com barra de 4 pt, Votos em 2026 "312", Cota usada "R$ 412 mil", Patrimônio declarado "R$ 1,2 mi". Cada bloco tem rótulo `caption` caixa alta `.secondary` e, embaixo, a fonte em `caption2` ("Câmara", "TSE 2022"). Sem nota nem selo.
- **"Nos seus temas":** padrão Health, com frase factual ("Nos seus 4 temas, votou Sim em 12 e Não em 7 de 21 votações") e uma `SegmentedBar` de 8 pt. O botão "Outra lente" mostra o mesmo bloco pelos temas do outro público.
- **Votos recentes:** linha com data (`caption`, 44 pt de largura fixa), título curto da votação e chip do voto à direita (símbolo + texto, cor de dado).
- **Gastos:** gráfico de barras mensal (Swift Charts, 160 pt de altura) com seletor de período segmentado ("12 meses · 2025 · 2024") à moda Stocks. Barras em cor neutra `.primary` a 70%; o mês selecionado fica na cor de destaque do **dado**, não da paleta.
- **Rodapé da tela:** "Dados: Câmara dos Deputados, TSE · carga de 25/10/2026" e "Ver no site oficial ›".

### Não fazer

- Foto recortada gigante com o nome atrás (cartaz de campanha).
- "Nota", estrelas, termômetro, "fidelidade ao partido" em %, "índice de…".
- Fundo com degradê na cor do partido ocupando a tela: a cor fica na borda, no chip e na listra.
- Citação do político em destaque, que vira propaganda.

---

## 4. Votações (lista, pauta, detalhe com placar por partido)

### Referências

| App | O que vi | Captura |
|---|---|---|
| **Apple Sports** (lista) | Linhas de placar: números **condensados** grandes (~32 pt bold) colados aos dois lados, o estado do jogo no centro em `.caption`, a liga em `caption2` acima. Seletor Ontem / Hoje / Próximos no topo. Um brilho sutil na cor do time atrás do vencedor. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/bc/93/78/bc9378cf-f321-0649-e2b8-b079a8e008ba/Sports-iPhone6p9-iOS26-USEN-Wrapper2.png/600x1300bb.jpg |
| **Apple Sports** (detalhe) | Herói com placar 10 × 27 (~64 pt condensado). Fundo dividido na diagonal com as cores dos dois times. Tabela por período. "Team Stats" como **barras espelhadas a partir do centro**: rótulo centralizado, valores nas pontas e cada lado na cor do seu time. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/79/c7/23/79c72328-d9e5-5200-9bd5-daf7c09bd1bc/Sports-iPhone6p9-iOS26-USEN-Wrapper3.png/600x1300bb.jpg |
| **Things 3** (Upcoming) | Pauta por dia com o **número do dia grande** (~28 pt bold) + "Tomorrow"/"Thursday", itens embaixo e eventos do calendário em `.caption` colorido. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/73/4e/12/734e12cf-9248-3347-bb9f-e11d98da3bfe/iPhone_14_Pro_Max_-_3.png/600x1300bb.jpg |
| **Structured** | Faixa da semana no topo com pontinhos coloridos por dia e linha do tempo vertical com cápsulas por horário. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/84/da/9b/84da9bd8-1c70-1f39-a5be-21d964f842e8/6.9_baseline_1.jpg/600x1300bb.jpg |
| **Sky Guide** (Calendar) | Lista de eventos com data em caixa alta pequena, título e uma miniatura à direita. | https://apps.apple.com/us/app/sky-guide/id576588894 |

### Direção

- **Lista (Recentes):** `Picker` segmentado "Recentes · Pauta". Linha de votação com o tema em `caption2` caixa alta, título em `.headline` (2 linhas) e placar "SIM **312** · NÃO **141**" em `.title3` bold rounded com `monospacedDigit()`. Uma `SegmentedBar` de 6 pt embaixo. Chip "Aprovada"/"Rejeitada" com símbolo (`checkmark.seal`/`xmark.seal`) em cor de dado.
- **Pauta:** agrupada por dia no molde Things, com o cabeçalho da seção como dia grande ("**28** terça") em `.title2` bold e o mês em `.secondary`. Faixa de 7 dias no topo (Structured) com um ponto de 6 pt nos dias com sessão e o dia de hoje na `appTint`. O item mostra hora, casa (Câmara/Senado) e título.
- **Detalhe, herói:** chip "PLENÁRIO · CÂMARA · 28/10", placar SIM × NÃO em `.amountHero` lado a lado com rótulos `caption` em cima e linha "faltam 41 para 308 (PEC)" ou "maioria simples atingida" em `.subheadline`. É o "272 needed for majority" da Live Activity de eleição vista no Dribbble. O fundo é **neutro** (`.groupedBackground`), sem diagonal de cores, porque os lados são Sim/Não, não partidos.
- **Placar por partido** (adaptação das "Team Stats"): uma linha por partido, ordenada **pelo tamanho da bancada**. Listra de 4 pt e sigla na cor do partido à esquerda, depois uma barra empilhada de 10 pt (Sim | Não | Abst | Ausente, cores de dado). Contagens em `.caption` `monospacedDigit()` à direita ("38 · 4 · 0 · 2"). O toque expande a lista nominal.
- **"O que muda para você":** 3 linhas em `.body` marcadas "Resumo do aparelho" (`apple.intelligence` + `caption`). "Texto oficial" em `DisclosureGroup` logo abaixo, mais "Outra lente". O placar por estado vem depois, como lista ou mapa opcional.
- **Movimento:** o placar entra com `numericText`, e as barras dos partidos preenchem em cascata (40 ms por linha). Tudo desligado com Reduzir movimento.

### Não fazer

- Fundo dividido em cores de partido no herói da votação.
- Ordenar partidos por "quem mais votou Sim" ou por "fidelidade".
- Logotipo de partido (a Live Activity do Dribbble usa logos, e aqui é proibido).
- Hemiciclo de assentos como gráfico principal: é bonito mas ilegível no iPhone e no VoiceOver. No máximo, como extra no iPad.

---

## 5. Dinheiro (gastos e salários com gráficos)

### Referências

| App | O que vi | Captura |
|---|---|---|
| **Copilot Money** (finalista ADA) | Herói "$15,566.93" e comparação "vs $13,512 in Jan 1–Sep 12, 2024" com chip "↗ 22%". Barras mensais com o negativo em vermelho abaixo do zero. Orçamentos como **barras horizontais cheias por categoria**, com emoji e cor, e variação à direita. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/a7/8e/d8/a78ed888-7ddf-8502-b78c-2dbfbef8407e/4.2.jpg/600x1300bb.jpg · https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/8f/11/2a/8f112af7-7012-6c45-722d-94fbf8721f21/4.4.jpg/600x1300bb.jpg |
| **Gentler Streak** (ADA) | "Monthly insights": número grande com seta ("↑ 290.84 mi") e lista de barras horizontais coloridas por atividade embaixo. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/83/c8/5e/83c85e09-5e04-03ea-1408-84c952cde27d/Valera_English_iPhone9.png/600x1300bb.jpg |
| **Strava** (Progress) | Duas séries, atual × período anterior ("Prior 3 months"), com os totais grandes acima. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/33/f2/f4/33f2f44f-ad26-898c-884e-749588d44d2a/16ASO-5.5-ProgressComparison-en-US.jpg/600x1300bb.jpg |
| **HIG, Charting data** | "Aid comprehension by adding descriptive text" (manchete-resumo acima do gráfico); manter o mesmo tipo e as mesmas cores entre gráficos do mesmo dado. | https://developer.apple.com/design/human-interface-guidelines/charting-data |

### Direção

- **Herói da aba:** chip "COTA PARLAMENTAR · 2026", "R$ 186,4 mi" em `.amountHero` e legenda "gastos pelos 513 deputados até 25/10". `Picker` segmentado: "Cota · Salários · Emendas · Campanha · Patrimônio".
- **Manchete do gráfico** (HIG): uma frase factual em `.headline` acima de cada gráfico ("Outubro teve o maior gasto do ano: R$ 22,1 mi"). Barras mensais de 180 pt de altura, neutras, com o mês corrente na cor de dado e uma linha tracejada para a média.
- **Por categoria:** lista no molde Copilot com símbolo + nome ("Passagens aéreas"), `ProgressBar` de 8 pt proporcional ao total e valor à direita em `.body` semibold `monospacedDigit()`. A ordem é por **valor da categoria** (é dado agregado, não pessoa), sem nomes de políticos.
- **Comparação com o período anterior** (Strava/Copilot): "vs R$ 171,0 mi no mesmo período de 2025" com chip "↗ 9%". Esconder o percentual quando a base não existe (regra do manual).
- **Salários e benefícios:** tabela simples (`LabeledContent`) com "Subsídio mensal R$ 46.366,19", auxílio-moradia, verba de gabinete. Cada linha tem `caption` com a lei ou o ato e a data.
- **Fornecedores (CNPJ):** lista com CNPJ formatado em `caption` `monospaced`, valor e "ver na Receita ›". Sem "suspeito" nem alerta automático.

### Não fazer

- "Top 10 deputados que mais gastaram": é ranking, e a lista de pessoas não é ordenada por gasto.
- Vermelho para "gasto alto": gasto não é erro. Cor de dado só para Sim/Não/Abst/Ausente; o resto é neutro.
- Rosca/anel de categorias (o Copilot usa anel nos widgets; aqui não).
- Gráfico sem manchete e sem fonte.

---

## 6. Fiscalizar (busca, comparar, eleições)

### Referências

| App | O que vi | Captura |
|---|---|---|
| **Ground News** (Perspectives) | **Dois cartões empilhados**, "US right-leaning outlets" e "Left-leaning…", cada um com manchete e citação. A ponte entre lados sem dizer qual está certo. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/25/b4/d2/25b4d21f-dbd4-84e3-21d1-4f51723435b0/6.9_screen_seven.png/600x1300bb.jpg |
| **Ground News** (Collections) | Coleções em cartões largos com ícone gráfico ("Popular with the Left", "Popular with the Right", "You Might Have Missed"). | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/09/cf/0e/09cf0eff-19c6-2b07-52c4-62ef0a34f9d3/6.9_screen_three.png/600x1300bb.jpg |
| **Apple Sports** (Team Stats) | Barras espelhadas a partir do centro, cada lado na cor do seu time. Modelo exato para **Comparar** dois políticos com a cor do partido de cada um. | (captura Wrapper3 acima) |
| **Dribbble · Can Tekgül, "DHA 2024 Turkish Local Elections"** | Cartão por cidade: "Açılan Sandık %99.31" (urnas apuradas), candidatos em linhas cujo **fundo é a própria barra** (preenchido até o % na cor do partido a ~20%), listra sólida de 4 pt, foto, %, votos e ✓ no eleito. | https://dribbble.com/shots/25269569-DHA-2024-Turkish-Local-Elections |
| **Dribbble · Om Patel, "Election Result iOS Live Activity"** | Live Activity com "Seats 287/543", contagem por partido e rodapé "272 needed for majority · Updated: 1 min ago". | https://dribbble.com/shots/24246062-Election-Result-iOS-Live-Activity |

### Direção

- **Busca** (`Tab(role: .search)`): o estado vazio mostra 3 atalhos em grade de 2 colunas, como cartões `.groupedRow` de 64 pt com símbolo ("Comparar", "Eleições", "CNPJ de fornecedor"), mais "Buscas recentes" (só no aparelho). Os resultados são agrupados por tipo (Pessoas, Partidos, Projetos, Cidades, Fornecedores) com a linha padrão de cada tipo.
- **Comparar 2 a 3 políticos:** cabeçalho com as fotos de 56 pt lado a lado, cada uma com borda na cor do partido. Linhas de métrica no molde Team Stats: rótulo centralizado em `caption` `.secondary`, valores nas pontas em `.title3` bold `monospacedDigit()` e barras espelhadas de 6 pt, **cada lado na cor do partido do político**. Se dois forem do mesmo partido, diferenciar por padrão (sólido × listrado) e pela posição.
- **Votações em comum:** lista com o título e os dois chips de voto lado a lado, sem "concordância %" como nota.
- **Eleições, apuração** (molde DHA): cartão por disputa com "Urnas apuradas 99,31%" e `ProgressBar` de 4 pt. Linha do candidato com **o fundo preenchido até o % na cor do partido a 20%**, listra sólida de 4 pt, foto de 36 pt, nome, sigla, % em `.title3` bold e votos em `.caption`. Ordem por votos, ✓ só depois do resultado oficial. "Atualizado há 1 min · TSE" no rodapé.
- **"Outra lente"** (molde Perspectives): folha com dois blocos empilhados, "Pelos temas que você escolheu" e "Pelos temas do outro público". Mesmo fato e mesmo número, só muda a ordem dos temas e o destaque. Rótulos neutros, sem "esquerda/direita" no título do bloco.

### Não fazer

- Rótulos de viés ou "factualidade" (o Ground News avalia veículos; o Fiscal não avalia ninguém).
- Coleções "Popular com a esquerda/direita".
- Projeção, pesquisa, "chance de vencer" ou enquete (lei eleitoral).
- Comparar com "vencedor" destacado em cor.

---

## 7. Setup inicial da Lente (3 passos com arte)

### Referências

| App | O que vi | Captura |
|---|---|---|
| **Duolingo** (ADA) | Barra de progresso fina no topo (`ProgressBar` verde, ~8 pt), pergunta curta, **grade 2×2 de cartões grandes com imagem** e CTA largo no rodapé. A seleção marca a borda e o fundo do cartão. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/cb/ee/31/cbee31c9-a814-b59b-db16-3136ce60d20d/V2_iOS6.5_02.jpg/600x1300bb.jpg |
| **Gentler Streak** (ADA) | Página de privacidade com personagem ilustrado ao centro e texto direto: "Processed on-device. No user accounts. No servers. Not used by AI models." | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/da/9b/da/da9bda15-7df7-b905-8e8a-2bac80a405f8/Valera_English_iPhone10.png/600x1300bb.jpg |
| **Apple Invites** (boas-vindas) | Carrossel de **pôsteres inclinados** (arte cheia, título sobre a arte) atrás de "Welcome to Apple Invites", com um botão branco em cápsula. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/89/65/3a/89653a24-5876-f88d-a1c9-1fe67c32aa89/Onboarding.png/600x1300bb.jpg |

### Direção

- **Abertura (antes do passo 1):** carrossel lento (~20 s por volta, parado com Reduzir movimento) de 5 a 7 obras das coleções de artistas, como pôsteres de ~200×280 pt com raio de 24 pt e leve rotação (±4°). Crédito "Obra: Nome · @artista" em `caption2` sobre cada pôster. Título "O que seus representantes fazem com o seu voto", subtítulo "Os mesmos fatos para todo mundo, na ordem que importa para você" e `primaryButton()` "Começar · 1 min".
- **Passo 1, "O que mais importa para você?"** (molde Duolingo): `ProgressBar` de 3 segmentos no topo e grade dos 12 temas em **3 colunas** de cartões quadrados (~104 pt) com SF Symbol de 28 pt e nome em `.subheadline` semibold. Selecionado = fundo `appTint` a 20% + borda de 2 pt + `checkmark.circle.fill` no canto. Contador "3 de 5" e botão desabilitado até 3.
- **Passo 2, "Como você se vê na política?":** "Prefiro não dizer" **primeiro**, como botão largo de destaque. Embaixo, a escala de 5 pontos em `Picker` segmentado neutro (sem cores de lado). Rodapé com cadeado: "Fica só neste aparelho. Não vai para nenhum servidor." (molde Gentler Streak), com ilustração de artista acima, creditada.
- **Passo 3, "Escolha sua arte":** grade de 2 colunas de coleções. Cada cartão mostra a **prévia real** de um card de compartilhar com aquela arte e aquela paleta, mais o nome da coleção e do artista. Paletas em pares espelhados, lado a lado. Botão "Pronto".
- **Lottie × arte:** o manual usa `GuideSheet` + Lottie nos guias. Proposta: Lottie só no microfeedback (selo de "pronto"); a arte de artista é o elemento visual do setup. **Registrar como decisão** em `docs/decisions.md`.

### Não fazer

- Paywall, "teste grátis", tabela Grátis × Pro (o app é gratuito).
- Escala esquerda/direita colorida em vermelho/azul ou verde/amarelo.
- Pré-selecionar temas a partir do posicionamento sem mostrar e deixar editar.
- Símbolo SF grande como "arte" de página (rejeitado no manual).
- Mais de ~3 linhas de texto por passo.

---

## 8. Cards de compartilhar (Stories 9:16, feed 4:5, mensagem 1:1)

### Referências

| App | O que vi | Captura |
|---|---|---|
| **Flighty** (Passport) | O resumo do ano vira um **objeto**, um passaporte com mapa, números grandes (86 voos, 293.931 mi) e uma **faixa tipo MRZ** (texto monoespaçado de máquina) no rodapé que passa autenticidade. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/bd/25/56/bd25568f-4f9d-edc7-13cf-aabfd2780175/Annual_Stats.png/600x1300bb.jpg |
| **Partiful** | Galeria de pôsteres de estilos variados. Folha "Share Link" com a **prévia do pôster** + alvos (Copy Link, Messages, WhatsApp, More). | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/6e/f1/af/6ef1afb4-e0cc-7967-b7f5-23132b514a4c/3.png/600x1300bb.jpg · https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/60/6a/b0/606ab02c-36e4-7d89-d3d1-15ab4ed7579b/2.png/600x1300bb.jpg |
| **Apple Invites** (evento) | Arte em sangria total no topo. Título grande (~34 pt bold) **sobre a arte** no terço inferior, data e local embaixo. O fundo continua a arte desfocada. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/28/e9/0d/28e90d0c-a157-c291-0593-eb2577aa40f0/Event_View.png/600x1300bb.jpg |

### Direção

- **Stories 1080×1920:** arte do artista em sangria nos 55% de cima, com a arte desfocada continuando atrás do bloco de dados (molde Invites). O bloco de dados é um cartão branco ou preto a 92% com raio de 40 pt.
- **Bloco de dados** (exemplo "Como votou"): foto de 120 px com borda na cor do partido, nome em 56 px bold rounded, "PL · SP" e a votação em 40 px. O voto vem como **chip enorme** (símbolo + "SIM", 72 px, cor de dado) e o placar geral em uma linha.
- **Faixa de autenticidade** (molde Flighty MRZ): rodapé em SF Mono 22 px `.secondary`, por exemplo `CAMARA·VOT·2389117·28OUT2026·FONTE camara.leg.br`, mais o QR de 160 px para o perfil no app e "Fiscal" em texto, sem brasão.
- **Crédito da arte** sempre visível no canto superior: "Arte: Nome · @artista · CC BY 4.0" em 24 px sobre uma faixa escura a 40%.
- **Folha de compartilhar** (molde Partiful): prévia real do card em ~60% da altura, seletor de formato "Stories · Feed · Mensagem", trocador de coleção de arte em fileira de miniaturas de 56 pt e `ShareLink` como ação principal.
- **Tipos:** voto, gasto, placar, apuração, comparação e "meus representantes". Mesmo layout de bloco em todos e mesma faixa de fonte; só o miolo muda.

### Não fazer

- Adjetivo ou frase de efeito no card ("traiu", "votou contra você").
- Card sem fonte e data, ou com o crédito do artista escondido ou pequeno demais para ler no Stories.
- Logotipo de partido, bandeira recolorida, brasão.
- Cor do card mudando a cor do partido ou do dado (a arte e a paleta vestem o fundo, nunca o dado).

---

## 9. Widgets (e Live Activity)

### Referências

| App | O que vi | Captura |
|---|---|---|
| **Apple Sports** (tela bloqueada) | Live Activities empilhadas, cada uma com fundo na cor do jogo, placar condensado grande, tempo e **uma linha de narração** ("P. Mahomes throws for 11 yards…"). | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/61/4c/b2/614cb216-6406-2f02-30a9-427f668fba97/Sports-iPhone6p9-iOS26-USEN-Wrapper1.png/600x1300bb.jpg |
| **Flighty** (Live Activity) | Origem e destino nas pontas com horários grandes, status em verde ("On Time", "5m Early"), barra de progresso da viagem e contagem regressiva grande no centro ("1h 20m UNTIL GATE ARRIVAL"). | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/3e/51/40/3e51405d-3ab8-70f6-a560-a981bfe6da9a/Live_Activities.png/600x1300bb.jpg |
| **Things 3** (widgets) | Widget de lista curta (3 itens com checkbox) e widget de bloqueio de uma linha. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/8a/ea/c6/8aeac693-bc8a-483c-71cb-d5ee7fc8d329/iPhone_14_Pro_Max_-_8.png/600x1300bb.jpg |
| **Copilot** (widgets) | Widget pequeno com um rótulo, um número grande e uma variação. | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/34/88/1e/34881e58-56bc-56f1-73b7-77b21f1f140e/4.6.jpg/600x1300bb.jpg |
| **HIG, Widgets** | Margem padrão de 16 pt (11 pt para agrupamentos), texto ≥ 11 pt, não depender só de cor, modos accented/vibrant, imagem colorida com parcimônia, prévia realista na galeria. | https://developer.apple.com/design/human-interface-guidelines/widgets |

### Direção

- **Pequeno, "Meu deputado hoje":** foto de 32 pt com borda do partido, nome em `.caption` bold, último voto como chip (símbolo + "Sim") e título da votação em 2 linhas de `.caption2`. Fonte "Câmara · 18:42" a ≥ 11 pt. Deep link para o perfil.
- **Médio, "Votação do dia":** tema em caixa alta, título em 2 linhas, placar SIM **312** × NÃO **141** em `.title2` bold rounded `monospacedDigit()`, `SegmentedBar` de 6 pt e "faltam 41 para 308". Um `Button` (App Intent) "Ver como meus representantes votaram".
- **Live Activity da votação/apuração** (molde Flighty + Sports): à esquerda SIM com número grande, à direita NÃO, no centro a barra de progresso dos votos computados e "faltam X". Linha de narração factual ("Orientação do governo: Sim"). Na apuração: "Urnas apuradas 87,4%" e os 2 primeiros por voto, com listra na cor do partido. Ilha Dinâmica compacta: "312 · 141".
- **Bloqueio, `accessoryRectangular`:** "Votação: PEC 45 · 312 × 141" com barra linear. **Nada de `accessoryCircular` com gauge circular** (é anel, rejeitado no manual); se houver circular, mostrar só o número ("312") com símbolo.
- **Modos accented/clear:** marcar foto e listra do partido com `widgetAccentable`. Como a cor some nesses modos, o símbolo do voto e a sigla em texto carregam o significado.

### Não fazer

- Widget que só repete o ícone do app ou fica estático o dia inteiro.
- Cor de partido como fundo inteiro do widget (no modo tingido vira uma mancha sem sentido e parece propaganda).
- Gauge circular de presença.
- Texto < 11 pt ou sem fonte.

---

## Fontes consultadas

- App Store: Apple Sports (id6446788829), Flighty (id1358823008), Copilot Money (id1447330651), Stocks (id1069512882), Apple News (id1066498020), Weather (id1069513131), Apple Health (id1242545199), Apple Fitness (id1208224953), Journal (id6447391597), Apple Invites (id6472498645), Partiful (id1662982304), Gentler Streak (id1576857102), Ground News (id1324203419), Structured (id1499198946), Duolingo (id570060128), Sky Guide (id576588894), Things 3 (id904237743), Strava (id426826309).
- HIG: Widgets e Charting data (developer.apple.com/design/human-interface-guidelines).
- Dribbble: 24246062 (Om Patel), 25269569 (Can Tekgül), 26907788 (Nixtio, usado como contraexemplo).

## Decisões para o usuário confirmar antes de desenhar

1. **Cores de dado.** Proposta: Sim oliva, Não ferrugem, Abstenção mostarda, Ausente cinza tracejado, sempre com símbolo. Precisa conferir contra o `PartyPalette`.
2. **Números do placar.** Ficam em SF Pro **Rounded** (regra do manual). A alternativa é uma exceção com `.fontWidth(.condensed)` só no herói do placar, como no Apple Sports.
3. **Arte de artista no lugar da Lottie no setup da Lente.** É uma exceção ao §3 do manual; registrar em `docs/decisions.md`.
4. **Hemiciclo de assentos.** Proposta: fica fora do iPhone, no máximo como extra no iPad.
### Decididas pelo coordenador (2026-10-25)

O usuário pediu tudo numa tacada e uma rodada de revisão visual no fim; estas escolhas seguem o que ele já aprovou e voltam para ele nessa rodada.

1. **Cores de dado:** aceitas, com o teste de distância contra o `PartyPalette` antes de fixar os tons.
2. **Números do placar:** `.width(.condensed)` no herói do placar, como na Live Activity aprovada ("agora sim"); o resto segue Rounded.
3. **Arte no setup da Lente:** entra no lugar da Lottie; as imagens de artistas são prioridade do usuário. Registro em `docs/decisions.md`.
4. **Hemiciclo:** fora do iPhone.
