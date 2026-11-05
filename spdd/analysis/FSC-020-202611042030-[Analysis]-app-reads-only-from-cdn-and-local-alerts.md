# SPDD Analysis: O app só lê a CDN, e os alertas de destaque são locais

## Original Requirement

Pedidos literais do usuário:

> "Não teria como fazer esse disparo localmente no iPhone, podemos fazer uma vez por dia. Pensamos em um horário para o live activity e outra para outra notificação. Com isso não sobrecarregamos o SO e tiramos isso da VPS"

> "uma coisa que notei, não apareceu a foto do politico (bonequinho) no liveactivity."

> "eu quero tirar tudo de bater o app direto na vps. as atividades ao vivo vão demorar para proxima eleição, com isso, não precisamos se preocupar com isso. só vamos deixar a vps responsavel por popular a cdn."

Respostas dele às perguntas anteriores: "Sim, local, uma vez por dia (Recomendado)" e "Corrijo o sumiço, e o local vem antes da FSC-018 (Recomendado)".

Critérios de aceite que saem do pedido:

1. A Atividade ao Vivo do destaque aparece no máximo uma vez por dia, num horário fixo, com o app fechado.
2. Uma notificação local sai em outro horário, também no máximo uma vez por dia.
3. O destaque deixa de depender da VPS: nenhum registro de aparelho, nenhum envio.
4. O app não faz nenhuma chamada direta à VPS: nem leitura de reserva, nem apuração, nem registro.
5. A VPS só alimenta a CDN.
6. A Atividade do destaque mostra o bonequinho do político.

## Domain Concept Identification

### Existing Concepts

- **Regra do alerta** (`HighlightAlertRule` em `FiscalDomain/PublicData`): peso 70 ou mais, fato de até 24 h depois do fim do dia dele em Brasília, 8 h de vida, escolhe o de maior peso que ainda não apareceu. Vem de `method/weight.json` pela CDN.
- **Registro do que apareceu** (`HighlightAlertLedger`): preferência ligada, os 60 últimos ids mostrados e o token registrado.
- **Centro do alerta** (`HighlightAlertCenter` em `AppShell/Integrations`): hoje, ao abrir o app, inicia uma Atividade na hora e registra o token de início no servidor.
- **Atividade do destaque** (`HighlightActivities`, `HighlightActivityAttributes`, `HighlightLiveActivity`): a tela de bloqueio e a Ilha Dinâmica.
- **Envio pela VPS** (`server/internal/highlightalert`, registros em `highlight-registrations.json`, rotas `POST` e `DELETE /api/v1/highlight-activities`): o vigia que manda o destaque por push.
- **Prateleira de retratos** (`PortraitShelf`, `PortraitStore.shelve`): o app grava um PNG no App Group, e a Atividade da apuração o lê. Só a disputa usa hoje.
- **Atualização em segundo plano** (`OfflineDataCenter`, `BGAppRefreshTaskRequest`): já existe para o pacote offline. O iOS decide quando roda.
- **Interruptor em Ajustes** (`HighlightAlertsSection`): "Destaques de maior peso na tela de bloqueio", com o texto "Só peso 70 ou mais, do último dia. O Fiscal envia só um código anônimo da Apple."
- **Canvas e textos públicos:** a `FSC-007` diz que o Fiscal avisa "só por Atividades ao Vivo, nunca por notificação comum"; `site/privacy.html` descreve o envio do código dos destaques.

- **Reserva na VPS** (`PublicDataClient.legacy`, `PublicDataRoute`, `PublicDataOrigin`): se a CDN responde erro ou o `release.json` falha, o app lê `FiscalAPIURL`, em `/api/v1`.
- **Apuração** (`LiveResultsClient`): lê `v2/races.json` e, se a lista estiver velha ou falhar, `/api/v1/races`. Também registra o token da disputa, com App Attest.
- **Atividade da disputa** (`RaceActivities`, `RaceLiveActivity`, `RaceWinnerLockScreen`, botão de acompanhar): depende do push da VPS.
- **`fiscal-api`:** faz a leitura do TSE (que grava `races*.json`), envia APNs e serve as rotas. Só a leitura do TSE alimenta a CDN.
- **Rótulo da loja** ([ADR 0017](../../docs/adr/0017-app-store-privacy-label.md)): declara o ID do dispositivo por causa dos tokens e das chaves no servidor.

### New Concepts Required

- **Plano do dia:** o que fica agendado no aparelho em cada abertura: no máximo uma Atividade e uma notificação, cada uma com o destaque, o horário e o estado de "já valeu".
- **Notificação local do destaque:** o primeiro uso de notificação comum no app, com permissão do sistema e interruptor próprio.
- **Retrato do destaque na prateleira:** o PNG do político gravado antes de agendar, para a Atividade e a notificação.

