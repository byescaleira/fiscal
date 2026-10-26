# API interna do Politicômetro: engenharia reversa

Levantado em 25/10/2026 a partir do que o próprio front-end do site chama: código dos chunks do Next.js, payload RSC das páginas e tráfego de rede no navegador. Cada rota foi chamada uma vez, com parâmetros pequenos, só para ver a estrutura da resposta. Nenhuma base foi baixada.

O objetivo é replicar o **contrato** no nosso servidor, alimentado direto pelas fontes oficiais (seção "De onde vem cada dado"). Os dados deles não devem ser reaproveitados: o site declara "todos os direitos reservados" para código, design e textos.

## Arquitetura inferida

| Peça | O que foi visto |
|---|---|
| Front e API | Next.js App Router na Vercel. As rotas são Route Handlers (`app/api/**/route.ts`) e as páginas são Server Components |
| Cache | Tudo público passa pelo CDN da Vercel (`x-vercel-cache: HIT`), com `Cache-Control` por rota (tabela abaixo) |
| Banco | Muito provavelmente Postgres com `node-postgres`: valores `numeric` chegam como string (`"245604.47"`) e os timestamps vêm no formato do Postgres (`"2026-10-25 04:53:11.15065"`) |
| Fotos | Pré-processadas para WebP e servidas estáticas em `/fotos/{slug}.webp`, cache de 7 dias |
| Carga | Jobs diários de madrugada (03:10 a 05:42), descritos em `/atualizacoes`: Câmara e Senado todo dia, assembleias e câmaras municipais toda semana, Receita todo mês, TSE a cada eleição |
| Perfil | A página `/p/{slug}` **não usa API**: vem pronta no RSC. As rotas `/api/cracha/*` só servem a paginação e a troca de ano |
| Proteção | Vercel Security Checkpoint (o `curl` direto leva 429) |

Para o app iOS isso muda uma coisa importante: o perfil completo precisa de uma rota JSON própria no nosso servidor, porque o iOS não consome RSC.

## Convenções

- **Nomes em português**, em camelCase (`porCategoria`, `temMais`, `igualOrientacao`).
- **Dinheiro:** string decimal nas listas detalhadas (`"valor": "300.12"`) e number nos agregados (`"total": 245604.47`). No nosso servidor, padronizar: **centavos em inteiro** ou sempre string decimal.
- **Datas:** `"YYYY-MM-DD"` ou `"YYYY-MM-DD HH:MM:SS"`, sem fuso (horário de Brasília implícito). No nosso, usar ISO 8601 com fuso.
- **Ausência:** `null` quer dizer "a fonte não publica". O front mostra "—", nunca 0.
- **Erros:** `{ "erro": "mensagem" }` com 400 ou 404.
- **Paginação**, em três estilos:
  - `pagina` (0, 1, 2…), 20 itens, resposta `{ itens, total }`: listas do perfil;
  - cursor `depois` = `"{ordem}|{id}"` (keyset), 60 itens, resposta `{ itens, proximo, total }`: lista geral;
  - `{ itens, temMais }`: votações do Congresso.
- **Identificadores:** `slug` é a chave pública. Em caso de homônimo, ganha sufixo da UF (`lula-br`, `lula-sp`, `quati-sp`). Há também `id` interno, `idCamara` (Câmara) e `sq` (sequencial do candidato no TSE).
- **Fonte por bloco:** cada seção do perfil traz `fontes: [{ credito, url, atualizadoEm }]`.

## Rotas

### Pessoas

#### `GET /api/galeria`
Lista geral, de A a Z. Cache: `public, max-age=300`.

| Parâmetro | Valores |
|---|---|
| `area` | `presidencia` · `senado` · `camara` · `governo_estadual` · `assembleia` · `prefeitura` · `camara_municipal` |
| `uf` | sigla em maiúsculas |
| `partido` | sigla, como aparece no TSE (há variantes: `PC do B`, `PCdoB`, `PCDOB`) |
| `cod` | código IBGE do município |
| `q` | texto livre |
| `letra` | `A`–`Z` |
| `depois` | cursor `proximo` da página anterior |

```json
{
  "itens": [{
    "id": 1650, "slug": "…", "nome": "…", "ordem": "nome sem acento em minúsculas",
    "foto": "/fotos/{slug}.webp", "cargo": "Prefeito", "partido": "PT",
    "uf": "RJ", "situacao": "em_exercicio"
  }],
  "proximo": "abimael|34572",
  "total": 5689
}
```
`cargo` já vem flexionado no gênero (`Senador`/`Senadora`).

`situacao` tem três valores, conferidos percorrendo `area=camara` e `area=senado` inteiras:

| Valor | Câmara | Senado |
|---|---|---|
| `em_exercicio` | 513 | 81 |
| `eleito_aguardando_posse` | 211 | 40 |
| `licenciado` | 8 | 0 |

