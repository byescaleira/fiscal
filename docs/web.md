# Site e Fiscal na Web

O site público de `fiscal.byescaleira.com` (landing, privacidade, termos e suporte) existe para vender o Fiscal, **só em português do Brasil** ([ADR 0003](adr/0003-portuguese-only.md)). O **Fiscal na Web** (`/app`, uma versão somente leitura do app num computador, pareada com o iPhone por QR code) fica **para depois da 1.0**: os arquivos continuam no repositório, mas o site não tem link para ele nem o anuncia. Receita completa na skill `byescaleira-sdd` (`launch-site-and-support.md` e `web-companion.md`); o painel de flags e versões está em `docs/admin.md`.

## Onde está cada peça

| Caminho | O que é |
| --- | --- |
| `site/index.html`, `site/style.css`, `site/app.js` | Landing com o design system do app em CSS (tokens, paleta clara e escura do kit, Bricolage na ênfase, iPhone em CSS) e as abas de recursos |
| `site/privacy.html`, `site/terms.html`, `site/support.html` | Política de Privacidade com cada saída de rede do app, Termos de Uso sobre o EULA da Apple e Suporte com as dúvidas reais |
| `site/fonts/BricolageGrotesque.woff2`, `site/fonts/OFL.txt` | A fonte de ênfase do app ([ADR 0009](adr/0009-bricolage-emphasis-font.md)), local, com a licença ao lado |
| `site/assets/` | Ícone claro e escuro (`FiscalIcon.imageset`) e favicon de 64 px |
| `site/llms.txt` | O mesmo resumo da landing em Markdown simples, em português, para agentes e buscadores com IA |
| `site/link.html`, `site/.well-known/apple-app-site-association` | Link universal `/link` e a página para quem não tem o app |
| `site/package.json` | Só a versão do site (SemVer, `0.1.0` até o lançamento); não vai para o servidor |
| `site/app.html`, `site/web*.js`, `site/web.css`, `site/vendor/` | O Fiscal na Web, parado até depois da 1.0 |
| `bridge/` | Ponte em Node 22 sem dependências (`bridge/README.md`), também para depois da 1.0 |
| `scripts/site-server.mjs` | Site e ponte no mesmo processo em `127.0.0.1:4173` (preview `site` no `.claude/launch.json`), com URLs sem `.html` e `.woff2` como `font/woff2` |
| `scripts/site-i18n.py` | `check` confere as regras do site em pt-BR; `extract` lista os textos de cada página para revisão |

## O que manter em dia

1. **Nada inventado.** Os mockups reproduzem telas que existem, com os textos e os dados que o app mostra (aba Votações, Região de Campo Grande, Dinheiro de Mato Grosso do Sul, apuração do 2º turno sem nomes). Troque quando as telas mudarem. Nada de depoimento, nota, plataforma ou recurso que o app não tem.
2. **Sem Pro e sem a Web.** O Fiscal é grátis, sem assinatura e sem compras no app. O site não liga para `/app` e não fala do Fiscal na Web até ele voltar.
3. **Privacidade:** cada saída de rede nova do app ganha um item em `site/privacy.html` antes de ir para a loja (hoje: dados públicos na CDN e na API, ajustes no banco público do iCloud, token da Atividade ao Vivo da apuração e dos destaques, App Attest, notificações da Apple e links das fontes).
4. **App Store:** os botões apontam para `https://apps.apple.com/app/id6826982117`, o mesmo `FiscalAppStoreID` do `Info.plist`.
5. **`site/llms.txt`** muda junto com a landing e a política.
6. **Contraste medido.** Toda cor de texto passa 4,5:1 nos dois esquemas: laranja `#af5626`, mostarda `#906716` e oliva `#5c762d` no claro (as do kit), texto sobre o destaque em `--on-tint` (branco no claro, 5,02:1; preto no escuro, 7,45:1), chips com o texto misturado 72% com `--label` (pior caso 4,70:1) e notas dentro das mídias tingidas em `--secondary-strong`.
7. **Acessibilidade.** `:focus-visible` em todo controle, link "Pular para o conteúdo", abas com setas, Home e End, e o conteúdo inteiro visível sem JavaScript.