### Key Business Rules

- No máximo **1 Atividade** e **1 notificação** por dia em cada aparelho.
- Só agenda **com o app em primeiro plano**: em segundo plano o iOS recusa a Atividade (`visibility`, medido no iPhone).
- **Nunca acumula:** depois de 5 agendadas, o iPhone recusou a seguinte (`targetMaximumExceeded`, medido). A abertura do app pode rodar várias vezes, então agendar duas vezes o mesmo plano não pode criar outra.
- **O conteúdo da Atividade congela ao agendar:** atualizar uma pendente não teve efeito (peso 80 continuou, medido no simulador e no iPhone).
- A regra de peso 70 e de idade é conferida **para o horário em que o alerta vai aparecer**, não para o momento de agendar.
- Uma Atividade na tela nunca é trocada (cenário 25 da `FSC-017`).
- A escolha é igual para todo mundo: só peso público e data. **Quem a pessoa segue ou apoia não entra**, e apoio não sai do aparelho (lint `support_stays_private`).
- **Zero chamada direta:** o único endereço de dados do app é `FiscalDataURL`. A CDN fora do ar cai no cache e no pacote offline; sem eles, a tela mostra o erro que já existe.
- Sem opinião: o texto é o título e o subtítulo do fato, e uma estimativa continua mostrando a incerteza.

## Strategic Approach

### Solution Direction

A cada abertura, o app lê os destaques na CDN e monta o plano do próximo horário: agenda a Atividade com o destaque de maior peso que ainda vai valer naquele horário, e a notificação com o próximo destaque. O aparelho passa a decidir e disparar sozinho. Toda a leitura vai para a CDN, sem reserva na VPS, e somem o registro, o App Attest e o push, inclusive os da apuração. Na VPS sobram a carga, a leitura do TSE sem rota pública e a publicação no Pages. Antes de agendar, o app grava o bonequinho na prateleira do App Group, e a Atividade o lê como já faz na apuração. O alerta "na hora" some: abrir o app não inicia mais nada na tela.

### Key Design Decisions

| Decisão | Escolha | Trade-off | Porta |
| --- | --- | --- | --- |
| Horários | **Pergunta 1.** Recomendo Atividade às 08:00 e notificação às 19:00, no relógio do aparelho | Às 08:00 ela mostra o que foi aprovado até a noite anterior e termina às 16:00, sem sobrepor a notificação. Não há medição de uso por trás disso, porque o app ainda não saiu | pergunta |
| Conteúdo da notificação | **Pergunta 2.** Recomendo o segundo destaque de maior peso, diferente do da Atividade; com um só, não sai notificação | Duas informações por dia, sem repetir. Em dia fraco, fica sem notificação | pergunta |
| Permissão da notificação | **Pergunta 3.** Recomendo interruptor desligado, com a pergunta do iOS só quando a pessoa liga | Respeita quem não quer, e menos gente recebe. Reverte a regra "nunca por notificação comum" da `FSC-007` | pergunta |
| Saída da VPS | Remover do app `FiscalAPIURL`, a reserva, o registro e o App Attest; do servidor, o vigia, o APNs, o App Attest e as rotas públicas. Os arquivos de registro são apagados no deploy, com o ok do usuário | A VPS deixa de receber o app. Pedido do usuário | veto |
| Atividade da disputa | Sai com o botão de acompanhar e o push; a apuração continua no Feed e nas telas, pela CDN. Volta pelo git quando a próxima eleição se aproximar | Sem tela de bloqueio na apuração até lá. O usuário disse que não é preocupação agora | veto |
| Leitura do TSE | O `fiscal-api` fica só com a leitura que grava `races*.json`, sem rota pública, para não quebrar a publicação; renomear fica para depois | Um nome que já não descreve o serviço | veto |
| Rótulo da loja | Sem código de aparelho no servidor, a proposta é "Dados não coletados", num ADR que substitui o 0017. O preenchimento no App Store Connect é do usuário | Mais simples para quem lê; depende da conferência final do que sai do app | veto |
| CDN fora do ar | Sem servidor de reserva: cache, pacote offline e erro | Se o Pages cair, os dados param até voltar. Antes, a reserva não aguentaria a escala de 50 milhões (estimativa) | veto |
| Abrir o app | Não inicia mais a Atividade na hora | Respeita "uma vez por dia", e quem abre às 09:00 só vê a de amanhã | veto |
| Quanto agendar à frente | Só o próximo horário | Sem conteúdo velho e sem bater no limite. Quem não abre o app para de receber na manhã seguinte | veto |
| Retrato | Tela de bloqueio e Ilha expandida passam a mostrar o bonequinho; a Ilha compacta segue com o ícone; sem imagem, fica a silhueta atual | Pedido do usuário, com mudança visual para mostrar no iPhone | veto |
| Espalhar o horário | Cada aparelho soma um atraso fixo de até 10 min, para os toques não caírem no mesmo minuto | Cerca de 10 min de diferença entre aparelhos. A CDN é quem absorve; o ganho é uma estimativa | reversível |
| Atualizar a notificação em segundo plano | Se o iOS rodar a atualização existente, troca a notificação pendente pelo destaque novo | Conteúdo mais novo quando der, sem garantia. Depende de um teste no iPhone | reversível |
| Som | Sem som, se o iOS permitir, porque um horário fixo pode acordar alguém | A confirmar na API; se o iOS exigir som, volta como decisão no canvas | reversível |
| Retrato nos widgets | Fora desta mudança; vai ao backlog | Os widgets também caem na silhueta, pela leitura do código; o usuário pediu para mostrar variantes antes de ampliar | reversível |
| Regra e canvases | ADR novo; a `FSC-007` é atualizada por `spdd-prompt-update`; o cenário 26 da `FSC-017` deixa de valer com o deploy desta | O PR #16 entra primeiro, sem ser reaberto | reversível |

