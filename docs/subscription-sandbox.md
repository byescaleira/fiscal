# Compras do Fiscal Pro: StoreKit local e sandbox

Duas camadas de validação das compras. A primeira roda sem rede, com o arquivo `Fiscal.storekit`, no simulador e no Xcode Cloud. A segunda usa o servidor de sandbox da Apple, a conta de testador e o aparelho, e pega o que o arquivo local não mostra: produtos e preços do App Store Connect, folhas da Apple, renovação real e restauração entre aparelhos. O roteiro geral de uma versão está em [validation.md](validation.md).

## StoreKit local

O scheme **Production** usa o `Fiscal/Fiscal/Fiscal.storekit` (moeda base BRL, vitrine `BRA`, grupo "Fiscal Pro" com `fiscal.pro.monthly` e `fiscal.pro.yearly`, 7 dias grátis como oferta introdutória). Rodando pelo Xcode no simulador, as compras são locais e o Transaction Manager do Xcode (Debug › StoreKit › Manage Transactions) permite aprovar, recusar, reembolsar e expirar.

Os testes de compras ficam no alvo `FiscalStoreTests`, hospedado no app, porque o `SKTestSession` não funciona nos testes do pacote (o processo `xctest` não é um app instalado e o StoreKit recusa a configuração). O scheme compartilhado `FiscalStoreTests` roda o test plan `StoreKit`, que aponta para o `Fiscal.storekit` e roda em série.

```sh
scripts/store-test.sh
scripts/store-test.sh -only-testing:FiscalStoreTests/<Suíte>/<teste>
FISCAL_TEST_DESTINATION="platform=iOS Simulator,id=<udid>" scripts/store-test.sh
```

- Padrão: iPhone 17 com iOS 27; outro destino com `FISCAL_TEST_DESTINATION` (simulador só pelo sim-monitor). Resultados em `~/Library/Developer/FiscalBuild/StoreTests/<data>.xcresult` (ou `FISCAL_BUILD_ROOT`).
- `FISCAL_STORE_ACTION=build-for-testing` só compila.
- O template nasce com `StoreKitFixture` (abre um `SKTestSession` novo com `resetToDefaultState`, `disableDialogs` e `clearTransactions`) e `CatalogTests` (os dois planos no mesmo grupo, anual no nível acima e 7 dias grátis). Quando o `FeatureStore` entrar, cada teste usa o cliente de StoreKit e o model da loja reais, com banco em memória.
- Cubra pelo menos: catálogo carregado com preço, período e teste grátis; teste grátis uma vez por grupo; renovação forçada (`forceRenewalOfSubscription`); desligar a renovação; reembolso; Ask to Buy pendente, aprovado e recusado; falha na compra; nova tentativa de cobrança e carência; restaurar num segundo model; troca de plano com `PurchaseOption.purchaseDate(_:)`, nunca com tempo acelerado.
- O StoreKit local não toca no sandbox nem no App Store Connect: divergência entre o `.storekit` e os produtos reais só aparece no sandbox. Mudou preço ou nome? Edite os dois no mesmo passo.

## Sandbox

O scheme **Sandbox** é igual ao Production, sem o `.storekit`: as compras vão para o servidor de sandbox da Apple. Builds do TestFlight também usam sempre o sandbox. Passe o roteiro a cada build candidata que mexa na loja, no catálogo ou nos produtos do App Store Connect.

### Antes de começar

1. Produtos criados no App Store Connect com os mesmos IDs do `Fiscal.storekit` (grupo "Fiscal Pro", `fiscal.pro.monthly`, `fiscal.pro.yearly`, 7 dias grátis), mesmo em "Prepare for Submission".
2. Conta de testador criada em App Store Connect › Users and Access › Sandbox, território Brasil, com um e-mail que não seja Apple ID real. A API não cria testadores; `scripts/sandbox-tester.py` gerencia os que já existem (abaixo).
3. No iPhone: Ajustes › Desenvolvedor › Conta Apple de Sandbox › entrar com o testador. A conta de produção continua logada para o resto.
4. Instalar pelo Xcode com o scheme **Sandbox** (aparelho assinado) ou pelo TestFlight.
5. Para começar do zero: `scripts/sandbox-tester.py clear <email>`, apagar o app e reinstalar.

### Durações no sandbox

O tempo é acelerado. Com a taxa padrão:

