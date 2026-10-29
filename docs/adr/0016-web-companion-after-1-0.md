# 0016. Fiscal na Web só depois da 1.0

- **Estado:** Aceito
- **Data:** 2026-10-29
- **Mudança:** [`align-workspace`](../changes/align-workspace/proposal.md)

## Contexto

O template traz o Fiscal na Web em `/app` (`site/app.html`, `site/web*.js`): uma versão só de leitura num computador, pareada com o iPhone por QR, com o resumo cifrado passando por uma ponte na VPS (`bridge/`). No Fiscal, a ponte não está publicada (`FiscalWebBridgeURL` vazio no `Info.plist`, sem serviço no [runbook](../server-runbook.md)), o app não monta o resumo para a web e o contrato do recurso não existe. O [roadmap](../roadmap.md) põe o Fiscal na Web em "Depois da 1.0", e a regra do site é nunca anunciar recurso que não existe.

## Decisão

- O Fiscal na Web fica para depois da 1.0. Até lá, o site não tem link para `/app`, nem seção `#web`, nem item da política sobre a ponte, e a página da loja e o README não citam o recurso.
- A ponte (`bridge/`) não é publicada na VPS e `FiscalWebBridgeURL` continua vazio; o código do template fica no repositório, testado pelo `verify.sh`, para servir de base.
- O recurso volta por uma mudança própria em `docs/changes/<id>/`, com o contrato do resumo, a revisão de segurança da cifra e da ponte e o deploy pedido ao usuário.

## Consequências

- O app não oferece "Abrir no computador" nem pareamento por QR; os testes da ponte e da cifra continuam no `verify.sh`.
- A política de privacidade não precisa da ponte enquanto ela não existe; quando o recurso entrar, a política e o rótulo da loja mudam junto.
- O item "Contrato do Fiscal na Web" fica no [backlog](../backlog.md).

## Alternativas consideradas

- **Lançar a web junto com a 1.0:** acrescenta servidor, cifra e revisão de segurança a uma versão que já tem apuração, carga de dados e loja; o usuário pôs a web depois.
- **Apagar o código do template:** perderia a base testada da cifra v2 e da ponte que o recurso vai usar.
