# Feed como primeira aba e a aba Região

Terceira das quatro fases da [análise FSC-011](FSC-011-202611011850-[Analysis]-feed-profile-and-end-of-lens.md).

## Original Requirement

Pedido do usuário em 01/11/2026:

> primeira tab não deve ser seguindo, mas sim feed. Nela tem que ter um comportamento de feed, foco no que estou seguindo e no que é relevante, o ideal é que esse feed seja infinito e bonito.

Respostas do usuário na análise FSC-011:
- **Abas:** Feed absorve Hoje. Feed, Votações, Dinheiro, Região e Fiscalizar. Apuração e destaques entram no Feed. A aba Região guarda quem a pessoa segue, as sugestões, quem governa e as bancadas.
- **Feed infinito:** montado só no app, sem servidor novo. Quem segue pouca gente vê o feed acabar, e o fim é mostrado com clareza.

**Tamanho:** L, já no [roadmap](../../docs/roadmap.md) como etapa 8.3.7. Muda as abas, o contrato do [brief](../../docs/brief.md), dois modelos grandes (`TodayModel` e `MineModel`) e os links de entrada.

## Domain Concept Identification

| Conceito | Hoje | O que muda |
| --- | --- | --- |
| **Abas** | Seguindo, Hoje, Votações, Dinheiro e Fiscalizar | Feed, Votações, Dinheiro, Região e Fiscalizar |
| **Hoje** | Data, apuração, destaques, resumo, pauta do Congresso, atalho de Seguindo e votações recentes, em cerca de 1.700 linhas | Deixa de ser aba. Apuração e destaque do momento vão para o topo do Feed |
| **Seguindo** | Novidades, quem segue, sugestões, Sua região, Quem governa, bancadas e "Na sua região agora", em cerca de 2.650 linhas | As novidades vão para o Feed; o resto vira a aba Região |
| **Novidades** | `FollowingFeed`: voto, gasto e checagem, 30 dias e até 50 itens, de quem segue | Passam a ser a primeira fonte do Feed, sem o limite de 30 dias |
| **Relevante** | `highlights.json` (4 itens), `votes/recent.json` (60 votações) e os destaques da região | Segunda fonte do Feed |
| **Fontes por pessoa** | `actions.json` (40 por pessoa) e arquivos por ano desde 2023: votos, propostas, discursos e gastos | Base do "infinito": cada volta ao fim da lista carrega mais um ano |
| **Junção por votação** | `SupportTimeline` já junta fontes da mesma votação numa linha e ordena por data | A mesma lógica serve ao Feed |
| **Selo de novidades** | Número na aba Seguindo, com `FollowingSeenStore`, zerado ao sair dela | Vai para a aba Feed |
| **Widget e Siri** | "Quem eu sigo" abre Seguindo e usa `FollowingSnapshot` | Continuam funcionando; quem publica o retrato passa a ser o Feed |

**Achados:**
- **"Infinito" tem limite real:** sem seguidos, só há as 60 votações recentes, os 4 destaques e os destaques da região. O fim chega rápido e precisa ser honesto, com um convite para seguir alguém.
- **Teto de dados:** um histórico longo de quem segue muita gente pede muitos arquivos por ano. O carregamento em lotes de 6 já existe e continua valendo, e cada ano só carrega quando a pessoa chega ao fim da lista.
- **Cargos sem votos:** governador e prefeito têm pouco. Os fatos deles entram no Feed quando existem, sem linha vazia.
- **Teste quebrado:** `testTodayOpensTheLiveResults` já falha e mexe no que muda aqui; esta fase o reescreve.

## Strategic Approach

**Decisões:**

