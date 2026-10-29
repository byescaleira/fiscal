# Alertas

O Fiscal avisa a pessoa só por Atividades ao Vivo: o resultado de uma disputa que ela segue e o destaque do momento de maior peso. Não há notificação comum nem pedido de permissão de notificações. Os alertas são raros e iguais para todo mundo: o servidor não sabe quem é a pessoa nem o que ela apoia. O que falta fazer está em [backlog.md](../backlog.md).

## Princípios

- **Raro.** Só quando o dado pede: o fim de uma disputa seguida ou um destaque de peso 85 ou mais do último dia, nunca rotina diária.
- **Igual para todos.** O destaque é o mesmo para qualquer pessoa; a Lente nunca escolhe nem muda o alerta.
- **Só um código anônimo sai do aparelho.** O registro leva o token de push da Apple e o ambiente, protegido por App Attest; nada da Lente, do lugar ou dos seguidos.
- **Desligar é fácil.** O destaque se desliga em Ajustes; a disputa, ao deixar de segui-la.

## Onde fica

| Target | O que fica nele |
| --- | --- |
| `FiscalDomain` | `HighlightAlertRule` (peso mínimo, janela, ids já mostrados, preferência), `HighlightActivityAttributes`, `VoteBoard` (links) |
| `FeatureLiveResults` | `HighlightActivities` (token de push-to-start, início local, uma por vez), `HighlightAlertCenter` (registro e remoção), `RaceActivities` |
| `FeatureSettings` | Interruptor "Destaques de maior peso na tela de bloqueio" em Seus dados e privacidade (só iOS) |
| `AppShell` | `SystemIntegrations` (ativa o centro na abertura e ao voltar para o primeiro plano) |
| `Fiscal/FiscalWidgets` | `HighlightLiveActivity`, `RaceLiveActivity` |
| `server/` (`internal/highlightalert`, `internal/apns`, `internal/store`) | Vigia de `highlights.json`, registros e envio APNs |

## Mecânicas e regras

### Destaque do momento

- Elegível: peso 85 ou mais e até 24 h depois do fim do dia do item, no horário de Brasília. O app pode receber outra regra pelo `method.alertRule` publicado.
- O servidor confere `PUBLIC_DIR/published/highlights.json` a cada 1 min e escolhe no máximo um item por vez; cada item sai uma vez só (os enviados ficam 14 dias). O app lembra os últimos 60 ids mostrados.
- Envio: push-to-start da Atividade ao Vivo do destaque, título "Destaque do momento", corpo de até 140 caracteres, carga de até 4.000 bytes; um push por token, com 8 envios em paralelo. Não há limite diário além da regra.
- O app também inicia a Atividade localmente quando acha um destaque elegível; só uma roda por vez e nunca duas vezes o mesmo item. A Atividade dura 8 h.
- Tocar abre `fiscal://person/{slug}` para uma ação, `fiscal://vote/{id}` para uma votação e Hoje no resto.
- O servidor só liga as rotas com `HIGHLIGHT_ALERTS=1` (padrão); com 0, elas respondem 404.

### Preferência

- "Destaques de maior peso na tela de bloqueio", em Ajustes › Seus dados e privacidade, com o texto "Só peso 85 ou mais, do último dia. O Fiscal envia só um código anônimo da Apple." Vem **ligado** e depende de as Atividades ao Vivo estarem permitidas no aparelho.
- Desligar encerra a Atividade em andamento e remove o token do servidor.

### Registro do destaque

- `POST` e `DELETE /api/v1/highlight-activities` com o token e o ambiente, sob App Attest ([live-results.md](live-results.md#app-attest)).
- O servidor guarda token, ambiente e data em `highlight-registrations.json`, sem IP; vale 30 dias e renova a cada registro. No máximo 200.000 registros e 100 por origem.

### Resultado da disputa

- A pessoa segue a disputa na Apuração; o servidor manda as atualizações e o fim com o alerta "Resultado" ([live-results.md](live-results.md#atividade-ao-vivo)). Tocar na Atividade abre o app em Hoje (`fiscal://home`, que o app trata como Hoje; ver o [backlog](../backlog.md)).

### O que não existe

- Notificação comum, `UNUserNotificationCenter` e pedido de permissão de notificações.
- Canal de broadcast do APNs; o envio é por token.
- Alerta por tema ou por pessoa seguida.

## Construção

1. **Domínio:** `RaceActivityPlanTests` em `FiscalDomainTests` para a Atividade da disputa. A regra do destaque (`HighlightAlertRule`) e o `HighlightAlertCenter` ainda não têm testes ([backlog](../backlog.md)).
2. **Feature:** `LiveResultsModelTests`; `SettingsModelTests` para os Ajustes.
3. **Servidor:** `internal/highlightalert`, `internal/apns`, `internal/store` e `internal/httpapi`, com `go test ./...`.
4. **Textos:** pt-BR no app, nos widgets e no corpo do push.

## O que fica com você

- A chave APNs na VPS e o deploy do `fiscal-api` ([runbook](../server-runbook.md)).
- O rótulo de privacidade com os tokens guardados ([ADR 0017](../adr/0017-app-store-privacy-label.md)).

## Histórico

| Data | Mudança ou ADR |
| --- | --- |
| 2026-10-29 | [0017](../adr/0017-app-store-privacy-label.md) |
| 2026-10-29 | [`app-1.0`](../changes/archive/2026-10-29-app-1.0/proposal.md), com a regra do [peso](../changes/archive/2026-10-29-app-1.0/weight.md) |
| 2026-10-25 | [`live-results`](../changes/archive/2026-10-29-live-results/proposal.md) |
