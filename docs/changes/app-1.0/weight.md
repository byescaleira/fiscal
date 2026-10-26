# Peso do que cada político faz e o Destaque do momento

Parte da mudança [`app-1.0`](proposal.md), pedida em 2026-10-25 (brief, "Destaque do momento, antes e durante o mandato, e o peso do que cada um faz"). A regra mora em `server/internal/publicdata/weight.go` e `highlights.go`; a explicação que o app mostra em "Como medimos" sai do mesmo código, em `v1/method/weight.json`.

## Regras de neutralidade

- **O peso ordena, nunca qualifica.** Nenhum texto diz "polêmico", "bom" ou "ruim"; o app mostra o número e o que entrou nele.
- **Uma regra para todos:** os mesmos fatores, tetos e pesos para qualquer político, partido ou tema.
- **O tema só conta pelo alcance de pessoas atingidas**, pela tabela pública abaixo; nenhum tema pesa por lado político.
- **Título oficial:** a ementa (ou o sumário do discurso) como a casa publicou.
- **Só contagens de terceiros:** nenhum texto de notícia ou post é guardado nem publicado.

## Fórmula

```text
peso = round(0,5 × repercussão + 0,5 × impacto)                     0 a 100

repercussão = 100 × (0,40 × L(notícias da proposição, 200)
                   + 0,20 × L(notícias com o nome do político, 2.000)
                   + 0,25 × L(visitas ao artigo do político, 300.000)
                   + 0,15 × L(visitas ao artigo do tema, 100.000))
L(x, teto)  = min(1, log10(1 + x) / log10(1 + teto)); sinal não medido = 0

impacto = 100 × (0,35 × tipo + 0,20 × abrangência + 0,25 × estágio + 0,20 × alcance do tema)
```

- **Tipo:** PEC 1,0; PLP 0,85; MPV 0,8; PL, PLS, PLC, PLN e PLV 0,7; PDL, PDS e PDC 0,45; PRC, PRS e PR 0,3; requerimento e indicação 0,1; discurso 0,1; outros 0,2.
- **Abrangência:** nacional 1,0 (Câmara, Senado, Presidência); estadual 0,5 (assembleias, governos); municipal 0,2.
- **Estágio:** apresentado 0,25; aprovado em comissão 0,5 (ainda não medido); votado e rejeitado em plenário 0,6; aprovado em plenário 0,75; virou lei 1,0. O estágio vem de uma votação de plenário com a mesma proposição (`PL 1234/2025`) e da lista de leis do dia da Câmara (`transformada em norma`).
- **Alcance do tema** (o maior entre os temas da ação; sem tema, 0,5):

| Tema | Alcance | Por quê |
| --- | --- | --- |
| saúde, economia, impostos, segurança, consumidor, meio ambiente, política | 1,0 | atinge toda a população |
| educação, social, transporte, cidade, mulheres, direitos, tecnologia | 0,7 | atinge parte grande da população |
| campo, cultura | 0,4 | atinge um grupo específico |
| homenagens | 0,1 | datas e títulos simbólicos, sem efeito material |

## Destaque do momento

- **Candidatos:** cada proposição apresentada no escopo (uma vez só, mesmo com vários autores; vale o autor de maior peso e o subtítulo diz "e mais N") e cada votação nominal de plenário de PEC, PLP, MPV, PL ou PDL. Discursos e votos individuais ficam só no perfil.
- **Decaimento:** `peso × 0,5^(dias desde a data / 14)`, só com fatos dos últimos 90 dias, até 4 itens (um principal e três secundários), sem repetir a mesma proposição.
- **Nunca vazio:** sem nada nos 90 dias, entra o candidato de maior peso de qualquer data.
- **Tipos previstos:** `action`, `vote`, `money` e `indicator`. A carga desta frente gera `action` e `vote`; `money` e `indicator` entram quando as séries de preço (ANP, IPCA) e o antes e durante o mandato forem publicados.

## Destaque na tela de bloqueio (Live Activity)

Regra fixa e pública, a mesma para todos (publicada em `method/weight.json › alert`):

