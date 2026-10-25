# Site e Fiscal na Web

O site público de `fiscal.byescaleira.com` (landing, privacidade, termos, suporte) e o Fiscal na Web em `/app`: uma versão **somente leitura** do app num computador, pareada com o iPhone por QR code. O iPhone monta um resumo, cifra para aquele navegador e envia por uma ponte mínima na VPS que guarda um pacote que não consegue abrir. Receita completa na skill `byescaleira-sdd` (`launch-site-and-support.md` e `web-companion.md`); o painel que pausa a ponte e grava as flags está em `docs/admin.md`.

## Onde está cada peça

| Caminho | O que é |
| --- | --- |
| `site/index.html`, `site/style.css`, `site/app.js` | Landing de venda com o design system do app em CSS (tokens, paleta clara e escura, aparelhos em CSS, Lottie recolorida pelo nome da camada) |
| `site/i18n.js`, `site/i18n/<idioma>.json` | `?locale=` primeiro, depois o navegador, depois inglês; um JSON por idioma com as chaves do HTML |
| `site/privacy.html`, `site/terms.html`, `site/support.html` | Páginas legais e suporte, traduzidas, com a linha "a versão em inglês prevalece" fora do inglês |
| `site/link.html`, `site/.well-known/apple-app-site-association` | Link universal `/link` e a página para quem não tem o app |
| `site/llms.txt` | Resumo do app em Markdown para agentes e buscadores com IA, com os links das páginas principais |
| `site/app.html`, `site/web*.js`, `site/web.css` | O Fiscal na Web: QR, cifra v2, painel de desktop |
| `site/animations/*.json` | As mesmas animações de `scripts/animations/` |
| `bridge/` | Ponte em Node 22 sem dependências (`bridge/README.md`) |
| `scripts/site-server.mjs` | Site e ponte no mesmo processo em `127.0.0.1:4173` (preview `site` no `.claude/launch.json`) |
| `scripts/site-i18n.py` | `extract` gera o `en.json` a partir do HTML; `check` confere os 10 idiomas |
| `scripts/web-vector.mjs` | Gera `docs/web-test-vector-v2.json` com chaves fixas |

## O que trocar antes de publicar

O template sai com textos genéricos e verdadeiros para o esqueleto (Início, Ajustes, itens, iCloud, sem conta). Antes de publicar, a landing tem de vender **este** app:

1. **Herói:** título de benefício (`home.hero.title`), linha de apoio (`home.hero.lead`) e a nota de preço (`home.hero.footnote`).
2. **Mockups:** iPhone, Mac, iPad e navegador reproduzem telas reais do app com os textos do catálogo (`mock.*`). Troque quando as telas mudarem.
3. **Faixa de números** (`home.values.*`), **explorador em abas** (`home.tabs.*` e um painel por recurso com a animação certa), **comparação** (`home.versus.*`, com as alternativas reais), **dicas** dos guias do app (`home.tips.*`), **Grátis × Pro** igual ao paywall (`home.pricing.*`), **perguntas frequentes** (`home.faq.*`) e **chamada final** (`home.closing.*`).
4. **Remova o que o app não tem:** sem assinatura, tire o bloco Pro do herói, da precificação, dos termos e do suporte; sem o Fiscal na Web, tire o link do topo, a seção `#web`, o item da política e a página `/app`. Nunca anuncie plataforma, recurso ou depoimento que não existe.
5. **Privacidade:** cada saída de rede do app ganha um item em `privacy.network.*` antes de ir para a loja.
6. **App Store:** os botões apontam para `https://apps.apple.com/app/id<AppStoreID>`; o mesmo id vai em `FiscalAppStoreID` no `Info.plist`.
7. **Ícones:** `site/assets/icon.png`, `icon-dark.png` e `favicon.png` vêm do ícone do template; depois de `scripts/icons.sh`, copie as PNGs de `FiscalKit/Sources/FiscalResource/Assets/Media.xcassets/AppIcon/FiscalIcon.imageset/` e gere o favicon com `sips -Z 64`.
8. **`site/llms.txt`:** o mesmo resumo da landing em Markdown simples (o que o app faz, plataformas, preço, privacidade e links), em inglês. Muda junto com o herói, a precificação e a política; nunca anuncie ali o que o app não tem.

