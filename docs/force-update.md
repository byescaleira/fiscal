# Atualização obrigatória e recomendada

O Fiscal lê do CloudKit público uma política de versões por plataforma e decide sozinho se está em dia, se recomenda atualizar ou se bloqueia. Quem edita a política é o admin (`admin/`); o app só lê. As decisões estão em [decisions.md](decisions.md) (histórico) e nos [ADRs](adr/README.md); o roteiro manual está em [validation.md](validation.md#atualização-obrigatória).

## Regra

Registro `AppRelease` por plataforma (`ios` vale para iPhone e iPad, `macos`, `visionos`) com versão mínima, build mínima, versão recomendada e build recomendada. O app compara com a própria `CFBundleShortVersionString` e `CFBundleVersion` (`InstalledApp`):

| `UpdateState` | Quando | O que acontece |
| --- | --- | --- |
| `required` | versão instalada < versão mínima **ou** build instalada < build mínima | tela de bloqueio no lugar do app inteiro |
| `recommended` | não está bloqueado, mas versão < recomendada **ou** build < recomendada | aviso dispensável, uma vez por versão recomendada (`1.2.0 (80)`) |
| `current` | o resto, inclusive sem registro para a plataforma | nada |

- Versões comparam por número, parte a parte (`AppVersion`: `1.10.0` > `1.9.2`, `1.0` = `1.0.0`). O app aceita de 1 a 3 partes; o admin exige `x.y.z`.
- Sem texto livre: título e mensagem são fixos e traduzidos no catálogo, nos 10 idiomas.
- O app nunca bloqueia se não consegue ler a própria versão e build, e trata recomendada abaixo da mínima como igual à mínima.

## Onde fica

| Target | Arquivo | O que faz |
| --- | --- | --- |
| `FiscalDomain` | `Update/` | `AppVersion` (comparação), `AppRelease` (política e `state(for:)`), `UpdateState`, `AppPlatform` (`ios`, `macos`, `visionos`, `current`), `InstalledApp` (versão e build do bundle), protocolo `AppReleaseSource`, `AppReleaseStore` e `AppReleaseCache` (arquivo de cache) |
| `FiscalData` | `Services/CloudKitAppReleaseSource.swift` | lê o registro do banco público do container `iCloud.fiscal` |
| `FeatureCore` | `Update/AppUpdateModel.swift` | estado efetivo, leituras, intervalo, aviso recomendado e simulação |
| `FeatureCore` | `Update/UpdateHoldModel.swift` | liga e desliga as conexões quando o bloqueio chega ou sai com o app aberto |
| `AppShell` | `Update/UpdateRequiredScreen.swift` | tela de bloqueio com **Update** e **Export Data** |

## Schema no CloudKit

Tipo `AppRelease` no **banco público** do container `iCloud.fiscal`, um registro por plataforma, com `recordName` igual à plataforma (`ios`, `macos`, `visionos`):

| Campo | Tipo | Exemplo |
| --- | --- | --- |
| `minimumVersion` | String | `1.0.0` |
| `minimumBuild` | Int(64) | `1` |
| `recommendedVersion` | String | `1.1.0` |
| `recommendedBuild` | Int(64) | `12` |

- O tipo é criado no **CloudKit Console** (banco público, ambiente Development), com `recordName` consultável e permissão de leitura para todos; o app não cria o tipo.
- **Deploy Schema Changes to Production é do usuário.** É irreversível; sem ele, TestFlight e App Store não enxergam o tipo e ficam em `current`.
- Os registros são gravados pelo admin (`admin/`), no ambiente certo: Development para builds instaladas pelo Xcode, Production para TestFlight e App Store.

## Leitura e cache

- O app busca o registro pelo `recordName` da plataforma (`CKDatabase.record(for:)`), sem consulta. Registro inexistente (`unknownItem`) significa "sem política". Registro com campos inválidos conta como falha de leitura.
- A última política lida fica em `app-release.json` no App Group `group.com.byescaleira` (pasta `fiscal`), para widgets e intents enxergarem. Sem App Group, cai na Application Support.
- **Sem rede, vale o cache.** Falha de leitura nunca apaga a política guardada, então o modo avião não escapa do bloqueio.
- Lê ao abrir e ao voltar para o primeiro plano, com intervalo mínimo de **15 minutos** entre leituras (**1 minuto** enquanto está bloqueado, para soltar logo depois de o admin baixar a mínima). Se a política guardada já bloqueia, a abertura espera a leitura antes de decidir.
- No simulador não há leitura do CloudKit (igual às flags); vale só a simulação.

## O que para no bloqueio

- **A interface:** `UpdateRequiredScreen` substitui o app inteiro (e a janela de Ajustes no Mac), entra e sai com fade (`.opacity`) e usa a animação de abertura em loop. O texto cita as versões ("Version 1.0 is no longer supported. Update to 1.1.0 or later. You can still export your data."); sem política no cache, fica o texto genérico.
- **Botões:** **Update** abre `https://apps.apple.com/app/id<FiscalAppStoreID>`, com o id lido do `Info.plist`; **Export Data** gera um `DataArchive` (`FeatureCore/Export`, todos os itens em JSON) pelo `DataExportModel` e abre o seletor de arquivos (`fileExporter`). Os dados nunca ficam presos. Na simulação aparece também **Stop Simulating**.
- **Siri, Atalhos e App Intents:** o atalho do template (`NewItemIntent`) só abre o app, que mostra o bloqueio. Intent que grava, quando existir, lê `AppReleaseStore.shared.blocks` e responde com erro pedindo a atualização, sem gravar nada.
- **Widgets:** só leem o último dado gravado; tocar abre o app, que mostra o bloqueio.

## Bloqueio com o app aberto

`UpdateHoldModel` liga e desliga as conexões conforme `isRequired`. A composição entrega a lista ao abrir o banco (`attach`) e chama `apply()` a cada mudança do estado; as transições rodam em fila e, se o estado vira de novo no meio, o model termina no estado atual.

| Conexão (exemplos) | Bloqueio chega | Bloqueio sai |
| --- | --- | --- |
| Servidor local (ex.: MCP no Mac) | para e descarta o model | recria se a flag e o ajuste estiverem ligados |
| Ponte com a web | desliga as sessões | religa com as sessões guardadas |
| Sincronização própria (ex.: `CKSyncEngine` de dados compartilhados) | para os motores guardando o estado | recria a partir do estado guardado |
| Sincronização do SwiftData | segue | segue como abriu |

- O template nasce sem conexões: a lista começa vazia e cada integração nova entra nela.
- Abertura bloqueada não liga nada; se o bloqueio sai depois, tudo liga como numa abertura normal.
- O SwiftData não desliga o CloudKit de um `ModelContainer` aberto, e trocar o container com o app aberto arrisca o histórico. Como no bloqueio nada grava na base, a sincronização segue até fechar o app.

## Desenvolvimento

- Build Debug nunca bloqueia: lê e mostra a política real, mas o estado efetivo é o simulado.
- Simulação pelo argumento de abertura `-fiscal.developer.update required` (ou `recommended`), lido pelo `AppUpdateModel` só quando ele não impõe a política (Debug). **Stop Simulating** grava o fim da simulação no cache; o argumento volta a simular na próxima abertura.
- Para ver o texto com versões, grave no cache uma política junto com a simulação, por exemplo `{"release":{"minimumVersion":"1.1.0","minimumBuild":1,"recommendedVersion":"1.2.0","recommendedBuild":1},"simulated":"required"}`.

## Como testar

1. **Testes:** `AppReleaseTests` (`FiscalDomainTests`: comparação de versões, regra dos três estados, cache), `AppReleaseRecordTests` (`FiscalDataTests`: leitura do registro) e, em `FeatureCoreTests`, `DataExportModelTests` (exportação e erros), `AppUpdateModelTests` (fontes falsas: bloqueio, cache offline, intervalo de 15 e 1 minuto, aviso uma vez por versão, simulação) e `UpdateHoldModelTests` (abertura livre e bloqueada, bloqueio e liberação com o app aberto, modo avião, estado que vira no meio da transição).
2. **Debug:** abrir com `-fiscal.developer.update required` e depois `recommended`; conferir a tela, o **Export Data** e o atalho "New Item" abrindo o app no bloqueio.
3. **Bloqueio real:** precisa de configuração Release. Instalada pelo Xcode (assinatura de desenvolvimento) ela lê o ambiente Development; TestFlight e App Store leem Production. No admin, no ambiente certo, gravar a mínima acima da build instalada; abrir o app e ver o bloqueio; ligar o modo avião e reabrir (continua bloqueado); remover a política e voltar ao primeiro plano depois de 1 minuto (solta). Repetir com só a recomendada acima para ver o aviso uma única vez.
