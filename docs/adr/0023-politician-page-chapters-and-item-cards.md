# 0023. A página do político em capítulos, gesto sem dado e cartões de um item

- **Estado:** Aceito
- **Data:** 2026-11-02
- **Mudança:** [FSC-014](../../spdd/prompt/FSC-014-202611020300-[Feat]-politician-page-and-share-an-item.md)

## Contexto

A página do político tinha 16 seções numa lista, com traços onde faltava dado, o bonequinho só no topo e as notas escondidas. O usuário pediu uma página didática, que varie conforme a pessoa, com o bonequinho presente ao rolar e a chance de compartilhar um item específico. O app só publica fatos, e o retrato não pode sugerir juízo sobre ninguém.

## Decisão

1. A página é uma rolagem só, em capítulos com título simples. A ordem é fixa por cargo e só entram os capítulos com dado. Nenhum valor reordena nada.
2. O retrato fica num cabeçalho fixo ao rolar e faz um gesto neutro por capítulo. O gesto é calculado só a partir do capítulo, então nenhum valor muda o rosto. `sad`, `thumbsUp`, `shakeNo` e `celebrate` não aparecem nesta página. Com Reduzir movimento ou pouca energia, o retrato fica parado.
3. Dado ausente não aparece. Uma frase no fim diz o que a fonte não cobre para aquele cargo.
4. Compartilhar ganha uma nota, um mês, o voto de uma pessoa e uma proposta. A nota sempre diz "Uma de N notas de <ano>, total R$ X". O voto traz a proposta. Os cartões seguem sem o bonequinho e usam chaves do site que já existem.
5. Nota sem CNPJ não vira cartão, porque o cartão circula fora do app e exporia o nome de uma pessoa comum.
6. As checagens entram na página como "O que circulou sobre <nome>", com aviso de cobertura e crédito, só por data. Sem checagem, não há capítulo nem frase.

## Consequências

- A página fica diferente por cargo, e o roteiro de teste precisa cobrir todos os cargos.
- Um voto ou uma nota podem circular sozinhos. O cartão leva o contexto e a fonte para reduzir o risco de leitura fora de contexto.
- A página deixa de usar `List`, e passa a cuidar ela mesma de grupos, separadores e acessibilidade.
- Quem compartilha uma proposta cai na página da pessoa, porque não há chave própria no site.
- O brief pede uma marca no retrato; a regra das 72 horas nos cartões de candidato segue no backlog, porque estes cartões não têm retrato.

## Alternativas consideradas

- **Abas dentro da página:** cada uma seria mais curta, mas separaria o bonequinho e a história, e esconderia o resto. O usuário escolheu a rolagem.
- **Ordem por relevância do dado:** poria o mais chamativo primeiro, mas a ordem deixaria de ser explicável e pareceria julgar a pessoa.
- **Expressão ligada ao dado:** seria mais expressiva, mas contraria o brief e a neutralidade do app.
- **Só o mês no cartão de gasto:** teria menos risco de contexto, mas não atende ao pedido de um gasto específico. O usuário escolheu a nota e o mês.
- **Nota de pessoa física no cartão:** é dado oficial, mas exporia alguém comum fora do app.