Texto novo no site sai só em pt-BR, direto no HTML. Antes do commit, `python3 scripts/site-i18n.py check` confere: `lang="pt-BR"` em cada página, nenhum atributo ou link de tradução, nenhum link para `/app`, links da App Store com o id certo, links locais que existem e nenhuma sobra do template (Pro, "Fiscal na Web", textos de exemplo).

## Desenvolvimento local e verificação

- `node scripts/site-server.mjs` (ou o preview `site`) serve o site e a ponte em `http://127.0.0.1:4173`; `/`, `/privacy`, `/terms`, `/support`, `/link` e `/bridge/health` respondem como em produção.
- `node --test bridge/server.test.mjs site/web-crypto.test.mjs` e `python3 scripts/site-i18n.py check` antes de cada commit que mexe no site ou na ponte.
- Abra a página em claro e em escuro e na largura de celular (375 px), sem rolagem horizontal.

## Publicar

Só com o ok do usuário, pedido a cada vez, a partir da worktree de integração (`development`), nunca de uma `feature/*`. O bloco do Caddy está no [runbook do servidor](server-runbook.md#9-site-no-mesmo-bloco-proposta-com-o-ok-do-usuário).

```sh
cd /Users/rafael.escaleira/Documents/projects/lab-vibecode/politico-monitor/.claude/worktrees/integration && python3 scripts/site-i18n.py check && ls site/.well-known && rsync -a --delete --exclude '.DS_Store' --exclude '*.test.mjs' --exclude 'package.json' --exclude '_upload' --exclude 'app.html' --exclude 'link.html' --exclude 'web.css' --exclude 'web*.js' site/ root@179.198.114.91:/opt/fiscal-site/public/
```

- **Fiscal na Web fica de fora até depois da 1.0** ([ADR 0016](adr/0016-web-companion-after-1-0.md)): `app.html`, `link.html`, `web.css` e os `web*.js` continuam no repositório e não sobem.
- **`--delete`** deixa o servidor igual ao repositório; os `--exclude` protegem o que não sobe e o que já está lá com esses nomes. Nunca `--delete-excluded`.
- **`.well-known/` vai junto e fica.**

Depois, confira cada rota:

```sh
for u in / /privacy /terms /support /link /llms.txt /style.css /app.js /fonts/BricolageGrotesque.woff2 /assets/icon.png /.well-known/apple-app-site-association; do curl -s -o /dev/null -w "$u %{http_code} %{content_type}\n" https://fiscal.byescaleira.com$u; done
curl -sI https://fiscal.byescaleira.com/.well-known/apple-app-site-association
curl -s https://fiscal.byescaleira.com/api/health
```

Todas respondem `200`, sem redirecionamento; a `apple-app-site-association` com corpo JSON, e o `/api/health` com `{"ok":true,"version":"…"}`. Na dúvida sobre o que está no ar, compare o `md5` local com o `md5sum` remoto de cada arquivo mudado (`vps-operations.md`).

## Fiscal na Web (depois da 1.0)

Uma versão **somente leitura** do app num computador. O iPhone monta um resumo, cifra para aquele navegador e envia por uma ponte mínima na VPS que guarda um pacote que não consegue abrir. Nada disto está no app nem no site da 1.0; quando voltar, a página `/app` e as `site/web*.js` passam a sair só em pt-BR, como o resto do site, e a política ganha o item da ponte.

### Como a pessoa usa

1. No computador, `/app` mostra um QR code e "Aguardando o iPhone…".
2. O iPhone lê o QR pela Câmera (link universal `https://fiscal.byescaleira.com/link?s=…&k=…`) ou em Ajustes › Fiscal na Web › Ler QR code. O app pergunta se pode mostrar os dados neste computador.
3. Em até 2 segundos a página troca o QR pelo painel. Nada é digitado.
4. Enquanto a sessão vale (24 horas), o app reenvia quando os dados mudam e a página busca a versão nova a cada 30 segundos.
5. "Desconectar" no app apaga o pacote na ponte; "Sair" na página apaga a chave do navegador e volta ao QR.

### Criptografia (versão 2)

- **Página:** par ECDH P-256 do Web Crypto, privada não exportável no IndexedDB (`fiscal-web`), ID de sessão de 16 bytes (base64url). O QR leva `https://fiscal.byescaleira.com/link?s=<sessão>&k=<chave pública bruta>`.
- **App:** par ECDH P-256 efêmero por sessão; segredo = coordenada x.
- **Chave:** `HKDF-SHA256(segredo, sal = bytes da sessão, info = "fiscal-web:v2", 32 bytes)`.
- **Cifra:** AES-256-GCM, nonce de 12 bytes a cada envio, AAD = UTF-8 do ID da sessão; pacote `{"v":2,"appKey","nonce","ciphertext"}` em base64.
- **Dono:** `ownerToken` de 32 bytes por sessão; a ponte guarda só o SHA-256.
- **Vetor compartilhado:** `docs/web-test-vector-v2.json`, gerado por `node scripts/web-vector.mjs`. Lido por `site/web-crypto.test.mjs` e pelo teste Swift do alvo `FiscalWeb`. Mudou a cifra: suba o `v` e o `info`, gere o vetor de novo.

### Contrato do resumo

O app cifra um JSON com chaves ordenadas. `v` do resumo é `1` e só ganha campos novos. Tudo, menos `v`, é opcional: a página esconde o que faltar. **A web nunca recalcula nada:** os números e os textos prontos (`title`, `label`, `detail`) vêm do app.

- `format`: `number`, `percent` (0–1), `currency` (na moeda de `currency`) ou texto quando o valor é string.
- `tone`: `positive`, `warning`, `negative` ou `neutral`; cores pelos nomes da paleta (`olive`, `rust`, `mustard`, `teal`, `denim`, `plum`, `brown`, `orange`).
- `metrics`: até 4 KPIs no topo; `ratio` desenha a barra e `elapsed` a marca do período.
- `groups`: barras de `value` sobre `target`; sem `groups`, a aba some.
- `items`: a tabela com busca, filtro e ordenação; até 300, os mais recentes.
- Seção sem dado fica de fora, nunca vazia nem zerada.
- Ao especializar o Fiscal na Web, troque `items`, `groups` e os textos da navegação (`site/web-strings.js`) pelo domínio do Fiscal (votações, gastos, pessoas seguidas) e mantenha o vetor e os testes dos dois lados em dia.

### A ponte

`bridge/server.mjs` em `127.0.0.1:3110`, publicado pelo Caddy em `https://fiscal.byescaleira.com/bridge/` (`handle /bridge/*`). Tudo em memória, dono por hash, 24 h, limites por IP, CORS só para o site, pausa `503 {"error":"paused"}`, porta de controle interna `3111` só na rede Docker `fiscal-control` com `BRIDGE_ADMIN_TOKEN`. `/bridge/health` devolve `{"ok":true,"version":"0.1.0"}`, a versão do `bridge/package.json`. Detalhes e runbook em `bridge/README.md`.

### No app (quando o recurso entrar)

- Alvo de serviço `FiscalWeb` (link, cifra, pacote, resumo, cliente da ponte, sessões no Keychain) e tela em `FeatureSettings/Web`, só no iPhone e no iPad.
- Flag remota `web` (`FeatureFlag.web`) no app e no `admin/src/flags.mjs`, e as chaves `FiscalWebBridgeURL` e `FiscalWebsiteURL` no `Info.plist`.
- Entitlement `com.apple.developer.associated-domains` com `applinks:fiscal.byescaleira.com`.
- Teste Swift do vetor (`FiscalKit/Tests/FiscalWebTests/WebVector.swift`) lendo `docs/web-test-vector-v2.json`.
- Com o recurso ligado, um resumo sai do aparelho cifrado de ponta a ponta para o navegador cujo QR o iPhone leu, fica até 24 horas na ponte e só abre naquele navegador. O rótulo da App Store continua "Dados não coletados".
