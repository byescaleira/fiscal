# Cards de compartilhar: peça gráfica, não tela

Redesenho da imagem do card de compartilhar (perfil, votação, gastos, comparação, representantes e apuração) depois do retorno do usuário no iPhone em 2026-10-25: "a parte de compartilhar não precisa ter muita informação, não vamos usar o componente nativo na imagem, tá muito feio do jeito que está agora."

## Crítica honesta da versão anterior

PNGs em `share/before-*.png`.

- **Parecia uma tela de Ajustes colada numa foto.** Era um cartão branco com cantos de 14 pt, grade de blocos cinza no estilo `.groupedRow`, `Label` com SF Symbol, `Divider` e chip de resultado. Ninguém posta isso no Stories.
- **Tinha informação demais.** O perfil trazia retrato, quatro métricas, fonte, carimbo em monoespaçada, marca, domínio, "Ilustração do Fiscal" e QR. A votação trazia o resumo, a ementa, a proposição, três colunas, uma barra, um chip e o quórum. Nenhum número dominava a peça.
- **A arte ficava em segundo plano e parecia quebrada.** No Feed e na Mensagem, a foto em licença aberta (que não pode ser recortada) virava uma faixa estreita, ou uma miniatura, sobre um fundo desfocado da própria obra. Esse fundo é um filtro sobre a obra, o que a pesquisa de licenças desaconselha.
- **O crédito era o texto mais visível da imagem:** duas linhas em uma faixa preta no topo.
- **A Mensagem era só o Stories espremido.** Não havia composição própria para cada formato.

## Referências (vistas em 2026-10-25)

