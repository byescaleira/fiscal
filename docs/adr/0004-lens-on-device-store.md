# 0004. A Lente fica num banco só do aparelho; os seguidos no iCloud privado

- **Estado:** Proposto
- **Data:** 2026-10-25
- **Mudança:** [`app-1.0`](../changes/app-1.0/proposal.md)

## Contexto

O [brief](../brief.md) diz que a Lente e o posicionamento político "ficam só no aparelho" e "nunca saem no backup do servidor": opinião política é dado sensível na LGPD (art. 5º, II, e art. 11). Quem a pessoa segue também fica no aparelho, com "o iCloud opcional". O `FiscalDatabase` sincronizava todo o SwiftData com o CloudKit privado (`iCloud.fiscal`) nos aparelhos assinados.

## Decisão

1. O SwiftData do Fiscal abre **duas configurações** no mesmo `ModelContainer`, com o mesmo `FiscalSchemaV1`:
   - `Device` (`Device.store`): `LensEntity`, sempre com `cloudKitDatabase: .none`;
   - `Fiscal` (`Fiscal.store`): `FollowEntity`, com o CloudKit privado quando a sincronização está ligada.
2. `FiscalSchemaV1.deviceModels` e `cloudModels` separam os dois lados; o `initializeCloudSchema` só envia `cloudModels` ao CloudKit.
3. Nada da Lente vai para o servidor do Fiscal nem para telemetria. O único caminho de saída é a exportação que a própria pessoa pede (`DataArchive`, com a Lente e os seguidos).

## Consequências

- A Lente não aparece em outro aparelho da mesma conta: cada aparelho escolhe a sua (o setup é curto).
- Os seguidos podem chegar duplicados por CloudKit; o `FiscalStore` lê um por `slug` e grava sem repetir.
- Um teste (`DeviceStoreTests`) garante que `LensEntity` nunca entra em `cloudModels`.

## Alternativas consideradas

- **Tudo no CloudKit privado:** mais simples, mas a opinião política sairia do aparelho, contra o brief.
- **Lente no `UserDefaults`:** entra no backup do aparelho do mesmo jeito e foge do padrão SwiftData do projeto.