| Decisão | Porta | Escolha e motivo |
| --- | --- | --- |
| Abas | veto | Feed, Votações, Dinheiro, Região e Fiscalizar, nessa ordem, como respondido. O app abre no Feed |
| Topo do Feed | veto | Apuração ao vivo, quando houver, e depois o destaque do momento, em cartões grandes. Depois, a lista |
| Mistura | respondida | **Tudo por data, com filtro:** uma lista só, do mais novo para o mais antigo, com os filtros Tudo, Seguindo e Relevante |
| Resumo do dia e pauta | respondida | **Pauta em Votações, resumo no Feed:** a pauta fica só em Votações, e os eventos do dia, como sessão e lei sancionada, viram linhas relevantes |
| O que entra | veto | Votos, propostas, discursos, gastos do mês e checagens de quem a pessoa segue; votações recentes e destaques como relevantes. Cada linha com data e fonte |
| Motivo visível | veto | Cada linha diz por que está ali: o nome de quem você segue ou "Relevante". Sem dizer que algo é bom ou ruim |
| Apoio | veto | O Feed não lê o apoio, e a regra `support_stays_private` barra. Mesma ordem para todo mundo com os mesmos seguidos |
| Infinito | veto | Carrega o ano corrente e, ao chegar ao fim da lista, o ano anterior, até 2023. Sem carregar tudo de uma vez, com lotes de 6 |
| Fim real | veto | No fim, uma mensagem clara: até onde vão os dados e, se a pessoa segue pouca gente, o convite para seguir. Nunca lista vazia sem explicação |
| Sem seguidos | veto | O Feed funciona só com o relevante, e um cartão convida a seguir alguém. Nunca uma tela vazia |
| Erros | reversível | Falha numa fonte não derruba as outras; um aviso oferece tentar de novo |
| Formato | reversível | Cartões de forma diferente por tipo, com pessoa, fato, fonte, data e compartilhar quando já existe. Referências reais antes de desenhar, e **parada no iPhone para o ok** |
| Junção | reversível | Mesma votação de várias fontes vira uma linha, com o voto de cada pessoa seguida, reaproveitando a lógica da linha do tempo |
| Destaques da região | reversível | Entram como relevantes quando a pessoa escolheu um lugar, com o nome do lugar no motivo |
| Selo | reversível | O número de novidades vai para a aba Feed e zera ao sair dela |
| Região | reversível | Aba com ícone de mapa: quem segue, sugestões, Sua região, Quem governa, bancadas e "Na sua região agora" |
| Barra | reversível | Coração de "Meu apoio" e Ajustes vão para o Feed |
| Links | reversível | `fiscal://feed` e `fiscal://region`, com `fiscal://today`, `following` e `mine` levando ao lugar novo. Widget e Siri seguem funcionando |
| Código | reversível | `FeatureToday` vira `FeatureFeed`, e `FeatureMine` vira `FeatureRegion`, com os modelos divididos por responsabilidade |
| Documentos | veto | ADR novo registra a estrutura e corrige o ADR 0014. Brief, arquitetura, App Store e site passam a dizer a verdade. **Publicar o site espera o ok** |

**Etapas do canvas:** abas e links; domínio do Feed; a tela, com parada no iPhone; dividir `TodayModel` e `MineModel`; documentos e fechamento.

## Risk & Gap Analysis

| Risco | Efeito | Tratamento |
| --- | --- | --- |
| Rolagem longa com cartões variados | Travar em aparelho antigo | Lista preguiçosa, retratos pequenos parados e medição no iPhone |
| Muitos seguidos | Muitos pedidos e consumo de dados | Lotes de 6, um ano por vez, cache atual |
| Feed parecer rede social que puxa atenção | Contra "só fatos" | Sem contagem de engajamento e sem recomendação escondida; o motivo fica visível e a ordem é explicável |
| Ordem que muda sozinha | Linha some enquanto a pessoa lê | Atualiza só ao abrir ou ao puxar a tela |
| Modelos grandes divididos | Regressão em Hoje e Seguindo | Testes existentes migram com o código, e a divisão vem depois da tela aprovada |
| Links antigos | Widget ou Siri abrem o lugar errado | `DeepLinkTests` para cada alias, e widget conferido |
| Mac e dobrável | Layout de duas colunas quebra | Conferir o Duo aberto e a lista de origem do Mac |
| Site em desacordo | Fala de "Hoje" até publicar | Texto muda na fase; a publicação espera o ok |

**Critérios de aceite (para o canvas):**

| Cenário | Prova |
| --- | --- |
| O app abre no Feed, com as 5 abas na ordem nova | Teste de interface e captura |
| Com apuração ao vivo e destaque, os dois ficam no topo | Teste de modelo e captura |
| Quem segue 2 pessoas vê os fatos delas e os relevantes, cada um com o motivo | `FeedTimelineTests` e captura com dados reais |
| Sem seguidos, há relevantes e o convite | Teste de modelo e captura |
| Chegar ao fim carrega o ano anterior, sem repetir linha | Teste de modelo |
| Depois de 2023 ou sem mais dados, a mensagem de fim aparece | Teste de modelo e captura |
| Votação com duas pessoas seguidas é uma linha só | `FeedTimelineTests` |
| Falha numa fonte mantém o resto e avisa | Teste de modelo |
| A ordem não muda com o apoio | Regra `support_stays_private` |
| Selo aparece no Feed e zera ao sair | Teste de modelo |
| Região mostra quem segue, sugestões, quem governa e bancadas | Captura |
| `fiscal://today`, `following` e `mine` levam ao lugar novo | `DeepLinkTests` |
| Widget "Quem eu sigo" continua atualizando | `FollowingSnapshotTests` |
| VoiceOver e maior tamanho de texto no Feed | Teste de interface e captura |

**Fora de escopo:** nova página do político e compartilhar um item (`FSC-014`), servidor novo, web e publicação do site sem ok.
