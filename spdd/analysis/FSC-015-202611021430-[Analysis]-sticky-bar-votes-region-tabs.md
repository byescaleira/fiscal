# Barra do topo, votações, região e ícones das abas

## Original Requirement

Pedido do usuário em 02/11/2026, ao ver a página do político no iPhone:

> Eu gostei muito desse componente que quando dou scroll aparece no top bar, isso deveria ser mais utilizada, soa muito nativos, pois quando dou scroll as vezes preciso manter algo lá em cima visível, e essa forma que você fez ficou show demais. Obviamente que não é preciso todas as vezes

Anotações do usuário no mesmo dia, para encaixar se der:

> a tela região está meio estranho por que fica aparecendo quem você segue sugestões, isso não tem nada a ver com essa tela.

> ícones da tab: a feed pode ser duas pessoas (como era seguindo), o proeminente de fiscalizar pode ser um binoculo;

> tela de votações está boa, da pra melhorar um pouco também, sinto que tem muito conteudo, acho que da pra facilitar a compreensão do que tem nela; o mesmo vale para tela de detalhe da votação, as vezes fico meio perdido nela, as vezes não tem votação nenhuma, ainda tem componentes em capsule que deveriam ser circle (checkmark e o xmark)

**Tamanho:** M, uma fase só, com paradas no iPhone. As telas se conversam: o detalhe da votação é o maior caso da barra, e as outras anotações são ajustes pequenos.

## Domain Concept Identification

**Crítica honesta**, vista no simulador com os dados publicados, salvo onde está dito:

- **Votações abre pelo que menos importa:** a primeira coisa é a pauta, com data vencida ("Pauta de 28/10" em 02/11), textos oficiais de nove linhas e temas cortados ("Direitos...", "Internet e..."). O que foi votado só aparece depois de rolar várias telas.
- **Cada linha de votação pesa muito:** horário, tema, número, resumo, aviso de outras votações, placar e barra. Numa tela, cabem menos de duas linhas.
- **Texto errado e cortado:** "1 outros" em Votações e "1 outros votos" no detalhe, e "Requerimentos de Ur..." na pauta.
- **O detalhe da votação não diz por onde ir:** são nove seções, e a de cada voto chega a centenas de linhas no fim de uma lista. Não há como pular até "Por partido". Ao rolar, some qual é a proposta e qual foi o placar.
- **A explicação vem antes do que explica:** "O que isso quer dizer" fica antes de "O que muda", que é o que a pessoa veio ver.
- **Votação simbólica:** pelo código, ela não tem Sim nem Não e cai em traços e numa lista vazia. É o "às vezes não tem votação nenhuma". Não abri uma na tela.
- **Cápsulas erradas:** o ✓ e o ✗ do placar ficam numa cápsula com espaço vazio à direita, porque o rótulo reserva lugar e não aparece. O selo de aprovada ou rejeitada na linha de Votações tem o mesmo defeito.
- **Outros defeitos de texto:** "Albu-querque" quebra no meio da palavra em "Seus representantes", e "BL UNIPPPSD..." fica cortado na orientação dos partidos.
- **Região mistura dois assuntos:** abre com "Quem você segue" e "Sugestões", antes do lugar. Isso sobrou da aba Seguindo, juntada à Região na `FSC-013`.
- **Ícones:** a aba Feed usa `newspaper`, e Fiscalizar usa a lupa.

| Conceito | Hoje | O que muda |
| --- | --- | --- |
| **Barra ao rolar** | Só na página do político, feita para ela | Uma peça genérica de barra e atalhos, com o conteúdo de cada tela |
| **Onde ela entra** | Página do político | Detalhe da votação, detalhe da corrida e notas de um político. Fora onde nada precisa ficar visível, como Votações e Feed |
| **Detalhe da votação** | Lista de nove seções | Placar, o que muda, quem votou como e os votos, com os atalhos e o placar na barra |
| **Lista de votos** | No fim do detalhe, com busca | Em tela própria, com busca, aberta por "Ver os N votos" |
| **Votação simbólica** | Traços e lista vazia | Diz o resultado e explica que a casa não registrou votos por pessoa |
| **Votações** | Pauta no topo e linhas altas | Linhas mais curtas, com a pauta numa linha só |
| **Sim e Não** | Cápsula | `StatusCircle`, o círculo que o app já usa |
| **Quem você segue e Sugestões** | Em Região | Saem de Região, que fica só com o lugar |
| **Ícones das abas** | `newspaper`, `magnifyingglass` | `person.2`, `binoculars` |

**Achados:**
- **Lista grande:** a página do político usa `VStack`, que serve para poucos itens. Centenas de votos numa `VStack` pesariam, por isso a lista de votos precisa sair do detalhe ou continuar preguiçosa.
- **Mac:** o detalhe da votação já usa `VSplitView` com tabela, e os votos não ficam na lista no Mac. A mudança vale para o iPhone, o iPad e o visionOS.
- **Peça genérica:** pela regra do repositório, ela vai para o `byescaleira-kit`, num PR de lá. O retrato e o placar ficam no app.
- **Quem segue:** a `FSC-013` tirou a aba Seguindo e pôs essa lista em Região. Sem ela lá, deixar de seguir precisa continuar a um toque, e o convite de compartilhar precisa de lugar.
- **Lupa na aba:** a aba de busca usa `Tab(role: .search)`. Falta testar se o sistema aceita outro ícone nesse papel.

