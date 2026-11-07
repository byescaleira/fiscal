# Ligar os conceitos como ícones alternativos

- **Data:** 2026-10-25
- **Branch:** `feature/app-1.0-icon`
- **Para:** o coordenador, que integra no projeto o que esta frente não pôde mexer (`project.pbxproj`, `Localizable.xcstrings`, `FeatureSettings`, testes)

## O que já está pronto nesta branch

- Quatro bundles do Icon Composer, ao lado do principal, na pasta sincronizada do alvo `Fiscal` (`PBXFileSystemSynchronizedRootGroup` "Fiscal", que entram no alvo sem tocar no pbxproj):
  - `Fiscal/Fiscal/FiscalIconLens.icon`
  - `Fiscal/Fiscal/FiscalIconIris.icon`
  - `Fiscal/Fiscal/FiscalIconBallot.icon`
  - `Fiscal/Fiscal/FiscalIconMonogram.icon`
- O `FiscalIcon.icon` (estrela do template) **não foi tocado**: a troca do principal é decisão do usuário.
- Prévias para dentro do app, geradas por `scripts/icons.sh`, em `FiscalKit/Sources/FiscalResource/Assets/Media.xcassets/AppIcon/FiscalIcon{Lens,Iris,Ballot,Monogram}.imageset` (claro e escuro).
- `FeatureCore/Icons/AppIcon.swift`: casos `lens`, `iris`, `ballot` e `monogram`. O `assetName` segue a regra do manual (`"FiscalIcon"` + caso com inicial maiúscula), o que dá exatamente os nomes das pastas `.icon`.
- `FeatureCore/Icons/AppIconSwitcher.swift`: `AppIconSwitching` (`supportsAlternateIcons`, `current`, `set(_:)`) e `SystemAppIconSwitcher` com `UIApplication.setAlternateIconName`, só no iOS e iPadOS. Em outras plataformas, responde `false`/`.standard` e não faz nada.

> **Nomes:** o pedido sugeria `FiscalIcon-Lens.icon`, mas o manual (`icons-and-imagery.md` §2.2 e o `AppIcon.assetName` do template) usa `<App>Icon<Caso>`, sem hífen. Segui o manual para o `assetName` continuar derivado do caso.

## 1. Build settings (alvo `Fiscal`, Debug `A1000000000000000000C003` e Release `A1000000000000000000C004`)

As duas configurações já têm:

```
ASSETCATALOG_COMPILER_APPICON_NAME = FiscalIcon;
ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES;
```