| Duração real | No sandbox |
| --- | --- |
| 3 dias | 2 minutos |
| 1 semana (teste grátis) | 3 minutos |
| 1 mês | 5 minutos |
| 2 meses | 10 minutos |
| 3 meses | 15 minutos |
| 6 meses | 30 minutos |
| 1 ano | 1 hora |

- A taxa pode ser trocada por testador (o mês passa a durar o tempo escolhido e o ano, proporcionalmente mais): 1 hora, 30, 15, 5 ou 3 minutos, em Ajustes › Desenvolvedor › Conta Apple de Sandbox › Gerenciar ou com `scripts/sandbox-tester.py renewal`.
- Uma assinatura renova no máximo 12 vezes no sandbox e depois para sozinha.
- Sem a conta de sandbox, o TestFlight renova uma vez por dia, até 6 vezes, e não simula falha de cobrança.

### Roteiro

Anote em cada cenário o estado no paywall e no cartão do Fiscal Pro em Ajustes.

| # | Cenário | Como | Esperado |
| --- | --- | --- | --- |
| 1 | Assinar com teste grátis | Paywall › Anual › Assinar | Folha da Apple mostra 1 semana grátis; Ajustes mostra "Free Trial" com a data de término |
| 2 | Teste grátis só uma vez | Com o histórico do cenário 1, abrir o paywall | Os dois planos sem o selo de teste grátis (mesmo grupo) |
| 3 | Renovar | Taxa 5 min; esperar o fim do teste e duas renovações | "Active" com a nova data a cada renovação, sem ação da pessoa |
| 4 | Desligar a renovação | Ajustes › Fiscal Pro › Gerenciar › Cancelar | Pro continua até a data; depois "Expired" e o paywall volta |
| 5 | Upgrade Mensal → Anual | Assinar o Mensal, esperar virar pago, assinar o Anual | Troca imediata, sem cobrança dupla, acesso sem interrupção |
| 6 | Downgrade Anual → Mensal | Assinar o Anual, depois o Mensal | Anual segue até o fim do período; o Mensal começa na renovação |
| 7 | Falha de cobrança | Gerenciar › desligar "Permitir compras e renovações" e esperar a renovação | Sem carência, o Pro cai; com carência ligada só para o sandbox no App Store Connect, continua durante a carência. Religar: volta |
| 8 | Compra interrompida | `scripts/sandbox-tester.py interrupt <email> on`; assinar | Folha pede ação extra; depois de concluir, a compra chega por `Transaction.updates` e libera sem tocar de novo. Voltar com `off` |
| 9 | Restaurar | Segundo aparelho com o mesmo testador, app recém-instalado, Ajustes › Restaurar compras | Pro e não consumíveis voltam; consumíveis não |
| 10 | Ask to Buy | Testador filho num grupo familiar de sandbox | Compra fica pendente e libera quando aprovada |

Ao terminar: `renewal <email> 1h`, `interrupt <email> off` e `clear <email>`, para deixar a conta limpa para a próxima rodada.

## `scripts/sandbox-tester.py`

Gerencia os testadores de sandbox pela API do App Store Connect, com uma chave de API (função Admin ou App Manager). A chave nunca vai para o repositório: só variáveis de ambiente. O token JWT (ES256, 15 minutos) é assinado com o `openssl` do sistema; não há dependências.

```sh
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=00000000-0000-0000-0000-000000000000
export ASC_KEY_PATH=~/.appstoreconnect/AuthKey_XXXXXXXXXX.p8

scripts/sandbox-tester.py list
scripts/sandbox-tester.py clear tester@example.com
scripts/sandbox-tester.py renewal tester@example.com 5m
scripts/sandbox-tester.py interrupt tester@example.com on
scripts/sandbox-tester.py --dry-run clear tester@example.com
```

O testador pode ser o ID ou o e-mail da conta; `clear` aceita vários. `--dry-run` só imprime as requisições, sem chave e sem rede.

| Comando | Requisição |
| --- | --- |
| `list` | `GET /v2/sandboxTesters` (até 200 por página, segue `links.next`); imprime id, e-mail, território, taxa e compras interrompidas |
| `clear <testador>...` | `POST /v2/sandboxTestersClearPurchaseHistoryRequest` com `relationships.sandboxTesters` |
| `renewal <testador> <taxa>` | `PATCH /v2/sandboxTesters/{id}` com `subscriptionRenewalRate`: `1h`, `30m`, `15m`, `5m`, `3m` (ou o valor `MONTHLY_RENEWAL_EVERY_...` da API) |
| `interrupt <testador> on\|off` | `PATCH /v2/sandboxTesters/{id}` com `interruptPurchases` |
