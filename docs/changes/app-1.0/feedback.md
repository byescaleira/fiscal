# Pedidos do usuário na rodada de ajustes da 1.0

Lista única dos pedidos feitos no iPhone, com o estado de cada um. Atualizada a cada entrega; cada entrega é instalada no iPhone e relatada.

Estados: **no iPhone** (instalado no aparelho), **em andamento** (frente rodando), **na fila** (ainda não começou), **decisão** (precisa do usuário).

## Navegação e componentes

| Pedido | Estado | Onde |
| --- | --- | --- |
| Ícones das abas (casa, pessoas, arquivo, recibo, lupa) e Fiscalizar em destaque — ajuste do usuário em 26/10 | no código | AppSection, MainScreen |
| Tags de partido em faixas verticais iguais, sem gradiente | no iPhone | PartyMark, PartySeal |
| Nenhum segmented control no app | no iPhone | Compartilhar, Gastos, Votos do detalhe |
| Seguir e Compartilhar do perfil numa linha, mesma altura | no iPhone | ProfileHero |
| Retrato sem rosto em cinza neutro | no iPhone | PersonPortrait |

## Votações

| Pedido | Estado | Onde |
| --- | --- | --- |
| Filtros na toolbar em vez da pilha vertical | no iPhone | VotesToolbar |
| Card Sim × Não com margem da lista e mais respiro | no iPhone | VoteHeroSection |
| Check e xmark dos representantes em círculo | no iPhone | VoteBallotsSection |

## Meus e dados

| Pedido | Estado | Onde |
| --- | --- | --- |
| Escolher qualquer cidade, com prefeito e vereadores | no iPhone | Meus, servidor (TSE 2024) |
| Comparação só com 2 políticos | no iPhone | Compare |
| Todos os políticos nos dados de teste (ex.: Flávio Bolsonaro) | no iPhone (594 nacionais) | showcase-people.json |
| Volume da base de dados (votações, perfis, dinheiro reais) | em andamento | frente data |
| Rostos para todos (628 desenhados) | no iPhone | avatars.py, fiscal-portraits.deflate |

## Compartilhar

| Pedido | Estado | Onde |
| --- | --- | --- |
| Card com pouca informação e sem componentes nativos | no iPhone | SharePoster |
| Arte brasileira antes das paisagens | no iPhone | ShareModel |
| Paisagem ocupando o card inteiro, como as pinturas | no iPhone | ShareArtwork |
| Acervo histórico só com pinturas coloridas em alta resolução | no iPhone (22 pinturas) | art-works.json |

## Apuração ao vivo

| Pedido | Estado | Onde |
| --- | --- | --- |
| Card ao vivo do Hoje com uma barra de força por lado, sem diferença | no iPhone | TodayLiveRaceCard |
| Live Activity igual ao card: foto, tag, % apurado, barra de força, fundo do sistema em vidro | no iPhone | RaceLiveActivity |
| Live Activity cabendo na tela de bloqueio, percentual em destaque | no iPhone | RaceLiveActivity |
| Card do Hoje igual ao destaque da apuração; Live Activity no mesmo desenho | no iPhone | RaceHeroCard, TodayRaceHero |
| Live Activity menos apertada: candidatos em linhas | no iPhone | RaceLiveActivity |
| Resumo do dia sem carregar (dado real ainda não publicado) | na fila: deploy | VPS |
| Apuração mostrando 87% (era o cenário de teste) | no iPhone, só dado real | launch sem cenário |
| Tela de apuração menos repetitiva, com brancos, nulos, abstenção e fotos | no iPhone | LiveResultsScreen, RaceDetailScreen |

## Lente e visual

| Pedido | Estado | Onde |
| --- | --- | --- |
| "De que lado você está?" na proposta do app | no iPhone | LensStanceSpectrum, LensChoices |
| "O seu visual" consistente com o app | no iPhone | LensLookPreview, LensLookChoices |
| Gráfico de "Seus temas" na tela da Lente | no iPhone | LensThemeChart |

## Gráficos e dinheiro

| Pedido | Estado | Onde |
| --- | --- | --- |
| Temas em Fiscalizar com Swift Charts | no iPhone | ThemeCharts |
| Seções de Dinheiro com gráficos próprios do Swift Charts | no iPhone | FeatureMoney |

## Novas funcionalidades