Pelo manual, `INCLUDE_ALL_APPICON_ASSETS = YES` basta para incluir todos os `.icon` da pasta como alternativos. A documentação da Apple para arquivos `.icon` ([Configuring your app to use alternate app icons](https://developer.apple.com/documentation/xcode/configuring-your-app-to-use-alternate-app-icons)) nomeia os alternativos explicitamente. Para não depender do comportamento do "include all" com arquivos do Icon Composer no Xcode 27 beta, **acrescente nas duas configurações**:

```
ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "FiscalIconLens FiscalIconIris FiscalIconBallot FiscalIconMonogram";
```

(No Xcode: alvo Fiscal › Build Settings › Asset Catalog Compiler - Options › Alternate App Icon Sets.) Mantenha `INCLUDE_ALL_APPICON_ASSETS = YES`. Não edite `CFBundleIcons` no `Info.plist`, porque o Xcode gera essas chaves.

**Conferir depois do build** (não verificado aqui, porque esta frente não podia rodar `xcodebuild`):

```bash
plutil -p "$FISCAL_BUILD_ROOT/Build/Products/Debug-iphoneos/Fiscal.app/Info.plist" | grep -A20 CFBundleAlternateIcons
```

A saída tem de listar as quatro chaves `FiscalIconLens`, `FiscalIconIris`, `FiscalIconBallot` e `FiscalIconMonogram`. O alvo também roda no visionOS (`TARGETED_DEVICE_FAMILY = "1,2,7"`), onde a troca fica desligada pelo `SystemAppIconSwitcher`.

## 2. Textos (`Fiscal/Fiscal/Localizable.xcstrings`, só pt-BR)

Depois do `scripts/build.sh Debug`, rode `scripts/strings.sh` e traduza as chaves novas:

| Chave | pt-BR |
|---|---|
| `Magnifier` | Lupa |
| `Watchful Eye` | Olhar |
| `Ballot Box` | Urna |
| `Checked Document` | Documento |

A chave `Lens` não foi usada de propósito: ela já existe como "Lente", o nome da feature.

## 3. Escolha do ícone em Ajustes (`FeatureSettings`)

Hoje `SettingsModel.appIcon` é uma constante (`public let appIcon = AppIcon.standard`). Para o usuário escolher no iPhone:

1. Em `SettingsModel`, troque a constante por estado, injetando o switcher:
   ```swift
   public private(set) var appIcon: AppIcon
   @ObservationIgnored private let iconSwitcher: any AppIconSwitching
   ```
   No `init`, receba `iconSwitcher: any AppIconSwitching = SystemAppIconSwitcher()` e faça `appIcon = iconSwitcher.current`. Acrescente:
   ```swift
   public var supportsAlternateIcons: Bool { iconSwitcher.supportsAlternateIcons }

   public func setAppIcon(_ icon: AppIcon) async {
       guard icon != appIcon else { return }
       do {
           try await iconSwitcher.set(icon)
           appIcon = icon
       } catch {
           appIcon = iconSwitcher.current
       }
   }
   ```
2. Em Aparência (`AppearanceScreen`), uma seção "Ícone" que só aparece com `supportsAlternateIcons`: grade com `AppIconImage(icon:size:)` de cada `AppIcon.allCases`, o `title` embaixo e um check no atual. O toque chama `setAppIcon`. Splash, Sobre e compartilhar já usam `settings.appIcon`, então passam a mostrar o escolhido.

## 4. Testes (`FiscalKit/Tests/FeatureCoreTests/AppIconTests.swift`, Swift Testing)

```swift
import FeatureCore
import Testing

struct AppIconTests {
    @Test func standardHasNoAlternateName() {
        #expect(AppIcon.standard.assetName == nil)
        #expect(AppIcon.standard.previewName == "FiscalIcon")
    }

    @Test(arguments: [
        (AppIcon.lens, "FiscalIconLens"), (.iris, "FiscalIconIris"),
        (.ballot, "FiscalIconBallot"), (.monogram, "FiscalIconMonogram"),
    ])
    func conceptsMatchIconFiles(icon: AppIcon, name: String) {
        #expect(icon.assetName == name)
        #expect(icon.previewName == name)
    }

    @Test func assetNameRoundTrips() {
        for icon in AppIcon.allCases {
            #expect(AppIcon(assetName: icon.assetName) == icon)
        }
        #expect(AppIcon(assetName: "Unknown") == .standard)
    }
}
```

Para o `SettingsModel`, um `AppIconSwitching` falso no teste do `FeatureSettings` cobre a troca bem-sucedida e o erro, que volta ao `current`.

## 5. Ordem sugerida

1. Build setting (passo 1), `scripts/build.sh Debug ios` e o `plutil` acima.
2. `scripts/strings.sh` e as traduções (passo 2).
3. Seção de ícone em Aparência (passo 3) e testes (passo 4).
4. Instalar no iPhone e deixar o usuário trocar entre os cinco na tela de início, nos modos claro, escuro e tingido, até o "agora sim". Depois disso, o escolhido vira o `FiscalIcon.icon` (copie a pasta por cima do principal e rode `scripts/icons.sh`), e a estrela sai.

## Exportar de novo as prévias

```bash
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
"$ictool" Fiscal/Fiscal/FiscalIconLens.icon --export-image --output-file Lens.png \
  --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
```

Renditions aceitas pelo `ictool` do Xcode 27 beta 6: `Default`, `Dark`, `TintedLight`, `TintedDark`, `ClearLight` e `ClearDark`. Para o tamanho de Ajustes, use `--width 58 --height 58`.
