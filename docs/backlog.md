# Backlog

O que falta, por prioridade. Itens concluídos saem daqui; o motivo das decisões fica em [adr/](adr/README.md) e o plano por fase no [roadmap](roadmap.md).

## Antes de distribuir

- **[P1] Live Activity da apuração ponta a ponta.** Etapas abertas da [`live-results`](changes/archive/2026-10-29-live-results/tasks.md): conferir a chave APNs em `/opt/fiscal-api/secrets/apns.p8` e a conta no Xcode (usuário), rodar o servidor em modo de simulação, iniciar a Live Activity no iPhone físico e receber os pushes de atualização e de fim.
- **[P1] Vencedor na Live Activity da apuração.** A regra de vencedor do widget (`RaceBoard.winner`) difere da do app (`Race.winner`) e mostra "ELEITO" a 100% no 1º turno com mais de 2 candidatos: igualar as duas ([FSC-001](../spdd/prompt/FSC-001-202610291700-[Codify]-live-results.md)). O toque já abre `fiscal://races`.
- **[P1] Rótulo de privacidade e política.** Declarar o rótulo do [ADR 0017](adr/0017-app-store-privacy-label.md) no App Store Connect e listar na política do site as três saídas com os prazos.
- **[P1] Retratos do app.** A marca "Ilustração do Fiscal" entrou no retrato grande do perfil na [FSC-014](../spdd/prompt/FSC-014-202611020300-[Feat]-politician-page-and-share-an-item.md). Faltam a marca nos outros retratos grandes e a regra de não gerar cartaz de candidato com retrato nas 72 h antes e nas 24 h depois de uma votação ([brief](brief.md), "Retratos e marcas animados").
- **[P1] App ID da Meta.** Criar o app na Meta e preencher `FiscalMetaAppID` no `Info.plist`. Sem ele, os Stories do Instagram e do Facebook abrem pela folha do sistema ([ADR 0020](adr/0020-share-to-social-networks.md)).
- **[P1] Publicar a AASA dos links do site.** Com o ok do usuário. Antes disso, os links impressos nos cartões abrem o site, não o app ([docs/web.md](web.md)).
- **[P1] Apagar a escolha da Lente.** A confirmação "Apagar minha escolha" existe no `LensScreen`, mas nenhum botão a abre; o brief pede o botão.
- **[P1] Testes do destaque na tela de bloqueio.** `HighlightAlertRule` e `HighlightAlertCenter` não têm testes (peso mínimo, janela de 24 h, ids já mostrados, desligar remove o token); a constituição pede Swift Testing para toda lógica.
- **[P1] Capabilities no portal da Apple.** Conferir no App ID `com.byescaleira.fiscal`: App Attest, Push Notifications, iCloud (`iCloud.fiscal`), App Group `group.com.byescaleira` e Background Modes, e o App Group na extensão dos widgets.
- **[P1] Capturas da loja pelo pipeline.** Gerar as capturas de [app-store/media/](app-store/media/README.md) com `launch.sh` e `compose.py` depois do texto final do site, trocando a SF Pro Rounded do `style.css` pela Bricolage nos títulos ([ADR 0009](adr/0009-bricolage-emphasis-font.md)), conferidas no iPhone físico.

- **[P2] "Como medimos" no cartão "Na sua região agora".** O botão aparece só com o ícone, sem o texto, sobre o fundo escuro. Visto no simulador na `FSC-011`, fora do canvas dela.
- **[P2] Selo "Pior que a média" cortado em "Pior que a mé...".** No cartão de "Quem Gasta Mais e em Quê", em largura estreita. Rever também se a palavra "pior" cabe na regra de só fatos.
- **[P1] Mesma pessoa com dois partidos.** Medido em 02/11/2026: 264 pessoas têm partidos diferentes entre `index/people.json` e `places/<uf>.json`. Riedel é PSDB no índice e PP na lista de MS. Vem da montagem no servidor; mudança separada, combinada com o usuário, junto com a carga parada.
- **[P1] Dados publicados parados em 28/10.** Em 02/11/2026, o `meta.json` publicado traz `generatedAt` de 28/10, e a pauta também. O site diz que a pauta é lida de 5 em 5 minutos. Visto na [FSC-015](../spdd/prompt/FSC-015-202611021500-[Feat]-sticky-bar-votes-region-tabs.md); falta olhar a carga na VPS, com o ok do usuário.
- **[P2] Maior tamanho de texto em telas antigas.** Na corrida, o nome do candidato corta em "L..." e o percentual quebra no meio ("50,0 / 4%"). No gráfico mensal das notas, as iniciais dos meses se sobrepõem e o valor do eixo some. Visto na [FSC-015](../spdd/prompt/FSC-015-202611021500-[Feat]-sticky-bar-votes-region-tabs.md), fora do canvas dela.
- **[P2] Repensar o antes e durante o mandato.** Saiu da página do político na [FSC-014](../spdd/prompt/FSC-014-202611020300-[Feat]-politician-page-and-share-an-item.md), porque o usuário achou que o componente não se encaixa no app, embora os dados importem. Os arquivos seguem publicados e a Investigação segue lendo. Falta uma forma nova.
- **[P3] Duo dobrado: espaço acima dos filtros do Feed.** Ao rolar para cima, o sistema devolve a área da barra de navegação e os filtros fixos descem 58 pt, com um espaço branco acima ([QA da `FSC-013`](evidence/FSC-013/qa.md)).
- **[P2] Capturas do README e da loja.** `01-hoje.png` e as outras ainda mostram as abas antigas; refazer antes da publicação.
- **[P3] Cartão "Na sua região agora" com o texto oficial.** O do Feed já usa o texto simples, e a tela de conteúdo também.

