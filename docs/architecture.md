# Arquitetura

O Fiscal segue a arquitetura padrão dos apps do Rafael (skill `byescaleira-sdd`, `references/architecture.md`): um projeto Xcode fino que abre o banco e entrega a janela ao pacote `FiscalKit`, com um target por feature. As features não se importam; navegam pedindo uma `Route` ao `AppShell`. Models `@MainActor @Observable` chegam às telas pelo `Environment`.

## Repositório

```text
fiscal/
├── Fiscal.xcworkspace          projeto + pacote; scheme compartilhado FiscalKitTests
├── Fiscal/
│   ├── Fiscal.xcodeproj        target Fiscal (pasta sincronizada); scheme Production
│   └── Fiscal/                 FiscalApp.swift, Info.plist, entitlements, Assets, FiscalIcon.icon, Localizable.xcstrings
├── FiscalKit/                  Package.swift, Sources/<Target>, Tests/<Target>Tests
├── scripts/                     build, lint, format, test, strings, icons, animations, simulator
├── ci_scripts/                  Xcode Cloud
└── docs/                        constitution, specs/, changes/, adr/, este arquivo, design-system, backlog, roadmap
```

## Targets

| Target | Responsabilidade | Depende de |
| --- | --- | --- |
| `FiscalDomain` | Entidades (`Item`), valores (`YearMonth`), protocolos de repositório, `FiscalError`, `AppLanguage`/`String(appLocalized:)`, `RemoteFlag` | nada |
| `FiscalData` | `FiscalDatabase` (SwiftData + CloudKit `iCloud.fiscal`), `FiscalStore` (`@ModelActor`), entidades `@Model`, schema versionado, repositórios, `CloudKitFlagSource` | Domain |
| `FiscalDesignSystem` | Tokens, estilos, modifiers, layouts e componentes sem regra de negócio | nada |
| `FiscalResource` | Prévia do ícone e animações Lottie embutidas (`FiscalResourceAnimation`) | nada |
| `FeatureCore` | `SessionModel`, navegação (`Route`, `AppSection`, `FiscalNavigation`, `\.open`, `\.close`), `FeatureFlag`/`FeatureFlags`, guias (`Guide*`), `EmptyStateView`, `MonthPicker`, editor (`EditorStatus`, `EditorActions`, `editorLifecycle`), `errorAlert`, cores retrô, `FiscalAnimationView` | Domain, DesignSystem, Resource, Lottie |
| `FeatureHome` | Início: herói, lista e estado vazio; editor de exemplo (`ItemEditorModel`) | Domain, DesignSystem, FeatureCore |
| `FeatureGuides` | `GuideScreen` e páginas dos tutoriais | Domain, DesignSystem, FeatureCore |
| `FeatureSettings` | Ajustes: Aparência (tema, cor de destaque), Idioma, Guias, Sobre, Desenvolvedor (flags) | Domain, DesignSystem, Resource, FeatureCore |
| `AppShell` | `FiscalWindow`, `MainScreen`, `SectionStack`, `SectionScreen`, `RouteScreen`, `InspectorScreen`, `SplashScreen`/`LaunchProgress`, `DeepLinks`, `FiscalServices` | todas as features |

`Item` é o exemplo vertical que nasce com o template (domínio → dados → feature → testes). Renomeie para a primeira entidade real ou remova quando ela existir.

## Links

| Link | Abre |
| --- | --- |
| `fiscal://home` | Início |
| `fiscal://items/new` | Editor de item novo |
| `fiscal://items/<id>` | Editor do item |
| `fiscal://settings` | Ajustes |

## Receita: nova feature

Siga `references/architecture.md › Receita: adicionar uma feature` da skill `byescaleira-sdd`: domínio, dados, target `Feature<Nome>` com model e telas, `Package.swift`, `Route`/`AppSection`, flag se não estiver pronta, testes e `TestableReference` no scheme `FiscalKitTests`, textos nos 10 idiomas. A mudança começa em `docs/changes/<id>/`, termina com a spec da capacidade em `docs/specs/` e as decisões em `docs/adr/`.