Por isso `area=camara` devolve 732, e não 513. Quem foi reeleito aparece uma vez só, como `em_exercicio`: o mandato futuro vai no perfil. A lista do app deve filtrar por padrão `situacao=em_exercicio`.

#### `GET /api/galeria/indice`
Mesmos filtros, menos `letra`, `q` e `depois`. Devolve a contagem por letra e as primeiras pessoas de cada uma: `[{ letra, total, rostos: [pessoa + "letra", "n"] }]`.

#### `GET /api/busca?q=`
Autocompletar de pessoas. Cache: `max-age=60`.
`[{ slug, nome, cargo, uf, foto }]`

### Perfil ("crachá")

#### `GET /api/cracha/{slug}/ano/{ano}`
Resumo de um ano. Cache: `max-age=600`.
```json
{
  "ano": 2026,
  "presenca": { "sessoes": 73, "elegiveis": 73, "presentes": 68 },
  "propostas": { "total": 101, "leis": 34, "porTipo": [{ "tipo": "REQ", "n": 39 }],
                 "recentes": [{ "tipo", "numero", "ementa", "url" }] },
  "falas": { "total": 6, "recentes": [{ "data", "tipo", "sumario", "url" }] },
  "votos": { "total": 134, "plenario": 116, "comOrientacao": 116, "igualOrientacao": 107,
             "porVoto": [{ "voto": "Sim", "n": 77 }] },
  "cota": { "total": 245604.47, "gastos": 185, "comNota": 185,
            "porMes": [{ "mes": 1, "total": 0 }], "porCategoria": [{ "categoria", "total" }] },
  "comissoes": [{ "nome", "cargo" }]
}
```
`elegiveis` são as sessões em que a pessoa estava em exercício: licença e período antes da posse não contam como falta.

#### `GET /api/cracha/{slug}/{lista}`
`lista` ∈ `proposicoes` · `votos` · `discursos`. Parâmetros: `pagina`, `ano`, `tema`, `q`. Cache: `max-age=300`. Resposta `{ itens, total }`.

| Lista | Item |
|---|---|
| `proposicoes` | `{ id, tipo, numero, ano, ementa, url }` |
| `votos` | `{ idVotacao, data, orgao, proposicao, descricao, ementa, voto, orientacao, bancada, sim, nao, aprovada, secreta, temVotacao }` |
| `discursos` | `{ data, tipo, sumario, url }` |

`tema` aceita as 17 chaves abaixo (conferido: `saude`, `educacao` e `homenagens` filtram de fato).

| Chave | Nome |
|---|---|
| `saude` | Saúde |
| `educacao` | Educação |
| `seguranca` | Segurança pública |
| `economia` | Trabalho, emprego e economia |
| `impostos` | Impostos e dinheiro público |
| `ambiente` | Meio ambiente e animais |
| `cidade` | Cidade, moradia e saneamento |
| `transporte` | Transporte e trânsito |
| `social` | Assistência social, crianças e idosos |
| `mulheres` | Mulheres |
| `campo` | Campo e agricultura |
| `cultura` | Cultura, esporte e turismo |
| `direitos` | Direitos e igualdade |
| `consumidor` | Consumidor |
| `tecnologia` | Internet e tecnologia |
| `politica` | Política e eleições |
| `homenagens` | Homenagens, datas e nomes de ruas |

**Votos de deputado e de senador têm formatos diferentes** na mesma lista:

| Campo | Deputado | Senador |
|---|---|---|
| `idVotacao` | id da Câmara (`"2236186-60"`) | prefixo `SF-` (`"SF-7042"`) |
| `orgao` | `PLEN`, ou a sigla da comissão (`CCJC`) | `PLEN-SF` |
| `voto` | `Sim`, `Não` | `Sim`, `Não`, `Votou (votação secreta)`, `Presente – Não registrou voto` e os demais registros do Senado (licença, missão, não compareceu) |
| `orientacao` | `Sim`, `Não`, `Obstrução`, `Liberado` ou `null` | sempre `null`: o Senado não publica orientação de bancada |
| `bancada` | partido ou bloco | `null` |

Consequência: "votou igual ao partido" só existe para deputados. No Senado, a "presença" sai dos registros de votação nominal.

#### `GET /api/cracha/{slug}/gastos`
Cota parlamentar (deputados e senadores) ou verba de gabinete (assembleias). Parâmetros: `pagina`, `ano`, `mes` (1–12) e `categoria`, que precisa ser o texto exato devolvido em `porCategoria`, como `COMBUSTÍVEIS E LUBRIFICANTES.`. Os quatro foram conferidos e se combinam: `soma` e `total` respeitam os filtros.
```json
{
  "anos": [2026, 2025],
  "soma": "245604.47", "total": 185,
  "porMes": [{ "periodo": 1, "total": "26970.88" }],
  "porCategoria": [{ "categoria": "…", "n": 15, "total": "121500.00" }],
  "itens": [{ "id", "ano", "mes", "categoria", "fornecedor", "cnpj", "valor", "url", "casa" }]
}
```

