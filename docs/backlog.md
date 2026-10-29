# Backlog

O que falta, por prioridade. Itens concluídos saem daqui; o motivo das decisões fica em [adr/](adr/README.md) e o plano por fase no [roadmap](roadmap.md).

## Antes de distribuir

- **[P1] Live Activity da apuração ponta a ponta.** Etapas abertas da [`live-results`](changes/archive/2026-10-29-live-results/tasks.md): conferir a chave APNs em `/opt/fiscal-api/secrets/apns.p8` e a conta no Xcode (usuário), rodar o servidor em modo de simulação, iniciar a Live Activity no iPhone físico e receber os pushes de atualização e de fim.
- **[P1] Toque na Live Activity da apuração.** O `widgetURL` é `fiscal://home`, um host que o app não conhece e que cai em Hoje; deve abrir `fiscal://races`. A regra de vencedor do widget (`RaceBoard`) também difere da do app (`Race+Decision`): igualar as duas.
- **[P1] Rótulo de privacidade e política.** Aprovar o [ADR 0017](adr/0017-app-store-privacy-label.md), declarar o rótulo no App Store Connect e listar na política do site as três saídas com os prazos.
- **[P1] Retratos nos cartazes.** Marca visível "Ilustração do Fiscal" nos retratos e nos cartazes de vitória e de investigação, e a regra de não gerar cartaz de candidato com retrato nas 72 h antes e nas 24 h depois de uma votação ([brief](brief.md), "Retratos e marcas animados"); hoje nenhuma das duas existe.
- **[P1] Apagar a escolha da Lente.** A confirmação "Apagar minha escolha" existe no `LensScreen`, mas nenhum botão a abre; o brief pede o botão.
- **[P1] Lente e pacote offline.** O pacote offline baixa os perfis das pessoas apoiadas junto com as seguidas e os representantes; decidir se isso fica (a CDN vê só o IP e os caminhos) ou se as apoiadas saem do pacote, e alinhar o rodapé "nunca em requisições" e o "Seu lugar ... nunca o envia", já que a cidade de casa também entra no pacote ([ADR 0015](adr/0015-background-fetch-offline-pack.md)).
- **[P1] Testes do destaque na tela de bloqueio.** `HighlightAlertRule` e `HighlightAlertCenter` não têm testes (peso mínimo, janela de 24 h, ids já mostrados, desligar remove o token); a constituição pede Swift Testing para toda lógica.
- **[P1] Capabilities no portal da Apple.** Conferir no App ID `com.byescaleira.fiscal`: App Attest, Push Notifications, iCloud (`iCloud.fiscal`), App Group `group.com.byescaleira` e Background Modes, e o App Group na extensão dos widgets.
- **[P1] Capturas da loja pelo pipeline.** Gerar as capturas de [app-store/media/](app-store/media/README.md) com `launch.sh` e `compose.py` depois do texto final do site, trocando a SF Pro Rounded do `style.css` pela Bricolage nos títulos ([ADR 0009](adr/0009-bricolage-emphasis-font.md)), conferidas no iPhone físico.
- **[P1] ADRs à espera do usuário.** Aceitar ou recusar 0004, 0005 e 0007 (já rodam em produção), 0015 e 0017.

## Depois da 1.0 ou sem data

- **[P2] Receita do Mac.** Lista de origem na barra lateral, `Table` nas listas longas, `GroupBox` nos painéis, comandos de menu e atalhos de teclado, antes de enviar o Mac para a loja.
- **[P2] Alvos `FiscalMock`, `FiscalPreview` e `FiscalAudit`.** Dados falsos compartilhados, prévias por tela e a auditoria do pacote (migração, prévia e volume), para o `scripts/audit.sh` deixar de pular.
- **[P2] Contrato do Fiscal na Web.** Resumo cifrado, ponte e pareamento por QR numa mudança própria ([ADR 0016](adr/0016-web-companion-after-1-0.md)).
- **[P2] Branch `feature/news-webngrams`.** Quatro commits fora da `development` que trocam a repercussão da API DOC do GDELT pelos arquivos Web NGrams; decidir entre integrar numa mudança própria ou descartar. Recomendado: manter a branch até a decisão.
- **[P2] Checagens no perfil.** A seção do perfil está desligada (`showsFactChecks = false`); ligar com o título "O que circulou sobre <nome>", o aviso de cobertura e o crédito por item, como no brief ([fact-checks.md](specs/fact-checks.md)).
- **[P2] Alertas por tema nas votações e emendas no Dinheiro.** O que ficou da fase 5 e da fase 6 do roadmap.
- **[P2] Broadcast do APNs.** Trocar o push por token do destaque pelos canais de broadcast quando o volume pedir ([ADR 0002](adr/0002-static-first-server.md)).
- **[P2] `scripts/ui-test.sh`.** O destino padrão (`iPad Pro 13-inch (M5)`, `OS=27.0`) não existe mais nesta máquina; escolher um iPad disponível como o `scripts/test.sh` faz com o iPhone.
