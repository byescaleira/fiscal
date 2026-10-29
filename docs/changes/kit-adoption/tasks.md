# Etapas: Fiscal no byescaleira-kit

## 1. Dependência e design

- [x] 1.1 `FiscalKit/Package.swift` depende do kit (commit do PR #11 até a `v0.5.1`).
- [x] 1.2 `FiscalDesignSystem` reexporta `ByescaleiraDesign`, `ByescaleiraAccessibility`, `ByescaleiraPlatform` e `ByescaleiraCharts`; saem as 47 cópias; o que é só do Fiscal (cores do placar e afins) fica em arquivos do Fiscal.
- [x] 1.3 Build e testes do pacote. Verificação: `swift build --build-tests`, `scripts/build.sh Debug ios` e a suíte no simulador (502 testes; o único que falhou, o do idioma, levou à correção da 2.1). Comparação das telas antes e depois no mesmo simulador: iguais, salvo o tom mais escuro do laranja, da mostarda e do oliva.

## 2. Componentes genéricos

- [x] 2.1 `FeatureCore` reexporta `ByescaleiraUI` e o `FiscalDomain` reexporta `ByescaleiraFoundation`; saem as cópias de guias, estado vazio, seletores, editor, alerta, `ModelHost`, idiomas, `YearMonth` e `FiscalCalendar` (agora `GregorianCalendar`). O idioma fica fixo em pt-BR por `FiscalLanguage.install()` no app e nos widgets ([ADR 0003](../../adr/0003-portuguese-only.md)).
- [ ] 2.2 Textos do Fiscal no catálogo conferidos (`scripts/strings.sh`). Verificação: `scripts/verify.sh --quick` e o iPhone físico.

## 3. Sistema 26 e versão

- [ ] 3.1 Mínimo 26 no projeto e no pacote; o que é do 27 atrás de `#available` com alternativa.
- [ ] 3.2 `MARKETING_VERSION = 1.0.0` e `CHANGELOG.md`.

## 4. Fechamento

- [ ] 4.1 `scripts/verify.sh --full`.
- [ ] 4.2 Revisões de design e de código.
- [ ] 4.3 ADR da adoção do kit; `docs/design-system.md` apontando para o kit.
- [ ] 4.4 Pasta arquivada em `docs/changes/archive/`.