### Alternatives Considered

- **Manter a VPS só como reserva da leitura:** é o caminho que o usuário pediu para tirar, e não aguentaria todo o tráfego se a CDN caísse.
- **Manter o envio pela VPS com o limite de 8 h:** segue dependendo de token por aparelho. A estimativa de 03/11 no backlog fala em dias para atingir 50 milhões.
- **Canal de broadcast da Apple:** o canal só atualiza uma Atividade já iniciada, e o início segue exigindo token por aparelho.
- **Agendar vários dias de uma vez:** o conteúdo fica congelado e velho, e bate no limite medido de 5.
- **Trocar a Atividade pendente em segundo plano:** não funciona, porque criar falha com `visibility` e atualizar não tem efeito.

## Risk & Gap Analysis

| Critério de aceite | Coberto pela direção? | Lacuna ou risco |
| --- | --- | --- |
| Atividade uma vez por dia, com o app fechado | parcial | No simulador apareceu a até cerca de 40 s do horário. No iPhone, o registro mostra só que ficou pendente; falta confirmar que apareceu |
| Notificação em outro horário | parcial | Agendar com o app aberto é o uso comum da API, mas ainda não foi testado aqui, nem em segundo plano |
| Destaque fora da VPS | sim | O deploy e a remoção do arquivo de registros pedem o ok do usuário |
| Nenhuma chamada direta do app à VPS | sim | Prova: sem `FiscalAPIURL` nos alvos, teste no cliente e captura de rede no iPhone. Conferir o log de acesso da VPS exige a VPN desligada |
| VPS só alimenta a CDN | sim | Deploy, Caddy e remoção de arquivos pedem o ok do usuário. A branch da correção dos gastos também mexe em `server/`, então vem antes |
| Bonequinho na Atividade | parcial | Causa vista só na leitura do código; falta confirmar no iPhone. Um PNG grande pode não aparecer: a apuração usa 120 px, e o mesmo tamanho será testado |

- **Riscos:**
  - Quem não abre o app para de receber → é o custo aceito; fica escrito em Ajustes e no método, sem prometer aviso diário.
  - Conteúdo de até um dia atrás → a regra é conferida para o horário do alerta, e o texto mostra a data do fato.
  - O iOS pergunta se a pessoa permite Atividades na primeira vez → medido no simulador; a pessoa pode recusar, e o app não insiste.
  - Atividades de teste ainda no iPhone do usuário podem atrasar um alerta real até expirarem → a primeira instalação desta mudança as encerra.
  - `FSC-018` e esta mudança mexem em `spdd/README.md` e nos ADRs → a numeração é conferida no merge; o ADR novo será o 0028.
  - A VPS passa a não ter como enviar um destaque urgente → aceito pelo pedido.
  - Se a CDN ou o `release.json` falhar, hoje a reserva esconde isso → passa a aparecer como cache, offline ou erro; o teste cobre os três.
  - O Fiscal na Web e a `bridge/` estão parados e usam a VPS; o app não os chama → ficam de fora, e a volta deles depois da 1.0 precisa rever isso.
- **Lacunas:**
  - Horários, conteúdo e permissão: respondidos pelo usuário (08:00 e 19:00, segundo maior destaque, só ao ligar em Ajustes).
  - Textos públicos: `site/privacy.html`, a linha de Ajustes, o método e, se preciso, `docs/app-store/`. **Publicar o site pede o ok do usuário.**
  - Como contar o que "apareceu" sem o app rodando no horário: o canvas define isso a partir do estado da Atividade na abertura seguinte.
  - Medição: com o app sem uso real, nenhum número desta análise diz como o alerta se comporta com 50 milhões de pessoas; a parte de escala é estimativa.

Sigo para o canvas?
