# 0007. Dados públicos no Cloudflare Pages, carga em fases na VPS atual e App Attest no registro

- **Estado:** Aceito (2026-10-29); os itens 4 (carga em fases) e 5 (publicação) foram substituídos por [0008](0008-smart-sync.md)
- **Data:** 2026-10-26
- **Mudança:** [`app-1.0`](../changes/archive/2026-10-29-app-1.0/proposal.md)

## Contexto

- **O problema.** Toda carga deixava o servidor indisponível.
- **A VPS.** São 2 núcleos e 8 GB para ~28 containers. O `fiscal-ingest` ocioso segurava 3,3 GB (processo de longa duração com `GOMEMLIMIT` de 3 GiB e 12 workers), e durante a carga a CPU saturava e o Caddy ficava lento.
- **O deploy.** O `docker compose up --build` compilava na VPS e recriava a API e a carga juntas, porque as duas usavam a mesma imagem.
- **A publicação.** Ela trocava arquivo a arquivo, nunca o conjunto inteiro.
- **O que o usuário pediu em 2026-10-26.** Um app para milhões de pessoas que não cai, que só o app consulta e que roda sem processamento por acesso.
- **As restrições dele.**
  - Custo fixo de US$ 0.
  - O DNS de `byescaleira.com` continua na Vercel.
  - Nada de VPS nova: tudo roda na VPS atual, com o processamento em fases e a publicação aos poucos no CDN.

Fatos conferidos em 2026-10-26:

- **Pages Free, arquivos.** Até 20.000 arquivos por site e 25 MiB por arquivo. Requisições a arquivos estáticos são grátis e ilimitadas nos dois planos; o limite de 10 milhões é só de Functions, que o Fiscal não usa.
- **Pages, limite de deploys.** A página de limites fala em 500 builds por mês no Free, mas descreve só o build por Git e não diz se o Direct Upload (`wrangler pages deploy`) conta. **Não confirmado**: medir no painel nos primeiros dias.
- **Plano pago.** O aumento para 100.000 arquivos (changelog de 2026-01-23) vale para "paid plans" sem dizer se o Workers Paid entra; por isso o orçamento mira o Free.
- **Volume publicado.** 93.408 JSON em `v1`, ~1 GB com `.gz`, assim distribuídos:
  - 71.626 perfis, dos quais 69.269 são de prefeitos, vices e vereadores;
  - 5.571 arquivos de municípios;
  - 4.453 votações;
  - ~9.800 listas anuais por pessoa.
- **Domínio.** O projeto `fiscal-dados` existe, e `dados.fiscal.byescaleira.com` (CNAME na Vercel para `fiscal-dados.pages.dev`) já responde pela Cloudflare.

## Decisão

1. **Leitura pública só pelo Pages.**
   - Os JSON públicos são um site estático do projeto Pages `fiscal-dados`, em `https://dados.fiscal.byescaleira.com/v2/…`.
   - A VPS não atende leitura pública. O Caddy dela continua servindo o layout `v1` só como reserva e para builds antigos.
   - Cache por `_headers`:
     - apuração, 10 s;
     - índices, `meta`, `today` e destaques, 60 a 300 s;
     - perfis, votações e municípios, 1 h com `stale-while-revalidate`;
     - `ETag` automático do Pages.
   - Não suba `.gz`: o Pages comprime sozinho.
2. **Layout `v2` agrupado, com orçamento de arquivos.**
   - O stager (`internal/site`) transforma o `v1` em `v2` na hora de montar o site:
     - um arquivo por político, com o perfil e todas as listas: `people/{slug}.json` = `{ profile, files }`;
     - um por município, com todos os mandatários: `places/city/{ibge}.json` = `{ place, people }`;
     - 256 índices `index/city-people/{bucket}.json` (slug → município);
     - 512 pacotes `votes/by-id/{bucket}.json`.
   - O bucket são os 2 primeiros bytes do SHA-256 da chave, módulo o número de pacotes.
   - Estimativa: ~8.800 arquivos (2.357 pessoas, 5.571 municípios, 256 + 512 pacotes e ~60 avulsos). O número fica estável: pessoas e municípios crescem pouco, e as votações caem em pacotes de número fixo.
   - A validação **falha acima de 18.000** (`SITE_MAX_FILES`, teto de 20.000 no código), e o job do Pages recusa mais de 20.000.
