# QA da FSC-025: o site e os links universais na Cloudflare Pages

- **Canvas:** [FSC-025](../../../spdd/prompt/FSC-025-202611081040-[Feat]-site-and-universal-links-on-cloudflare-pages.md)
- **Etapa:** A, no repositório. A etapa B (cenários 10 a 14) vem depois do deploy da FSC-020, com o ok do usuário a cada passo, e ganha as linhas dela aqui.
- **Ambiente:** Mac, Node 22.23.1, branch `feature/site-on-pages`.
- **Data:** 08/11/2026.
- **Capturas:** nenhuma versionada. A página 404 foi vista no navegador em `scripts/site-server.mjs`.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 | Só as páginas públicas, os arquivos delas e o arquivo da Apple sobem | `node --test scripts/site-build.test.mjs` | passou em teste | "only the public pages, their files and the association go up": 14 arquivos, sem `app.html`, `app.js`, `link.html`, `web.css`, `web.js`, `vendor`, `package.json` e o teste |
| 2 | `_headers` | Mesmo teste | passou em teste | O arquivo da Apple tem só `Content-Type: application/json` na regra dele; `/*` tem HSTS, `nosniff`, `Referrer-Policy` e `Cache-Control: public, max-age=300`; nenhum cabeçalho aparece nas duas regras. O efeito na Pages é conferido na etapa B (cenário 10) |
| 3 | Arquivo da Apple inválido, de outro app ou ausente | Mesmo teste | passou em teste | Três testes, cada um falha com a mensagem do problema e sem deixar a pasta; o arquivo sobe idêntico, com os 8 `components` |
| 4 | Pasta de saída com arquivos | Mesmo teste | passou em teste | "a folder that already has files is never touched" |
| 5 | Página 404 | `python3 scripts/site-i18n.py check` e o navegador | passou | "5 pages in pt-BR, problems: 0". Em `http://localhost:4173/404`: título "Página não encontrada", o link para a página inicial, o mesmo cabeçalho e rodapé do site, `noindex` |
| 6 | Plano sem `--apply` | `scripts/site-publish.sh` | passou em parte | No commit `dc2ec61`, com uma variável de teste que trocava a branch esperada, o plano listou os 14 arquivos, o projeto `fiscal-site`, a branch `main` e o commit, e terminou com "nada foi enviado". A variável saiu na revisão, porque deixaria publicar de uma `feature/*`. Na `development`, o plano roda depois do merge, na operação 5 |
| 7 | Recusa fora da `development`, com árvore suja ou opção errada | `scripts/site-publish.sh` nesta branch | passou | "Nada foi publicado: a branch é 'feature/site-on-pages'; publique da 'development'" e "há mudanças sem commit", com saída 1; opção desconhecida termina com saída 2. A falha do `site-i18n.py` e da montagem só foi conferida na leitura |
| 8 | `--apply` | Leitura do script | não executável aqui | Publicar pede o ok do usuário e só vem na operação 5. O comando do `wrangler` e o `trap` que apaga a pasta foram conferidos na leitura |
| 9 | `verify.sh` com o teste novo | `scripts/verify.sh --quick` | ver Verificações | `node --test bridge/server.test.mjs site/web-crypto.test.mjs scripts/site-build.test.mjs` |
| 15 | Documentos | Leitura | passou | `docs/web.md` (Publicar), runbook (seção 9, com a ordem, a volta atrás e o aviso de nunca apagar o projeto com o CNAME no ar), ADR 0030 Aceito, backlog (host do admin e da ponte) e `CHANGELOG` |

**Revisão (08/11)**
- **Painel (interface, código e segurança):** aprovado, sem bloqueador. Os dois "deveria" entraram no mesmo commit das correções:
  - o CNAME passa a usar o subdomínio que a Pages imprime;
  - fica registrado no ADR o risco de o `wrangler` baixar dependências sem lockfile.
- **Contra o canvas:** Needs Rework, com 1 crítico: a variável que trocava a branch esperada. Ela saiu. Os dois "importantes" entraram no canvas pelo `spdd-prompt-update`:
  - o cabeçalho de cache do arquivo da Apple vem da regra `/*`;
  - a seção 7 do runbook é da FSC-020.
