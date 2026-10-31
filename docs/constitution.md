# Constituição do Fiscal

As regras inegociáveis do repositório. Valem para toda mudança, de qualquer pessoa ou agente, mesmo sem abrir outro documento, e vencem qualquer canvas ou ADR que diga o contrário. Mudar uma regra daqui exige um ADR aceito pelo usuário e a atualização deste arquivo no mesmo commit. O detalhe de cada regra está na skill `byescaleira-sdd` do plugin `byescaleira-workspace`.

## Regras

1. **Idioma.** Responda em pt-BR, inclusive nas notas de andamento. Código, chaves de texto e commits em inglês.
2. **Processo.** Toda mudança de comportamento passa pelo SPDD ([ADR 0019](adr/0019-spdd-process.md)):
   - análise e REASONS Canvas em `spdd/`;
   - ok do usuário no canvas antes do código;
   - o canvas corrigido antes do código quando a realidade diverge;
   - `spdd-sync` depois de refatorar.

   Para tela existente, **crítica honesta antes de redesenhar**, na análise. "Em etapas" = parar e esperar o ok entre etapas. `docs/specs/`, `docs/changes/` e `docs/decisions.md` são histórico congelado e não recebem entrada nova.
3. **Arquitetura.** App fino + pacote `FiscalKit` com um target por feature; features não se importam (navegação por `Route`); models `@MainActor @Observable` injetados por `@Environment(Tipo.self)`, `@Bindable var model = model` dentro do `body`; lógica, cálculo, formatação e ações só no model; views curtas, uma subview por seção.
4. **Código.** Zero comentários; zero warnings; Swift Testing para toda lógica nova; tokens do `FiscalDesignSystem` em vez de números soltos.
5. **Design.** Nativo Apple/HIG primeiro, sem identidade visual nova além da fonte de ênfase ([ADR 0009](adr/0009-bricolage-emphasis-font.md)); **nunca anéis ou progresso circular** (só barras, sempre `ProgressBar`, um `Gauge` com `.linearCapacity`, nunca `ProgressView(value:)`); toolbar sem `.fill`; herói com a informação principal, prévias reais com componentes do app, chips de estado, grades para escolhas visuais, barras que preenchem, cascata e `symbolEffect` discretos, rodapés que explicam; confirmações são guias (`GuideSheet`: título e texto em cima, Lottie ou animação SwiftUI, até ~3 linhas, botões); Lottie gerada por `scripts/animations.py`, sem fundo, camadas nomeadas pela paleta; ênfase em Bricolage Grotesque (`emphasisTitle`, `sectionTitle()`, `primaryButton()`, `Font.emphasis`) e corpo em SF Pro, nunca `.fontDesign(.rounded)` na raiz de tela; **número e título de destaque só na Bricolage**, inclusive em cartaz, widget e Live Activity (nada de SF condensada, arredondada, mono, nem heavy/black em tamanho fixo; algarismos alinhados com `.monospacedDigit()`); Reduzir movimento sempre respeitado; layout adaptativo (iPhone retrato e paisagem, iPad, Mac, visionOS); **Apple TV só consome conteúdo** (sem formulários, edição ou participação; a conta entra pelo app do iPhone).
6. **Textos.** Exceção do Fiscal ([ADR 0003](adr/0003-portuguese-only.md)): o app é só em português do Brasil, com código e chaves em inglês e só a tradução `pt-BR` no catálogo; o resto desta regra vale para apps com mais de um idioma. Inglês é a língua primária (texto que só pode ter um idioma fica em inglês), inglês no código, catálogo único com **10 idiomas** (en, pt-BR, es, de, fr, it, ja, ko, zh-Hans, ru), todos `translated`; `Text("Key")` nas telas, `String(appLocalized:)` nos models; plurais por variação. No Fiscal, o site também é só em pt-BR.
7. **Verificação.** Durante o trabalho e antes de cada commit `scripts/verify.sh --quick` (build da plataforma e `scripts/test.sh --affected`); uma vez antes do merge da fase `scripts/verify.sh --full` (build das 3 plataformas, `scripts/lint.sh` e a suíte inteira); sempre pelos scripts, na mesma pasta de build e um build pesado por vez; simulador só pelo sim-monitor (`acquire`/`release`, limite global de 2); verificação visual **no iPhone físico** quando disponível; nunca dizer que verificou o que não verificou.
8. **Git flow.** `main` (loja), `development` (integração), `feature/<assunto>` saindo da `development` e voltando com `--no-ff`; nunca commitar direto na `main` ou na `development`.
9. **Aprovação humana.** Push para `main` ou `development`, merge na `main`, envio para a App Store ou o TestFlight, publicação do site, deploy na VPS e Deploy do schema do CloudKit para Production só com o ok explícito do usuário, pedido a cada vez. Aprovação anterior não vale para a próxima.
10. **Paralelismo.** Frentes independentes = um subagente por frente em worktree, com `FISCAL_BUILD_ROOT` próprio, sem simulador; o coordenador integra uma por vez e roda a verificação pesada.
11. **Fiscalização.** O hook do plugin roda a auditoria (`.byescaleira-sdd.json`) ao encerrar e bloqueia com violações; commit ou merge de interface exige a aprovação do revisor de design. Exceções legítimas só em `.byescaleira-sdd.json › allow`, com o motivo num ADR.
12. **CI.** Xcode Cloud com os scripts de `ci_scripts/`; o repositório não usa GitHub Actions.
13. **Versão.** Decisão do usuário de 2026-10-28 para todo o workspace ([ADR 0012](adr/0012-constitution-version-and-facts.md)): mínimo de sistema 26 em todas as plataformas, compilando com o SDK mais novo; tudo do 27 atrás de `#available` com alternativa no 26. `MARKETING_VERSION` em SemVer (`1.0.0`), igual em todos os alvos; `CHANGELOG.md` com `Unreleased` atualizado em todo PR; tag `vX.Y.Z` em cada versão da loja, com ok. Regra completa: skill `sdd`, `versioning.md`.
14. **Fato, não opinião; incerteza explicada.** Exceção do Fiscal ([ADR 0012](adr/0012-constitution-version-and-facts.md), [brief](brief.md)): o app mostra números e textos oficiais como vieram, com fonte e data, sem adjetivo de valor, causa atribuída, nota ou ranking de pessoas; dado ausente é "—", nunca 0; tudo que é estimado (peso, repercussão, temas, explicação gerada) diz ao lado, em uma linha, por que é estimado e o que ficou sem medir; a mesma regra vale para todos os políticos, partidos e lados.

## Onde cada coisa fica

| O quê | Onde |
| --- | --- |
| Análises, canvases e revisões (a verdade atual de cada capacidade) | [spdd/](../spdd/README.md) |
| Decisão e o porquê | [adr/](adr/README.md) |
| Histórico de antes do SPDD (congelado) | [specs/](specs/README.md), [changes/](changes/README.md), [decisions.md](decisions.md) |
| O que falta e o que vem depois | [backlog.md](backlog.md), [roadmap.md](roadmap.md) |
