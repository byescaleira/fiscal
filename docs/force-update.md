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
- Sem texto livre: título e mensagem são fixos, com a tradução pt-BR no catálogo ([ADR 0003](adr/0003-portuguese-only.md)).
- O app nunca bloqueia se não consegue ler a própria versão e build, e trata recomendada abaixo da mínima como igual à mínima.

## Onde fica

| Target | Arquivo | O que faz |
| --- | --- | --- |
| `FiscalDomain` | `Update/` | `AppVersion` (comparação), `AppRelease` (política e `state(for:)`), `UpdateState`, `AppPlatform` (`ios`, `macos`, `visionos`, `current`), `InstalledApp` (versão e build do bundle), protocolo `AppReleaseSource`, `AppReleaseStore` e `AppReleaseCache` (arquivo de cache) |
| `FiscalData` | `Services/CloudKitAppReleaseSource.swift` | lê o registro do banco público do container `iCloud.fiscal` |
| `FeatureCore` | `Update/AppUpdateModel.swift` | estado efetivo, leituras, intervalo, aviso recomendado e simulação |
| `FeatureCore` | `Update/UpdateHoldModel.swift` | liga e desliga as conexões quando o bloqueio chega ou sai com o app aberto |
| `AppShell` | `Update/UpdateRequiredScreen.swift` | tela de bloqueio com **Atualizar** e **Exportar dados** |

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

- **A interface:** `UpdateRequiredScreen` substitui o app inteiro (e a janela de Ajustes no Mac), entra e sai com fade (`.opacity`) e usa a animação de abertura em loop. O título é "Atualize o Fiscal"; o texto cita as versões ("A versão 1.0.0 não tem mais suporte. Atualize para a 1.1.0 ou mais nova. Você ainda pode exportar seus dados."); sem política no cache, fica "Esta versão não tem mais suporte. Atualize para continuar usando o Fiscal. Seus dados continuam no aparelho e você pode exportá-los agora."
- **Botões:** **Atualizar** abre `https://apps.apple.com/app/id<FiscalAppStoreID>`, com o id lido do `Info.plist` (`6826982117`); **Exportar dados** gera um `DataArchive` (`FeatureCore/Export`: a Lente e os seguidos, em JSON) pelo `DataExportModel` e abre o seletor de arquivos (`fileExporter`). Os dados nunca ficam presos. Na simulação aparece também **Parar simulação**.
- **Siri, Atalhos e App Intents:** os três atalhos ("Como meu deputado votou", "Abrir o perfil de…", "Ver a apuração") rodam em primeiro plano e abrem o app, que mostra o bloqueio. O "Como meu deputado votou" ainda responde com a última votação antes de abrir: a recusa no bloqueio entra na mudança `align-workspace` (etapa A.12). Nenhum intent grava dado.
- **Widgets:** só leem o último dado gravado; tocar abre o app, que mostra o bloqueio.

## Bloqueio com o app aberto

`UpdateHoldModel` liga e desliga conexões conforme `isRequired`: recebe a lista ao abrir o banco (`attach`) e chama `apply()` a cada mudança do estado; as transições rodam em fila e, se o estado vira de novo no meio, o model termina no estado atual.

- Hoje a composição ainda não entrega nenhuma conexão: o destaque na tela de bloqueio, as Atividades ao Vivo da apuração e a atualização do pacote offline em segundo plano continuam rodando com o app bloqueado. Ligá-las ao `UpdateHoldModel` é a etapa A.12 da mudança `align-workspace`.
- Abertura bloqueada não liga nada; se o bloqueio sai depois, tudo liga como numa abertura normal.
- A sincronização do SwiftData segue até fechar o app: ela não desliga o CloudKit de um `ModelContainer` aberto, e no bloqueio nada grava na base.

## Desenvolvimento

- Build Debug nunca bloqueia: lê e mostra a política real, mas o estado efetivo é o simulado.
- Simulação pelo argumento de abertura `-fiscal.developer.update required` (ou `recommended`), lido pelo `AppUpdateModel` só quando ele não impõe a política (Debug). **Stop Simulating** grava o fim da simulação no cache; o argumento volta a simular na próxima abertura.
- Para ver o texto com versões, grave no cache uma política junto com a simulação, por exemplo `{"release":{"minimumVersion":"1.1.0","minimumBuild":1,"recommendedVersion":"1.2.0","recommendedBuild":1},"simulated":"required"}`.

## Como testar

1. **Testes:** `AppReleaseTests` (`FiscalDomainTests`: comparação de versões, regra dos três estados, cache), `AppReleaseRecordTests` (`FiscalDataTests`: leitura do registro) e, em `FeatureCoreTests`, `DataExportModelTests` (exportação e erros), `AppUpdateModelTests` (fontes falsas: bloqueio, cache offline, intervalo de 15 e 1 minuto, aviso uma vez por versão, simulação) e `UpdateHoldModelTests` (abertura livre e bloqueada, bloqueio e liberação com o app aberto, modo avião, estado que vira no meio da transição).
2. **Debug:** abrir com `-fiscal.developer.update required` e depois `recommended`; conferir a tela, o **Exportar dados** e o atalho "Ver a apuração" abrindo o app no bloqueio.
3. **Bloqueio real:** precisa de configuração Release. Instalada pelo Xcode (assinatura de desenvolvimento) ela lê o ambiente Development; TestFlight e App Store leem Production. No admin, no ambiente certo, gravar a mínima acima da build instalada; abrir o app e ver o bloqueio; ligar o modo avião e reabrir (continua bloqueado); remover a política e voltar ao primeiro plano depois de 1 minuto (solta). Repetir com só a recomendada acima para ver o aviso uma única vez.
