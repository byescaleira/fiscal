# Revisão da FSC-025, fase 1: bonequinhos em Metal

Revisão do `spec-reviewer` contra o [canvas](../prompt/FSC-025-202611061422-[Feat]-portraits-metal-proof.md), no intervalo `origin/development...237e033`, em 2026-11-06. Só leitura. Os números de paridade e de medição vieram do `qa.md` e do `proof.md`.

**Veredito: Needs Rework (2 críticos).** Os próximos passos estão na tabela. As correções entram num commit só, e a re-revisão olha só os críticos.

| Seção | Estado | Achados |
| --- | --- | --- |
| Requirements | desvio | 3 |
| Entities | desvio leve | 1 |
| Approach | ok | 0 |
| Structure | ok | 0 |
| Operations | desvio | 2 |
| Norms | ok | 0 |
| Safeguards | desvio | 3 |
| Sincronia | desvio | 2 |

## Achados

| Severidade | Onde | Achado | Próximo passo |
| --- | --- | --- | --- |
| crítica | `qa.md`, linha "Inclinar" | Omissão: o cenário do sensor de inclinação não tem prova | Corrigir o código e a evidência: passo manual no iPhone do usuário, com captura |
| crítica | `qa.md`, linha "Movimento reduzido" | Omissão: o cenário de Reduzir movimento não foi executado | Corrigir a evidência: passo manual no simulador, com captura |
| importante | `proof.md`, operação 16 | Omissão: sem Metal System Trace nem Power Profiler, e a régua pede energia | Atualizar o canvas: Instruments que não grava, com a dispensa do usuário, fica registrado por extenso |
| importante | `MetalPortraitRenderer.swift`, `preparation` | Omissão: o tempo do pipeline é gravado e nunca mostrado | Corrigir o código: o rodapé da medição mostra o tempo |
| importante | Safeguards × operação 10 | Divergência: "repouso sem quadro" contra o `idle` a 30 qps | Atualizar o canvas: repouso é fora da tela, com movimento restrito ou em segundo plano |
| importante | operação 17, `docs/roadmap.md`, `docs/research/` | Acréscimo: fases 7 e 8 e a pesquisa Memoji fora de Structure e Operations | Atualizar o canvas: os dois pedidos do usuário durante a geração entram em Structure e na operação 17 |
| importante | `docs/roadmap.md`, fases 2, 3 e 8 | Divergência: a régua manda a fase 2 virar "ações sobre o Lottie" | Atualizar o canvas e o roadmap: fase 2 = ações sobre o Lottie, depois da 7 |
| importante | Safeguard das três plataformas | Sem prova do build de macOS e visionOS | `scripts/verify.sh --full` |
| informativa | Entities | `PortraitStroke`, `PortraitClock`, `PortraitTilt` e `PortraitLabPerson` fora do diagrama | Sincronizar o canvas |
| informativa | `spdd/README.md` | "entregue" com PR "—" | Preencher o PR |
| informativa | `PortraitEngineTests.swift` | `.enabled(if:)` sem o motivo | Corrigir o código |

## Definição de pronto

| Cenário | Prova |
| --- | --- |
| Três motores no `idle` | Capturas no simulador com pixels diferentes |
| Trocar a pessoa | `bundledRigFitsTheSubset` |
| Paridade | `metalMatchesTheLottieStill` e `canvasMatchesTheLottieStill` |
| Tocar | `tapReactsAndReturnsToIdleWithoutAJump` e a captura do aceno |
| Segurar | `holdThinksUntilReleased` |
| Arrastar | `lookMovesTheEyesAndTiltTurnsTheHead` e `lookAndTiltStayInsideWhatTheRigAlreadyDoes` |
| Mistura em 0,2 s | `tapReactsAndReturnsToIdleWithoutAJump` |
| Inclinar | sem prova |
| Movimento reduzido | sem prova |
| Medir | Duas medições no iPhone, cada uma com três rodadas por motor e a mediana |
| Sem Metal | Só no código; todo aparelho do alvo tem Metal |
| Evidência e decisão | `proof.md`, sem Instruments |

## Desvio de intenção e decisões implícitas

- **Acréscimos:** a pesquisa do estilo Memoji e as fases 7 e 8, os dois pedidos do usuário durante a geração.
- **Decisões implícitas:**
  - o relógio `PortraitClock`;
  - o sensor que só liga no `onAppear` com animação;
  - o `PortraitLabLaunch` público;
  - os 30 qps em repouso.
- **Conferido sem desvio:**
  - código Swift novo em `#if DEBUG`, sem comentários e sem `@unchecked Sendable`;
  - tempos do misturador como constantes nomeadas;
  - háptico e ações de acessibilidade;
  - `PortraitRig.animation` preservado.

## Portão de merge

As duas críticas bloqueiam. As importantes entram no mesmo commit de correção. As informativas são detalhes.