Texto novo no site exige as 10 traduções no mesmo commit: edite o HTML em inglês, rode `python3 scripts/site-i18n.py extract`, traduza os outros nove JSON e confira com `python3 scripts/site-i18n.py check`.

## Como a pessoa usa a web

1. No computador, `/app` mostra um QR code e "Aguardando o iPhone…".
2. O iPhone lê o QR pela Câmera (link universal `https://fiscal.byescaleira.com/link?s=…&k=…`) ou em Ajustes › Fiscal na Web › Ler QR code. O app pergunta se pode mostrar os dados neste computador.
3. Em até 2 segundos a página troca o QR pelo painel. Nada é digitado.
4. Enquanto a sessão vale (24 horas), o app reenvia quando os dados mudam e a página busca a versão nova a cada 30 segundos.
5. "Desconectar" no app apaga o pacote na ponte; "Sair" na página apaga a chave do navegador e volta ao QR.

## Criptografia (versão 2)

- **Página:** par ECDH P-256 do Web Crypto, privada não exportável no IndexedDB (`fiscal-web`), ID de sessão de 16 bytes (base64url). O QR leva `https://fiscal.byescaleira.com/link?s=<sessão>&k=<chave pública bruta>`.
- **App:** par ECDH P-256 efêmero por sessão; segredo = coordenada x.
- **Chave:** `HKDF-SHA256(segredo, sal = bytes da sessão, info = "fiscal-web:v2", 32 bytes)`.
- **Cifra:** AES-256-GCM, nonce de 12 bytes a cada envio, AAD = UTF-8 do ID da sessão; pacote `{"v":2,"appKey","nonce","ciphertext"}` em base64.
- **Dono:** `ownerToken` de 32 bytes por sessão; a ponte guarda só o SHA-256.
- **Vetor compartilhado:** `docs/web-test-vector-v2.json`, gerado por `node scripts/web-vector.mjs` (o `bin/new-app` já roda). Lido por `site/web-crypto.test.mjs` e pelo teste Swift do alvo `FiscalWeb`. Mudou a cifra: suba o `v` e o `info`, gere o vetor de novo.

## Contrato do resumo

O app cifra um JSON com chaves ordenadas. `v` do resumo é `1` e só ganha campos novos. Tudo, menos `v`, é opcional: a página esconde o que faltar. **A web nunca recalcula nada:** os números e os textos prontos (`title`, `label`, `detail`) vêm do app, já traduzidos no `locale` do resumo; o resto da página segue o `?locale=` dela.

```json
{
  "v": 1,
  "generatedAt": "2026-10-18T09:41:00Z",
  "locale": "en-US",
  "currency": "USD",
  "profile": { "name": "Dana", "initials": "DT", "color": "teal" },
  "period": { "start": "2026-10-01", "end": "2026-10-31", "today": "2026-10-17", "title": "October 2026" },
  "status": { "label": "On track", "tone": "positive" },
  "metrics": [ { "title": "Done", "value": 0.58, "format": "percent", "ratio": 0.58, "elapsed": 0.55, "tone": "positive", "detail": "7 of 12" } ],
  "daily": { "goal": 1, "format": "number", "points": [ { "date": "2026-10-01", "value": 1 } ] },
  "history": [ { "month": "2026-09", "value": 14 } ],
  "highlights": [ { "title": "Most active day", "value": "Tuesday", "detail": "2 items on average" } ],
  "groups": [ { "name": "Ideas", "symbol": "lightbulb", "color": "mustard", "value": 5, "target": 8, "format": "number" } ],
  "items": [ { "date": "2026-10-17", "title": "First idea", "group": { "name": "Ideas", "color": "mustard" }, "tags": ["Home"], "status": { "label": "Open", "tone": "warning" }, "value": 12.5, "format": "currency" } ],
  "upcoming": [ { "title": "Weekend plan", "date": "2026-10-20", "detail": "Plans", "color": "teal" } ]
}
```

