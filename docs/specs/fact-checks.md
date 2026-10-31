# Checagens (histórico)

Congelada em 2026-10-29; a verdade atual está em [`spdd/prompt/FSC-006-202610291700-[Codify]-fact-checks.md`](../../spdd/prompt/FSC-006-202610291700-[Codify]-fact-checks.md).

As checagens do Projeto Comprova que citam um político pelo nome, ligadas à pessoa só quando o nome não deixa dúvida. Hoje aparecem nas investigações de Fiscalizar; a seção do perfil existe, mas está desligada. A escolha da fonte está na [pesquisa de checagens](../research/2026-10-25-fact-checks.md); o que falta fazer está em [backlog.md](../backlog.md).

## Princípios

- **O veredito é do conteúdo checado, não da pessoa.** Checagem que cita alguém nem sempre é sobre algo que a pessoa disse.
- **Na dúvida, fica de fora.** Homônimo, nome parcial ou mais de uma pessoa possível não é publicado.
- **Como a agência publicou.** Título, selo, data e link sem reescrever, com o crédito e a licença CC BY-ND 4.0.
- **Sem contagem de "mentiras".** Todas as checagens, não só as falsas, em ordem de data e com a mesma regra para todos.

## Onde fica

| Target | O que fica nele |
| --- | --- |
| `server/` (`internal/sources/comprova`) | Leitura da API do Comprova e o veredito de cada publicação |
| `server/` (`internal/publicdata/checks.go`, `build.go`) | Ligação nome → pessoa, lista de revisão interna e `people/{slug}/checks.json` |
| `FiscalDomain`, `FiscalData` | Tipo da checagem e leitura de `checks.json` |
| `FeatureSearch` | Investigação "Houve checagens sobre {nome}?" (`InvestigationLinks+People`) |
| `FeatureProfile` | Seção de checagens, desligada (`ProfileModel.showsFactChecks = false`) |

## Mecânicas e regras

### Leitura

- Fonte: `https://projetocomprova.com.br/wp-json/wp/v2/publicacoes`, licença CC BY-ND 4.0, com o link da licença.
- 100 publicações por página, até 200 páginas, por id, a partir de `COMPROVA_SINCE` (padrão 2022-01-01). Depois da primeira carga, só o que mudou (`modified_after`, com 1 h de sobreposição); a janela inteira é relida a cada 7 dias.
- Job `checagens`: a cada 45 min, das 7 h às 24 h, todos os dias, conferindo só a última publicação alterada, com idade máxima de 24 h.
- Saem as publicações institucionais, as de fora do site e as sem título.
- Veredito pela tag, pela frase de definição, pelo cabeçalho da seção ou pelo nome da imagem do selo: Falso, Enganoso, Comprovado, Verdadeiro, Sátira, Contextualizando, Comprova Explica, Golpe. Selos em conflito vão para a revisão.

### Ligação à pessoa

- O texto procurado é o título mais as explicações das tags.
- Nomes indexados: o de urna e o civil, sem acento nem caixa. Nome de uma palavra só vale se for o de urna e tiver pelo menos 4 letras.
- O trecho achado é a maior sequência de palavras inteiras, todas com inicial maiúscula.
- Liga só quando o nome identifica uma única pessoa entre todas as do escopo e não é parte de um nome maior. O resto vai para a lista interna de revisão, que não é publicada:

| Motivo | Quando |
| --- | --- |
| `ambiguousName` | Mais de uma pessoa tem esse nome |
| `partOfLongerName` | O nome está colado a outro nome com maiúscula (salvo com 3 palavras ou mais) |
| `surnameOnly` | Só o sobrenome aparece |
| `officeMismatch` | Há um cargo antes do nome que a pessoa não ocupa |
| `possibleHomonym` | Cargo contraditório sem confirmação |
| `verdictConflict` | Os selos da publicação não batem |

### Arquivo publicado

- `people/{slug}/checks.json` só existe com pelo menos 1 checagem; cada item tem id, título, veredito, data, link, editor, licença e link da licença, do mais novo para o mais antigo, sem limite de itens desde 2022-01-01.

### No app

- **Investigação em Fiscalizar:** "Houve checagens sobre {nome}?", com "O Projeto Comprova publicou N checagens que citam {nome}." (ou que não há nenhuma), as 3 primeiras com título, veredito, data e link, a fonte "Fonte: Projeto Comprova · CC BY-ND 4.0" e o aviso "Uma checagem que cita alguém nem sempre é sobre algo que essa pessoa disse."
- **Perfil:** a seção está desligada no código; quando ligada, mostra hoje só um item genérico ("Checagens publicadas por agências de checagem."), sem a lista.

## Construção

1. **Dados:** `FactCheckTests` em `FiscalDataTests`.
2. **Servidor:** `internal/sources/comprova` e `internal/publicdata` (ligação por nome e motivos de revisão), com `go test ./...`.
3. **Textos:** pt-BR no catálogo; a seção nunca usa "Fato ou Fake", marca do g1.

## O que fica com você

- Autorização por escrito antes de qualquer outra agência (Lupa, Aos Fatos) ou da API do Google.
- Ler de vez em quando a lista interna de revisão.

## Histórico

| Data | Mudança ou ADR |
| --- | --- |
| 2026-10-29 | [`app-1.0`](../changes/archive/2026-10-29-app-1.0/proposal.md) |
| 2026-10-25 | [Pesquisa de checagens](../research/2026-10-25-fact-checks.md) |
