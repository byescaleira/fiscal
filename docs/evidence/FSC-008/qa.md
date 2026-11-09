# QA da FSC-008

Roteiros manuais da definição de pronto do [canvas](../../../spdd/prompt/FSC-008-202610311530-[Feat]-shell-fold-mac-vision-developer.md), executados em 31/10/2026 depois do `scripts/verify.sh --full` verde. Resultado: 4 passou, 0 falhou, 6 não executável aqui.

| Roteiro | Resultado | Evidência e observação |
| --- | --- | --- |
| Duo fechado: abas na barra vertical à direita, rota na pilha da aba | passou | `duo-closed-profile.png`: perfil aberto na pilha de Hoje, barra vertical com as cinco abas |
| Duo aberto (tela plana): nada muda | não executável aqui | A postura só muda à mão no Device Hub; o usuário pediu para pular as capturas da dobra. Coberto por `FoldNavigationTests.flatWidthKeepsTheStackAndTheInspector` |
| Duo meio aberto em pé: raiz à esquerda, rota à direita, nada sobre a dobra | não executável aqui | Mesmo motivo. Coberto por `FoldNavigationTests.foldedSideBySideOpensBesideInEverySection` e `foldingMovesStacksToTheRoutePaneAndBack` |
| Duo meio aberto deitado: rota em cima, raiz embaixo | não executável aqui | Mesmo motivo. Coberto por `FoldNavigationTests.foldedStackedPutsTheRouteOnTop` |
| Duo dobrado em tamanho AX: uma coluna | não executável aqui | Mesmo motivo. Coberto por `FoldNavigationTests.accessibilitySizeNeverFolds` |
| Mac: lista de origem "Acompanhar" e "Congresso", sem abas | passou | `mac-source-list.jpg`, build assinado do Mac |
| Mac: menu Ir com as cinco seções e ⌘1…⌘5 | passou | Menu "Ir" com Hoje, Região, Votações, Dinheiro e Fiscalizar; o item abriu Votações. Com a janela fora de foco os itens ficam desativados, porque a navegação vem do `focusedSceneValue` |
| Mac: votos de uma votação em `Table` | passou | `mac-vote-table.jpg` (capturado antes da tradução: colunas em inglês, hoje Nome, Partido, UF e Voto); a votação aberta não tinha nomes publicados. Recibos e representantes cobertos por `ExpensesRecordsTests` e `MineRosterTests` |
| visionOS: rota em janela vizinha | não executável aqui | Build do visionOS verde no `verify --full`; sem sessão interativa no simulador do Vision nesta fase |
| Developer: flags em três estados, registro, diagnóstico e Layout | não executável aqui | Os toques no Duo fechado chegaram fora de hora e não abriram a página; coberto por `DeveloperModelTests`, e a build está no iPhone do usuário para conferir |

Achado da QA, corrigido na fase: o app do Mac não carregava dados porque o sandbox não tinha a rede de saída (`ENABLE_OUTGOING_NETWORK_CONNECTIONS`, commit `6ecec51`).
