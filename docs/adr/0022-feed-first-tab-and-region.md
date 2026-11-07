# 0022. O Feed é a primeira aba, e a Região guarda o lugar e quem a pessoa segue

- **Estado:** Aceito (2026-11-01)
- **Data:** 2026-11-01
- **Mudança:** [FSC-013](../../spdd/prompt/FSC-013-202611012300-[Feat]-feed-first-tab-and-region.md)
- **Corrige:** o [ADR 0014](0014-settings-in-today-toolbar.md) e o brief, que tinham Hoje como primeira aba
- **Emendado por:** [ADR 0024](0024-reveal-bar-following-and-ballots-screens.md), que tira quem a pessoa segue e as sugestões da aba Região (decisão 6)

## Contexto

O app abria em Seguindo, com uma lista de pessoas e de região, e o que acontecia estava dividido entre Hoje e Seguindo. O usuário pediu um feed como primeira aba, com foco em quem a pessoa segue e no que é relevante.

## Decisão

1. As abas são Feed, Votações, Dinheiro, Região e Fiscalizar, nessa ordem. O app abre no Feed. Hoje deixa de ser aba.
2. O topo do Feed tem a apuração ao vivo, quando houver, e o destaque do momento. A lista vem depois, só por data, com os filtros Tudo, Seguindo e Relevante.
3. Cada linha diz por que está ali. Nada reordena a lista: nem peso, nem apoio, nem algoritmo.
4. O Feed é montado no app, a partir dos arquivos públicos, sem servidor novo. Carrega um ano por vez, até 2023, e mostra com clareza onde os dados acabam.
5. Ajustes e "Meu apoio" ficam na barra do Feed. A pauta fica só em Votações.
6. A aba Região guarda quem a pessoa segue, as sugestões, quem governa e as bancadas.

## Consequências

- A primeira tela mostra o que acontece, em vez de uma lista de pessoas.
- O "infinito" tem um fim real: quem segue pouca gente chega nele rápido.
- Propostas sem data não entram na lista; só as de `actions.json`, até 40 por pessoa.
- Mudam os links internos, com os antigos mantidos como apelidos.

## Alternativas consideradas

- **Páginas publicadas pelo servidor:** o feed seria longo para todos, mas exigiria deploy e arquivos a mais perto do teto de 18 mil. O usuário escolheu montar só no app.
- **Ordem por relevância:** poria o mais pesado primeiro, mas a ordem ficaria difícil de explicar, contra a credibilidade do app.
- **Manter Hoje e Feed em abas separadas:** preservaria o que existe, mas as duas abas se repetiriam.
