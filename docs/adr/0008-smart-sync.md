# 0008. Sincronização por cadência, detecção de mudança e reconstrução incremental

- **Estado:** Aceito (em produção desde 2026-10-26)
- **Data:** 2026-10-26
- **Mudança:** [`app-1.0`](../changes/archive/2026-10-29-app-1.0/proposal.md)

## Contexto

O [ADR 0007](0007-pages-cdn-phased-ingest.md) tirou a leitura pública da VPS, mas manteve uma premissa cara: toda fase, e até a atualização "ao vivo" de 10 em 10 minutos, refazia o conjunto inteiro.

O que foi medido em 26/10, na VPS (4 vCPU, 16 GB) e no Mac com os dados reais copiados de lá:

- **Atualização ao vivo.** Levava 2 min 50 s na VPS e 158 s no Mac, com 2,9 GB de memória residente, para regravar 5 arquivos. Cada execução também montava uma release nova de 783 MB.
- **Fases.** A `memoria` levava de 12 a 17 min e a `camara`, 30 min. Duas execuções morreram por memória (código 137).
- **Montagem dos arquivos.** O `publicdata.Build` levava 146 s, e 62% disso era a classificação de temas: o mesmo texto de votação era classificado uma vez por voto de cada parlamentar (491 mil vezes).
- **Assembleias.** Toda fase relia da rede os anos da Assembleia da Paraíba que nunca entram no cache, porque passam de 100 páginas no SAPL. Eram cerca de 25 min perdidos em cada fase no Mac.
- **Memória (histórico).** Os arquivos `history/*` não entravam no site `v2`, então o app recebia 404 no Pages.
- **Limite de deploys do Pages Free.** A [página oficial de limites](https://developers.cloudflare.com/pages/platform/limits/) diz "500 builds per month" e descreve o build pelo push no Git. A página do [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/) não fala de cota, e um resumo da própria documentação fala em "500 deploys per month". **Não está confirmado se o `wrangler pages deploy` conta.** Publicar a cada 5 minutos (cerca de 288 por dia, 8.900 por mês) só caberia se não contar.

## Decisão

1. **Catálogo de cadência versionado** (`server/internal/ingest/cadence.go`, tabela no [runbook](../server-runbook.md#5-cadência-por-fonte)).
   - Cada trabalho tem tema, fontes, horário ou intervalo, janela do calendário, tipo de sonda, idade máxima e o motivo da cadência em uma linha.
   - Um único `fiscal-sync.timer` dispara a cada 5 min `fiscal-ingest -sync`, que roda só o que está devido e depois chama o `fiscal-pages`.
   - O estado fica em `DATA_DIR/sync-state.json`.
   - Na primeira execução, o catálogo assume que os dados de hoje estão em dia e roda só o trabalho quente.
2. **Detecção de mudança antes de baixar.**
   - **Arquivos** (ANP, Receita, ZIPs do TSE, IBGE, ZIPs da Memória): `HEAD` com `ETag`, `Last-Modified` e tamanho. Sem validador, o arquivo vem pelo cache condicional e entra o hash do conteúdo.
   - **APIs** (Comprova, SIDRA): uma consulta mínima, como a última publicação alterada ou o último período, e o hash da resposta.
   - Com a impressão digital igual à da última leitura, a fonte não é lida e nada é reconstruído. A idade máxima obriga uma leitura de tempos em tempos, para um validador errado não esconder mudança.
   - Câmara, Senado e SAPL rodam pela cadência, sem sonda: a Câmara regera todos os arquivos anuais toda madrugada, e as APIs não têm validador. O "sem mudança" deles vem do hash do conteúdo gerado (item 3).
3. **Reconstrução incremental por partição, com saída por hash.**
   - **Quente** (`hot`, a cada 5 min em sessão). Lê só a pauta e as votações de hoje. Se a impressão digital não mudou, sai em segundos sem escrever nada. Se mudou, monta só `today.json`, `agenda/today.json`, `votes/recent.json` e os `votes/{id}.json` de hoje, a partir de uma base pequena (`hot-base.json`: as 60 votações mais recentes sem os votos, as leis, as fontes e o mapa chave → slug). Não carrega o conjunto nacional.
   - **Derivados** (`destaques`, no máximo a cada 20 min e só com votação nova). Perfis, listas de votos por pessoa, fatos, destaques e peso são recalculados a partir do snapshot nacional, sem cidades.
   - **Fontes de sobreposição** (Comprova, ANP, SIDRA, Receita, repercussão, cidades e Memória). O snapshot é reaproveitado e só a parte da fonte é trocada. Não há mais a restauração de todas as fontes do banco.
   - **Fontes de ligação** (Câmara, Senado, assembleias e TSE). Mudam quem é quem, então restauram o resto do banco como antes. Os 75 mil arquivos de cidades e a Memória ficam como estão.
   - **Manifesto de hashes** (`DATA_DIR/v1-manifest.json`). Guarda o caminho e o hash de cada arquivo do preparo, sem o `generatedAt`. Só o que mudou é gravado (com o `.gz`), e a lista do que mudou alimenta o stager. As mudanças ainda não publicadas sobrevivem a uma queda.
   - **Release por delta** (`site.StageDelta`). Os pacotes que não mudaram viram links físicos da release anterior, e só os pacotes afetados são remontados: pessoa, município, índice de cidade, pacote de votações e arquivo avulso. A validação relê só o que foi reescrito; as checagens estruturais (índice ⇄ perfis, `meta.counts`, teto de arquivos, trava de queda) continuam completas.
   - **Classificação de temas** com índice por prefixo e memória por texto. O `Build` caiu de 146 s para 13 s, com resultado idêntico em 431.881 textos reais.
   - **Verificação semanal** (`memoria`, quarta 00:20). Roda primeiro o caminho incremental e depois a reconstrução completa do banco, com montagem completa da release. Compara o preparo e as duas releases arquivo por arquivo, sem `meta.json` e `history/*`, e grava `DATA_DIR/consistency.json`. Qualquer divergência registra `ALERT consistency` no log e sai com código 3. A release incremental continua publicada até alguém conferir a completa e publicá-la com `-site rollback -to`; o `fiscal-pages` roda mesmo com o código 3.
4. **Publicação no Pages dentro de um orçamento mensal.**
   - **Teto.** `PAGES_MAX_DEPLOYS_PER_MONTH` (padrão 450, abaixo dos 500 do Free, com folga para rollback).
   - **Espaçamento.** As releases de rotina esperam `tempo até o fim do mês ÷ deploys restantes` (cerca de 96 min no começo do mês). As quentes esperam também `PAGES_DATA_INTERVAL`. `full`, `memoria`, rollback, `-force` e mudança na apuração saem na hora.
   - **Cada deploy envia só os arquivos alterados.** O `wrangler` deduplica por hash, e a troca continua atômica e validada.
   - **O quente direto da origem.** O `release.json` ganha `origin: { first, onMissing, maxAge }`. O app lê `today.json`, `agenda/today.json` e `votes/recent.json` primeiro no `api/v1` da VPS (Caddy, do disco, `max-age=30`) e cai para o Pages se a VPS falhar. Uma votação de hoje que ainda não está no pacote do Pages (404) vem da origem. `HOT_FROM_ORIGIN=0` tira o campo no próximo deploy e devolve tudo ao Pages, sem versão nova do app.
   - **Se o Direct Upload não contar no limite.** Com `PAGES_MAX_DEPLOYS_PER_MONTH=9000` e `PAGES_DATA_INTERVAL=10m`, o Pages acompanha o quente sozinho, e o `HOT_FROM_ORIGIN` pode ir para 0.
5. **Systemd.** `fiscal-sync.timer` e `fiscal-sync.service` substituem os 10 timers de fase e o `fiscal-live.timer`. O `fiscal-phase@<trabalho>.service` passa a forçar um trabalho à mão (`-job`), e o `fiscal-pages.timer` continua só para dia de eleição.

## Consequências

- **Medido no Mac, com o banco, o snapshot e o preparo copiados da VPS em 26/10:**

  | Trabalho | Antes | Depois |
  | --- | --- | --- |
  | Tique quente sem novidade | 158 s e 2,9 GB (`-once live`), que regravava 5 arquivos e montava uma release de 783 MB | 1,0 s e 26 MB, sem escrita nem release |
  | Tique quente com impressão digital nova | — | 1,9 s e 98 MB |
  | `destaques` com uma votação nova de 404 votos | — | 43 s e 3,2 GB (1,9 GB com `GOMEMLIMIT=1200MiB`, em 52 s); 780 arquivos de preparo e 376 pacotes refeitos |
  | `checagens` | fase completa, cerca de 12 min | 25 s (sobreposição) |
  | `senado` (diária) | 19 min 13 s e 3,4 GB | 2 min 52 s e 2,9 GB, com os mesmos 626 arquivos mudados |
  | `memoria` (semanal) | 12 min 33 s (só a reconstrução) | 2 min 24 s, com o incremental, a reconstrução e a comparação |
  | Disco de 3 releases | 2,3 GB | 1,2 GB |

- **Bug achado.** A verificação, já na primeira execução com dados reais, achou 3.255 arquivos divergentes. O snapshot em `gob` perdia `false` e `0` atrás de ponteiro, então a atualização ao vivo publicava votação rejeitada com `approved: null` até a fase seguinte. O snapshot passou a ser JSON (`live-snapshot.json`), e a segunda verificação deu zero divergências.
- **Mais fácil.**
  - Em dia de sessão sem novidade, o tique de 5 min custa algumas chamadas à API e nenhuma escrita.
  - Com novidade, só os arquivos de hoje mudam, e a release nova é feita de links físicos.
  - Fonte sem mudança não gasta CPU nem deploy.
  - Releases antigas ocupam só o que mudou, não 783 MB cada.
  - A Memória passa a estar no `v2`.
- **Obrigações.**
  - **Conferir no painel se o Direct Upload conta.** Em Account Home › Workers & Pages › Plans, ver o uso de builds depois de alguns deploys e ajustar `PAGES_MAX_DEPLOYS_PER_MONTH` e `HOT_FROM_ORIGIN`.
  - **Caddy.** O bloco `@hot` (runbook, seção 7) com `max-age=30` deve entrar antes do `@data`.
  - **Pico na VPS.** O quente na origem põe três arquivos pequenos de volta na VPS; acompanhar a carga do Caddy em pico. A saída é `HOT_FROM_ORIGIN=0`.
  - **Alerta de consistência.** Precisa de olho humano: `systemctl --failed` e `DATA_DIR/consistency.json`.
- **Mudam junto.**
  - `PublicDataClient`/`PublicDataRoute` no app (leitura do `origin`).
  - `scripts/server-deploy.sh` (liga o `fiscal-sync.timer` e remove os timers antigos).
  - `compose.yaml` (`PAGES_MAX_DEPLOYS_PER_MONTH`).
  - O ADR 0007 fica valendo para o Pages, o layout `v2`, a validação e o App Attest; os itens 4 e 5 dele (calendário das fases e publicação) passam a ser os deste.
- **Pendências.**
  - Os anos de 2023 a 2025 da Assembleia da Paraíba ficavam fora porque passam de 100 páginas no SAPL (o SAPL limita cada página a 100 itens, e 2023 tem 15,5 mil matérias). O teto subiu para 400 páginas, e um ano já fechado é lido do cache por 30 dias; só o ano corrente é relido todo dia.
  - O snapshot nacional (cerca de 520 MB de heap) ainda é carregado pelos derivados e pelas sobreposições. Dividi-lo por casa é o próximo passo, se a memória apertar.

## Alternativas consideradas

- **Dependência por entidade dentro do `Build` (só a pessoa X, só a votação Y).** Foi descartada. Cada perfil depende das quartis dos pares (benchmarks), da data de hoje (meses de mandato, decaimento do peso), do `updatedAt` de cada fonte citada e do casamento de checagens com todas as pessoas. Rastrear isso à mão seria frágil.
  - **A troca adotada.** Partições com fronteiras limpas (quente, nacional, cidades e Memória), `Build` rápido e saída por hash dão o mesmo efeito: só o que mudou é gravado e publicado. A verificação semanal pega o que escapar.
- **Deploy no Pages a cada 5 min.** Cabe só se o Direct Upload não contar no limite, o que não está confirmado. O orçamento mensal com o quente na origem funciona nos dois casos.
- **R2 ou KV para o quente.** Exigem a zona do domínio na Cloudflare, cobram por operação ou têm cota diária pequena no Free (100 mil leituras no Workers). A VPS já serve o `v1` pelo Caddy.
- **Manter um processo de longa duração com o conjunto em memória.** Foi a causa da queda que levou ao ADR 0007.
