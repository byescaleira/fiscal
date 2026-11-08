# 0030. O site e os links universais na Cloudflare Pages

- **Estado:** Aceito (2026-11-08)
- **Data:** 2026-11-08
- **Mudança:** [FSC-025](../../spdd/prompt/FSC-025-202611081040-[Feat]-site-and-universal-links-on-cloudflare-pages.md)

## Contexto

O site de `fiscal.byescaleira.com` (`site/`) nunca foi publicado. O bloco do Caddy na VPS termina em `respond 404`, e o arquivo dos links universais (`/.well-known/apple-app-site-association`) também responde 404. Por isso os links que os cartões de compartilhar imprimem abrem o navegador, não o app. O robô da Apple recebe 404 desde pelo menos 01/11/2026. Com o [ADR 0028](0028-app-reads-only-from-cdn-and-local-alerts.md), a VPS fica só para alimentar a CDN. Os dados públicos já saem pela Cloudflare Pages, no projeto `fiscal-dados`.

## Decisão

1. O site estático e o arquivo dos links universais ficam num projeto próprio da Cloudflare Pages, o `fiscal-site`, com o domínio `fiscal.byescaleira.com`. Decisão do usuário em 07/11/2026.
2. A publicação é por Direct Upload, a partir do Mac, na worktree de integração. Um script monta a pasta e por padrão só mostra o plano; com `--apply`, publica com o `wrangler` de versão fixa. O login do `wrangler` é do usuário, no app Terminal. Decisão do usuário em 08/11/2026.
3. Sobem as páginas públicas, os arquivos delas e o arquivo da Apple. O Fiscal na Web fica de fora até depois da 1.0 ([ADR 0016](0016-web-companion-after-1-0.md)). Um `_headers` dá o tipo `application/json` ao arquivo da Apple e os cabeçalhos de segurança e de cache. Um `404.html` faz caminho desconhecido responder 404.
4. Na Vercel, o registro `fiscal` deixa de ser um A para a VPS e passa a ser um CNAME para `fiscal-site.pages.dev`, como o `dados.fiscal`. Depois disso, o bloco do Caddy desse domínio sai.
5. A primeira publicação vem depois do deploy e da limpeza da VPS da FSC-020, para a política de privacidade publicada ser verdadeira. Decisão do usuário em 08/11/2026.

## Consequências

- A VPS deixa de receber qualquer tráfego de `fiscal.byescaleira.com`, inclusive os pedidos de builds antigos em `/api/*`, que passam a receber o 404 da Pages.
- O log de acesso da VPS deixa de ver esse domínio. A conferência de que o app não chama a VPS (cenário 33 da FSC-020) vem antes da troca do DNS.
- O admin e a ponte, quando entrarem, precisam de um host próprio apontando para a VPS (por exemplo, `admin.fiscal.byescaleira.com`). A passkey do admin usa o RP ID `fiscal.byescaleira.com`, que continua válido num subdomínio.
- Volta atrás: o registro A anterior na Vercel, com o TTL anotado antes da troca.
- O plano Free da Pages aceita o projeto a mais. Um site estático muda pouco, e o orçamento de deploys do `fiscal-dados` não é afetado.

## Alternativas consideradas

- **Site no Caddy da VPS:** mantém tráfego público na VPS, contra o ADR 0028.
- **Integração Git da Pages:** publicaria sem pedido a cada push e criaria prévias públicas de branch.
- **Publicar pela VPS, com o token que já está lá:** põe o site no ciclo do servidor.
- **Mesmo projeto do `fiscal-dados`:** o limite de 20 mil arquivos e o orçamento de deploys ficariam divididos, e os dados apareceriam em `fiscal.byescaleira.com/v2/…`.