- `format`: `number`, `percent` (0–1), `currency` (na moeda de `currency`) ou texto quando o valor é string.
- `tone`: `positive`, `warning`, `negative` ou `neutral` (item `neutral` aparece riscado, como cancelado); cores pelos nomes da paleta (`olive`, `rust`, `mustard`, `teal`, `denim`, `plum`, `brown`, `orange`).
- `metrics`: até 4 KPIs no topo; `ratio` desenha a barra e `elapsed` a marca do período.
- `groups`: barras de `value` sobre `target` e a barra de participação empilhada; sem `groups`, a aba some.
- `items`: a tabela com busca (título, grupo, tags), filtro por `status.label` e por grupo, ordenação por data ou `value`; até 300, os mais recentes.
- Seção sem dado fica de fora, nunca vazia nem zerada. Escalas iguais às do app.
- Ao especializar o app, renomeie `items`, `groups` e os textos da navegação (`navItems`, `navGroups` em `site/web-strings.js`) para o domínio, e mantenha o vetor e os testes dos dois lados em dia.

## A ponte

`bridge/server.mjs` em `127.0.0.1:3110`, publicado pelo Caddy em `https://fiscal.byescaleira.com/bridge/` (`handle /bridge/*`). Tudo em memória, dono por hash, 24 h, limites por IP, CORS só para o site, pausa `503 {"error":"paused"}`, porta de controle interna `3111` só na rede Docker `fiscal-control` com `BRIDGE_ADMIN_TOKEN`. Detalhes e runbook em `bridge/README.md`.

## No app (a fazer quando o recurso entrar)

- Alvo de serviço `FiscalWeb` (link, cifra, pacote, resumo, cliente da ponte, sessões no Keychain) e tela em `FeatureSettings/Web`, só no iPhone e no iPad.
- Flag remota `web` (`FeatureFlag.web`, padrão ligado) e as chaves `FiscalWebBridgeURL` e `FiscalWebsiteURL` no `Info.plist`.
- Entitlement `com.apple.developer.associated-domains` com `applinks:fiscal.byescaleira.com`.
- Teste Swift do vetor (`FiscalKit/Tests/FiscalWebTests/WebVector.swift`) lendo `docs/web-test-vector-v2.json`.

## Desenvolvimento local e verificação

- `node scripts/site-server.mjs` (ou o preview `site`) serve o site e a ponte em `http://127.0.0.1:4173`; `/`, `/app`, `/link`, `/privacy` e `/bridge/health` respondem como em produção.
- `node --test bridge/server.test.mjs site/web-crypto.test.mjs` e `python3 scripts/site-i18n.py check` antes de cada commit que mexe no site ou na ponte.
- Ponta a ponta só no iPhone físico: QR pela Câmera e pelo app, reenvio ao mudar um dado, sessão expirada, "Desconectar", dois navegadores e ponte pausada.

## Publicar

```sh
rsync -av --exclude '*.test.mjs' --exclude _upload site/ root@<vps>:/opt/fiscal-site/public/
curl -sI https://fiscal.byescaleira.com/.well-known/apple-app-site-association
```

A `apple-app-site-association` responde `200`, sem redirecionamento, enquanto houver versão com `applinks:` na loja.

## Privacidade

Com o recurso ligado, um resumo sai do aparelho cifrado de ponta a ponta para o navegador cujo QR o iPhone leu, fica até 24 horas na ponte e só abre naquele navegador. O rótulo da App Store continua "Dados não coletados".
