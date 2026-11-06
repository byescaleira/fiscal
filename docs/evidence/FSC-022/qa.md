# FSC-022: QA dos ícones com paisagens vistas de cima

Canvas: [FSC-022](../../../spdd/prompt/FSC-022-202611051909-[Feat]-icons-aerial-brazil-landscapes.md). Rodada 2, 05/11/2026, simulador "Fiscal Icons iPhone" (iPhone Duo, iOS 27.1) e `ictool` do Icon Composer.

| Roteiro | Resultado | Evidência |
| --- | --- | --- |
| Ícone principal na tela inicial: Amazônia ao amanhecer vista de cima, rio em curvas, mapa em vidro | passou | [round1-settings.png](round1-settings.png), [round2.png](round2.png) |
| Ajustes › Aparência › "Ícone do app": Amanhecer na Amazônia, Dia na Amazônia, Encontro das Águas, nesta ordem | passou | [round2-settings.png](round2-settings.png) |
| "Temas": Cataratas do Iguaçu, Jalapão, Pantanal, Ipês em flor, Chapada dos Veadeiros, Fernando de Noronha, Pão de Açúcar, Lençóis Maranhenses, nesta ordem, cada um com a sua cor | passou | [round2-settings.png](round2-settings.png), [round2-themes.png](round2-themes.png) |
| Escolha salva continua valendo: os 11 `assetName` e valores brutos iguais, 47 casos | passou | `AppIconTests.landscapeIconsKeepTheirSavedNamesInOrder` e `assetNameRoundTrips` no `verify --quick` |
| Cada tema com um título diferente | passou | `AppIconTests.everyThemeShowsADifferentPlace` |
| Claro, escuro e tinted legíveis, mapa em vidro se destaca | passou | [round2.png](round2.png) (linhas claro, escuro e tinted) |
| Clear (vidro transparente) | não executável aqui | o `ictool` não exporta o clear; conferir no iPhone |
| 60 pt na tela inicial | passou para o principal na rodada 1; os 8 novos na prévia de Ajustes, que tem tamanho parecido | [round1-settings.png](round1-settings.png), [round2-settings.png](round2-settings.png) |
| Gerador determinístico: duas rodadas seguidas sem diff | passou | `python3 -I scripts/landscape-icons.py` duas vezes, hash do `git diff` igual |
| Paisagem inválida: "landscape <nome>: <motivo>" e saída 1, sem escrever | passou | ícone desconhecido, cor `#00000` e paisagem sem camada |
| Mapa idêntico ao principal nos 11 | passou | `cmp` de `9 Map.svg` e `9b Rim.svg` |
| Até 12 camadas e 200 KB por `.icon`; gerador em até 10 s | passou | no máximo 9 camadas de paisagem mais 2 do mapa, até 124 KB, 2,9 s para os 11 |
| Fauna e partido fora do diff | passou | as prévias reexportadas pelo `scripts/icons.sh` foram restauradas; `git status` só lista os 11 |
| Trocar o ícone no simulador | não executável aqui | o toque no ícone durante a rolagem não abriu o aviso do sistema; o código da troca não mudou nesta fase |
| iPhone físico | pendente | instalação ao fim da rodada 2, para o ok do usuário |
| Mac, iPad e visionOS | não executável aqui | declarados no PR enquanto não forem vistos |

`scripts/verify.sh --quick`: ok (build iOS, testes Swift dos alvos afetados, ponte, site e admin).
