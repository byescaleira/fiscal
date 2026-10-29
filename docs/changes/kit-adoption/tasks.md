# Etapas: Fiscal no byescaleira-kit

## 1. Dependência e design

- [x] 1.1 `FiscalKit/Package.swift` depende do kit (commit do PR #11 até a `v0.5.1`).
- [x] 1.2 `FiscalDesignSystem` reexporta `ByescaleiraDesign`, `ByescaleiraAccessibility`, `ByescaleiraPlatform` e `ByescaleiraCharts`; saem as 47 cópias; o que é só do Fiscal (cores do placar e afins) fica em arquivos do Fiscal.
- [x] 1.3 Build e testes do pacote. Verificação: `swift build --build-tests`, `scripts/build.sh Debug ios` e a suíte no simulador (502 testes; o único que falhou, o do idioma, levou à correção da 2.1). Comparação das telas antes e depois no mesmo simulador: iguais, salvo o tom mais escuro do laranja, da mostarda e do oliva.

## 2. Componentes genéricos

- [x] 2.1 `FeatureCore` reexporta `ByescaleiraUI` e o `FiscalDomain` reexporta `ByescaleiraFoundation`; saem as cópias de guias, estado vazio, seletores, editor, alerta, `ModelHost`, idiomas, `YearMonth` e `FiscalCalendar` (agora `GregorianCalendar`). O idioma fica fixo em pt-BR por `FiscalLanguage.install()` no app e nos widgets ([ADR 0003](../../adr/0003-portuguese-only.md)).
- [x] 2.2 Textos do Fiscal no catálogo conferidos (`scripts/strings.sh`, que agora ignora os textos do kit, já traduzidos no catálogo dele): 969 textos em uso que estavam marcados como obsoletos voltaram a valer e 10 rótulos de gráfico ganharam pt-BR. O iPhone físico estava desconectado: a conferência no aparelho, com widgets e Live Activity, fica pendente.

## 3. Sistema 26 e versão

- [x] 3.1 Mínimo 26 no projeto e no pacote; o que é do 27 atrás de `#available` com alternativa (aba Fiscalizar `.prominent` no 27 e `.search` no 26; largura da Ilha Dinâmica só no 27). Ícones alternativos só no iOS (`[sdk=iphone*]`), sem aviso no visionOS. **Não rodado num sistema 26:** o Xcode desta máquina só tem o runtime iOS 27.1, então os caminhos do 26 (aba `.search`, Ilha sem limite de largura) só foram compilados.
- [x] 3.2 `MARKETING_VERSION = 1.0.0` e `CHANGELOG.md`.
- [x] 3.3 Regra `display-font` do workspace no repositório inteiro: números e títulos de destaque na Bricolage (placar, widgets, Live Activity, cartões de compartilhar), corpo em SF Pro, nada de SF condensada ou arredondada; a extensão dos widgets registra a fonte. Cartões conferidos antes e depois pelo `ShareCardSnapshotTests`.

## 4. Fechamento

- [x] 4.1 `scripts/verify.sh --full` (lint, 3 plataformas, 503 testes, web e auditoria; testes do admin pulados por falta do `node_modules`).
- [x] 4.2 Revisões de design e de código: aprovadas, sem bloqueador. Corrigidos nesta fase: três `.fontWidth(.condensed)` que sobraram, teste do dinheiro abreviado em pt-BR, teste de cartões sem mudar o idioma global da suíte, credencial do kit só nas URLs com `byescaleira@`, `audit.sh` com acesso ao kit, `architecture.md`, ADRs 0009 e 0010, `AGENTS.md`, `README.md` e `CHANGELOG.md`.
- [x] 4.3 [ADR 0010](../../adr/0010-byescaleira-kit.md); `docs/design-system.md` e `AGENTS.md` apontando para o kit.
- [ ] 4.4 Pasta arquivada em `docs/changes/archive/`.
