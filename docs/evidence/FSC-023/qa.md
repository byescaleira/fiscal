# QA da FSC-023: plenário em pontos e carta colecionável

- **Canvas:** [FSC-023](../../../spdd/prompt/FSC-023-202611052151-[Feat]-plenary-and-holographic-card.md)
- **Ambiente:** simulador "Fiscal Metal iPhone Duo" (iOS 27.1), com os dados publicados, em 06/11/2026. Build com o `byescaleira-kit` 0.11.0.
- **iPhone físico:**
  - a faixa holográfica da etapa C foi vista pelo usuário ("Sim deu certo, mas não parece um card colecionável");
  - a carta colecionável não foi vista no aparelho, porque o usuário respondeu "Não consigo validar agora, vamos seguindo" e o iPhone ficou indisponível;
  - a inclinação, o giro e a medição de quadros ficam no [backlog](../../backlog.md).
- **Contraste:** o script compara o percentil 10 da luminância (fundo) com os 2% mais claros (texto) em cada caixa de texto, na captura em resolução cheia.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 | Plenário da Câmara | Abrir `fiscal://vote/camara-2236186-60` | passou | [Claro](plenary-camara-light.png), [escuro](plenary-camara-dark.png): 252 sim, 176 não, 1 outro e 84 não votaram; sem linha de quórum (PLP); a legenda vira grade de duas colunas quando não cabe numa linha. Testes `VoteDetailModelPlenaryTests` |
| 2 | Plenário do Senado com quórum | Abrir `fiscal://vote/senado-7107` | passou | [Claro](plenary-senado-light.png): 81 pontos, 2 não votaram, linha tracejada e "49 para aprovar" |
| 3 | PEC na Câmara | Modelo | passou em teste | Quórum 308 em `VoteDetailModelPlenaryTests` |
| 4 | Contagem animada uma vez | Abrir a votação e capturar a cada 0,6 s | passou em parte | [Sequência](plenary-count-sequence.png): no 3º quadro o sim e o não sobem juntos, com o meio ainda apagado; do 4º em diante, completo. "Voltar à tela sem repetir" não foi executável aqui (sem toque automatizado); o código guarda `isFinished` em `@State` por instância |
| 5 | Sem movimento | Reduzir movimento ligado, abrir a votação | passou | [Sequência](plenary-reduce-motion-sequence.png): o primeiro quadro com o plenário já está completo |
| 6 | VoiceOver | Modelo | passou em teste | `plenaryAccessibility` em `VoteDetailModelPlenaryTests` (513 cadeiras, 308 para aprovar) |
| 7 | Sem plenário | Modelo | passou em teste | Simbólica, pendente, total zero e votos acima das cadeiras em `VoteDetailModelPlenaryTests` |
| 8 | Carta colecionável | Abrir `fiscal://person/tabata-amaral` (PSB), `lindbergh-farias` (PT) e `nikolas-ferreira` (PL) | passou no simulador | [PSB](card-psb-light.png), [PSB escuro](card-psb-dark.png), [PT](card-pt-dark.png), [PL](card-pl-dark.png): moldura, janela com brilhos e o mesmo desenho para os três. Sem inclinação no simulador |
| 8a | Contraste igual ao de antes do holográfico | Medir nome, cargo, mandato e situação | passou | Tabela abaixo |
| 9 | Carta parada | Reduzir movimento; Aumentar contraste | passou no simulador | [Reduzir movimento](card-psb-reduce-motion.png); [Aumentar contraste](card-psb-contrast.png): janela sem holográfico e moldura em prata liso |
| 10 | Sensor parado fora da tela | Testes do kit | passou em teste | `TiltLifecycleTests` e `TiltReaderTests` no kit; o giro e o sensor no aparelho ficam no backlog |
| 11 | Onda no kit | Kit 0.10.0 | passou | `RippleTimingTests` e o catálogo do kit |
| 12 | Sem laboratório | `git grep "MetalLab\|FiscalMetalLab"` | passou | Nenhum resultado no código |

**Contraste da carta** (antes do holográfico → carta colecionável):

| Partido | Nome | Cargo | Mandato | Situação |
| --- | --- | --- | --- | --- |
| PSB | 5,25 → 5,30 | 2,89 → ver nota | 2,89 → 2,87 | 3,10 → 3,16 |
| PT | 11,54 → 12,00 | 5,22 → 5,42 | 5,29 → 5,48 | 5,26 → 5,22 |
| PL | 8,75 → 8,88 | 4,20 → 4,17 | 4,12 → 4,08 | 4,57 → 4,66 |

- **Nota do cargo no PSB:** a caixa pegou parte do nome e deu 5,30. O mandato, com a mesma cor de texto, deu 2,87.
- **Resultado:** a carta tem o contraste de antes do holográfico, com diferença de até 0,4, dentro do ruído da medição.
- **Problema anterior:** o texto secundário sobre o fundo do PSB já ficava abaixo de 4,5:1 antes desta mudança. Isso vem do `PartyBackdrop` e não muda aqui.

**Verificação:**
- `scripts/verify.sh --full` passou: lint, auditoria, build de iOS, macOS e visionOS, suíte inteira, web, servidor e ponte.
- Os testes do admin não rodaram, porque falta o `admin/node_modules`.
