# QA da FSC-016: cartões no modo claro e bonequinho de todos

- **Canvas:** [FSC-016](../../../spdd/prompt/FSC-016-202611021923-[Feat]-light-cards-and-portraits.md)
- **Ambiente:** simulador "Fiscal iPhone Duo" (iOS 27.1, dobrado), com os dados de teste e, nos retratos, com os dados publicados; e iPhone 17 Pro Max físico, com os dados reais.
- **Usuário no iPhone físico:** viu a primeira versão, pediu para não mexer no cartão do político e só tirar o preto, e disse "ficou excelente" sobre a versão final. Escolheu a versão B do placar por uma captura.
- **Referências:** as telas de FotMob estão atrás de cadastro, e a busca não trouxe imagens do Apple Sports no modo claro. Nenhuma referência visual foi vista nesta mudança; o desenho veio das três versões mostradas ao usuário.
- **Capturas:** usam a lista fixa dos dados de teste; nenhuma mostra o apoio de alguém.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 | Riedel com outro partido no dado | Abrir o perfil com dados publicados | passou | `drawsThePersonWithThePartyTheDataBrings`, [captura](portrait-riedel.png) |
| 2 | Mesmo rosto em outro partido | Modelo | passou em teste | `drawsThePersonWithThePartyTheDataBrings` |
| 3 | Arthur Henrique em Região | Abrir com dados publicados | passou | [Captura](portrait-mayor.png). Nos dados de teste, o prefeito tem outro identificador e continua neutro |
| 4 | Sem traços | Modelo | passou em teste | `findsTraitsByTheSlugAlone`, `drawsThePersonWithThePartyTheDataBrings` |
| 5 | As 2.356 pessoas publicadas | `scripts/portrait-check.py --published` | passou | 2.356 lidas, 0 sem traços, 0 problemas, em 03/11/2026. Os dados publicados são de 28/10 |
| 6 | Identificador com outro nome | Teste do script | passou | `scripts/portrait-check-test.py`, no `verify --full` |
| 7 | Placar claro | Abrir | passou | [Claro e escuro](appearance-and-contrast.png), [captura](vote-light.png), iPhone |
| 8 | Placar escuro | Comparar o build de `efaae65` com o novo | passou | [Antes e depois](dark-before-after.png): nominal e simbólica sem nenhum pixel diferente no cartão |
| 9 | Cartões coloridos iguais | `git diff` contra a `development` | passou | Nenhum desses arquivos no diff; [político](cards-two-modes.png) no simulador; iPhone |
| 10 | "Na sua região agora" | Abrir Região | passou em parte | O cartão não apareceu nos dados de teste. Só o código e a versão instalada no iPhone, sem confirmação específica desse cartão |
| 11 | Conclusão da investigação | Abrir uma investigação no modo claro | passou | [Captura](cards-two-modes.png) |
| 12 | Comparar | Abrir | passou | `testTheScoreboardAndTheComparisonOpenInTheCurrentMode`, [captura](hero-compare.png), [dois modos](cards-two-modes.png). Com mais de duas colunas: `twoSidesKeepANeutralCenterAndMoreColumnsKeepTheirColors`, sem ver na tela |
| 13 | Modo escuro dos 4 cartões | Comparar builds | passou em parte | Placar: igual. Comparar: a única diferença é o rosto de Kim Kataguiri, antes neutro e agora desenhado ([antes e depois](dark-before-after.png)). Conclusão e "Na sua região agora" só lidos no código |
| 14 | Ajuste de Aparência | Forçar pelo valor salvo: Claro em aparelho escuro e Escuro em aparelho claro | passou em parte | [Capturas com legenda](appearance-and-contrast.png), no placar. A chave foi passada no lançamento, sem usar a tela de Ajustes |
| 15 | Contraste | Modelo | passou em teste | `everyPartyColorKeepsTheTextReadableInLightMode`, com todas as cores da paleta, em cálculo sobre os valores do sistema |
| 16 | Aumentar contraste | Ligar no simulador | passou | [Captura](appearance-and-contrast.png): cinza e contorno, no placar |
| 17 | Reduzir transparência | Ligar por `defaults` | não comprovado | No código, a superfície não usa material e é opaca. A captura ficou igual, e não confirmei que o ajuste estava ativo |
| 18 | Cartazes | `git diff` e testes | passou em parte | `FeatureShare` e `PartyBackdrop` fora do diff, testes passando. O retrato segue a regra nova neles, e nenhum cartaz foi comparado na tela |
| 19 | Widget e Atividade ao Vivo | `git diff` | passou em parte | `FiscalWidgets` fora do diff. Não abertos |
| 20 | Maior tamanho de texto | Abrir comparar | passou em parte | `testTheComparisonIsReadableAtTheLargestTextSize`, [captura](hero-compare-largest.png), que só confere se os nomes existem. Placar coberto na `FSC-015` |

**Verificação:** `scripts/verify.sh --full` passou, e `scripts/ui-test.sh` passou nos 25 testes. A proteção contra rosto errado é o `portrait-check`: sobre os dados de teste a cada verificação completa e, sobre os publicados, manual, antes de versão e depois de carga.

**Não visto:** Mac, iPad, Duo aberto e VoiceOver.

**Falha no meio da fase:** o commit `7e5f680` saiu com um teste novo falhando, porque estava encadeado no comando. O teste comparava cores dinâmicas e foi corrigido em `f627431`.

**Fora do canvas, no backlog:** a mesma pessoa com dois partidos e os dados parados em 28/10. Riedel aparece como PSDB no perfil por causa disso.
