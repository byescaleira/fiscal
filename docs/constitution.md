# Constituição do Fiscal

As regras inegociáveis do repositório. Valem para toda mudança, de qualquer pessoa ou agente, mesmo sem abrir outro documento, e vencem qualquer spec, proposta ou ADR que diga o contrário. Mudar uma regra daqui exige um ADR aceito pelo usuário e a atualização deste arquivo no mesmo commit. O detalhe de cada regra está na skill `byescaleira-sdd` do plugin `byescaleira-workspace`.

## Regras

1. **Idioma.** Responda em pt-BR, inclusive nas notas de andamento. Código, chaves de texto e commits em inglês.
2. **Processo.** Entender → perguntar só decisões genuínas (opção recomendada primeiro) → propor a mudança em `docs/changes/<id>/` (`proposal.md`, `design.md`, `tasks.md`) → planejar em fases → para tela existente, **crítica honesta antes de redesenhar** → implementar → verificar → atualizar `docs/specs/` e arquivar a mudança → registrar as decisões em `docs/adr/` → commit por fase. "Em etapas" = parar e esperar o ok entre etapas.
3. **Arquitetura.** App fino + pacote `FiscalKit` com um target por feature; features não se importam (navegação por `Route`); models `@MainActor @Observable` injetados por `@Environment(Tipo.self)`, `@Bindable var model = model` dentro do `body`; lógica, cálculo, formatação e ações só no model; views curtas, uma subview por seção.
4. **Código.** Zero comentários; zero warnings; Swift Testing para toda lógica nova; tokens do `FiscalDesignSystem` em vez de números soltos.
5. **Design.** Nativo Apple/HIG primeiro, sem identidade visual nova; **nunca anéis ou progresso circular** (só barras, sempre `ProgressBar`, um `Gauge` com `.linearCapacity`, nunca `ProgressView(value:)`); toolbar sem `.fill`; herói com a informação principal, prévias reais com componentes do app, chips de estado, grades para escolhas visuais, barras que preenchem, cascata e `symbolEffect` discretos, rodapés que explicam; confirmações são guias (`GuideSheet`: título e texto em cima, Lottie ou animação SwiftUI, até ~3 linhas, botões); Lottie gerada por `scripts/animations.py`, sem fundo, camadas nomeadas pela paleta; `.fontDesign(.rounded)`; Reduzir movimento sempre respeitado; layout adaptativo (iPhone retrato e paisagem, iPad, Mac, visionOS); **Apple TV só consome conteúdo** (sem formulários, edição ou participação; a conta entra pelo app do iPhone).
6. **Textos.** Inglês é a língua primária (texto que só pode ter um idioma fica em inglês), inglês no código, catálogo único com **10 idiomas** (en, pt-BR, es, de, fr, it, ja, ko, zh-Hans, ru), todos `translated`; `Text("Key")` nas telas, `String(appLocalized:)` nos models; plurais por variação. Texto novo no site também sai nos 10 idiomas.
7. **Verificação.** Durante o trabalho e antes de cada commit `scripts/verify.sh --quick` (build da plataforma e `scripts/test.sh --affected`); uma vez antes do merge da fase `scripts/verify.sh --full` (build das 3 plataformas, `scripts/lint.sh` e a suíte inteira); sempre pelos scripts, na mesma pasta de build e um build pesado por vez; simulador só pelo sim-monitor (`acquire`/`release`, limite global de 2); verificação visual **no iPhone físico** quando disponível; nunca dizer que verificou o que não verificou.
8. **Git flow.** `main` (loja), `development` (integração), `feature/<assunto>` saindo da `development` e voltando com `--no-ff`; nunca commitar direto na `main` ou na `development`.
9. **Aprovação humana.** Push para `main` ou `development`, merge na `main`, envio para a App Store ou o TestFlight, publicação do site, deploy na VPS e Deploy do schema do CloudKit para Production só com o ok explícito do usuário, pedido a cada vez. Aprovação anterior não vale para a próxima.
10. **Paralelismo.** Frentes independentes = um subagente por frente em worktree, com `FISCAL_BUILD_ROOT` próprio, sem simulador; o coordenador integra uma por vez e roda a verificação pesada.
11. **Fiscalização.** O hook do plugin roda a auditoria (`.byescaleira-sdd.json`) ao encerrar e bloqueia com violações; commit ou merge de interface exige a aprovação do revisor de design. Exceções legítimas só em `.byescaleira-sdd.json › allow`, com o motivo num ADR.
12. **CI.** Xcode Cloud com os scripts de `ci_scripts/`; o repositório não usa GitHub Actions.

## Onde cada coisa fica

| O quê | Onde |
| --- | --- |
| Verdade atual de cada capacidade | [specs/](specs/README.md) |
| Mudança em andamento ou entregue | [changes/](changes/README.md) |
| Decisão e o porquê | [adr/](adr/README.md) |
| Decisões de antes dos ADRs | [decisions.md](decisions.md) |
| O que falta e o que vem depois | [backlog.md](backlog.md), [roadmap.md](roadmap.md) |
