# Roadmap

O que o Fiscal vai ganhar, por fase, até a 1.0. A visão, os públicos, a Lente e as 5 abas estão no [brief](brief.md). Cada fase vira uma ou mais mudanças em [changes/](changes/README.md); os pré-requisitos técnicos ficam no [backlog](backlog.md).

## Como dimensionar

- **S:** uma sessão; uma mudança pequena, sem dado novo nem tela nova.
- **M:** duas ou três etapas; uma tela ou entidade nova com testes, sem migração delicada.
- **L:** quatro ou mais etapas; dado novo com migração, serviço externo, plataforma nova ou fluxo inteiro. Uma fase L que puder ser dividida vira duas M.

## Fases até a 1.0

| Fase | Entrega | Tecnologia | Tamanho | Estado |
| --- | --- | --- | --- | --- |
| 0 | Base: estrutura por feature, design system, Ajustes, guias, flags, deep links, idiomas, lint, scripts, CI, site, ponte e admin | Template `byescaleira-workspace` | S | pronta |
| 1 | **Apuração ao vivo do 2º turno** (25/10/2026), com a Live Activity atualizada por push | TSE `resultados`, servidor Go, ActivityKit, APNs | L | em andamento |
| 2 | **Dados federais no servidor:** carga diária da Câmara, do Senado e do TSE; API `/api/v1` com lista, busca, perfil, votos, propostas, discursos e gastos | Go, SQLite ou Postgres na VPS, arquivos anuais oficiais | L | — |
| 3 | **Meus, perfil e Fiscalizar:** os representantes pelo endereço, seguir no aparelho, perfil federal completo (presença, votos, propostas, gastos, patrimônio, campanhas, contato), busca universal e as 5 abas no lugar das atuais | SwiftData, IBGE, `Tab(role: .search)` | L | — |
| 4 | **Lente e Aparência:** onboarding de prioridades, posicionamento opcional e privado, Hoje personalizado, "Outra lente", paletas, símbolos e ícones alternativos | SwiftData no aparelho, `GuideSheet`, Lottie, ícones alternativos | M | — |
| 5 | **Votações:** pauta e calendário, placar por partido e por estado, quem votou como, "o que muda para você", alertas por tema e a Live Activity da votação importante | Servidor (pauta do dia), ActivityKit, notificações filtradas no aparelho | L | — |
| 6 | **Dinheiro:** cota e notas, salários e benefícios, emendas, financiamento de campanha, patrimônio ao longo do tempo e arrecadação federal | Swift Charts com Audio Graphs, Receita, Portal da Transparência | M | — |
| 7 | **Compartilhar com arte:** cards de Stories, feed e mensagem para cada tela, coleções de artistas pela Lente, galeria com crédito e licença, manifesto `art-credits.json` e Comparar | `ImageRenderer`, `ShareLink`/`Transferable`, deep links, licenças assinadas | M | — |
| 8 | **Integrações e polimento para a loja e o Apple Design Award:** widgets, App Intents com a Siri, Spotlight, resumo de projetos no aparelho, acessibilidade completa, iPad, Mac e visionOS, revisão de neutralidade, App Store e TestFlight público | WidgetKit, App Intents, Core Spotlight, Foundation Models; revisores; `app-store-release.md` | L | — |

- **Ordem:** a fase 2 destrava as fases de 3 a 8.
- **Em paralelo:** 4 e 6 podem correr ao mesmo tempo que 5, cada uma em sua worktree.
- **Fase 7:** começa o licenciamento das obras logo depois da [pesquisa de artistas](research/README.md), porque contrato leva semanas. O código dos cards pode ser feito com obras em domínio público enquanto os contratos andam.
- **Fase 1:** depois de hoje, a apuração vira um card em Hoje durante eleições e uma seção em Fiscalizar.

- **Antes da fase 2:** tirar os outros idiomas ([ADR 0003](adr/0003-portuguese-only.md)) e ligar o setup inicial da Lente com Aparência e arte, que o usuário pediu como prioridade (imagens de artistas primeiro).

## Critério de pronto da 1.0

- Uma pessoa de qualquer lado instala, escolhe a Lente em menos de um minuto e, na primeira tela, vê o que os seus representantes fizeram nos temas dela, com fonte e data.
- Os 513 deputados, os 81 senadores e o presidente com perfil completo; Live Activity para apuração e para votação importante.
- Zero dado pessoal no servidor; a Lente só no aparelho.
- VoiceOver, Dynamic Type nos tamanhos de acessibilidade e Reduzir movimento em todas as telas; iPhone, iPad e Mac.

## Depois da 1.0

- Governadores, assembleias e câmaras municipais, onde houver dado aberto (SAPL, portais de transparência).
- STF: pauta, julgamentos e votos dos ministros.
- Eleições municipais de 2028: apuração por cidade, prefeitos e vereadores.
- Push-to-start da Live Activity (a apuração começa sozinha na tela de bloqueio).
- Apple Watch (complicação com a votação do dia) e o Fiscal na Web.