#### O que vem só no RSC de `/p/{slug}`
É o que a nossa rota `GET /v1/politicos/{slug}` precisa devolver:

| Bloco | Campos |
|---|---|
| cabeçalho | nome, cargo, uf, partido, idade, naturalidade, situação, mandatos atual e futuro, vezes eleito e reeleito |
| `numeros` | cartões prontos `{ chave, rotulo, valor, detalhe, ancora }`: salário, ganhos, cota, bens, votos, campanhas, presença, propostas. **No nosso, mandar o número cru e formatar no app** |
| `salario` | `{ mensal, fonte }`, a partir da lei vigente |
| `ganhos` | `{ total, meses, estimativa, porCargo: [{ cargo, meses, total }], leis: [{ lei, url }] }`, calculado como salário da lei × meses em exercício |
| `resumo` | por ano: `{ ano, presentes, elegiveis, proposicoes, leis, discursos, votos, cota }` |
| `sessoes` | grade de presença: `{ idEvento, casa, data, urlVideo, presente, elegivel }` |
| `temas` | `{ chave, propostas, falas }`, mais `anosPropostas` e `anosFalas` |
| `campanhas` | `{ sq, ano, cargo, situacao, receitas, despesas, tipo }` e itens `{ sq, tipo: receita\|despesa, categoria, nome, publico, valor, n }` |
| `bens` | por ano `{ ano, total, itens }` e itens `{ ano, tipo, valor }` |
| `equipe` | `{ casa, pessoas: [{ nome, cargo, funcao, vinculo, lotacao, desde, bruto, mesFolha, partes, nota }], fontes }` |

Os blocos abaixo chegam já como HTML, sem props estruturadas. Os campos foram tirados do conteúdo exibido:

| Bloco | Campos |
|---|---|
| comissões (por ano) | `{ nome, cargo (Titular, Suplente, 3º Vice-Presidente…), inicio, fim \| null (= atual) }` |
| viagens e missões (por ano) | deputado: `{ inicio, fim, tipo (Missão oficial, Visita técnica…), destino, descricao, passagens, diarias, url }` e o custo somado no topo. Senador: `{ data, tipo (missão com ou sem ônus), requerimento, comOnus, url }`, sem valores |
| linha do tempo | por candidatura no TSE, de 2008 em diante: `{ ano, resultado (Eleito por QP, Suplente, Não eleito, Candidatura cassada…), cargo, local, partido, esfera, votos }`, mais as trocas de partido entre uma e outra |
| quanto custa o mandato | `{ salario, gabinete (verba mensal ou nº de cargos), moradia (imóvel funcional ou auxílio), cotaTeto (por UF), atos: [{ nome, url }], avisos }` |
| dados e contato | `{ nomeCivil, nascimento, escolaridade, gabinete, telefone, email }` e os canais fixos de "como cobrar" (ouvidoria da casa, Fala.BR, MPF e TCU) |
| o que está e o que não está | checklist por tipo de dado: salário, presença, votos, projetos, discursos, gastos, bens e contas de campanha, cada um com `{ status, fonte }` |
| propostas de governo | só para candidatos a cargo executivo: `{ disputa, ano, partes: [{ url, paginas }] }` |

#### Diferenças do perfil de senador
Conferido no RSC de um senador:
- **presença:** `resumo[].presentes` e `elegiveis` vêm `null`, sem a grade de sessões. O bloco explica que o Senado não publica presença;
- **votos:** formato próprio, descrito na tabela acima;
- **equipe:** traz a remuneração de cada pessoa, que a Câmara não publica: `bruto`, `mesFolha` e `partes: { basica, abateTeto, eventuais, vantagensPessoais, funcaoComissionada }`;
- **custo:** o gabinete aparece como "até 50 cargos comissionados", sem valor mensal; o teto da cota é por UF;
- `idCamara` vem `null`; o Senado tem o próprio código de parlamentar.

### Lugares

| Rota | Cache | Resposta |
|---|---|---|
| `GET /api/municipios?q=` | 1 dia | `[{ cod, nome, uf, tipo: "cidade" \| "uf" }]` |
| `GET /api/estado/{uf}` | CDN 1 h + SWR 1 dia | `{ casas: { senado, camara, assembleia, governo_estadual, prefeitura, camara_municipal }, cidades, rostos: [{ slug, nome, cargo, partido, foto }] }` |
| `GET /api/mapa/{uf}` | CDN 1 dia + SWR 7 dias | `[{ cod, nome, chave, path }]`, em que `path` é o SVG do município (IBGE simplificado) |
| `GET /api/cobertura?q=` | 1 h | `[{ cod, nome, uf, salPrefeito, salVereador, fonteSal, atividade }]`: o que cada cidade publica |

