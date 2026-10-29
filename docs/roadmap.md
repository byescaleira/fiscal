# Roadmap

O que o Fiscal vai ganhar, por fase, até a 1.0. A visão, os públicos, a Lente e as 5 abas estão no [brief](brief.md). Cada fase vira uma ou mais mudanças em [changes/](changes/README.md); os pré-requisitos técnicos ficam no [backlog](backlog.md).

## Como dimensionar

- **S:** uma sessão; uma mudança pequena, sem dado novo nem tela nova.
- **M:** duas ou três etapas; uma tela ou entidade nova com testes, sem migração delicada.
- **L:** quatro ou mais etapas; dado novo com migração, serviço externo, plataforma nova ou fluxo inteiro. Uma fase L que puder ser dividida vira duas M.
- **Mantenha a 1.0 com até ~8 fases.** Passou disso, corte escopo para depois da 1.0 antes de começar; trabalho de base ou de alinhamento entra como etapa da fase em que acontece, não como fase nova.

## Fases até a 1.0

| Fase | Entrega | Tecnologia | Tamanho | Estado |
| --- | --- | --- | --- | --- |
| 0 | Base: estrutura por feature, design system, Ajustes, guias, flags, deep links, lint, scripts, CI, site, ponte e admin | Template `byescaleira-workspace` | S | pronta |
| 1 | **Apuração ao vivo do 2º turno** (25/10/2026), com a Live Activity atualizada por push | TSE `resultados`, servidor Go, ActivityKit, APNs | L | entregue ([`live-results`](changes/archive/2026-10-29-live-results/proposal.md)) |
| 2 | **Dados públicos no servidor:** carga por cadência da Câmara, do Senado, do TSE, do IBGE, da Receita, da ANP, das assembleias e do Comprova; arquivos estáticos `v2` na CDN | Go, SQLite na VPS, Cloudflare Pages | L | entregue ([`app-1.0`](changes/archive/2026-10-29-app-1.0/proposal.md)) |
| 3 | **Região, perfil e Fiscalizar:** quem governa cada lugar, seguir no aparelho, perfil com presença, votos, propostas, gastos, patrimônio e campanhas, busca, Comparar, investigações e Memória, nas 5 abas | SwiftData, IBGE, `Tab(role: .search)` | L | entregue (`app-1.0`) |
| 4 | **Lente e Aparência:** "quem você apoia", temas, Hoje e listas na ordem da pessoa, "Outra lente" na tela da Lente, paletas e ícones alternativos | SwiftData só no aparelho, Lottie, ícones alternativos | M | entregue (`app-1.0`) |
| 5 | **Votações:** pauta e calendário, placar por partido, votações do mesmo projeto agrupadas, "o que muda na prática" e o destaque na tela de bloqueio | Servidor (pauta do dia), ActivityKit | L | entregue em parte (`app-1.0`); alertas por tema no backlog |
| 6 | **Dinheiro:** cota e recibos, custo do mandato contra o salário mínimo, financiamento de campanha, patrimônio declarado e arrecadação federal | Swift Charts, Receita, TSE | M | entregue em parte (`app-1.0`); emendas no backlog |
| 7 | **Compartilhar com arte:** cartazes de Stories, feed e mensagem, galeria de artistas com crédito e licença, `art-credits.json` | `ImageRenderer`, `ShareLink`/`Transferable`, deep links | M | entregue (`app-1.0`); arte encomendada depois da 1.0 |
| 8 | **Integrações e polimento para a loja:** widgets, Live Activities, App Intents, Spotlight, explicações no aparelho, acessibilidade completa, revisão de neutralidade, App Store e TestFlight | WidgetKit, App Intents, Core Spotlight, Foundation Models; revisores; `app-store-release.md` | L | em andamento |

A fase 8 corre em etapas:

