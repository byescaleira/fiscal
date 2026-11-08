# SPDD Analysis: Site e links universais na Cloudflare Pages

## Original Requirement

Na revisão da `FSC-020`, em 07/11/2026, o log de acesso da VPS mostrou que o robô da Apple (`AASA-Bot`) recebe 404 ao buscar o arquivo dos links universais de `fiscal.byescaleira.com`, e que a raiz do site também responde 404. À pergunta "Onde eles devem ficar?", o usuário respondeu:

> "Cloudflare Pages (Recomendado)"

Em 08/11/2026, ao receber a proposta de sessão para esta análise:

> "Faça esta tarefa aqui: 'FSC-025: site e links universais na Cloudflare Pages'"

## Domain Concept Identification

### Existing Concepts

- **O site (`site/`).** São 24 arquivos estáticos, 884 KB: `index.html`, `privacy.html`, `terms.html`, `support.html`, `llms.txt`, `style.css`, `assets/`, `fonts/` e `.well-known/apple-app-site-association`. Também estão no repositório o Fiscal na Web (`app.html`, `app.js`, `web*.js`, `web.css`, `link.html`, `vendor/`) e o teste `web-crypto.test.mjs`, que não sobem ([ADR 0016](../../docs/adr/0016-web-companion-after-1-0.md), [docs/web.md](../../docs/web.md#publicar)).
- **O site nunca foi publicado.** O bloco do Caddy em `fiscal.byescaleira.com` termina em `respond 404` ([runbook](../../docs/server-runbook.md), seções 7 e 9). A receita de publicação em `docs/web.md` é um `rsync` para `/opt/fiscal-site/public` na VPS, que nunca rodou.
- **O arquivo dos links universais (AASA).** Ele lista `appIDs: Q7QLR2PH2X.com.byescaleira.fiscal` e um `components` por chave na raiz: `?person=`, `?vote=`, `?expenses=`, `?compare=`, `?place=`, `?race=` e `?highlight=`, além de `/link`. São os links que os cartões de compartilhar imprimem (`ShareCardBuilder.host`) e que o `DeepLink` do app abre.
- **O app.** Tem `applinks:fiscal.byescaleira.com` nas permissões e abre no navegador as páginas `/support`, `/privacy` e `/terms`, sem `.html` (`Info.plist`).
- **A Cloudflare Pages.** O projeto `fiscal-dados` (`dados.fiscal.byescaleira.com`) já serve os dados, no plano Free e só por Direct Upload. O `wrangler` roda na VPS, no `fiscal-pages`, com o token de lá. O DNS de `byescaleira.com` fica na Vercel; `dados.fiscal` é um CNAME para `fiscal-dados.pages.dev`.
- **O que roda hoje na VPS.** Só o `fiscal-api` (conferido em 08/11, só leitura). O admin (`/admin`) e a ponte (`/bridge/`) não estão no ar; no log há apenas varreduras de robôs nesses caminhos, todas com 404.
- **A FSC-020** ([PR #21](https://github.com/byescaleira/fiscal/pull/21), aberto) tira da VPS tudo o que o app chamava e troca a política de privacidade por "Dados que coletamos: Nenhum". O runbook (seção 8, passo 6) diz que essa política só vale depois do deploy e da limpeza da VPS.

### New Concepts Required

- **Projeto `fiscal-site` na Pages**, separado do `fiscal-dados`, com o domínio `fiscal.byescaleira.com`.
- **Pasta de publicação montada a partir de `site/`**, só com o que sobe. Leva mais três arquivos:
  - `_headers`, com o tipo do AASA e os cabeçalhos que o bloco do Caddy previa;
  - `404.html`, porque sem ele a Pages responde qualquer caminho desconhecido com o `index.html` e o código 200;
  - nenhum `_redirects`.
- **Script de publicação**, no modelo do `scripts/server-deploy.sh`: por padrão só mostra o plano, e publica com `--apply`, sempre com o ok do usuário.

### Key Business Rules

- **O arquivo da Apple** responde 200, sem redirecionamento, com o tipo `application/json`, em `/.well-known/apple-app-site-association`, enquanto houver versão do app com `applinks:`.
- **As páginas** `/`, `/privacy`, `/terms` e `/support` respondem 200 sem `.html`, porque o app abre esses endereços. Caminho desconhecido, inclusive o `/api/*` dos builds antigos, responde 404.
- **O Fiscal na Web não sobe** antes da 1.0 ([ADR 0016](../../docs/adr/0016-web-companion-after-1-0.md)). O site não anuncia recurso que não existe.
- **Ok do usuário a cada vez:** publicar, trocar DNS e mexer no Caddy.
- **A política de privacidade publicada** precisa ser verdadeira no dia em que entra no ar.
- **Segredos fora do Claude Code:** o login do `wrangler` e qualquer token ficam no app Terminal, com o usuário.

## Strategic Approach

### Solution Direction

Um projeto Pages próprio para o site, publicado por Direct Upload a partir de uma pasta montada com os arquivos que sobem, mais `_headers` e `404.html`. O domínio `fiscal.byescaleira.com` deixa de apontar para a VPS e passa a ser um CNAME para o projeto, como o `dados.fiscal` já é. A VPS fica sem nenhum tráfego do site. O bloco do Caddy sai depois da troca, com o ok do usuário, para o Caddy não tentar renovar um certificado de um domínio que não aponta mais para ele.

### Key Design Decisions

| Decisão | Escolha | Trade-off | Porta |
| --- | --- | --- | --- |
| Onde o site fica | Cloudflare Pages | Decidido pelo usuário em 07/11/2026. Nada do site depende da VPS | veto |
| Projeto | `fiscal-site`, separado do `fiscal-dados` | O `fiscal-dados` publica da VPS a cada carga, tem orçamento de deploys e está perto do limite de 20 mil arquivos (`SITE_MAX_FILES=18000`). Misturar faria o site depender da carga e exporia os dados em `fiscal.byescaleira.com/v2/…`. Um projeto a mais no plano Free, que aceita vários | veto |
| Como publicar | Direct Upload com `wrangler`, a partir do Mac, na worktree de integração (`development`), por um script com plano e `--apply` | Exige um login do `wrangler` no Mac, feito pelo usuário no Terminal. Sem integração Git, nada sai sozinho com um push, e nenhuma prévia de branch fica pública | pergunta |
| Quando publicar a primeira vez | Depois do deploy da FSC-020 e da limpeza da VPS (runbook, seção 8), já com a política nova | Os links universais esperam esse deploy. Publicar antes exigiria a política antiga, que fala de tokens e App Attest, e a troca dela logo depois | pergunta |
| O que sobe | `index`, `privacy`, `terms`, `support`, `llms.txt`, `style.css`, `assets/`, `fonts/`, `.well-known/`, mais `_headers` e `404.html` gerados | A mesma lista de exclusão do `docs/web.md`: fora `app.html`, `link.html`, `web.css`, `web*.js`, `vendor/`, `*.test.mjs` e `package.json` | reversível |
| `/link` | Fica no AASA e não tem página. Com o app instalado, abre o app; sem o app, responde 404 | A página de quem não tem o app é do Fiscal na Web e volta com ele | reversível |
| Tipo do AASA | `_headers` com `Content-Type: application/json` só nesse caminho | A Pages serve arquivo sem extensão como binário. O `scripts/site-server.mjs` já serve como JSON | reversível |
| Cabeçalhos do site | Os mesmos do bloco do Caddy proposto: `Strict-Transport-Security`, `X-Content-Type-Options`, `Referrer-Policy` e `Cache-Control: public, max-age=300` | O AASA fica com cache curto, para uma troca dele chegar logo à CDN da Apple | reversível |
| Páginas sem `.html` | O comportamento padrão da Pages: `/privacy` serve `privacy.html`, e `/privacy.html` redireciona para `/privacy` | É o caminho que o app abre. Sem `_redirects` | reversível |
| DNS | Na Vercel, `fiscal` passa de registro A para a VPS a CNAME para `fiscal-site.pages.dev`, sem proxy, como o `dados.fiscal`. Antes, o domínio é ligado no painel da Pages | Volta atrás: o registro A com o IP da VPS. O tempo de propagação depende do TTL atual, que será conferido antes | veto |
| Caddy | O bloco `fiscal.byescaleira.com` sai depois que o DNS apontar para a Pages, com backup e `caddy validate` | Sem isso, o Caddy registraria falha de renovação do certificado. O log de acesso desse domínio para de existir | reversível |
| Admin e ponte, quando entrarem | Num host próprio (por exemplo, `admin.fiscal.byescaleira.com`) apontando para a VPS | Hoje nenhum dos dois está no ar. A passkey do admin usa o RP ID `fiscal.byescaleira.com`, que continua válido num subdomínio dele. Fica no backlog, sem mudar código agora | reversível |
| Prova no iPhone | Ajustes › Desenvolvedor › Links universais › Diagnóstico com a URL; tocar num link `?person=` no Notas e no Mensagens; e `curl` na CDN da Apple | A CDN da Apple pode levar até um dia para baixar o arquivo de novo. O teste no aparelho espera ela | reversível |

### Alternatives Considered

- **Site no Caddy da VPS (runbook, seção 9):** é mais rápido de ligar, mas mantém tráfego público na VPS, contra o pedido de deixá-la só para a CDN. Também deixaria o site dependendo da VPS em pico.
- **Integração Git da Pages:** publicaria a cada push no branch escolhido, sem token no Mac. Mas faria publicação sem pedido, criaria prévias públicas de cada branch se não fossem desligadas, e precisaria de um passo de build para tirar o Fiscal na Web.
- **Publicar pela VPS, com o `wrangler` e o token que já estão lá:** reaproveita a credencial. Mas põe o site no ciclo do servidor e exige copiar `site/` para a VPS a cada mudança.
- **Mesmo projeto do `fiscal-dados`:** já descartado acima, pelo limite de arquivos e pelo orçamento de deploys.

## Risk & Gap Analysis

| Critério de aceite | Coberto pela direção? | Lacuna ou risco |
| --- | --- | --- |
| AASA com 200, JSON e sem redirecionamento | sim | O tipo depende do `_headers`. A prova é o `curl -sI` depois de publicar e a leitura pela CDN da Apple (`app-site-association.cdn-apple.com/a/v1/fiscal.byescaleira.com`) |
| Links `?person=` e os outros abrem o app no iPhone | parcial | Depende de a CDN da Apple atualizar, o que leva até um dia, e do diagnóstico no aparelho. O build de desenvolvimento pode usar `?mode=developer` para pular a CDN; isso é decidido no canvas |
| `/privacy`, `/terms` e `/support` abrem sem `.html` | sim | Comportamento padrão da Pages, conferido depois de publicar |
| Caminho desconhecido responde 404 | sim | Exige o `404.html`. Sem ele, a Pages entrega a `index.html` com 200, e um build antigo chamando `/api/v1/…` receberia HTML |
| Fiscal na Web fora | sim | A lista de exclusão vira código no script, com teste |
| Privacidade verdadeira no dia da publicação | sim, pela ordem | Exige o deploy da FSC-020, a limpeza da VPS e o merge do PR #21 antes |
| Sem segredo no Claude Code | sim | O login do `wrangler` é do usuário, no Terminal |

- **Riscos:**
  - Troca de DNS errada tira o site e os links do ar → a volta é o registro A anterior. O TTL é anotado antes da troca, e a troca vem só depois de o domínio aparecer como Active na Pages.
  - O certificado da Pages para `fiscal.byescaleira.com` demora a sair → o domínio é ligado no painel antes da troca, e a validação fica pendente até o CNAME existir. Pode haver alguns minutos sem HTTPS válido; a troca fica para um horário de pouco uso.
  - O Caddy fica tentando renovar o certificado depois da troca → o bloco sai em seguida, com o ok.
  - O log de acesso da VPS deixa de ver o domínio → a prova de "o app não chama a VPS" (cenário 33 da FSC-020) tem de ser feita antes da troca, ou passa a ser pelo painel da Pages.
  - O plano Free pode limitar deploys → um site estático muda pouco, bem abaixo do limite. O orçamento é do `fiscal-dados`, não deste projeto.
  - Com o projeto Pages novo, o script toca a conta da Cloudflare a partir do Mac → só o `wrangler pages deploy` daquele projeto, com o ok a cada vez.
- **Lacunas:**
  - Confirmar na documentação atual da Pages: o `_headers` vale para arquivo sem extensão em `/.well-known/`, e o comportamento com e sem `404.html`. A prova final é sempre o `curl` depois de publicar.
  - O TTL atual do registro `fiscal` na Vercel. Será lido só pelo painel ou por `dig`, sem alterar nada.
  - Os ícones e capturas que a página inicial pede para a loja não entram nesta mudança.

## Respostas do usuário (08/11/2026)

- **Como publicar:** "Do Mac, com script (Recomendado)".
- **Primeira publicação:** "Depois da FSC-020 (Recomendado)".
- **Sem veto** às decisões de porta `veto`: Cloudflare Pages, projeto `fiscal-site` separado e o CNAME na Vercel.
- **Canvas:** "Sim, seguir (Recomendado)".
