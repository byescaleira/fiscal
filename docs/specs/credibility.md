# Credibilidade

Como o Fiscal mostra números e textos sem tomar partido: fonte e data em cada bloco, "—" para o que falta, comparação com os colegas por uma régua pública, peso das ações por faixa, a linha "Estimado" em tudo que não é número oficial e explicações em linguagem simples geradas no aparelho. Vale em todas as abas, no perfil, nos widgets e nos cartazes. A regra está na [constituição](../constitution.md) (regra 14, [ADR 0012](../adr/0012-constitution-version-and-facts.md)); o que falta fazer está em [backlog.md](../backlog.md).

## Princípios

- **Fato, não opinião.** Números e textos oficiais como vieram; sem adjetivo de valor, causa atribuída, nota ou ranking de pessoas.
- **Fonte e data em cada bloco.** Quem lê sabe de onde veio e de quando é.
- **Ausente não é zero.** Dado que não existe aparece como "—", e sinal que faltou fica fora da conta.
- **Estimado diz por quê.** Tudo que não é número oficial mostra, em uma linha, por que é estimado e o que ficou sem medir.
- **Mesma régua para todos.** Comparações só com colegas do mesmo cargo e da mesma casa, com o método publicado em "Como medimos".

## Onde fica

| Target | O que fica nele |
| --- | --- |
| `FiscalDomain` | `PublicFormat` ("—"), `PeerClassification` (rótulos, direção e faixas de peso), `WeightCoverage` (sinais medidos e a linha "Estimado") |
| `FeatureCore` (`PublicData/`) | `SourceFootnote`, `PeerBadge` e o "Como medimos" dos colegas, `WeightMethodSheet` e `WeightMethodCards`, `IndicatorFormat` |
| `FeatureCore` (`Explain/`) | `Explainer` (Foundation Models), `ExplainerGuard`, `ExplainerCard`, `Explanation` |
| `server/` (`internal/publicdata`) | `benchmarks.go` (quartis e faixas), peso das ações e `method/weight.json` |

## Mecânicas e regras

### Fonte e data

- O rodapé junta os nomes das fontes sem repetir, separados por vírgula: "Fonte: X, Y · atualizado DD/MM, HH:MM" com a data mais recente; sem data, "Fonte: X"; sem fonte, nenhum rodapé. Datas longas saem como DD/MM/AAAA.
- Usado no perfil, em Região, nos destaques de Hoje, na Memória e nos cartões de indicador.

### Dado ausente

- Dinheiro, número e porcentagem ausentes (ou não finitos) aparecem como "—" (`PublicFormat.missing`, `IndicatorFormat`).

### Comparação com os colegas

| Indicador | Direção | Acima de p75 | Entre p25 e p75 (inclusive) | Abaixo de p25 |
| --- | --- | --- | --- | --- |
| Presença | "Mais alta é melhor." | Melhor que a média | Na média | Pior que a média |
| Cota (centavos por mês de mandato) | "Mais baixa é melhor, por mês de mandato." | Pior que a média | Na média | Melhor que a média |
| Propostas | sem direção ("mais propostas não quer dizer propostas melhores") | Mais ativo que a média | Na média | Menos ativo que a média |
| Discursos | sem direção | Mais ativo que a média | Na média | Menos ativo que a média |

- O percentil é por interpolação linear entre os colegas com dado; com menos de 5 colegas (`BenchmarkMinPeers`), não há classificação.
- Cores: melhor em oliva (`retroOlive`), pior em ferrugem (`retroRust`), mais e menos ativo em azul-jeans (`retroDenim`), na média em cinza secundário. A cor nunca é o único sinal: o rótulo vai junto.
- As linhas mostram o valor do ano e a mediana da casa (Senado, Câmara, Assembleia ou Câmara Legislativa do DF) e a faixa da média (p25 a p75) com o número de colegas.
- O "Como medimos" dos colegas explica a régua e diz que número ausente nunca conta como zero.

### Peso das ações

| Peso | Faixa |
| --- | --- |
| 70 ou mais | Alta relevância |
| 40 a 69 | Média relevância |
| abaixo de 40 | Baixa relevância |

- Peso = arredondar(0,5 × repercussão + 0,5 × impacto), ou só o impacto quando nenhum sinal de repercussão foi medido.
- Sinais de repercussão e pesos: notícias 0,40, notícias que citam o político 0,20, Wikipédia do político 0,25, Wikipédia do tema 0,15; a média usa só os sinais medidos.
- Na tela, o peso aparece como faixa; o número fica no detalhe ("Peso N de 100"), com os chips de repercussão e impacto.
- O peso ordena e destaca; nunca qualifica.

### Linha "Estimado"

- Cobertura completa: sem linha. Parcial: "Estimado: repercussão medida só com X; faltou Y nesta carga." Só impacto: "Estimado: peso só pelo impacto; nenhum sinal de repercussão foi medido nesta carga (faltaram …)." O Bluesky aparece sempre como ausente e não muda a confiança.
- A mesma regra vale fora do peso: temas sugeridos na Lente, temas do perfil, Comparar e as investigações de Fiscalizar mostram a sua linha "Estimado: …" ao lado.

### Explicações geradas no aparelho

- Usam o `SystemLanguageModel.default` do Foundation Models, só no aparelho e só quando o modelo aceita pt-BR; amostragem gulosa, até 220 tokens, cache de 200 explicações.
- Instruções: só fatos, até 3 frases, sem adjetivo de valor e sem lado.
- Entrada: o tema da explicação (presença, propostas, discursos, cota, números do mandato, votação, contagem, preço, barras e ritmo de temas), os fatos e o texto fixo.
- O texto fixo, escrito por regra, aparece primeiro e fica quando o modelo não está disponível, não há fatos, a geração falha ou a guarda recusa.
- A guarda recusa palavra de valor que não está nos fatos e qualquer número que não está nos fatos.
- Só quando o texto do modelo aparece, o selo diz "Explicação gerada pela Apple Intelligence no seu iPhone · pode errar; vale o texto oficial" (ou iPad, Mac, Apple Vision Pro).

## Construção

1. **Domínio:** `PublicFormatTests` e os testes de classificação e cobertura em `FiscalDomainTests`.
2. **Feature:** `SourceFootnoteTests` em `FeatureCoreTests`; testes dos models que montam as linhas (`ProfileModelTests`, `CompareModelTests`, `LensSetupModelTests`).
3. **Servidor:** `internal/publicdata` (quartis, mínimo de 5 colegas, faixas de peso), com `go test ./...`.
4. **Textos:** pt-BR no catálogo; texto que qualifica pessoa, voto ou partido é bloqueador de revisão.

## O que fica com você

- Revisão de neutralidade dos textos antes de cada versão.

## Histórico

| Data | Mudança ou ADR |
| --- | --- |
| 2026-10-29 | [0012](../adr/0012-constitution-version-and-facts.md) |
| 2026-10-29 | [`app-1.0`](../changes/archive/2026-10-29-app-1.0/proposal.md), com o [peso](../changes/archive/2026-10-29-app-1.0/weight.md) |