## Strategic Approach

| Decisão | Porta | Escolha e motivo |
| --- | --- | --- |
| Onde fica "Quem você segue" | pergunta | **Recomendado: uma tela própria aberta pelo filtro Seguindo do Feed**, com sugestões e o convite de compartilhar. O Feed é onde seguir faz efeito, e Região fica só com o lugar |
| Lista de votos do detalhe | pergunta | **Recomendado: tela própria**, com busca, aberta por "Ver os N votos". Encurta a página e permite a barra. O Mac mantém a tabela |
| Pauta em Votações | pergunta | **Recomendado: uma linha no topo**, com a próxima sessão, abrindo a pauta em tela própria; pauta vencida não abre a tela sozinha. O que foi votado vira o começo da tela |
| Só fatos | veto | Nenhuma cor, ordem ou texto novo diz se um voto foi bom. A cor de Sim e Não continua só como já é |
| Sem dado inventado | veto | Votação simbólica não mostra número, traço ou zero. Diz o que a casa publicou |
| Barra só onde ajuda | veto | Decisão do usuário: entra onde algo precisa continuar visível, e não em toda tela |
| Peça genérica no kit | veto | A barra e os atalhos vão para o `byescaleira-kit`, num PR de lá, e a página do político passa a usar essa peça sem mudar de comportamento |
| Um destino por cartão | veto | As telas tocadas seguem a regra da `FSC-014`: setinha à direita e nada cortado |
| Rótulos curtos | veto | Nada quebra no meio da palavra, inclusive em nomes como "Albuquerque" |
| Sem servidor | veto | Nenhuma mudança em `server/`, dado novo ou deploy |
| Publicar o site | veto | O texto muda no repositório; a publicação espera o ok do usuário |
| Corridas e notas | reversível | A barra mostra a corrida com o apurado, e a pessoa com o ano. Iterar no iPhone |
| Conteúdo da barra no detalhe | reversível | Número da proposta, placar compacto e atalhos: O que muda, Quem votou, Por partido |
| Ordem do detalhe | reversível | Placar, O que muda, a explicação, quem você apoia e seus representantes, Por partido, orientação e "Ver os N votos" |
| Linha de Votações | reversível | Número, resumo em até duas linhas e placar compacto com o círculo; hora e tema em uma linha só |
| Sim e Não | reversível | `StatusCircle` no placar e nas linhas, e o selo de resultado com o texto visível |
| Lupa | reversível | Se o sistema não aceitar `binoculars` no papel de busca, mostrar o resultado no iPhone antes de trocar o papel da aba |
| Referências | reversível | FotMob, que mantém o placar e as abas fixos ao rolar uma partida, e Apple Sports, com a parada no iPhone |

**Etapas do canvas:** peça no kit e página do político usando ela; detalhe da votação, com parada no iPhone; Votações; Região, tela de quem você segue e ícones; corrida e notas; documentos e fechamento.

## Risk & Gap Analysis

| Risco | Efeito | Tratamento |
| --- | --- | --- |
| Mudar a página do político para a peça do kit | Regressão numa tela já aprovada | Os testes de interface da `FSC-014` seguem iguais, e ela é conferida no iPhone |
| Tirar a lista de votos do detalhe | Quem usava a busca ali perde o caminho | "Ver os N votos" sempre visível na barra de atalhos; a busca abre junto na tela nova |
| Lista de quem segue fora de Região | Quem procura ali não acha | Filtro Seguindo com a linha "Quem você segue", e o caminho `IntegrationLink.region` do widget revisado |
| Widget e Siri que abrem Região para ver quem segue | Link leva a tela errada | Rever `FollowIntent` e o widget "Quem eu sigo" |
| Bateria e travada | Medida de posição a cada quadro, apontada na revisão da `FSC-014` | Atualizar só quando muda o capítulo atual, e conferir no iPhone |
| Ícone no papel de busca | O sistema pode ignorar | Testar antes de decidir |
| Pauta escondida | Perde destaque quando há sessão hoje | A linha mostra "em sessão" e a quantidade de itens |
| Mac | Telas com tabela não ganham a barra | Declarar no PR; o Mac não abre nesta máquina |

**Critérios de aceite (para o canvas):**

| Cenário | Prova |
| --- | --- |
| Votação nominal: ao rolar, a barra mostra a proposta, o placar e os atalhos | Teste de interface, captura e iPhone |
| Votação simbólica: sem traço e sem lista vazia, com a frase do que a casa publicou | Teste de modelo e captura |
| "Ver os N votos" abre a tela com busca | Teste de interface |
| Sim e Não em círculo, no placar e nas linhas | Captura, com "1 outro voto" no singular |
| Votações começa pelo que foi votado, com a pauta numa linha | Teste de modelo e captura com pauta vencida e com sessão hoje |
| Região sem "Quem você segue" nem "Sugestões" | Teste de interface |
| Seguir e deixar de seguir continuam a um toque na tela nova | Teste de modelo e de interface |
| Abas com `person.2` e `binoculars` | `AppSectionTests` e captura |
| Corrida e notas com a barra | Captura |
| Página do político igual, usando a peça do kit | `ProfileChaptersTests` e iPhone |
| Maior tamanho de texto e Reduzir movimento nas telas novas | Teste de interface e captura |

**Fora de escopo:** dado novo, mudança no servidor, redesenho do Feed, outras telas de Dinheiro e Fiscalizar, web e publicação do site sem ok.
