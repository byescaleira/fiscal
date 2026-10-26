# Apuração ao vivo com Live Activity

Proposta da mudança `live-results`.

- **Estado:** em andamento
- **Data:** 2026-10-25
- **Branch:** `feature/live-results`

## Por quê

O 2º turno de 2026 é hoje, 25/10, e a apuração começa às 17h (Brasília). A pessoa quer acompanhar presidente e governador sem abrir o app: o placar fica na tela de bloqueio e na Dynamic Island, atualizado pelo servidor com os números oficiais do TSE. Esta é a fase 1 do [roadmap](../../roadmap.md), com prioridade total.

## O que muda

- Tela **Apuração** no lugar do exemplo `Item`, com as 7 disputas do 2º turno: Presidente (Brasil) e Governador (AC, AM, DF, ES, RN, TO).
- Cada disputa mostra:
  - % de urnas apuradas, numa barra (nunca anel);
  - os dois candidatos com votos e % dos válidos;
  - quem foi eleito, quando o TSE marcar;
  - a hora do arquivo do TSE.
- Botão **Acompanhar na tela de bloqueio**, que inicia uma Live Activity da disputa, com a Dynamic Island e a tela de bloqueio.
- A Live Activity é atualizada por push (APNs) a partir do servidor, inclusive com o app fechado, e termina sozinha quando o resultado sai, mostrando o eleito.
- Serviço novo em Go, `server/`, publicado em `fiscal.byescaleira.com/api/*`. Ele lê o TSE a cada 20 s e manda o push só quando o número muda.
- Neutralidade: os candidatos vêm em ordem de votos, sem cor de partido, sem projeção e sem pesquisa. Os números são os do TSE, sem arredondamento além do que o TSE publica.

## Fora do escopo

- Deputados, senadores, perfis e o restante da [pesquisa](../../research/pesquisa-politicometro.md).
- Apuração por cidade ou mapa.
- Iniciar a Live Activity por push (push-to-start) às 17h.
- Widgets da tela de início.
- Publicar na App Store. Hoje a distribuição é pelo Xcode ou pelo TestFlight interno.

## Fonte: arquivos do TSE

Base `https://resultados.tse.jus.br/oficial/ele2026`. Configuração em `https://resultados.tse.jus.br/oficial/comum/config/ele-c.json`.

| Disputa | Eleição | Cargo | Arquivo |
|---|---|---|---|
| Presidente, Brasil | 6258 | 1 | `6258/dados/br/br-c0001-e006258-u.json` |
| Governador, UF ∈ ac, am, df, es, rn, to | 6260 | 3 | `6260/dados/{uf}/{uf}-c0003-e006260-u.json` |

- O arquivo traz `ETag`, `Last-Modified` e `cache-control: max-age≈55`. Os números chegam como string, e as porcentagens com vírgula (`"pvap":"50,12"`).
- **Campos usados:**
  - `dg` e `hg`: data e hora em que o arquivo foi gerado (Brasília);
  - `tf`: totalização final (`s`/`n`);
  - `s.ts`, `s.st` e `s.pst`: seções totais, totalizadas e %;
  - `e.te`, `e.c` e `e.a`: eleitorado, comparecimento e abstenção;
  - `v.vv`, `v.vb`, `v.tvn` e `v.tv`: votos válidos, brancos, nulos e total;
  - `carg[0].agr[].par[].cand[]`: `n` (número), `sqcand`, `nm`, `nmu` (nome de urna), `e` (eleito `s`/`n`), `vap` (votos), `pvap` (% dos válidos), e `par[].sg` (partido).

## Contrato da API (`server/`)

Base `https://fiscal.byescaleira.com/api`. JSON em camelCase. Erros no formato `{"error":{"code":"snake_case","message":"..."}}`. `Cache-Control: no-store` em tudo.

| Rota | Resposta |
|---|---|
| `GET /api/health` | `{"ok":true}` |
| `GET /api/v1/races` | `{"races":[Race], "fetchedAt":"ISO8601"}`, com as 7 disputas na ordem: presidente-br, depois governador por UF em ordem alfabética |
| `GET /api/v1/races/{id}` | `Race`, ou 404 `race_not_found` |
| `POST /api/v1/live-activities` | corpo `{"raceId":"presidente-br","pushToken":"<hex>","environment":"development"\|"production"}` → 204. Validação: corpo ≤ 4 KiB, `raceId` conhecido, token hexadecimal de 32 a 400 caracteres e ambiente válido; senão 422 `invalid_request`. O mesmo token só é guardado uma vez |
| `DELETE /api/v1/live-activities/{pushToken}` | 204 |