- **[P2] Validar o esquema das URLs na publicação.** O servidor repassa o que as fontes mandam. A tela de conteúdo já recusa o que não é `http` ou `https`; os outros pontos do app e `server/internal/publicdata` ainda não. Precisa de deploy, com o ok do usuário.

- **[P2] Arquivos auxiliares do banco do aparelho.** A exclusão do backup marca `-wal` e `-shm` só se já existirem na abertura, e o `groupContainer` do `Device.store` não foi conferido. Vale conferir com o app rodando, porque o apoio mora nesse banco.

- **[P2] Validar a carta colecionável no iPhone.** A variante "Carta" foi escolhida sem teste no aparelho ("Não consigo validar agora, vamos seguindo", 06/11/2026). Faltam a inclinação, o giro com os botões e a medição de quadros ao abrir a página; um ajuste muda só os tokens do kit ([FSC-023](../spdd/prompt/FSC-023-202611052151-[Feat]-plenary-and-holographic-card.md)).
- **[P2] Custo dos efeitos medido.** Instruments (SwiftUI e Metal System Trace) e o Power Profiler num iPhone antigo, com o plenário e a carta, antes de levar shader para outra tela ([ADR 0026](adr/0026-shader-effects-never-carry-data.md)).

## Depois da 1.0 ou sem data

- **[P2] Onda no curtir.** O `byescaleira-kit` 0.10.0 já tem `View.ripple(origin:trigger:)`; ela entra com a mudança de curtir, só em conteúdo SwiftUI ([FSC-023](../spdd/prompt/FSC-023-202611052151-[Feat]-plenary-and-holographic-card.md)).
- **[P2] Linha de quórum da PLP e da maioria simples.** Lei complementar pede maioria absoluta (art. 69 da Constituição: 257 na Câmara, 41 no Senado), mas a mesma proposição também tem votações de requerimento e de destaque, em que a regra é outra. A linha só entra quando o dado disser o tipo de cada votação.
- **[P2] Mac: grade do painel.** Dinheiro em `CardGrid` com cartões de tamanhos diferentes (herói em duas colunas, métricas pequenas); a lista de origem, as tabelas, o `GroupBox` e o menu Ir entraram na `FSC-008`.
- **[P2] Capturas do iPhone Duo.** Aberto, meio aberto em pé e deitado e AX no simulador, com a postura trocada à mão no Device Hub (puladas na `FSC-008` a pedido do usuário; a lógica está coberta pelo `FoldNavigationTests`).
- **[P3] Workspace: `asc.py` mais estrito.** Aceitar só URLs da API da Apple no `call` e no `links.next`, e trocar os `assert` do DER por saída com erro (no template do workspace, revisão de segurança da `FSC-008`).
- **[P2] Alvos `FiscalMock`, `FiscalPreview` e `FiscalAudit`.** Dados falsos compartilhados, prévias por tela e a auditoria do pacote (migração, prévia e volume), para o `scripts/audit.sh` deixar de pular.
- **[P2] Contrato do Fiscal na Web.** Resumo cifrado, ponte e pareamento por QR numa mudança própria ([ADR 0016](adr/0016-web-companion-after-1-0.md)).
- **[P2] Branch `feature/news-webngrams`.** Quatro commits fora da `development` que trocam a repercussão da API DOC do GDELT pelos arquivos Web NGrams; decidir entre integrar numa mudança própria ou descartar. Recomendado: manter a branch até a decisão.
- **[P2] Alertas por tema nas votações e emendas no Dinheiro.** O que ficou da fase 5 e da fase 6 do roadmap.
- **[P2] Broadcast do APNs.** Trocar o push por token do destaque pelos canais de broadcast quando o volume pedir ([ADR 0002](adr/0002-static-first-server.md)); vale para a apuração e o destaque ([FSC-001](../spdd/prompt/FSC-001-202610291700-[Codify]-live-results.md), [FSC-007](../spdd/prompt/FSC-007-202610291700-[Codify]-notifications.md)).
- **[P2] `scripts/ui-test.sh`.** O destino padrão (`iPad Pro 13-inch (M5)`, `OS=27.0`) não existe mais nesta máquina; escolher um iPad disponível como o `scripts/test.sh` faz com o iPhone.