3. **Release validada e troca atômica.**
   - Cada carga grava o `v1` local (área de preparo) e monta `site/sites/{stamp}-{fase}`.
   - Antes de trocar o link `site/ready`, ela valida:
     - JSON válidos;
     - arquivos obrigatórios presentes;
     - índice ⇄ perfis;
     - `meta.counts`;
     - mínimo de pessoas (500 na carga nacional);
     - **trava de queda de 20%** em arquivos ou pessoas contra a release anterior (`-allow-drop` libera uma execução).
   - Guarda as 3 últimas releases, e `-site rollback` volta à anterior.
   - O deploy do Pages troca o site inteiro de uma vez e tem rollback no painel.
4. **Carga em fases na VPS atual.**
   - Cada fase é um job que roda e sai (`fiscal-ingest -phase <nome>`, timer do systemd).
   - A fase lê só as suas fontes e reconstrói o resto a partir do SQLite (o mesmo `restore` usado quando uma fonte cai), sem rede para as outras.
   - Fases: `senado`, `assembleias`, `checagens`, `indicadores`, `repercussao` e `camara` todo dia de madrugada; `cidades` (sábado), `tse` (domingo), `receita` (segunda) e `memoria` (quarta, reconstrução sem fonte nenhuma).
   - Entre 07h e 23h50, a atualização ao vivo (`-once live`) roda a cada 10 min, a partir do snapshot da última fase.
   - **Lock global** (`DATA_DIR/ingest.lock`): nunca rodam duas.
   - **Orçamento por job:**
     - 1 núcleo (`cpus: 1`);
     - `Nice=19` e I/O ocioso (ajustados pelo próprio processo e pelo systemd);
     - `mem_limit` de 1,2 GB com `GOMEMLIMIT` de 900 MiB;
     - `oom_score_adj: 1000` (o kernel mata a carga antes de qualquer outro serviço);
     - 3 workers e 300 ms entre requisições ao mesmo host.
   - **Guarda de carga:** com load acima de 2 ou menos de 1,5 GB disponíveis, a fase espera até 20 min e pula para a próxima janela.
5. **Publicação aos poucos e em série.**
   - Ao fim de cada fase, o `fiscal-pages` faz o deploy (`wrangler pages deploy`, que só envia os arquivos cujo hash mudou).
   - Os deploys são um por vez (`pages.lock`), com 3 tentativas e espera crescente; se falhar, o site anterior continua no ar.
   - A atualização ao vivo publica no máximo 1 vez por hora (`PAGES_DATA_INTERVAL`).
   - Há um teto diário de deploys (`PAGES_MAX_DEPLOYS_PER_DAY`).
6. **Apuração.**
   - O `fiscal-api` continua lendo o TSE, mandando os pushes e gravando `races*.json` no preparo.
   - Em dia de eleição, liga-se o `fiscal-pages.timer`, que faz o deploy a cada ~60 s só quando os arquivos de apuração mudam.
   - O app lê `v2/races.json` no Pages e, sem ele, `api/v1/races` da VPS.
7. **App Attest no registro.**
   - Os dois `POST` que recebem dados (`live-activities` e `highlight-activities`) aceitam a asserção do App Attest. Ela é verificada só com a biblioteca padrão:
     - CBOR mínimo próprio;
     - cadeia até a Apple App Attestation Root CA embutida (SHA-256 `1cb9…c932`, válida até 2045);
     - nonce;
     - `rpIdHash`;
     - `aaguid`;
     - contador.
   - Os desafios valem 5 minutos e são de uso único.
   - Modo `optional` por padrão: o aparelho sem suporte (simulador, Mac sem Secure Enclave) registra sem asserção, com limite de 10 por minuto por IP. `required` recusa o que vier sem asserção.
