# Decisões (histórico)

Histórico das decisões tomadas antes dos ADRs, em ordem. Este arquivo não recebe entradas novas: cada decisão nova vira um ADR em [adr/](adr/README.md) ([0001](adr/0001-record-architecture-decisions.md) explica por quê). As entradas abaixo continuam valendo até um ADR substituí-las.

## 25/10/2026: criação do Fiscal

- **Estrutura do template `byescaleira-sdd`.** Projeto Xcode fino com pasta sincronizada, pacote `FiscalKit` com um target por feature (`FeatureHome`, `FeatureGuides`, `FeatureSettings`), `FeatureCore` para o compartilhado e `AppShell` como único ponto que conhece todas. É a forma do Cashly, para que cada app novo saia igual.
- **iOS, iPadOS, macOS e visionOS 27** com o mesmo código, Swift 6 e `ENABLE_DEBUG_DYLIB = NO` (App Intents registram em Debug).
- **Dados em SwiftData com CloudKit** no container `iCloud.fiscal`, desligado no simulador; App Group `group.com.byescaleira`.
- **Design system completo** copiado do Cashly, com tokens obrigatórios pelo lint; nada de anéis circulares, toolbar sem `.fill`, `.fontDesign(.rounded)`.
- **Dez idiomas** (en, pt-BR, es, de, fr, it, ja, ko, zh-Hans, ru) num catálogo único, todos traduzidos.
- **`Item` como exemplo vertical** (domínio, dados, Início, editor e testes) para mostrar o caminho completo; é substituído pela primeira entidade real.
- **Sem widget, assinatura ou onboarding no início.** Entram quando o produto pedir, seguindo as referências da skill (`platform-integrations.md`, `monetization.md`, `onboarding-and-guides.md`).
- **Pronto para a loja desde o início.** Atualização obrigatória (`AppRelease` no banco público do CloudKit, `AppUpdateModel`, `UpdateHoldModel`, tela de bloqueio com Atualizar e Exportar dados, cache `app-release.json`; ver `force-update.md`), novidades em Ajustes › Sobre (`ReleaseNote`, `WhatsNewScreen`), modo vitrine `-fiscal.developer.showcase YES` só em Debug, inicializador do schema do CloudKit (`-FiscalInitializeCloudSchema`, só no aparelho) e o atalho "New Item" com as frases em `AppShortcuts.xcstrings`.
- **Loja preparada, sem código de assinatura.** `Fiscal.storekit` com o grupo "Fiscal Pro" (mensal e anual, anual no nível 1, 7 dias grátis) ligado ao scheme `Production`; scheme `Sandbox` sem ele; alvo `FiscalStoreTests` hospedado pelo app, com o plano `StoreKit`, conferindo o catálogo (`scripts/store-test.sh`). O `FeatureStore` entra seguindo `monetization.md`.
- **Testes de interface em XCTest** no alvo `FiscalUITests` (isolamento `nonisolated`, o único lugar sem Swift Testing), com um teste de abertura; `scripts/ui-test.sh`.
- **`scripts/audit.sh` pula** enquanto o pacote não tiver o executável `FiscalAudit` (receita em `tooling-and-ci.md`).
- **Exceções da auditoria (`.byescaleira-sdd.json › allow`).** `literal-color` vale no `FiscalDesignSystem`, onde as cores são definidas, e no `FiscalDesignSystemTests`, que testa o `Color(hex:)` com textos de cor; `foreign-localization` vale em `FiscalDomain/Localization`, que implementa o `String(appLocalized:)`.
