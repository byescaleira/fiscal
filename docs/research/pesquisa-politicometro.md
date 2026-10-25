# Pesquisa: politicometro.org

Levantamento feito em 25/10/2026 (dia do 2º turno), navegando o site em desktop e em tamanho de celular.

## O que é

Site de transparência política brasileiro, feito em Next.js e hospedado na Vercel. Mostra todos os políticos eleitos no cargo hoje (70.836, do vereador ao presidente), com dados só de fontes oficiais e em linguagem simples.

Princípios que aparecem no site inteiro:

- **Neutralidade:** sem ranking, nota, "melhores e piores", enquete ou recomendação de voto (cita a Resolução TSE 23.610/2019). Listas em ordem alfabética. As cores indicam lugar ou tipo de cargo, nunca partido ou "bom e ruim".
- **Fonte em todo bloco:** cada seção termina com "Fonte: … · atualizado em …".
- **"—" quer dizer dado indisponível, nunca zero.** Quando a casa legislativa não publica, o site diz isso em vez de mostrar 0.
- **Aberto e sem login:** a conta é opcional, entra com código por e-mail (sem senha) e só serve para seguir políticos.

## Mapa do site

| Área | Rota | O que tem |
|---|---|---|
| Início / Mapa | `/` | Contadores por cargo, "pessoas no site agora", mapa do Brasil por região → estado → cidade, lista A–Z com filtros de cargo e partido |
| Quem é quem | `/quem`, `/quem/{cargo}` | Lista de todo mundo com filtros de nome, cargo, estado e partido |
| Estado | `/uf/{uf}` | Mapa do estado com todos os municípios; atalhos para representantes, governos e eleições do estado |
| Perfil ("crachá") | `/p/{slug}` | Página principal do produto (detalhe abaixo) |
| Me representa | `/representantes?uf=SP` | Digita cidade ou estado e vê todos os representantes, do vereador ao presidente, explicando o que cada cargo faz |
| Comparar | `/comparar` | De 2 a 5 políticos lado a lado, sem nota |
| Congresso | `/congresso` | Se há sessão agora na Câmara e no Senado, calendário com votações por dia, pauta do plenário com resultado de cada item (aprovado / não votado), tema e tipo (PL, PEC, MPV) |
| Impostômetro | `/impostos` | Arrecadação federal (Receita) por estado, mês e tipo de tributo |
| Governos | `/governos`, `/governos/{uf}` | Linha do tempo dos presidentes desde 1985 e indicadores por ano (PIB, inflação, Selic, dólar…) |
| Eleições | `/eleicoes`, `/eleicoes/{uf}`, `/eleicoes/apuracao` | Resultados do TSE por estado e cidade, mapa de quem venceu em cada UF, apuração ao vivo no 2º turno |
| Propostas | `/propostas` | Planos de governo registrados no TSE, lado a lado por tema, com busca e link para a página do PDF |
| STF | `/stf` | Os 11 ministros, processos na pauta, julgados e parados (pedido de vista), calendário do plenário |
| Cargos | `/cargos` | Quem elege, fiscaliza, julga e sanciona quem, com artigo da Constituição |
| Mais vistos | `/mais-vistos` | Perfis, estados, cidades e áreas mais abertos nas últimas 24 h |
| Dados abertos | `/dados-abertos` | Quais assembleias e câmaras municipais publicam dados abertos e quais não |
| Atualizações | `/atualizacoes` | De quando é cada fonte e a rotina de carga (diária, semanal, mensal, por eleição) |
| MCP | `/mcp` | Servidor MCP para usar o site num assistente de IA |
| Outros | `/sobre`, `/ajudar`, `/sugestoes`, `/entrar`, `/canal` | Metodologia, doação via Pix, sugestões, login, canal do WhatsApp |

## O perfil do político (`/p/{slug}`)

É o coração do site. Para um deputado federal, as seções são:

1. **Cabeçalho:** foto, cargo, UF, situação (em exercício / aguardando posse), partido, idade, cidade natal, quantas vezes foi eleito, mandato atual e futuro.
2. **Números grandes:** salário por mês, salário recebido na carreira, cota parlamentar gasta, patrimônio declarado (e o anterior), votos na última eleição, dinheiro arrecadado em campanhas, % de presença, nº de propostas.
3. **Seletor de ano:** a página inteira muda para o ano escolhido.
4. **Em resumo:** presença comparada com a média da casa, temas mais frequentes nas propostas, % de votos iguais à orientação do partido, maior gasto da cota.
5. **Presença:** grade com um quadrado por sessão (presente, sem registro, fora do exercício).
6. **Ano a ano:** tabela de presença, propostas, falas, votos e cota.
7. **Cota parlamentar:** total, gasto por mês, por categoria, cada nota fiscal.
8. **Comissões**, **o que propôs** (filtros por ano, tema e "podem virar lei"), **projetos que viraram lei**, **discursos**, **como votou**, **viagens**, **equipe do gabinete**.
9. **Campanhas:** de onde veio e com o que gastou, por eleição.
10. **Linha do tempo de mandatos**, **patrimônio declarado ao TSE**, **quanto custa o mandato**, **dados e contato** ("como cobrar") e **o que está e o que não está neste crachá**.

