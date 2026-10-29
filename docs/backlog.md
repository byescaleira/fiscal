# Backlog

O que falta, por prioridade. Itens concluídos saem daqui; o motivo das decisões fica em [adr/](adr/README.md) e o plano por fase no [roadmap](roadmap.md).

## Antes de distribuir

- **[P1] Live Activity da apuração ponta a ponta.** Etapas abertas da [`live-results`](changes/archive/2026-10-29-live-results/tasks.md): conferir a chave APNs em `/opt/fiscal-api/secrets/apns.p8` e a conta no Xcode (usuário), rodar o servidor em modo de simulação, iniciar a Live Activity no iPhone físico e receber os pushes de atualização e de fim.
- **[P1] Vencedor na Live Activity da apuração.** A regra de vencedor do widget (`RaceBoard.winner`) difere da do app (`Race.winner`) e mostra "ELEITO" a 100% no 1º turno com mais de 2 candidatos: igualar as duas ([FSC-001](../spdd/prompt/FSC-001-202610291700-[Codify]-live-results.md)). O toque já abre `fiscal://races`.
- **[P1] Rótulo de privacidade e política.** Declarar o rótulo do [ADR 0017](adr/0017-app-store-privacy-label.md) no App Store Connect e listar na política do site as três saídas com os prazos.
- **[P1] Retratos nos cartazes.** Marca visível "Ilustração do Fiscal" nos retratos e nos cartazes de vitória e de investigação, e a regra de não gerar cartaz de candidato com retrato nas 72 h antes e nas 24 h depois de uma votação ([brief](brief.md), "Retratos e marcas animados"); hoje nenhuma das duas existe.
- **[P1] Apagar a escolha da Lente.** A confirmação "Apagar minha escolha" existe no `LensScreen`, mas nenhum botão a abre; o brief pede o botão.
- **[P1] Testes do destaque na tela de bloqueio.** `HighlightAlertRule` e `HighlightAlertCenter` não têm testes (peso mínimo, janela de 24 h, ids já mostrados, desligar remove o token); a constituição pede Swift Testing para toda lógica.
- **[P1] Capabilities no portal da Apple.** Conferir no App ID `com.byescaleira.fiscal`: App Attest, Push Notifications, iCloud (`iCloud.fiscal`), App Group `group.com.byescaleira` e Background Modes, e o App Group na extensão dos widgets.
- **[P1] Capturas da loja pelo pipeline.** Gerar as capturas de [app-store/media/](app-store/media/README.md) com `launch.sh` e `compose.py` depois do texto final do site, trocando a SF Pro Rounded do `style.css` pela Bricolage nos títulos ([ADR 0009](adr/0009-bricolage-emphasis-font.md)), conferidas no iPhone físico.

## Depois da 1.0 ou sem data

- **[P2] Receita do Mac.** Lista de origem na barra lateral, `Table` nas listas longas, `GroupBox` nos painéis, comandos de menu e atalhos de teclado, antes de enviar o Mac para a loja.
- **[P2] Alvos `FiscalMock`, `FiscalPreview` e `FiscalAudit`.** Dados falsos compartilhados, prévias por tela e a auditoria do pacote (migração, prévia e volume), para o `scripts/audit.sh` deixar de pular.
- **[P2] Contrato do Fiscal na Web.** Resumo cifrado, ponte e pareamento por QR numa mudança própria ([ADR 0016](adr/0016-web-companion-after-1-0.md)).
- **[P2] Branch `feature/news-webngrams`.** Quatro commits fora da `development` que trocam a repercussão da API DOC do GDELT pelos arquivos Web NGrams; decidir entre integrar numa mudança própria ou descartar. Recomendado: manter a branch até a decisão.
- **[P2] Checagens no perfil.** A seção do perfil está desligada (`showsFactChecks = false`); ligar com o título "O que circulou sobre <nome>", o aviso de cobertura e o crédito por item, como no brief ([FSC-006](../spdd/prompt/FSC-006-202610291700-[Codify]-fact-checks.md)).
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

- **[P1] "Outra lente" não reordena nada**: nenhum model lê `LensContext.preview`.
- **[P2] Paleta, arte e ícone não mudam depois do setup**: `choose(_:)` e `setIcon(_:)` sem tela.
- **[P2] Erro ao salvar não aparece no setup**, só na `LensScreen`.
- **[P2] `ProgressView()` circular** no setup, nos temas, nos apoiados e na edição; trocar por barra (regra 5).
- **[P2] Durações e escalas soltas** no setup, nos temas, na tela e na prévia do visual.
- **[P3] Textos.** Passo de temas sem "12 + 5"; "Concluído" em vez de "Concluir"; "Mata e ouro" em vez de "Mata e Urucum". Decidir qual vale e registrar no canvas.
- **[P1] Testes** do limite de 5 apoiados, da sugestão de temas e "Estimado", das falhas de leitura e gravação, dos 450 ms, e dos testes de privacidade na `FiscalSchemaV3`.

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
- **[P2] Testes** dos pôsteres de investigação e de destaque, e do portão de licença do `art.py` e do `art-photos.py`. A marca dos retratos já está em "Retratos nos cartazes".

### Checagens ([FSC-006](../spdd/prompt/FSC-006-202610291700-[Codify]-fact-checks.md))

- **[P1] Plural das checagens**: "publicou 1 checagens"; usar variação de plural no catálogo (regra 6).
- **[P2] Selos em conflito publicam com `verdict` nulo** ("Sem selo") em vez de ir só para a revisão.
- **[P2] Pergunta some quando a leitura de `checks.json` falha**, sem frase de falha.
- **[P3] `possibleHomonym` pelo conjunto das checagens** e descarte de id ≤ 0 e data ilegível; registrar ou ajustar.
- **[P3] Contagem `checks` em `index/facts.json` sem uso no app.**
- **[P2] Testes** da investigação de checagens e da ausência da seção no perfil.

### Alertas ([FSC-007](../spdd/prompt/FSC-007-202610291700-[Codify]-notifications.md))

- **[P2] Atividade do destaque fora da Bricolage e com heavy** em tamanho fixo no título, no selo e no kicker (regra 5).
- **[P2] Rotas do destaque com o vigia desligado** respondem 401 antes do 404.
- **[P3] Um item por versão do arquivo**, não um por minuto; registrar ou ajustar.
- **[P3] `HighlightAlertCenter` no `AppShell`** e interruptor em Geral › Notificações; registrar no canvas se for o lugar certo.
- **[P2] Testes** do início local, de desligar a preferência, do link por tipo e dos códigos de erro das rotas `POST` e `DELETE /api/v1/highlight-activities`. Os testes da regra e do centro já estão em "Testes do destaque na tela de bloqueio".
