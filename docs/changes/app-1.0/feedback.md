# Pedidos do usuário na rodada de ajustes da 1.0

Lista única dos pedidos feitos no iPhone, com o estado de cada um. Atualizada a cada entrega; cada entrega é instalada no iPhone e relatada.

Estados: **no iPhone** (instalado no aparelho), **em andamento** (frente rodando), **na fila** (ainda não começou), **decisão** (precisa do usuário).

## Navegação e componentes

| Pedido | Estado | Onde |
| --- | --- | --- |
| Aba Fiscalizar sem destaque e ícones padrão nas abas | no iPhone | AppSection, MainScreen |
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
| Só dados reais no iPhone | no iPhone (apuração real; o resto depende do deploy) | sem -FiscalDataScenario |
| Backend que guarda tudo e sincroniza sozinho (SQLite, decisão do usuário) | pronto no código; entra no próximo deploy | datastore, ADR 0006 |
| Deploy da carga na VPS (aprovado pelo usuário) | no ar; primeira carga completa rodando | fiscal-ingest, Caddy /api/v1 |

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
| Ajustes e telas internas no padrão do app | em andamento | frente settings |

## Ícone

| Pedido | Estado | Onde |
| --- | --- | --- |
| Ícone com a identidade do projeto | sessão própria (fiscal-icon) | Fiscal/Fiscal/FiscalIcon*.icon |