Para presidente ou governador, o perfil é mais curto (sem presença, votos nem cota). Para vereadores e deputados estaduais, depende de a casa publicar dados abertos; a maioria não publica.

## Fontes oficiais usadas

| Fonte | O que dá | Formato |
|---|---|---|
| Câmara dos Deputados, `dadosabertos.camara.leg.br/api/v2` | deputados, presença, proposições, discursos, votações, comissões, cota (CEAP), viagens | API REST em JSON + arquivos anuais |
| Senado Federal, `legis.senado.leg.br/dadosabertos` | senadores, autorias, discursos, votações, comissões, cota (CEAPS) | API REST em XML/JSON |
| TSE, `dadosabertos.tse.jus.br` | candidaturas 2008–2026, bens declarados, votos, contas de campanha, fotos (DivulgaCandContas), planos de governo | CSVs grandes em ZIP |
| TSE, `resultados.tse.jus.br` | apuração ao vivo | JSON |
| IBGE, `servicodados.ibge.gov.br` | nomes e malhas dos 5.569 municípios | API REST |
| Receita Federal | arrecadação por estado e mês | CSV |
| Assembleias e câmaras municipais (SAPL do Interlegis) | presença, votos e matérias, só onde publicam | API SAPL, cobertura irregular |
| STF | composição e pauta | sem API pública; páginas |

O site tem uma API interna, que não é pública nem documentada. O contrato dela está mapeado em [api-politicometro.md](api-politicometro.md) para servir de modelo ao nosso servidor. O app não deve chamar essa API nem copiar textos ou visual (o rodapé diz "todos os direitos reservados"); o nosso servidor carrega direto das fontes oficiais acima.

## Visual e UX

- Fundo claro cinza-quente, tipografia grotesca, números enormes em fonte condensada (os contadores são o elemento principal).
- Cartões com cantos arredondados, pílulas para chips e botões, quase sem cor (azul só como marca de cargo).
- Faixa escura no topo para avisos do dia (apuração ao vivo, com "Adicionar à agenda" e canal no WhatsApp).
- "Ouvir esta página" em todas as telas (leitura em voz alta), e foco em acessibilidade.
- Botão de compartilhar no WhatsApp em todo canto; cada perfil tem um card pronto para Instagram/WhatsApp.

## O que levar para o app iOS (versão simplificada)

### Recorte sugerido para a v1

Ficar **só no nível federal: 513 deputados + 81 senadores**. Motivo: são as duas fontes com API REST boa, que o app consegue chamar direto, sem backend. Vereadores, prefeitos e deputados estaduais (70 mil pessoas) dependem dos CSVs do TSE e de câmaras que mal publicam dados, o que exige servidor e carga diária, como o Politicômetro faz.

Telas da v1:

1. **Busca e lista:** todos os deputados e senadores, com busca por nome e filtros de casa, UF e partido. Ordem alfabética.
2. **Perfil:** cabeçalho, alguns números (presença, propostas, cota gasta no ano), últimos votos, últimas propostas e gastos da cota por categoria. Seletor de ano.
3. **Meu estado:** escolhe a UF uma vez e vê os 3 senadores e os deputados do estado.
4. **Seguindo:** favoritos salvos no aparelho (SwiftData), sem conta e sem login.
5. **Congresso hoje** (opcional): se há sessão e o que está na pauta.

### Deixar para depois (ou de fora)

Vereadores, prefeitos e assembleias; Impostômetro; Governos e indicadores econômicos; Eleições e apuração ao vivo; Propostas de governo; STF; Comparar; Mais vistos; MCP; conta por e-mail.

### O que vale copiar como princípio (não como texto ou visual)

- Neutralidade: sem nota, ranking ou cor de partido. Isso também evita problema na revisão da App Store e com a lei eleitoral.
- Mostrar a fonte e a data em cada bloco.
- "—" para dado indisponível, nunca 0.
- Explicar em uma linha o que cada cargo faz.

### Riscos

- **Revisão da App Store:** apps sobre política são aceitos, mas dados de terceiros precisam de fonte clara; mostrar "dados da Câmara/Senado" e não sugerir ser app oficial do governo (não usar brasão nem nome que pareça órgão público).
- **Limite de requisições** da API da Câmara: usar cache local e paginação.
- **API do Senado** devolve XML por padrão; pedir JSON com `Accept: application/json`.
- **Período eleitoral:** sem conteúdo que pareça propaganda ou pesquisa de intenção de voto.
