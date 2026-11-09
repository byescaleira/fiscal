# QA da FSC-010

Roteiros da definição de pronto do [canvas](../../../spdd/prompt/FSC-010-202610312345-[Feat]-share-flow-by-network.md), executados em 01/11/2026 no simulador do iPhone Duo fechado (o único iPhone que o sistema desta máquina aceita), com `scripts/verify.sh --full` verde. A build também foi instalada no iPhone 17 Pro do usuário, que aprovou os cartões e o vídeo. Resultado: 10 passou no simulador, em imagem ou em teste, 1 aprovado pelo usuário no aparelho, 1 sem confirmação no aparelho e 6 não executável aqui.

| Roteiro | Resultado | Evidência e observação |
| --- | --- | --- |
| Estúdio: cartão fixo no topo e painel separado que rola sozinho | passou | `estudio-folha.png`; o cartão não se moveu ao rolar o painel |
| Pôster: trilho grande de arte como primeira seção, e um toque troca a obra | passou | `estudio-poster.png`; toques nas bordas da segunda e da terceira obra selecionaram a obra certa |
| Botão de postar na barra, com fundo | passou em parte | No Duo fechado a barra é lateral e mostra só o ícone. O texto "↑ Instagram" num iPhone comum não foi visto |
| Os 10 assuntos nos 3 estilos, em Stories, Feed e Conversa | passou | `cards-*.jpg`, gerados pelo `ShareCardSnapshotTests`, com dados de teste e iniciais no lugar dos retratos |
| Zona segura do 9:16 | passou | `ShareSafeAreaTests` mede os pixels de Folha e Dados; no Pôster, por inspeção de `cards-poster-stories.jpg` |
| Nada vazio: dado ausente some do cartão, dos chips e da legenda | passou | `ShareContentRulesTests`. Votação sem placar e cartão sem dado foram cobertos só por teste, sem captura |
| Vídeo: blocos em sequência, números rolando, primeiro quadro sem número | passou | `video-quadros.jpg` (0%, 10%, 20%, 30%, 40% e 55%) e `ShareStyleTests.theVideoSettlesOnTheRealNumbers` |
| Arquivo do vídeo | passou | Simulador: 1080×1920, 30 fps, 5 s e 1,2 MB num cartão de cor chapada; os 24 Mbps são teto. O Pôster gera arquivo maior (10,7 MB com 4 s antes da animação nova) |
| Sair da tela durante o vídeo cancela a entrega e apaga o arquivo | passou | `ShareFlowModelTests.cancellingBeforeTheDeliveryLeavesNothingBehind` |
| Cartões, tela e vídeo no aparelho | aprovado pelo usuário | iPhone 17 Pro: "ficou muito bom mesmo" e "o video ficou bem melhor!" |
| Desligar fatos | passou | `ShareSelectionTests.hidesOnlyOptionalFacts` |
| Seleção da arte no aparelho | sem confirmação | Relatada pelo usuário e corrigida; passou no simulador, e a rodada seguinte não trouxe nova queixa |
| Stories direto | não executável aqui | Falta o App ID da Meta. Coberto por `ShareDeliveryTests` |
| TikTok pelo Fotos | não executável aqui | Sem TikTok no simulador. Roteiro no iPhone pendente; o esquema `tiktok://` ainda não foi conferido com `canOpenURL` |
| WhatsApp com a legenda | não executável aqui | Sem WhatsApp no simulador. Coberto por `ShareFlowModelTests.postingHandsTheFileToTheSheet` |
| Link do site abrindo o app | não executável aqui | Depende de publicar a AASA, com o ok do usuário. Coberto por `DeepLinkTests` |
| Tela larga e fonte de acessibilidade | não executável aqui | Layouts implementados e compilados; o Duo aberto não subiu de forma estável nesta máquina |
| Convite "Compartilhe quem você acompanha" | não executável aqui | Coberto por `MineFollowingTests`; os toques no Duo fechado não são confiáveis |

## Testes de interface

`scripts/ui-test.sh` falha em `testLaunchShowsFollowingAndOpensSettings` (linha 17) e `testTodayOpensTheLiveResults` (linha 28). Os mesmos dois falham na `development`, sem nada desta fase (conferido em 01/11/2026), e estão no [backlog](../../backlog.md).