## Divergências dos canvases `[Codify]`

Registradas na migração para o SPDD ([ADR 0019](adr/0019-spdd-process.md)), sem correção. Cada uma vira uma mudança com canvas ou um S; o detalhe, com arquivo e linha, está em "Known divergences" do canvas. Quem muda o comportamento atualiza o canvas antes pelo `spdd-prompt-update`.

### Decisões do usuário

- **[P1] Lista de quem gasta mais em Dinheiro.** `placeQuota` publica só quem ficou "Pior que a média" na cota, do maior gasto para o menor, contra a regra 14 (sem ranking de pessoas). Decidir entre tirar a ordem, mostrar todos ou registrar a exceção num ADR ([FSC-004](../spdd/prompt/FSC-004-202610291700-[Codify]-credibility.md)).
- **[P1] Apoiados da Lente no iCloud.** Os apoiados viram seguidos e sincronizam pelo CloudKit, e entram no pacote offline, enquanto o cartão de cadeado diz que a escolha não entra no iCloud. Decidir entre separar apoio de seguir ou mudar o texto ([FSC-003](../spdd/prompt/FSC-003-202610291700-[Codify]-lens.md)).
- **[P2] Dependência do Projeto Comprova sem ADR.** Registrar a fonte externa (CC BY-ND 4.0) e a exigência de autorização das outras agências ([FSC-006](../spdd/prompt/FSC-006-202610291700-[Codify]-fact-checks.md)).
- **[P2] ADRs desatualizados.** O ADR 0007 diz 5 min para o desafio do App Attest (o código usa 2 min) e o ADR 0004 cita `FiscalSchemaV1` (o banco usa a V3).

### Apuração ao vivo ([FSC-001](../spdd/prompt/FSC-001-202610291700-[Codify]-live-results.md))

- **[P1] VoiceOver da Live Activity lê "0,00%" e "0 votos"** antes da apuração, em vez de "—" (regra 14).
- **[P2] Filtro "decididas" usa só `final`**, e uma disputa a 100% sem `tf` mostra "Resultado final" no cartão e fica em "Em apuração".
- **[P2] Aviso sem rede.** Com o pacote offline respondendo aparece a barra global, não "Sem conexão. Mostrando os últimos números recebidos.".
- **[P2] `DELETE /api/v1/live-activities`** manda só `{pushToken, challenge}`; alinhar o contrato descrito.
- **[P2] Job `apuracao`** é só um registro na cadência; quem lê o TSE é o `fiscal-api`.
- **[P2] `minimumScaleFactor` com números soltos** em `RaceHeroCard` e `RaceCompactCard`; usar tokens.
- **[P2] `numericText` na Live Activity sem Reduzir movimento.**
- **[P2] Chave `AppAttestKeyID` sem o prefixo `fiscal.`** (mudar exige migrar a chave guardada).
- **[P1] Testes de `Race.isDecided` e `Race.winner`**, e das telas da Live Activity.

### Dados públicos ([FSC-002](../spdd/prompt/FSC-002-202610291700-[Codify]-public-data-api.md))

