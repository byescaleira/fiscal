# Revisão da FSC-014: nova página do político e compartilhar um item

- **Canvas:** [FSC-014](../prompt/FSC-014-202611020300-[Feat]-politician-page-and-share-an-item.md)
- **Intervalo revisado:** `9429cec..d88b310`, numa rodada só, com o `spec-reviewer` e o painel de interface e código.
- **Veredito do canvas:** Needs Attention (0 críticos, 5 importantes, 3 informativos). **Veredito do painel:** aprovado, sem bloqueador.
- **Limite:** os revisores só leram o código; não rodaram build nem testes.

| Seção | Estado | Achados |
| --- | --- | --- |
| Requirements | desvio na evidência | 3 |
| Entities | desvio leve | 1 |
| Approach e ADR 0023 | ok | 0 |
| Structure | desvio leve | 2 |
| Operations | desvio leve | 1 |
| Norms | ok | 0 |
| Safeguards | ok | 0 |
| Sincronia | ok | 0 |

## Achados do canvas

| Severidade | Onde | Achado | Próximo passo |
| --- | --- | --- | --- |
| importante | QA, cenário 23 | "Passou", mas "sem apoio" só tem a regra do lint como prova | Corrigido no QA: passou em parte |
| importante | QA, cenário 32 | "Passou em teste", mas o teste só prova a largura | Corrigido no QA: passou em parte |
| importante | QA, cenário 13 | O rótulo do VoiceOver não tinha prova | Teste acrescentado; o QA fica em passou em parte, porque o VoiceOver ligado não foi usado |
| importante | QA, cenário 29 | Duo aberto, iPad e Mac sem prova | Declarado no QA e no PR como não verificado |
| importante | `README.md` | Ainda prometia os indicadores na página do político | Corrigido |
| informativa | Entities, Approach e operação 9 | `RouteCard` tem outra assinatura, e `CardBackdropButton` não está em Entities | `spdd-sync`, com o ok do usuário |
| informativa | Structure e Operations | `ProfilePortraitChoreographyTests` está em `ProfileChaptersTests`, `RaceHeroCard` não mudou, e `ProfileTokens` e `PortraitArtView` mudaram sem estar listados | `spdd-sync`, com o ok do usuário |
| informativa | QA, cenário 12 | Ausência das quatro expressões só por revisão de código | Sem ação; a coreografia recebe só o capítulo |

**Desvio de intenção:** nenhum acréscimo, omissão ou divergência em número, regra ou escopo. Os Safeguards foram conferidos no código: gesto só pelo capítulo, sem as expressões proibidas, CNPJ de 14 dígitos, sem mudança em `server/` nem em `PersonContext`.

**Decisões implícitas:** nenhuma que mude comportamento. Cartões compactos, de eleito e de região usam `RouteChevron` direto, sem `RouteCard`.

## Achados do painel

| Severidade | Onde | Achado | Próximo passo |
| --- | --- | --- | --- |
| deveria | `FeedRows.swift` | No cartão sem destino, a pessoa e as linhas de voto sumiam para o VoiceOver | Corrigido: o rótulo do cartão fica à parte, e os botões seguem expostos |
| deveria | `ProfileStickyHeader.swift` | A rolagem dos atalhos ignorava Reduzir movimento | Corrigido |
| detalhe | `RouteCard.swift` | Quem usa precisa esconder o corpo para o VoiceOver não ler em dobro | Sem ação; há um único uso, que esconde |
| detalhe | `FeedRows.swift` | O nome pode repetir entre o botão da pessoa e o do cartão | Sem ação; VoiceOver ligado não foi usado |
| detalhe, não verificado | `ExpenseRows.swift`, `ProfileActivitySections.swift` | O botão de compartilhar em camada pode cobrir texto no maior tamanho | Sem ação; não conferido em nota nem em proposta nesse tamanho |
| detalhe, não verificado | `ProfileScreen.swift` | Os topos dos capítulos são medidos a cada quadro de rolagem | Sem ação; o usuário não relatou travada no iPhone, e não foi medido com Instruments |
