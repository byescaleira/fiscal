# Fiscal

App SwiftUI para iOS, iPadOS, macOS e visionOS 27, com SwiftData local e sincronização CloudKit em aparelhos assinados. Criado com o template do plugin `byescaleira-workspace`. Regras para agentes em [AGENTS.md](AGENTS.md) (o [CLAUDE.md](CLAUDE.md) importa e acrescenta as notas do Claude Code).

- [Constituição](docs/constitution.md)
- [Specs](docs/specs/README.md)
- [Mudanças](docs/changes/README.md)
- [Decisões (ADRs)](docs/adr/README.md) e o [histórico de antes deles](docs/decisions.md)
- [Arquitetura](docs/architecture.md)
- [Design system](docs/design-system.md)
- [Backlog](docs/backlog.md)
- [Roadmap](docs/roadmap.md)
- [Atualização obrigatória](docs/force-update.md)
- [Validação antes de distribuir](docs/validation.md)
- [Site e Fiscal na Web](docs/web.md)
- [Admin](docs/admin.md)
- [App Store: textos e mídia](docs/app-store/README.md)

## Começando

Abra `Fiscal.xcworkspace` no Xcode 27 e use o scheme `Production` para o app, `FiscalKitTests` para os testes do pacote e `FiscalUITests` para a interface. O app é gratuito, sem compras nem StoreKit.

```sh
scripts/format.sh
scripts/lint.sh
scripts/build.sh Debug
scripts/strings.sh
scripts/test.sh
scripts/ui-test.sh
scripts/audit.sh
```

O simulador usa o banco local com CloudKit desligado. Nos aparelhos, o app usa o container `iCloud.fiscal`.

No Claude Code, o `.claude/settings.json` liga o plugin `byescaleira-workspace` para o time e define as permissões; a primeira mudança começa com `/byescaleira-workspace:specify`.