| Referência | O que vi | O que trouxe para o Fiscal |
|---|---|---|
| **Apple Music Replay '25** (cards de artista, [Apple Music for Artists](https://artists.apple.com/support/5486-celebrate-years-accomplishments-replay)) | Uma ideia por card. Tem um rótulo pequeno ("Top City"), uma palavra ou número enorme ("Sydney", "That's 663,340"), uma linha de apoio e a foto em placa com margem. A marca "Apple Music" fica pequena no canto. | **Uma ideia por card**, com rótulo em caixa alta espaçada, herói enorme e no máximo duas linhas de apoio. A obra fica em placa com margem, como a foto de Sydney. |
| **Apple Sports** (detalhe do jogo, [captura da App Store](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/79/c7/23/79c72328-d9e5-5200-9bd5-daf7c09bd1bc/Sports-iPhone6p9-iOS26-USEN-Wrapper3.png/600x1300bb.jpg)) | Placar "10 × 27" em fonte condensada e pesada, os dois lados nas pontas e cada lado com a cor do time. As estatísticas vêm em pares, com o rótulo pequeno e os valores grandes. | **O placar da votação em fonte condensada pesada**, com SIM e NÃO lado a lado. A apuração com dois candidatos e a comparação viram duas colunas iguais, e cada pessoa leva a faixa do próprio partido. |
| **Flighty Passport** ([captura da App Store](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/bd/25/56/bd25568f-4f9d-edc7-13cf-aabfd2780175/Annual_Stats.png/600x1300bb.jpg)) | O ano vira um objeto. Os números grandes (86 voos, 293.931 mi) aparecem sobre um fundo escuro com uma cor só, e os rótulos são pequenos. | **Fundo escuro de uma cor só, derivado da coleção**, com os números brancos. A faixa monoespaçada estilo MRZ saiu: era ruído no card do Fiscal. |
| **Strava, adesivo de estatísticas** ([anúncio de 03/04/2025](https://press.strava.com/articles/strava-updates-features-to-help-users-easily-plan-and-share-their-activities)) | Poucos números (distância, ritmo, tempo), cada um com o rótulo pequeno acima e o valor grande. A marca fica discreta e a imagem é o fundo. | **Fatos de apoio em par valor/rótulo** ("537 Votações nominais"), sem caixa nem fundo, só tipografia. |
| **Apple Invites** (evento, [captura da App Store](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/28/e9/0d/28e90d0c-a157-c291-0593-eb2577aa40f0/Event_View.png/600x1300bb.jpg), já em `design-references.md`) | A arte cobre o card inteiro e o título vai sobre ela, no terço de baixo. | **Obra em domínio público como fundo de sangria total**, com um véu na cor do campo só atrás do texto, para manter o contraste AA. |
| **Spotify Wrapped** (citado na [pesquisa de arte e licenças](../../research/2026-10-25-art-and-licensing.md)) | Formou o hábito do card 9:16 compartilhável: tipografia enorme, cor chapada e um dado por tela. | **Composição própria para o Stories**, com placa, crédito, rótulo, herói e assinatura embaixo. O Feed e a Mensagem não são o Stories esticado. |
| **Gráficos do NYT e do The Athletic** (convenção editorial) | O título responde à pergunta, o gráfico vem logo abaixo e a fonte aparece numa linha pequena no pé ("Source: …"). | **A fonte oficial em uma linha no rodapé**, acima da assinatura "Fiscal · fiscal.byescaleira.com". |

O Apple Music Replay, o Apple Sports, o Flighty e o Strava foram conferidos em imagem ou na página oficial. O Wrapped e a convenção do NYT e do The Athletic vêm da pesquisa já registrada e de padrões conhecidos, sem captura nova.

## Desenho novo

**Peça gráfica, sem componente de tela.** A imagem não usa `List`, `Form`, `GroupBox`, `Label`, `Section`, `Gauge`, `ProgressView`, `Divider` nem estilo de linha. Só há texto, uma barra desenhada (placar) e a obra.

### Camadas

1. **Campo:** `scoreboard` misturado a 32% com a cor mais saturada da paleta da coleção (`ShareArtwork.shade`), com um leve degradê vertical. A paleta veste só o fundo; dado e partido têm cores próprias.
2. **Obra, conforme a licença:**
   - **Domínio público:** cobre o card inteiro (`scaledToFill`). O crédito fica numa etiqueta escura a 86% no topo, e o véu do campo a 94% sobe 96 pt acima do texto.
   - **Licença aberta (CC BY-SA, a coleção padrão "Brasil agora"):** a obra **nunca é recortada, filtrada nem coberta**. Ela entra em placa com margem: no Stories, na largura útil, com o crédito embaixo; no Feed e na Mensagem, uma placa à direita (168 e 112 pt) com o crédito ao lado, como etiqueta de museu.
3. **Texto em branco,** com o secundário em branco a 74%. Por cima do véu ou do campo escuro, o contraste fica bem acima do AA.

### Ordem do texto

Rótulo em caixa alta espaçada → título (votação e apuração) → **herói** → fatos de apoio → nota → identidade → rodapé com a fonte, "Fiscal", o domínio e o QR (Stories e Feed).

- **Identidade:** nome em rounded bold e sigla do partido em caixa alta, ao lado de duas faixas verticais nas cores do partido (`PartyPalette`). Não há retrato, por isso a marca "Ilustração do Fiscal" saiu e a regra do TSE sobre conteúdo sintético fica atendida por construção.
- **Herói:** a fonte condensada e pesada encolhe pelo número de caracteres (`ShareFormat.figureSize`), para nunca truncar um valor como "R$ 386.637,50".

### O que entra em cada assunto

| Assunto | Herói | Apoio (no máximo 2 ou 3 linhas) |
|---|---|---|
| Perfil | O primeiro número publicado: presença (legislativo) ou votos na última eleição (executivo). Se faltar, entra o próximo, e "—" só quando não há nenhum | Dois fatos (votações nominais e propostas, por exemplo), só no Stories; nome e partido em faixas |
| Votação | Placar SIM × NÃO em colunas iguais, com a barra de três cores de dado | Resumo em linguagem simples, "Aprovada"/"Rejeitada" na cor do dado, OUTROS com o número (o placar sai inteiro) e a proposição só no Stories |
| Gastos | Total da cota no ano | Notas fiscais, maior gasto (só no Stories), nome e partido |
| Comparação | Duas pessoas em colunas iguais, cada uma com a faixa do partido | Presença, votações nominais e propostas (duas linhas na Mensagem) |
| Representantes | Nome do lugar em rounded heavy | Todos os grupos em grade (contagem + cargo), sem lista de nomes |
| Apuração | Com dois candidatos, os dois percentuais lado a lado; com mais, todos em linhas | Nome, partido em faixas e "Eleito" quando o resultado é final; urnas apuradas, brancos e nulos em todos os formatos |

### Formatos

- **Stories (9:16):** placa grande no topo, conteúdo logo abaixo e assinatura no pé. O herói vai até 132 pt.
- **Feed (4:5):** placa com etiqueta de museu no topo e herói de até 96 pt. Saem os fatos de apoio e a nota.
- **Mensagem (1:1):** placa pequena com etiqueta, herói de até 72 pt e título de no máximo duas linhas. Sem QR, só com o domínio.

### Regras mantidas

- A Lente muda só a arte; o conteúdo, o texto e a ordem são os mesmos (testes `theLensOnlyChangesTheArt` e `theCardNeverCarriesTheStance`, que agora conferem os textos desenhados).
- A imagem nunca diz o lado da pessoa.
- Cor de dado (`voteYes`, `voteNo`, `voteAbstain`) é diferente de cor de partido (só nas faixas da identidade) e da paleta (só no campo).
- A acessibilidade do card na tela usa um rótulo com os textos desenhados mais o crédito (`SharePoster.accessibilitySummary`).

## Tela em volta (ShareScreen)

Continua nativa, com prévia, seletor de formato, coleções e botão de compartilhar. Saiu o crédito repetido embaixo das miniaturas, porque ele já está na imagem.

## Como os PNGs foram feitos

- O teste `ShareCardSnapshotTests` gera os PNGs quando existe a variável `FISCAL_SHARE_SNAPSHOTS`. Neste Mac (macOS 26.5) o pacote é para macOS 27 e não carrega, por isso os PNGs saíram de um executável temporário que compila os mesmos fontes para macOS 26 e chama `ShareRenderer.render(_:code:scale: 3)` com os textos em pt-BR.
- Os arquivos foram reduzidos para 256 cores para não pesar no repositório.
- **Antes:** `share/before-{person,vote}-{stories,feed,message}[-historical].png`.
- **Depois:** `share/after-{person,person-executive,person-long,vote,expenses,compare,representatives,race}-{stories,feed,message}.png`, mais `-historical` (obra em domínio público) para o perfil e a votação.