- **[P2] `docs/validation.md` linha 62** diz que os apoiados abrem do pacote offline; o pacote não os leva pela Lente.
- **[P2] 429 ou 5xx com cópia em cache** devolvem a cópia sem a barra offline.
- **[P3] Limite de 6 s e `maxAge` de 30 s da origem quente** não estão no app: o `maxAge` vai no `release.json` e os 30 s vêm do Caddy. Registrar no canvas ou levar ao app.
- **[P2] Pacote offline passa de 12 MiB** com a última pessoa; o corte não conta os arquivos-base.
- **[P2] Intervalo de 600 s do pacote só na memória**; todo processo novo atualiza na primeira abertura.
- **[P3] Validação de queda, tentativas de deploy e `PAGES_DATA_INTERVAL`.** Queda ">20%" estrita e também por pessoas; espera dobrada (30 s e 60 s); intervalo só para as releases quentes. Registrar no canvas se for intencional.
- **[P2] Testes dos textos de `PublicDataError`, da barra offline, do agendamento da `BGAppRefreshTask` e do corte em 12 MiB.**

### Lente ([FSC-003](../spdd/prompt/FSC-003-202610291700-[Codify]-lens.md))

Substituída pela [FSC-012](../spdd/prompt/FSC-012-202611012040-[Feat]-end-of-lens-my-support.md). As divergências daqui deixaram de existir com a retirada da Lente.

### Credibilidade ([FSC-004](../spdd/prompt/FSC-004-202610291700-[Codify]-credibility.md))

- **[P2] Quatro formatos de rodapé de fonte** (`TodayModel.sourceLine`, `MoneyText.sourceLine` com "Fonte: —", `MemoryText.sources`, `SourceFootnote`) e dois carimbos de data; unificar no `SourceFootnote`.
- **[P2] Faixa p25 a p75 só no `PeerMethodSheet`**; o perfil e Comparar mostram só a mediana.
- **[P3] Seis tipos de `Explanation` sem uso** (contagem, preço, presença, propostas, discursos, cota).
- **[P3] `ProfileModel.numbersExplanation` no arquivo da view**; mover para `ProfileModel+<Assunto>.swift`.
- **[P1] Testes** de `BandOf` e do mínimo de 5 colegas, da fórmula do peso e `RelevanceOf`, de `PeerClassification`, de `WeightCoverage`, das linhas "Estimado", de `Explainer` e `ExplainerGuard`, e de `IndicatorFormat` com valor ausente.

### Cartazes e acervo ([FSC-005](../spdd/prompt/FSC-005-202610291700-[Codify]-share-cards-and-art.md))

- **[P2] Explicação de "Melhor que a média" só no Stories**; os outros formatos levam a faixa sem a linha que a explica (regra 14).
- **[P2] VoiceOver sem "Ilustração de {nome}"** na prévia dos cartazes com retrato.
- **[P2] Fatos e nota nos três formatos**, não só no Stories; decidir qual vale.
- **[P2] Galeria mostra o `holder`**, não o acervo.
- **[P2] QR da bancada com `place`** e investigação sem pessoa única caindo na raiz do site.
- **[P2] Pôster de vitória com SF heavy em tamanho fixo**, galeria sem `.monospacedDigit()` e `scaleEffect` 0.94 solto.
- **[P2] Testes** do pôster de destaque e do portão de licença do `art.py` e do `art-photos.py`. A marca dos retratos já está em "Retratos do app".

### Checagens ([FSC-006](../spdd/prompt/FSC-006-202610291700-[Codify]-fact-checks.md))

- **[P1] Plural das checagens**: "publicou 1 checagens"; usar variação de plural no catálogo (regra 6).
- **[P2] Selos em conflito publicam com `verdict` nulo** ("Sem selo") em vez de ir só para a revisão.
- **[P2] Pergunta some quando a leitura de `checks.json` falha**, sem frase de falha.
- **[P3] `possibleHomonym` pelo conjunto das checagens** e descarte de id ≤ 0 e data ilegível; registrar ou ajustar.
- **[P3] Contagem `checks` em `index/facts.json` sem uso no app.**
- **[P2] Testes** da investigação de checagens.

### Alertas ([FSC-007](../spdd/prompt/FSC-007-202610291700-[Codify]-notifications.md))

- **[P2] Atividade do destaque fora da Bricolage e com heavy** em tamanho fixo no título, no selo e no kicker (regra 5).
- **[P2] Rotas do destaque com o vigia desligado** respondem 401 antes do 404.
- **[P3] Um item por versão do arquivo**, não um por minuto; registrar ou ajustar.
- **[P3] `HighlightAlertCenter` no `AppShell`** e interruptor em Geral › Notificações; registrar no canvas se for o lugar certo.
- **[P2] Testes** do início local, de desligar a preferência, do link por tipo e dos códigos de erro das rotas `POST` e `DELETE /api/v1/highlight-activities`. Os testes da regra e do centro já estão em "Testes do destaque na tela de bloqueio".