"Quem me representa" (`/representantes?cidade={cod}` ou `?uf=`) não tem API: é HTML renderizado no servidor. O conteúdo é:
- grupos por nível (cidade, estado, Brasília) e, dentro deles, por cargo;
- em cada grupo, rostos `{ slug, nome, foto, cargo, partido }` (a web mostra os 12 primeiros e expande o resto);
- um aviso de cobertura da câmara municipal, por exemplo "a Câmara publica (SAPL), mas o sistema dela está fora do ar ou com erro".

No nosso servidor isso vira uma rota JSON.

### Congresso, STF, eleições e impostos

| Rota | Parâmetros | Resposta |
|---|---|---|
| `GET /congresso/votacoes` | `dia=YYYY-MM-DD`, `casa=camara\|senado` | `{ itens: [{ id, casa, data, hora, proposicao, tipo, resumo, etapa, resultado, aprovada, nominal, procedimento, placar, sim, nao }], temMais }` |
| `GET /congresso/votacao/{id}` | — | o item acima mais `{ ementa, decidido, secreta, quorum, outros, registro, orientacoes, partidos, pessoas, urlDados, urlOficial, urlVideo }` (detalhe abaixo) |
| `GET /stf/lista` | `lista=recentes\|pauta\|parados` (qualquer outro valor dá 400) | `{ casos: [{ id, classe, numero, assunto, relator, relatorCodigo, data, link, resumo, eventos: [{ identificacao, ambiente: virtual\|presencial, estado: pauta\|concluido\|adiado…, inicio, fim, sessao, aFavor, contra, dispositivo, votos, suspensao }] }] }`. Em 25/10: 454 recentes, 39 na pauta e 117 parados |
| `GET /api/apuracao/vivo` | — | `{ lidoEm, presidente: { andamento, definido, geradoEm, secoes: { total, totalizadas, pct }, votos: { validos, brancos, nulos, total }, candidatos: [{ sq, nome, numero, partido, votos, pct, eleito }] } }` |
| `GET /api/apuracao/{uf}` | `cargo=presidente\|governador`; `uf` em qualquer caixa; `br` dá 404 | `{ uf, nome, disputa, temGov, pagina, a: { eleicao, cargo, turno, abrangencia, andamento, definido, geradoEm, totalizadoEm, eleitorado, comparecimento, abstencao, secoes, votos, candidatos: [{ sq, nome, nomeUrna, numero, partido, coligacao, vice, votos, pct, eleito, situacao }] }, cidades: [{ id, nome, path, lider, detalhe, href }], cores: { "{numero}": "#hex" }, pessoas: { "{sq}": { slug, foto } } }` |

**Detalhe de votação nominal** (conferido numa votação da Câmara com 404 votos):
```json
{
  "nominal": true, "sim": 286, "nao": 116, "outros": 2,
  "placar": "286 sim × 116 não · 2 outros",
  "resultado": "Mantido", "aprovada": null, "decidido": "Mantido o texto.",
  "quorum": "Para passar, projeto de lei complementar precisa de…",
  "orientacoes": [{ "b": "PL", "o": "Não" }],
  "partidos": [{ "p": "PL", "v": { "Sim": 10, "Não": 50, "Obstrução": 1 } }],
  "pessoas": [{ "voto": "Sim", "nomes": [{ "slug", "nome", "foto", "partido", "orientacao" }] }]
}
```
`pessoas` agrupa por voto, e cada pessoa traz a orientação que o próprio partido deu, o que permite marcar quem votou contra. Na votação simbólica, `orientacoes`, `partidos` e `pessoas` vêm vazios e `sim`, `nao` e `outros` vêm `null`. `aprovada` fica `null` quando o resultado não é aprovar ou rejeitar (destaque mantido, por exemplo).
| `GET /api/impostos` | `ano`, `mes`, `uf` | `{ total, porUf: [{ uf, total }], grupos: [{ chave, nome, explicacao, total, itens: [{ nome, total }] }] }` |

Ficam fora de `/api` porque são Route Handlers dentro das pastas das páginas.

### Conta, contato e métricas

| Rota | Uso |
|---|---|
| `GET /api/conta/eu` | `{ ligado, conta }` (sessão por cookie, `no-store`) |
| `GET /api/conta/acompanhando` | `{ slugs: [] }`: quem a pessoa segue |
| login | código por e-mail, via Server Action; não há rota REST |
| `POST /api/lead` / `POST /api/whatsapp` | cadastro para receber novidades (`email`, ou `telefone` + `aceite`) |
| `POST /api/sugestao` | formulário de sugestão `{ cidade, tipo, pagina, … }` |
| `GET` e `POST /api/online` | contador de "pessoas no site agora" (`{ agora, total, desde, estimado }`), via `sendBeacon` |
| `GET` e `POST /api/evento` | analytics próprio, sem cookie: o GET devolve `{ modo, amostra }` (taxa de amostragem) e o POST manda lotes de até 25 eventos |
| `GET /api/mais-vistos` | `{ em, pessoas, fora, politicos, estados, cidades, areas, origem, segundoTurno }`, janela de 24 h e mínimo de 3 pessoas |
| `POST /api/mcp` | servidor MCP (Streamable HTTP), ainda fechado ao público. Ferramentas anunciadas: `buscar_politico`, `ver_politico`, `listar_votos`, `listar_propostas`, `listar_discursos`, `listar_gastos`, `quem_me_representa`, `eleicoes`, `arrecadacao_federal`, `comparar_politicos` |

