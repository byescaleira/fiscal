# 0015. Modo `fetch` em segundo plano para o pacote offline

- **Estado:** Aceito (2026-10-29)
- **Data:** 2026-10-29
- **Mudança:** [`align-workspace`](../changes/archive/2026-10-29-align-workspace/proposal.md)

## Contexto

Sem rede, o Fiscal mostra um pacote offline com o mínimo para consultas recentes (README, "Sempre no ar"). O pacote só é útil se estiver fresco quando a rede some, e atualizá-lo só com o app aberto deixa dados de dias atrás para quem abre pouco. O `Info.plist` já declara `UIBackgroundModes › fetch` e `BGTaskSchedulerPermittedIdentifiers › com.byescaleira.fiscal.offline-refresh`, e a revisão da Apple pergunta por que o app roda em segundo plano.

## Decisão

- Use o modo `fetch` com uma única tarefa `BGAppRefreshTask`, `com.byescaleira.fiscal.offline-refresh`, só para o pacote offline (`OfflineDataCenter`, `OfflinePackCoordinator`).
- Ao abrir, atualize o pacote se a última atualização tiver mais de 600 s; em segundo plano, peça a próxima execução para dali a pelo menos 4 h (`earliestBeginDate`) e deixe o sistema decidir quando.
- O pacote leva os arquivos-base (meta, índices de pessoas e lugares, Hoje, pauta, destaques, votações recentes e apuração), a UF e a cidade de casa e até 40 pessoas (seguidas e até 12 representantes; nunca as apoiadas na Lente), num orçamento de 12 MiB, em `Application Support/OfflinePack`, fora do backup. Release igual (`v2/release.json`) reaproveita os arquivos guardados.
- Nada mais roda nesse modo: sem processamento, sem upload, sem notificação.

## Consequências

- As notas de revisão explicam o modo `fetch` (pacote offline) e o `remote-notification` (sincronização do iCloud), e o roteiro de [validation.md](../validation.md) testa o `BGAppRefresh` no aparelho.
- As requisições do pacote são `GET` anônimos de arquivos públicos na CDN. A CDN vê o IP e os caminhos (perfis seguidos, representantes, região), como em qualquer abertura de perfil, e nunca as pessoas apoiadas na Lente: elas ficaram fora do pedido na revisão de segurança da `align-workspace`, para a política de privacidade valer também em segundo plano.
- O sistema pode adiar ou não rodar a tarefa (pouca bateria, Modo de Pouca Energia, app pouco usado); a abertura do app continua sendo o caminho garantido.
- A atualização obrigatória também vale aqui: com o app bloqueado, a tarefa não baixa nada (mudança `align-workspace`, etapa A.12).

## Alternativas consideradas

- **Só atualizar ao abrir:** mais simples, mas o pacote envelhece justamente para quem precisa dele sem rede.
- **Push silencioso do servidor para disparar a atualização:** exige guardar token de todos os aparelhos no servidor e contradiz o servidor estático ([ADR 0002](0002-static-first-server.md)).
- **`BGProcessingTask`:** pensado para trabalho longo com o aparelho carregando; o pacote é pequeno e cabe no `BGAppRefresh`.