- **Peso ≥ 85** de 100 (`minWeight: 85`).
- **Fato do último dia** (`maxAgeHours: 24`): conta a partir do fim do dia do fato no horário de Brasília (as fontes só dão a data), então vale para fatos de hoje e de ontem até 24 h depois da meia-noite.
- **Uma vez por aparelho:** o app guarda os ids já mostrados no App Group (`fiscal.highlightAlerts.shown`, últimos 60) e o servidor guarda os ids já enviados em `DATA_DIR/highlight-alerts.json` (14 dias). Só o primeiro destaque da lista que passa da regra entra; um novo tira o anterior da tela.
- **Duração:** 8 h (`endsAt` e `stale-date`); o app encerra na abertura seguinte o que passou do prazo, e o sistema encerra sozinho em 8 h.
- **Início:** local, quando o app abre ou volta para a frente e lê `highlights.json`; ou por push-to-start (iOS 17.2+), quando o servidor da apuração lê um `PUBLIC_DIR/v1/highlights.json` novo (confere a cada minuto, só relê quando o arquivo muda).
- **Desligável** em Ajustes › Seus dados e privacidade › "Destaques importantes na tela de bloqueio" (ligado por padrão). Desligado, o app não inicia, encerra o que estiver na tela e apaga o registro do token no servidor.
- **Privacidade:** o registro leva só o token de push-to-start da Apple e o ambiente, no corpo (nunca na URL), vale 30 dias e é renovado a cada abertura; nenhum dado da pessoa vai junto.

```text
POST   /api/v1/highlight-activities  { pushToken, environment } → 204 | 422 | 413 | 409 token_bound_to_other_environment | 429 | 507
DELETE /api/v1/highlight-activities  { pushToken }              → 204 | 422 | 413 | 429
push-to-start: aps { event: "start", attributes-type: "HighlightActivityAttributes",
                     attributes { highlightId, kind, title, subtitle, date, route, personName?, personSlug?, party? },
                     content-state { weight, endsAt }, alert { title, body }, stale-date, relevance-score }
```

## Fontes de repercussão

| Fonte | Endereço | O que conta | Estado |
| --- | --- | --- | --- |
| GDELT DOC 2.0 | `https://api.gdeltproject.org/api/v2/doc/doc?query="PL 1234/2025" sourcelang:portuguese&mode=timelinevolraw&timespan=30d&format=json` | soma de `timeline[].data[].value` (notícias por dia) | medido, com limite de uma consulta a cada 5 s; a carga espera 6 s, faz até `NEWS_BUDGET` (120) consultas por carga, em ordem de impacto, guarda por 3 dias e para no primeiro 429 |
| Wikipédia em português | `https://pt.wikipedia.org/w/api.php?action=query&formatversion=2&redirects=1&prop=pageprops|description&ppprop=disambiguation&titles=…` | título do artigo do político (nome de urna, depois nome civil; não pode ser desambiguação e a descrição precisa falar de política) | medido, lotes de 50, guardado por 30 dias |
| Wikimedia Pageviews | `https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/pt.wikipedia/all-access/user/{artigo}/daily/{início}00/{ontem}00` | soma de `items[].views`, 30 dias, sem robôs | medido, guardado por 24 h |
| Bluesky | `https://public.api.bsky.app/xrpc/app.bsky.feed.searchPosts` | — | fora: responde 403 sem autenticação (testado em 2026-10-25) |

X, Instagram, TikTok e YouTube não têm busca aberta e gratuita usada aqui; entrar com uma delas é decisão do usuário, porque tem custo.

## Arquivos

- `v1/people/{slug}/actions.json`: `{ items: [Action], sources }`, até 40 ações dos dois últimos anos carregados, por peso (empate: data, depois id). Só existe quando há ação.
- `v1/highlights.json`: `{ generatedAt, items: [Highlight], method: WeightMethod, sources }`.
- `v1/method/weight.json`: `WeightMethod`, a mesma explicação de `highlights.json › method`.

```text
Action { id, kind ∈ proposal | vote | speech, title, proposition, date, url, ref (id da votação), ballot,
         scope, stage, themes, weight, repercussion, impact,
         signals { news, newsPerson, wiki, wikiTheme, bluesky, test } }
Highlight { id, kind ∈ action | vote | money | indicator, title, subtitle, weight, repercussion, impact,
            route (slug, id da votação ou do indicador), person (PersonCard ou null), proposition, date, url, signals }
WeightMethod { version, summary, formula, repercussion, impact, parts, signals, impactParts,
               kinds, scopes, stages, themes, decay { halfLifeDays, windowDays, text }, rules, limits, sources,
               alert { minWeight, maxAgeHours } }
```

`signals.*` é `null` quando o sinal não foi medido; `signals.test` é `true` só no showcase do app.

## Limites conhecidos

- A repercussão mede quanto se fala, não o tom nem se é verdade.
- O nome de urna pode ter homônimos no GDELT e na Wikipédia.
- O estágio "aprovado em comissão" não é medido: os arquivos abertos usados não trazem o parecer.
- O GDELT mede uma parte por carga; o resto fica sem notícia (zero) até a próxima.