`Race`:
```json
{
  "id": "presidente-br",
  "office": "president",
  "uf": "br",
  "round": 2,
  "sections": { "total": 499248, "counted": 0, "percent": 0.0 },
  "electorate": 158745502,
  "turnout": 0,
  "votes": { "valid": 0, "blank": 0, "null": 0, "total": 0 },
  "candidates": [
    { "number": "13", "name": "Lula", "party": "PT", "votes": 0, "percent": 0.0, "elected": false }
  ],
  "final": false,
  "sourceGeneratedAt": "2026-10-24T19:19:13-03:00"
}
```
- `office` ∈ `president`, `governor`.
- `candidates` vem ordenado por votos, do maior para o menor; no empate, pelo número.
- `name` é o `nmu` do TSE em caixa de título, com `da`, `de`, `do`, `dos`, `das` e `e` em minúsculas, exceto na primeira palavra.
- `final` = `tf == "s"` ou algum candidato com `e == "s"`.

### Push da Live Activity

- **APNs:** HTTP/2 com JWT ES256 a partir da chave `.p8`. Host de produção `api.push.apple.com`; de desenvolvimento `api.sandbox.push.apple.com`, que é o que o app instalado pelo Xcode usa.
- **Cabeçalhos:** `apns-push-type: liveactivity`, `apns-topic: com.byescaleira.fiscal.push-type.liveactivity`. `apns-priority: 5` nas atualizações comuns e `10` quando a disputa termina.
- **Corpo:**
```json
{ "aps": {
    "timestamp": 1792960000,
    "event": "update",
    "content-state": {
      "sectionsPercent": 12.34,
      "candidates": [ { "number": "13", "votes": 1234, "percent": 50.1, "elected": false } ],
      "final": false,
      "updatedAt": 1792960000
    },
    "stale-date": 1792960600
} }
```
- **Quando a disputa termina:** `"event":"end"`, `"dismissal-date"` = agora + 4 h, e um `alert` com `title` "Resultado" e `body` "<Nome> foi eleito(a)".
- **Erros do APNs:** em 410 ou `BadDeviceToken`, o token é apagado.
- `updatedAt` é um Unix timestamp em segundos (`Double`), não `Date`, porque o `JSONDecoder` padrão do ActivityKit lê `Date` como segundos desde 2001.

### Atributos da Live Activity (app)

- `ActivityAttributes`: `raceId`, `office`, `uf` e `candidates` (`number`, `name`, `party`), fixados no início.
- `ContentState`: igual ao `content-state` acima.
- O widget junta os dois pelo `number`.

## Specs afetadas

### `docs/specs/live-results.md` (nova)

- **Adicionado:** tudo o que está acima, ao arquivar.

## Impacto

- **Targets:**
  - `FiscalDomain`: modelos `Race` e `Candidate`, e o atributo da atividade, compartilhado com o widget;
  - `FiscalData`: cliente HTTP;
  - `FeatureLiveResults`: no lugar do exemplo `FeatureHome`;
  - extensão de widget nova `FiscalWidgets`, com a Live Activity;
  - app, com `NSSupportsLiveActivities`, `NSSupportsLiveActivitiesFrequentUpdates` e o entitlement `aps-environment`.
- **Servidor:** `server/` em Go 1.26.5, só com a biblioteca padrão, em `/opt/fiscal-api` na porta `127.0.0.1:3130`. O Caddy encaminha `/api/*` de `fiscal.byescaleira.com`.
- **Dados:** nenhum dado da pessoa. O servidor guarda só os push tokens, com a disputa e o ambiente, em `/data/registrations.json` (`0600`).
- **Textos:** chaves novas nos 10 idiomas.

## Decisões pendentes

1. Push-to-start (iniciar a Live Activity às 17h sem abrir o app): fica para depois. Recomendo deixar fora hoje, porque é mais uma frente de risco.

## O que fica com você

- DNS: registro A `fiscal.byescaleira.com` → `179.198.114.91`, na Vercel.
- Chave APNs (`.p8`) e o Key ID, criados no developer.apple.com, em Keys.
- iPhone conectado e desbloqueado para a instalação.
- O ok para cada passo na VPS (subir o serviço e mexer no Caddy).
