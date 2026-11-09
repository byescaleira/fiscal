# 0024. A barra ao rolar, quem você segue no Feed e os votos em tela própria

- **Estado:** Aceito
- **Data:** 2026-11-02
- **Mudança:** [FSC-015](../../spdd/prompt/FSC-015-202611021500-[Feat]-sticky-bar-votes-region-tabs.md)
- **Emenda:** decisão 6 do [ADR 0022](0022-feed-first-tab-and-region.md)

## Contexto

O usuário aprovou a barra que aparece no topo da página do político e pediu mais uso dela, só onde algo precisa continuar visível. Ele se perdia no detalhe da votação, de nove seções, com centenas de votos no fim. E achou estranho Região abrir com quem a pessoa segue.

## Decisão

1. A barra ao rolar é um padrão: uma camada sobre a rolagem, que só muda de opacidade. Entra onde algo precisa continuar visível: votação, corrida, notas e político. Não entra em listas de abas, como Votações e Feed.
2. A barra e os atalhos ficam no `byescaleira-kit`, e o conteúdo de cada barra fica no app.
3. A lista de votos de uma votação vai para uma tela própria, com busca e filtros. No Mac, a tabela continua ao lado do detalhe.
4. Votação simbólica mostra o resultado e explica que a casa não registrou o voto de cada pessoa, sem traço nem zero.
5. Quem você segue, as sugestões e o convite de compartilhar vão para uma tela própria, aberta pelo filtro Seguindo do Feed. Região fica só com o lugar. Isso muda a decisão 6 do ADR 0022.
6. A pauta vira uma linha em Votações, com a próxima sessão, e abre em tela própria. Pauta vencida não aparece.

## Consequências

- O kit ganha uma peça e uma versão, e o app depende dela.
- Ver um voto específico pede um toque a mais, em troca de uma página que dá para ler.
- `fiscal://following`, o widget "Quem eu sigo" e a Siri passam a abrir a tela nova.
- Quem procurava a lista em Região precisa aprender o caminho novo; o convite do Feed ajuda.

## Alternativas consideradas

- **Barra em toda tela:** mais uniforme, mas o usuário pediu que não fosse em todas, e ocuparia espaço onde nada precisa ficar visível.
- **Inserir a barra no layout:** é o caminho mais simples, mas fez o conteúdo pular na `FSC-014`.
- **Votos no fim da página:** tudo num lugar só, mas a página continua longa e o salto entre partes fica incerto numa lista preguiçosa.
- **Botão de quem você segue na barra do Feed:** mais fácil de achar, mas a barra ficaria mais cheia. **Dentro de Ajustes:** fica longe de quem quer seguir alguém.
- **Pauta com os primeiros itens no topo:** mais à vista, mas ainda empurra as votações para baixo.
