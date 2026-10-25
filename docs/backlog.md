# Backlog

O que falta, por prioridade. Itens concluídos saem daqui; o motivo das decisões fica em [adr/](adr/README.md).

## Antes de distribuir

- **[P1] Definir o produto.** Propor a primeira feature real em `docs/changes/<id>/` (`/byescaleira-workspace:specify`), com a spec em `docs/specs/`, e substituir o exemplo `Item`.
- **[P1] Ícone próprio.** Trocar `FiscalIcon.icon` pelo ícone do app e rodar `scripts/icons.sh`.
- **[P1] Links do Sobre.** Preencher `FiscalAppStoreID`, `FiscalSupportEmail`, `FiscalHelpURL`, `FiscalPrivacyURL`, `FiscalTermsURL` e `FiscalWebsiteURL` no `Info.plist`.
- **[P2] Container e App Group.** Criar `iCloud.fiscal` e conferir `group.com.byescaleira` no portal da Apple antes do primeiro build assinado.