## Regras de negócio que aparecem nos dados

- **Presença:** só sessões deliberativas encerradas do Plenário, e só no período em exercício (`elegivel`). Sessão sem lista publicada não vira falta.
- **Votos:** `igualOrientacao / comOrientacao` = % de votos iguais à orientação do partido ou bloco.
- **Temas:** a lista de temas fica no JavaScript do cliente. Cada um dos 17 tem uma lista de radicais procurados na ementa ou no sumário, sem acento e em minúsculas, por exemplo "hospita" e "vacin" para saúde. Um radical terminado em `!` exige a palavra inteira (`sus!`, `ubs!`), para evitar falsos positivos. Um item pode cair em vários temas e muitos ficam sem nenhum: o site avisa quantos "falam de outros assuntos". **Não copiar as listas deles:** escrever as nossas com a mesma técnica e guardar o tema já calculado no banco.
- **Ementa simplificada:** também roda no cliente, com expressões regulares aplicadas ao texto oficial, que a API devolve sem mudança:
  - remove "e dá outras providências";
  - "Altera a Lei nº X, de [data], para…" vira "Muda uma lei para…";
  - com mais de um número de lei, vira "Muda leis…";
  - quando a ementa cita o nome da lei, usa o nome: "Muda o Código…", "Muda a Consolidação…", "Muda a lei (nome)…";
  - "Altera os arts. … da Lei" é normalizado antes; o caso da Constituição tem regra própria ("Muda a Constituição para…").

  Fazer o mesmo no app ou no servidor, com regras nossas.
- **"Podem virar lei":** separa PL, PLP, PEC e PDL de requerimentos e emendas (`propostas.leis`).
- **Ganhos:** salário da lei vigente em cada período × meses no cargo (`estimativa: true` quando falta dado).
- **Slugs:** `nome-de-urna` normalizado, mais `-uf` em caso de colisão.

## De onde vem cada dado (para a nossa carga)

Conferido em 25/10/2026 com chamadas reais: cabeçalhos, primeiras linhas dos arquivos e leitura parcial dos ZIPs. O que só foi lido na documentação está marcado com *(doc)*.

### Câmara dos Deputados

- **API:** `https://dadosabertos.camara.leg.br/api/v2`, JSON com `Accept: application/json`.
- **Paginação:** `pagina` e `itens`, com no máximo 100 itens por página. O total vem em `x-total-count` e os links em `link`.
- **Respostas:** trazem `cache-control: max-age=1800` e `retry-after: 30`. Não há limite de requisições documentado.
- **Arquivos anuais:** `https://dadosabertos.camara.leg.br/arquivos/{conjunto}/{csv|json|xml}/{conjunto}-{ano}.{formato}`. O CSV usa `;` e UTF-8 com BOM, e é regerado todo dia entre 03h e 07h UTC.