| Etapa | Entrega | Estado |
| --- | --- | --- |
| 8.1 | Integrações: widgets, Live Activities, App Intents, Spotlight, Foundation Models e pacote offline | entregue (`app-1.0`) |
| 8.2 | [`kit-adoption`](changes/archive/2026-10-29-kit-adoption/proposal.md): design, componentes e idioma do byescaleira-kit ([ADR 0010](adr/0010-byescaleira-kit.md)), mínimo de sistema 26 com o 27 por `#available`, `MARKETING_VERSION` 1.0.0 e `CHANGELOG.md` | feita (2026-10-29, PR #3) |
| 8.3 | [`align-workspace`](changes/archive/2026-10-29-align-workspace/proposal.md): fundo branco ou preto, acessibilidade, arquitetura, publicação, site, servidor e processo no padrão do workspace | feita (2026-10-29, PR #4) |
| 8.4 | Loja: roteiro de [validation.md](validation.md) no iPhone físico, rótulo de privacidade ([ADR 0017](adr/0017-app-store-privacy-label.md)), capturas, TestFlight e envio para a revisão | — |

- **Lançamento só iOS (iPhone e iPad).** Mac e visionOS compilam no mesmo projeto, mas a receita própria do Mac e o envio dessas plataformas ficam no [backlog](backlog.md).
- **Arte encomendada:** o licenciamento com artistas atuais segue a [pesquisa de artistas](research/README.md) e fica para depois da 1.0; os cartazes usam o acervo com licença conferida.

## Design de cada seção

Cada aba e cada peça visível (Hoje, Região, Votações, Dinheiro, Fiscalizar, setup, cards, widgets) passa pelo ciclo da skill `byescaleira-sdd` (`design-principles.md` §4.1), o mesmo que levou a Live Activity da apuração à versão aprovada:
1. referência visual real (capturas oficiais da App Store, HIG, Dribbble);
2. versão com dados de teste de todos os estados, no iPhone;
3. revisão com o usuário;
4. repetir até o "agora sim".

Correto no HIG não basta: a seção não pode parecer genérica.

## Critério de pronto da 1.0

- Uma pessoa de qualquer lado instala, escolhe a Lente em menos de um minuto e, na primeira tela, vê o que os seus representantes fizeram nos temas dela, com fonte e data.
- Os 513 deputados, os 81 senadores e o presidente com perfil completo; Live Activity para apuração e para votação importante.
- Zero dado pessoal no servidor; a Lente só no aparelho.
- VoiceOver, Dynamic Type nos tamanhos de acessibilidade e Reduzir movimento em todas as telas, no iPhone e no iPad.

## Depois da 1.0

- Governadores, assembleias e câmaras municipais, onde houver dado aberto (SAPL, portais de transparência).
- STF: pauta, julgamentos e votos dos ministros.
- Eleições municipais de 2028: apuração por cidade, prefeitos e vereadores.
- Push-to-start da Live Activity (a apuração começa sozinha na tela de bloqueio).
- Apple Watch (complicação com a votação do dia), a receita do Mac e o Fiscal na Web ([ADR 0016](adr/0016-web-companion-after-1-0.md)).

### Pedidos do usuário para depois (2026-10-25)

- **Acompanhamento de preços:** monitorar ao longo do tempo os preços do que pesa para toda a população, no Brasil e por estado, e ligar cada série ao governo e ao período. Itens:
  - gasolina e outros combustíveis;
  - o real contra o dólar;
  - a cesta de alimentos comuns, por exemplo os itens que aparecem na mídia quando sobem (arroz, feijão, carne, café, leite, ovo).

  Fontes oficiais a pesquisar: ANP (combustíveis), Banco Central (câmbio, via SGS/PTAX), IBGE (IPCA por item) e DIEESE (cesta básica por capital).
- **Notificações por feature, iguais para todo mundo** (hoje o destaque e a apuração chegam por Live Activity, um push por token; ver [notifications.md](specs/notifications.md)):
  - não são personalizadas por pessoa;
  - todo mundo recebe as mesmas, por canal de feature (broadcast do APNs), por exemplo "votação importante", "resultado da apuração", "variação forte de preço";
  - raras: só quando há necessidade ou variação significativa dos dados, nunca rotina diária.
- **Comparações como recurso central:**
  - pesquisar o que está em alta na internet nos argumentos políticos dos dois lados (comparações de governo, preços, gastos, votos, promessas contra entregas);
  - transformar cada argumento recorrente numa comparação com dado oficial e fonte, sem ranking nem conclusão pronta;
  - a pesquisa vem antes do desenho de cada comparação (skill `research`).
- **Base histórica de tudo:**
  - todas as apurações das eleições passadas: presidente, governador, senador, deputados, prefeito e vereador, por turno, UF, município e zona, desde o início da série digital do TSE;
  - os outros dados históricos relevantes, com a mesma regra de fonte oficial e arquivo estático:
    - candidaturas, bens e prestação de contas de cada eleição (TSE);
    - mandatos, votações nominais, proposições, discursos e gastos de legislaturas anteriores (Câmara e Senado);
    - composição das casas e das bancadas ao longo do tempo;
    - presidentes, governadores e mandatos (quem governou o quê, e quando);
    - arrecadação e indicadores (IBGE, Receita, Banco Central), para servir às comparações e ao acompanhamento de preços;
  - o perfil de cada político ganha a linha do tempo completa, e cada lugar a sua história eleitoral;
  - antes de carregar, pesquisar o que cada fonte tem de série e formato (skill `research`) e medir o tamanho publicado, porque a VPS é pequena (ADR 0002).
- **Arte encomendada a artistas de agora:** 3 a 6 artistas atuais equilibrados entre direita, centro e esquerda, para mapas, estados, florestas e cores dos partidos, com contrato por escrito que liste app, loja, site e divulgação. A lista, os contatos e o rascunho da mensagem saem antes, e nenhum contato é enviado sem o ok do usuário ([pesquisa](research/2026-10-25-contemporary-artists.md)).
