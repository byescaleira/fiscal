# QA da FSC-025, fase 1

Roteiro da definição de pronto do [canvas](../../../spdd/prompt/FSC-025-202611061422-[Feat]-portraits-metal-proof.md), conferido em 2026-11-06 no simulador "Fiscal Metal iPhone Duo" (iOS 27.1) e nos testes do `FeatureCoreTests`.

| Roteiro | Resultado | Evidência |
| --- | --- | --- |
| Abrir Developer, "Bonequinhos em Metal" e ver o mesmo bonequinho em Lottie, Canvas e Metal animando o `idle` | passou | `-portraitLab YES` abre a tela; duas capturas com 1 s de intervalo mudam nas três colunas (pixels diferentes: Lottie 4.899, Canvas 4.443, Metal 3.977) |
| Trocar a pessoa no seletor | passou | `bundledRigFitsTheSubset` com as quatro pessoas do seletor |
| Paridade de 25 pessoas em 9 quadros contra o `PortraitStill` | passou | Metal: média 0,2%, percentil 99,5 fora da borda 0,8%; Canvas: média 1,3%, percentil 4,7%. A primeira régua, com a borda, reprovou 2 de 225 imagens do Metal só por antisserrilhado ([mapa](parity-edges-diff.png)); a régua mudou no canvas antes do código |
| Tocar: gesto neutro e volta ao `idle` sem salto | passou | [captura do aceno no Metal](lab-metal-wave.png); `tapReactsAndReturnsToIdleWithoutAJump` |
| Segurar 0,5 s: `think` e `thinkLoop`, e volta em 0,3 s | passou nos testes | `holdThinksUntilReleased`; o gesto no simulador não foi capturado no meio |
| Arrastar: olhos e rosto seguem o dedo, presos ao `lookAround`, e voltam em 0,4 s | passou nos testes | `lookAndTiltStayInsideWhatTheRigAlreadyDoes`, `lookMovesTheEyesAndTiltTurnsTheHead` |
| Inclinar o iPhone | não executado | O simulador não tem sensor; no iPhone a sessão foi só de medição |
| Toque durante o `wave` mistura em 0,2 s | passou nos testes | `tapReactsAndReturnsToIdleWithoutAJump` |
| Movimento reduzido: só imagem parada e o rodapé | não executado | Não conferido em aparelho nem simulador |
| Botão "Medir" e a tabela | passou no iPhone | Duas rodadas no iPhone 17 Pro Max, com e sem otimização ([prova](proof.md)) |
| Sem Metal: "Metal indisponível neste aparelho" | não executável aqui | Todo aparelho do alvo tem Metal; o caminho está no código |
| Evidência e decisão em `proof.md` | passou | [Prova](proof.md): parar este motor; o Power Profiler não gravou e o usuário dispensou nova gravação |

## Achados durante o QA

- O `Canvas` congelava depois do primeiro quadro, porque o desenho não dependia do tique da `TimelineView`. O quadro passou a ser calculado fora do `Canvas`.
- A imagem parada do Metal reservava um buffer sem devolver, e o semáforo derrubava o teste ao ser liberado. Agora o buffer é devolvido depois do desenho.
- O banco do simulador e o do iPhone vinham de outra branch, com esquema mais novo, e o app não abria. No simulador, a reinstalação limpa resolveu; no iPhone, sem apagar nada, o laboratório passou a abrir na raiz da janela, por cima da tela de erro.
