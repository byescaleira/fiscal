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
| `FiscalDomain` | Valores (`YearMonth`), protocolos de repositório, `FiscalError`, `AppLanguage`/`String(appLocalized:)`, `RemoteFlag` | nada |
| `FiscalData` | `FiscalDatabase` (SwiftData + CloudKit `iCloud.fiscal`), `FiscalStore` (`@ModelActor`), entidades `@Model`, schema versionado, repositórios, `CloudKitFlagSource` | Domain |
| `FiscalDesignSystem` | Tokens, estilos, modifiers, layouts e componentes sem regra de negócio | nada |
| `FiscalResource` | Prévia do ícone e animações Lottie embutidas (`FiscalResourceAnimation`) | nada |
| `FeatureCore` | `SessionModel`, navegação (`Route`, `AppSection`, `FiscalNavigation`, `\.open`, `\.close`), `FeatureFlag`/`FeatureFlags`, guias (`Guide*`), `EmptyStateView`, `MonthPicker`, editor (`EditorStatus`, `EditorActions`, `editorLifecycle`), `errorAlert`, cores retrô, `FiscalAnimationView` | Domain, DesignSystem, Resource, Lottie |
| `FeatureGuides` | `GuideScreen` e páginas dos tutoriais | Domain, DesignSystem, FeatureCore |
| `FeatureToday` | Aba Hoje: eventos do dia, card da apuração e o botão de Ajustes | Domain, DesignSystem, FeatureCore |
| `FeatureMine` | Aba Meus: UF ou cidade, grupos de representantes e seguidos | Domain, DesignSystem, FeatureCore |
| `FeatureProfile` | Perfil (`Route.person(slug:)`), aberto por qualquer aba | Domain, DesignSystem, FeatureCore |
| `FeatureVotes` | Aba Votações: recentes, pauta do dia e detalhe (`Route.vote(id:)`) | Domain, DesignSystem, FeatureCore |
| `FeatureMoney` | Aba Dinheiro | Domain, DesignSystem, FeatureCore |
| `FeatureSearch` | Aba Fiscalizar (`Tab(role: .search)`): busca no índice, Comparar (`Route.compare(slugs:)`) e Eleições | Domain, DesignSystem, FeatureCore |
| `FeatureLens` | Lente (`Route.lens`): setup, edição, aparência e coleções de arte | Domain, DesignSystem, FeatureCore |
| `FeatureShare` | Cards de compartilhar e galeria de artistas (`Route.artists`) | Domain, DesignSystem, FeatureCore |
| `FeatureLiveResults` | Apuração (`Route.races`), aberta por Hoje e por Fiscalizar › Eleições | Domain, DesignSystem, FeatureCore |
| `FeatureSettings` | Ajustes: Aparência (tema, cor de destaque), Guias, Sobre, Desenvolvedor (flags) | Domain, DesignSystem, Resource, FeatureCore |
| `AppShell` | `FiscalWindow`, `MainScreen`, `SectionStack`, `SectionScreen`, `RouteScreen`, `InspectorScreen`, `SplashScreen`/`LaunchProgress`, `DeepLinks`, `FiscalServices` | todas as features |

## Links

| Link | Abre |
| --- | --- |
| `fiscal://today`, `mine`, `votes`, `money`, `search` | A aba |
| `fiscal://person/<slug>` | Perfil, na aba Meus |
| `fiscal://vote/<id>` | Votação, na aba Votações |
| `fiscal://compare?slugs=<a>,<b>` | Comparar, em Fiscalizar |
| `fiscal://races` | Apuração, em Fiscalizar |
| `fiscal://lens`, `fiscal://artists` | Lente e artistas, em Hoje |
| `fiscal://settings` | Ajustes, em Hoje |

## Receita: nova feature

Siga `references/architecture.md › Receita: adicionar uma feature` da skill `byescaleira-sdd`: domínio, dados, target `Feature<Nome>` com model e telas, `Package.swift`, `Route`/`AppSection`, flag se não estiver pronta, testes e `TestableReference` no scheme `FiscalKitTests`, textos nos 10 idiomas. A mudança começa em `docs/changes/<id>/`, termina com a spec da capacidade em `docs/specs/` e as decisões em `docs/adr/`.
