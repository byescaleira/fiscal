# Revisão da FSC-023: plenário em pontos e carta colecionável

- **Canvas:** [FSC-023](../prompt/FSC-023-202611052151-[Feat]-plenary-and-holographic-card.md)
- **Escopo:** `658dea0..HEAD` na `feature/metal-exploration`, numa rodada única.
- **Revisores:** canvas (`spec-reviewer`), interface (`ui-reviewer`), código (`code-reviewer`) e segurança (`security-reviewer`), porque o diff sobe a dependência `byescaleira-kit`.
- **Veredito final:** Ready to Merge. Os três críticos da primeira leitura e o crítico da re-revisão foram resolvidos na fase.

| Severidade | Dimensão | Achado | Resolução |
| --- | --- | --- | --- |
| crítica | canvas | Sem prova da contagem animada uma vez e de Reduzir movimento (DoD 4 e 5) | [QA](../../docs/evidence/FSC-023/qa.md) com as duas sequências; "voltar sem repetir" declarado como não executável aqui |
| crítica | canvas | Sem prova da carta, da carta parada e do sensor (DoD 8 a 10) | QA com 3 partidos, Reduzir movimento, Aumentar contraste, contraste medido e os testes do kit; o iPhone fica no backlog por decisão do usuário |
| crítica | canvas | Entities desatualizado | `spdd-sync` (`ce67f94`) |
| crítica | canvas (re-revisão) | Grade da legenda e limite do rótulo do quórum fora do canvas | `spdd-sync` (`a5d5f9d`) |
| importante | canvas | Structure sem `PlenarySeatsTests`, `Package.resolved` e evidência | `spdd-sync` |
| importante | canvas | Contagens sem `PublicFormat.number` | Norma registrada: as contagens ficam em `%lld` para o plural e nunca passam de 513 |
| importante | canvas | Padding da moldura não registrado | Approach 12, "Tamanho" |
| importante | canvas e código | Commits da exploração antes do canvas, sem `Canvas:` | Approach 13 registra a exceção; o histórico não foi reescrito |
| deveria | interface e código | A legenda podia passar da largura | `ViewThatFits` com grade de duas colunas |
| deveria | interface e código | O rótulo do quórum podia invadir as cadeiras | `dynamicTypeSize(...xLarge)` no gráfico |
| deveria | código | `EffectsWarmUp.compile()` a cada abertura do perfil, com `try?` | Mantido: a compilação repetida usa o cache do sistema, e uma falha só deixa a carta sem efeito. Fica como detalhe |
| deveria | interface | Ligar Reduzir movimento no meio da contagem | Descartado: `animates` é recalculado a cada `body`, e a contagem para na hora |
| detalhe | segurança | `from: "0.11.0"` aceita qualquer 0.x | Mantido, como nas outras dependências; o `Package.resolved` trava a revisão |
| detalhe | código | Empate de ângulos na linha do quórum e testes do meio | Sem efeito visto nas capturas; fica como detalhe |

**Segurança:** o sensor fica só na memória e não entrou segredo. O rótulo de privacidade não muda.
