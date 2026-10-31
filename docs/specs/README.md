# Specs (histórico)

Congeladas em 2026-10-29. A verdade atual de cada capacidade está no canvas `[Codify]` dela em [spdd/prompt/](../../spdd/README.md) ([ADR 0019](../adr/0019-spdd-process.md)). Estas specs não recebem mudança nova.

As specs vivas do Fiscal: um arquivo por capacidade, com a verdade **atual** do app. Quem quer saber como algo funciona hoje lê aqui; o caminho até chegar lá está nas mudanças arquivadas ([changes/archive/](../changes/README.md)) e o porquê está nos [ADRs](../adr/README.md).

## Regras

- **Um arquivo por capacidade**, em `docs/specs/<capacidade>.md`, com nome em inglês e kebab-case (`reminders.md`, `item-editor.md`). Capacidade é o que a pessoa consegue fazer, não um target ou uma tela.
- **Só o que é verdade agora.** Nada de plano, etapa em aberto ou histórico; isso fica na mudança (`docs/changes/<id>/`) e no ADR.
- **Muda junto com o código.** Uma spec só é editada ao arquivar a mudança que a altera, no mesmo commit; spec desatualizada é bug.
- **Números exatos.** Limites, prazos, preços, intervalos e textos fixos ficam escritos aqui; o código lê estes números e os testes os conferem.
- **Formato:** as seções de [spec-template.md](../spec-template.md) (Princípios, Onde fica, Mecânicas e regras, Construção, O que fica com você), sem as instruções em itálico.

## Índice

| Capacidade | Spec |
| --- | --- |
| Apuração ao vivo e Atividade ao Vivo da disputa | [live-results.md](live-results.md) |
| Dados públicos: arquivos, CDN, cache, erros, pacote offline e carga | [public-data-api.md](public-data-api.md) |
| Lente: quem você apoia, temas e visual, só no aparelho | [lens.md](lens.md) |
| Credibilidade: fonte, "—", comparação com colegas, peso, "Estimado" e explicações | [credibility.md](credibility.md) |
| Cartazes de compartilhar, acervo de arte e créditos | [share-cards-and-art.md](share-cards-and-art.md) |
| Checagens do Projeto Comprova | [fact-checks.md](fact-checks.md) |
| Alertas: destaque do momento e resultado da disputa | [notifications.md](notifications.md) |
| Atualização obrigatória ou recomendada | [../force-update.md](../force-update.md) |
| Site público e Fiscal na Web | [../web.md](../web.md) |
| Admin, flags remotas e versões | [../admin.md](../admin.md) |

As specs que nasceram com o template continuam em `docs/` para não quebrar links; capacidades novas entram aqui e na tabela. Roteiros de teste e operação (`validation.md`, `app-store/`) não são specs.