| Dado | Onde | Campos que importam | Desde |
|---|---|---|---|
| Deputados em exercício | `GET /deputados?itens=100&ordem=ASC&ordenarPor=nome` | `id, nome, siglaPartido, siglaUf, idLegislatura, urlFoto, email` | — |
| Detalhe e contato | `GET /deputados/{id}` | `nomeCivil, cpf, sexo, dataNascimento, municipioNascimento, escolaridade, redeSocial, ultimoStatus{nomeEleitoral, situacao, condicaoEleitoral, gabinete{predio, sala, telefone, email}}` | — |
| Exercício (licenças, posse) | `GET /deputados/{id}/historico` | `dataHora, situacao, condicaoEleitoral, descricaoStatus, siglaPartido` | legislaturas anteriores |
| Autoria de proposições | arquivo `proposicoesAutores-{ano}` | `idProposicao, idDeputadoAutor, tipoAutor, ordemAssinatura, proponente` | 1934 |
| Proposições | arquivo `proposicoes-{ano}` (2026: 41 MB) | `id, siglaTipo, numero, ano, ementa, keywords, dataApresentacao, urlInteiroTeor, ultimoStatus_*` | 1934 |
| Discursos | `GET /deputados/{id}/discursos?dataInicio=&dataFim=` | `dataHoraInicio, tipoDiscurso, sumario, transcricao, urlTexto, urlVideo` | — |
| Votações | arquivo `votacoes-{ano}` | `id, data, siglaOrgao, idEvento, aprovacao, votosSim, votosNao, votosOutros, descricao` | 1946 |
| Votos | arquivo `votacoesVotos-{ano}` (2026: 18 MB) | `idVotacao, voto, deputado_id, deputado_siglaPartido` | 2001 |
| Orientações | arquivo `votacoesOrientacoes-{ano}` | `idVotacao, siglaBancada, orientacao` | 2003 |
| Votação ↔ proposição | arquivo `votacoesProposicoes-{ano}` | `idVotacao, proposicao_id, proposicao_siglaTipo, proposicao_numero, proposicao_ano, proposicao_ementa` | — |
| Votação do dia (incremental) | `GET /votacoes?idOrgao=180&dataInicio=`, `/votacoes/{id}/votos`, `/votacoes/{id}/orientacoes` | no JSON, o objeto do deputado se chama `deputado_` (com sublinhado) | — |
| **Presença** | arquivo `eventosPresencaDeputados-{ano}` (`idEvento, idDeputado, dataHoraInicio`), cruzado com `eventos-{ano}` (`descricaoTipo = "Sessão Deliberativa"`) e `eventosOrgaos-{ano}` (`idOrgao = 180`, Plenário) | atrasa 1 a 2 dias; para o dia corrente, `GET /eventos?codTipoEvento=110&idOrgao=180` e `/eventos/{id}/deputados` | 1991 |
| Cota (CEAP) | `https://www.camara.leg.br/cotas/Ano-{ano}.csv.zip` (2026: 4,4 MB) | `ideCadastro (= id da API), cpf, numMes, numAno, txtDescricao, txtFornecedor, txtCNPJCPF, vlrLiquido, urlDocumento, ideDocumento` | 2009 completo (2008 parcial) |
| Comissões | arquivo `orgaosDeputados/csv/orgaosDeputados-L{legislatura}.csv`, ou `GET /deputados/{id}/orgaos` | `siglaOrgao, nomeOrgao, cargo, dataInicio, dataFim` | — |
| Equipe do gabinete | `https://dadosabertos.camara.leg.br/arquivos/funcionarios/csv/funcionarios.csv` (3,5 MB) | `grupo` ("Secretário Parlamentar", `codGrupo` 6), `nome, cargo, lotacao, dataNomeacao`; para secretários, `uriLotacao` aponta para o deputado | só o estado do dia anterior, sem histórico e sem salário |
| Foto | `https://www.camara.leg.br/internet/deputado/bandep/{id}.jpg` | volta com `no-cache`: guardar no nosso armazenamento | — |
| Viagens | sem dado aberto: só a busca em HTML `camara.leg.br/missao-oficial/missao-pesquisa` | — | — |

Armadilhas:
- `GET /deputados/{id}/despesas?ano=X` sem `idLegislatura` volta vazio; com `idLegislatura=57&ano=X` funciona;
- o `deputados.csv` em lote vem com o `cpf` vazio: o CPF só sai do detalhe ou do CSV da cota;
- para sessão deliberativa, o código de tipo de evento é `110` (`204` volta vazio).

### Senado Federal

- **API:** `https://legis.senado.leg.br/dadosabertos`, em JSON com o sufixo `.json` ou `Accept: application/json` (sem isso vem XML). Cache de `max-age=900`.
- **Limite:** acima de 10 requisições por segundo dá 429, e em pico pode dar 503 *(doc)*.
- **Dois formatos de resposta:** os serviços novos (`/votacao`, `/processo`) devolvem listas planas em camelCase; os antigos, `{Raiz:{…}}` em PascalCase.
- **Serviços descontinuados:** `/senador/{c}/autorias`, `/senador/{c}/votacoes`, `/relatorias`, `/liderancas` e a família `/materia/*` passaram do Sunset (01/02/2026). Ainda respondem, mas **não usar**.