| Pedido | Estado | Onde |
| --- | --- | --- |
| Destaque do momento sempre na aba Hoje | no iPhone (aparece com dados reais) | TodayHighlightSection |
| Peso de cada ação (repercussão + impacto, regra única) | no iPhone; repercussão só pela Wikipédia (GDELT limitou, Bluesky exige login) | weight.go, ProfileActionsSection |
| Preços com série histórica (gasolina e bens de consumo) | no iPhone (ANP desde 2001, IPCA) | indicators |
| Antes × durante o mandato para todos | no iPhone (aparece com dados reais) | ProfileContextSection |
| Explicar em linguagem simples o sentido dos dados, com Foundation Models e selo de interpretação imparcial | no iPhone (votação, perfil, Temas; aparece com dados reais) | FeatureCore/Explain |
| Selo: "Apple Intelligence" em vez de "Siri" | decidido: Apple Intelligence | ExplainerBadge |
| Repercussão no X, Instagram ou TikTok | decisão (custo) | — |

## Backend e dados reais

| Pedido | Estado | Onde |
| --- | --- | --- |
| Só dados reais no iPhone | no iPhone, dados reais no ar desde 26/10 01:51 UTC | sem -FiscalDataScenario |
| Backend que guarda tudo e sincroniza sozinho (SQLite, decisão do usuário) | no ar (banco de 1,3 GB, backup diário) | datastore, ADR 0006 |
| Deploy da carga na VPS (aprovado pelo usuário) | no ar: 2.357 pessoas, 69.269 municipais, 4.452 votações, 1.152 checagens | fiscal-ingest, Caddy /api/v1 |

## Rodada de 26/10

| Pedido | Estado | Onde |
| --- | --- | --- |
| Fotos dos dois escolhidos maiores na comparação | no iPhone | ComparePicker |
| Live Activity parecida com o card ao vivo, com padding adequado | no iPhone | RaceLiveActivity |
| Barra do card ao vivo como estava na apuração | no iPhone | RaceHeroCard |
| Seletor de imagens do compartilhar melhor | no iPhone | ShareArtPicker |
| Card ao vivo no topo do Hoje | no iPhone | TodayScreen |
| Compartilhar o Destaque do momento | no iPhone | SharePosterHighlight, TodayHighlightSection |
| Cargo no feminino (Deputada, Senadora…) | no iPhone (dados de teste; real após a próxima carga) | Office.title(for:) |
| Ajustes e telas internas no padrão do app | no iPhone | FeatureSettings |
| Sem "Apagar minha escolha" na Privacidade da Lente | no iPhone | LensPrivacySection |
| Destaque do momento no widget (sempre) e na Live Activity (só peso ≥ 85, últimas 24 h) | no iPhone; push por servidor depende do deploy do fiscal-api | HighlightWidget, HighlightLiveActivity |
| Cabeçalho de Meus melhor, sem cor | no iPhone | MineHeroCard |
| Botões da toolbar na cor do texto; Trocar lugar na toolbar de Meus | no iPhone | toolbars |
| Lente pelos candidatos que a pessoa apoia, no lugar do lado (apoiar ≠ seguir) | no iPhone | FeatureLens, SupportThemes, FiscalSchemaV2 |
| Tela "O que mais importa para você?" (temas) no layout do app | no iPhone | LensThemesStep |
| Boas-vindas (setup da Lente) no claro e no escuro | no iPhone | LensSetupScreen, LensBackdrop |
| Contraste dos botões principais no escuro | no iPhone | ProminentButton |
| Reiniciar o servidor da apuração (aprovado) | no ar: push dos destaques e abstenção | fiscal-api |

| Card do vencedor quando a disputa termina (sem "ao vivo"), com animação | no iPhone | RaceWinnerCard, WinnerLockScreen |
| Sem tag de "lente" no Hoje; a palavra lente sai da interface | no iPhone | TodayScreen, badges |
| Testar o disparo da Live Activity do destaque | no iPhone (forçado); pelo servidor não dispara: peso máx. 50 sem notícias | frente credibility |
| Compartilhar o card de vitória nos Stories | no iPhone | ShareVictoryPoster |
| Credibilidade: só fatos, motivo da incerteza, sinal ausente não é zero | em andamento | frente credibility |

| Selo de voto/resultado em círculo em todo o app | no iPhone | StatusCircle |
| Propostas do perfil desconfiguradas (espaços enormes) | no iPhone | FlowLayout, ProfileProposalRow |
| Card de vitória abrindo "disputa indisponível" | no iPhone (detalhe busca a disputa no servidor) | RaceDetailScreen |
| Tirar a tag "Sua cidade" | no iPhone | MineHeroCard |
| Destaque do momento parecido com o card de vitória | em andamento | frente credibility |
| Salários sem sentido (todos iguais) → "Quanto custa um mandato" | em andamento | frente mandate-cost |
| Mais retratos: deputados estaduais, vice-governadores, prefeitos de capitais e cidades > 200 mil | em andamento | frentes faces e–h |

## Ícone

| Pedido | Estado | Onde |
| --- | --- | --- |
| Ícone com a identidade do projeto | sessão própria (fiscal-icon) | Fiscal/Fiscal/FiscalIcon*.icon |
