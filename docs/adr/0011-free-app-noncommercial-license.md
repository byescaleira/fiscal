# 0011. App gratuito sem StoreKit e código sob a PolyForm Noncommercial

- **Estado:** Aceito
- **Data:** 2026-10-29
- **Mudança:** [`align-workspace`](../changes/align-workspace/proposal.md)

## Contexto

O template do workspace nasce com assinatura (`Fiscal.storekit`, grupo "Fiscal Pro", `FiscalStoreTests`, `scripts/store-test.sh`, `subscription-sandbox.md`) e com a regra de monetização da skill `byescaleira-sdd`. O Fiscal é um app de transparência política: cobrar por dado público ou esconder parte dele atrás de um paywall tira a credibilidade e o alcance que o produto precisa. O usuário decidiu em 2026-10-25 que o app é gratuito, sem assinatura, Pro, paywall nem StoreKit ([contrato da 1.0](../changes/archive/2026-10-29-app-1.0/contract.md)), e em 2026-10-26 pôs o código público sob a PolyForm Noncommercial 1.0.0 (`LICENSE.md`, commit `45fd416`).

## Decisão

- O Fiscal é gratuito: sem assinatura, compra no app, paywall, anúncio ou StoreKit. Não existe `ProAccess`, `FeatureStore`, `.storekit`, `FiscalStoreTests` nem `scripts/store-test.sh`, e nenhum documento do repositório os pede.
- O código está sob a [PolyForm Noncommercial 1.0.0](../../LICENSE.md): leitura, estudo, modificação e uso pessoal, educativo, de pesquisa e por organizações sem fins lucrativos; uso comercial proibido.
- Os dados exibidos continuam com a licença de cada fonte oficial; as obras dos cartazes, com a licença de cada obra (`art-credits.json`).

## Consequências

- A página da loja, o site e as notas de revisão dizem "gratuito, sem assinatura e sem compras no app"; o contrato de apps gratuitos basta no App Store Connect.
- Roteiros de validação e o modelo de spec não têm passos de compra nem de sandbox.
- Cobrar por algo no futuro pede um ADR novo que substitua este, a volta do StoreKit e a revisão da licença.
- Contribuição externa entra sob a mesma licença; quem quiser uso comercial precisa de outra licença do autor.

## Alternativas consideradas

- **Assinatura Pro do template:** cobra por dado público e divide o público; descartada pelo usuário.
- **Licença aberta permissiva (MIT, Apache):** permitiria revender o app ou o servidor como produto; o usuário escolheu proibir o uso comercial.