| Dado | Onde | Campos que importam |
|---|---|---|
| Senadores em exercício | `/senador/lista/atual.json` | `IdentificacaoParlamentar{CodigoParlamentar, NomeParlamentar, NomeCompletoParlamentar, SexoParlamentar, UrlFotoParlamentar, EmailParlamentar, SiglaPartidoParlamentar, UfParlamentar}`, `Mandato` |
| Detalhe | `/senador/{codigo}.json` | `DadosBasicosParlamentar{DataNascimento, Naturalidade}`, `Telefones`. **Sem CPF** |
| Mandatos e exercício | `/senador/{codigo}/mandatos.json` (e `/licencas`, `/filiacoes`) | `Exercicios[]{DataInicio, DataFim}`, `Suplentes`, `Partidos` |
| Comissões | `/senador/{codigo}/comissoes.json?ativo=S` | `SiglaComissao, NomeComissao, DescricaoParticipacao, DataInicio, DataFim` |
| Autorias | `/processo?codigoParlamentarAutor={codigo}` | `id, identificacao ("RQS 41/2023"), ementa, tipoDocumento, dataApresentacao, situacaoAtual, tramitando, urlDocumento` |
| Discursos | `/senador/{codigo}/discursos.json?dataInicio=AAAAMMDD&dataFim=AAAAMMDD` (janela máxima de 1 ano) | `CodigoPronunciamento, TipoUsoPalavra, DataPronunciamento, TextoResumo, UrlTexto` |
| Votações e votos | `/votacao?dataInicio=AAAA-MM-DD&dataFim=` (máximo de 1 ano, acima disso dá 400) ou `?codigoParlamentar=` | `codigoSessaoVotacao, dataSessao, identificacao, descricaoVotacao, resultadoVotacao, votacaoSecreta, totalVotosSim/Nao/Abstencao, votos[]{codigoParlamentar, siglaVotoParlamentar}` |
| Códigos de comparecimento | `/plenario/lista/tiposComparecimento.json` | `Sim`, `Não`, `Votou` (secreta), `P-NRV` (presente sem voto), `AP`, `LS`, `NCom`, `AUS`, `L1`–`L7`, `MIS`… |
| Cota (CEAPS) | `https://adm.senado.gov.br/adm-dadosabertos/api/v1/senadores/despesas_ceaps/{ano}` (JSON; use esta, porque traz `codSenador`) | `codSenador, ano, mes, tipoDespesa, cpfCnpj, fornecedor, documento, data, valorReembolsado` |
| Recursos do gabinete | `…/api/v1/senadores/{codigo}/recursos-utilizados?ano=` | cota, diárias de viagem, auxílio-moradia e pessoal por lotação |
| Equipe | `…/api/v1/servidores/servidores/comissionados` | `nome, vinculo, cargo, funcao, lotacao{nome}`. A lotação traz o **nome** do senador, não o código; a remuneração está em `/servidores/remuneracoes/{ano}/{mes}` *(doc)* |
| Foto | `https://legis.senado.leg.br/senadores/fotos-oficiais/{codigo}` (a URL que vem na API passa por 2 redirecionamentos) | — |

Presença: o Senado **não publica** lista por sessão. O que existe é o comparecimento em cada votação nominal, que lista os 81 senadores com um código. Nosso perfil deve mostrar "presença não publicada pelo Senado", como faz o Politicômetro, e no máximo "registros nas votações nominais".

### TSE

- **Catálogo (CKAN):** `https://dadosabertos.tse.jus.br/api/3/action/package_show?id={pacote}`.
- **Pacotes:** `candidatos-2022`, `candidatos-2026`, `resultados-2022`, `resultados-2026`, `prestacao-de-contas-eleitorais-2026` e, para 2022, `dadosabertos-tse-jus-br-dataset-prestacao-de-contas-eleitorais-2022`.
- **Arquivos:** ZIPs em `https://cdn.tse.jus.br/estatistica/sead/odsele/`, com um CSV por UF, um `_BRASIL.csv` e o `leiame.pdf`. CSV em Latin-1 com `;`. Ausência vem como `-1`, `-3`, `-4`, `#NULO`, `#NE` ou "NÃO DIVULGÁVEL".
- **Leitura parcial:** o servidor aceita HTTP Range, então dá para ler só o CSV de uma UF de dentro do ZIP.

| Dado | Arquivo (2022 / 2026) | Tamanho | Campos que importam |
|---|---|---|---|
| Candidaturas | `consulta_cand/consulta_cand_{ano}.zip` | 4,4 / 3,2 MB | `SQ_CANDIDATO, CD_CARGO, DS_CARGO, SG_UF, SG_UE, NM_CANDIDATO, NM_URNA_CANDIDATO, NR_CPF_CANDIDATO, SG_PARTIDO, DT_NASCIMENTO, DS_GENERO, DS_GRAU_INSTRUCAO, DS_OCUPACAO, DS_SIT_TOT_TURNO` |
| Bens | `bem_candidato/bem_candidato_{ano}.zip` | 5,7 / 3,8 MB | `SQ_CANDIDATO, DS_TIPO_BEM_CANDIDATO, DS_BEM_CANDIDATO, VR_BEM_CANDIDATO ("20000,00")` |
| Votos por município | `votacao_candidato_munzona/votacao_candidato_munzona_{ano}.zip` | **643 / 397 MB** | `SQ_CANDIDATO, CD_MUNICIPIO (código TSE, não IBGE), QT_VOTOS_NOMINAIS_VALIDOS, DS_SIT_TOT_TURNO` |
| Contas de campanha | `prestacao_contas/prestacao_de_contas_eleitorais_candidatos_{ano}.zip` | **467 / 201 MB** | receitas: `SQ_CANDIDATO, DS_ORIGEM_RECEITA, NM_DOADOR, VR_RECEITA`; despesas contratadas: `SQ_CANDIDATO, NM_FORNECEDOR, DS_ORIGEM_DESPESA, VR_DESPESA_CONTRATADA`. As despesas pagas não têm `SQ_CANDIDATO`: ligar por `SQ_PRESTADOR_CONTAS` |
| Fotos | `https://cdn.tse.jus.br/estatistica/sead/eleicoes/eleicoes{ano}/fotos/foto_cand{ano}_{UF}_div.zip` | SP 2026: 15,6 MB | arquivo `F{UF}{SQ_CANDIDATO}_div.jpg` |