8. **Deploy sem queda.**
   - Os binários são compilados no Mac (linux/amd64) e entram em três imagens mínimas (`fiscal-api` e `fiscal-ingest` em distroless; `fiscal-pages` em Node 22 com `wrangler` 4.149.0 fixado). Na VPS só há `COPY`, sem compilação.
   - `scripts/server-deploy.sh` imprime o plano e só age com `--apply`, com o ok do usuário a cada vez.
   - Troca um serviço por vez, com healthcheck e volta automática para `:previous`.
9. **Sem VPS dedicada.** A recomendação de uma VPS própria cai: a VPS não atende mais o público, então lentidão nela não derruba o app. Uma VPS própria só se justificaria por um destes motivos:
   - as fases não caberem em 1,2 GB;
   - a janela da madrugada não bastar;
   - a apuração precisar de mais de um poller;
   - isolar o APNs dos outros 28 containers por segurança.

## Consequências

- **Mais fácil.**
  - O app aguenta pico sem a VPS no caminho: milhões de leituras vão para a borda da Cloudflare, sem custo.
  - Uma carga ruim nunca chega ao público: a validação barra antes de trocar o `ready`, e o deploy é atômico.
  - Uma carga pesada não derruba nada: o job tem núcleo, memória e prioridade limitados e morre primeiro.
- **Obrigações.**
  - Conferir no painel se o Direct Upload conta no limite de 500 builds. Se contar, subir `PAGES_DATA_INTERVAL` (2 a 6 h) e baixar `PAGES_MAX_DEPLOYS_PER_DAY`.
  - Medir o pico de memória da primeira fase (`docker stats`). Se passar de 1,2 GB, o job morre sem efeito, e `INGEST_MEM_LIMIT` sobe.
  - Manter o orçamento de 18.000 arquivos. A próxima alavanca, se precisar, é agrupar `places/{uf}` ou as listas por ano em pacotes.
- **Mudam junto.**
  - Contrato do app: `PublicDataClient` lê `FiscalDataURL` + `v2` quando `v2/release.json` diz `layout: v2`, e cai para `FiscalAPIURL` + `v1` antes disso ou com o Pages fora.
  - O ADR [0002](0002-static-first-server.md) (CDN na frente) passa a ser cumprido por este.
- **Pendências.**
  - O entitlement `com.apple.developer.devicecheck.appattest-environment` não foi adicionado. Sem ele, builds de desenvolvimento usam o ambiente `development`, que o servidor recusa por padrão (`APPATTEST_ALLOW_DEVELOPMENT=0`) e trata como "sem asserção".
  - O TSE e os municípios não foram fatiados por UF: o agregado deles fica em cache até o `ETag` do ZIP mudar, então a fase semanal só pesa quando o TSE republica.

## Alternativas consideradas

- **R2 com manifesto e hash por arquivo.** Exige mover o DNS de `byescaleira.com` para a Cloudflare (domínio próprio do R2) e um manifesto de versões no app. Os PUTs são cobrados por operação. O deploy atômico do Pages já resolve a troca do conjunto.
- **Zona do `byescaleira.com` na Cloudflare, com proxy na frente da VPS.** O usuário não quer tirar o DNS da Vercel, e o Pages com CNAME externo entrega o mesmo cache na borda.
- **Plano pago do Pages (100.000 arquivos).** O custo deixa de ser zero, e não está claro se o Workers Paid conta. Agrupar os arquivos deixa o Free com folga.
- **VPS dedicada (4 vCPU/8 GB).** Deixa de ser necessária quando a VPS sai do caminho de leitura.
- **Direct Upload próprio em Go.** A API de upload de assets não é documentada e usa BLAKE3, que não está na biblioteca padrão. O `wrangler` fixado num container separado é o caminho suportado.
- **Carga contínua num processo só (como antes).** É a causa da queda: memória presa e CPU saturada durante horas.