A eleição de 2026 já está publicada, com eleitos e suplentes em `DS_SIT_TOT_TURNO`. Para a v1, basta filtrar `CD_CARGO` 5 (senador) e 6 (deputado federal) na leitura.

### IBGE

| Dado | Onde |
|---|---|
| Municípios | `https://servicodados.ibge.gov.br/api/v1/localidades/municipios?view=nivelado` (`municipio-id`, `municipio-nome`, `UF-sigla`) |
| Mapas | `https://servicodados.ibge.gov.br/api/v3/malhas/estados/{UF}?formato=application/vnd.geo+json&intrarregiao=municipio&qualidade=minima` (GeoJSON, `properties.codarea` = código IBGE) |

### Como ligar as bases

| Ligação | Chave |
|---|---|
| Deputado ↔ candidatura no TSE | **CPF**: `cpf` em `/deputados/{id}` ou no CSV da cota ↔ `NR_CPF_CANDIDATO`. O CPF é público nas duas fontes |
| Senador ↔ candidatura no TSE | sem CPF no Senado: nome completo ou nome de urna + UF + `CD_CARGO=5` + ano, revisando à mão os ambíguos (são só 81) |
| Tabelas do TSE entre si | `SQ_CANDIDATO` + `ANO_ELEICAO`; nas contas, também `SQ_PRESTADOR_CONTAS` |
| Município do TSE ↔ IBGE | os códigos são diferentes e precisam de uma tabela de-para, cuja fonte ainda não foi conferida. Fica para quando houver vereadores e prefeitos |
| Votação ↔ sessão | `idEvento` (Câmara) e `codigoSessao` (Senado) |

### Fora da v1

| Dado | Fonte | Situação |
|---|---|---|
| Apuração ao vivo | `resultados.tse.jus.br` | não conferido |
| Arrecadação | Receita Federal | não conferido |
| Assembleias e câmaras municipais | SAPL de cada casa | não conferido |
| STF | portal do STF | não tem API |

### Rotina de carga sugerida

1. **Todo dia, depois das 08h UTC:** baixar os arquivos anuais da Câmara do ano corrente com `If-Modified-Since`, mais a CEAPS e as votações do Senado da janela recente.
2. **Ao longo do dia:** usar a API só para o incremental (`/eventos` e `/votacoes` de hoje) e para o detalhe de cada parlamentar.
3. **Por eleição:** TSE, lendo só as UFs e os cargos necessários.
4. **Uma vez, depois só quando mudar:** fotos baixadas, convertidas para WebP e servidas pelo nosso CDN.

## Proposta para o nosso servidor (v1, só federal)

Mesmo contrato, simplificado, versionado e com tudo em JSON, inclusive o perfil:

| Rota | Equivale a |
|---|---|
| `GET /v1/politicos?area&uf&partido&q&letra&cursor` | `/api/galeria` |
| `GET /v1/busca?q=` | `/api/busca` |
| `GET /v1/politicos/{slug}` | RSC de `/p/{slug}` (cabeçalho, números crus, resumo por ano, bens, campanhas, fontes) |
| `GET /v1/politicos/{slug}/anos/{ano}` | `/api/cracha/{slug}/ano/{ano}` |
| `GET /v1/politicos/{slug}/{votos\|proposicoes\|discursos}?ano&tema&q&cursor` | `/api/cracha/{slug}/{lista}` |
| `GET /v1/politicos/{slug}/gastos?ano&mes&categoria&cursor` | `/api/cracha/{slug}/gastos` |
| `GET /v1/estados/{uf}/representantes` | `/representantes?uf=` (RSC) |
| `GET /v1/congresso/votacoes?dia&casa` e `/v1/congresso/votacoes/{id}` | `/congresso/votacoes` e `/congresso/votacao/{id}` |

Mudanças em relação ao original:
- dinheiro em centavos inteiros e datas em ISO 8601 com fuso;
- cursor em todas as listas, no lugar de `pagina`;
- números crus e formatação no app (os cartões prontos de `numeros` são acoplados à web);
- `ETag` e `Cache-Control` iguais aos deles, para o app aproveitar `URLCache`;
- seguir políticos fica no aparelho (SwiftData), sem conta no servidor.
