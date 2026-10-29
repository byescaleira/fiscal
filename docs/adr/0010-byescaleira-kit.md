# 0010. Design, componentes e idioma vêm do byescaleira-kit

- **Estado:** Aceito
- **Data:** 2026-10-29
- **Mudança:** [`kit-adoption`](../changes/kit-adoption/proposal.md)

## Contexto

O `FiscalDesignSystem` e parte do `FeatureCore` eram cópias do template do byescaleira-workspace, e cada app divergiu na sua cópia. O `byescaleira-kit` (pacote Swift `byescaleira`, repositório privado `byescaleira/byescaleira-kit`) passou a ser a referência em código das diretrizes de design, plataforma e acessibilidade de todos os apps.

## Decisão

- O `FiscalKit` depende do kit por versão (até sair a `v0.5.1`, pelo commit do [PR #11](https://github.com/byescaleira/byescaleira-kit/pull/11), que não vai à `main` nem ao TestFlight): `ByescaleiraDesign`, `ByescaleiraCharts`, `ByescaleiraAccessibility` e `ByescaleiraPlatform` reexportados pelo `FiscalDesignSystem`; `ByescaleiraUI` pelo `FeatureCore`; `ByescaleiraFoundation` pelo `FiscalDomain`.
- No Fiscal fica só o que é do Fiscal: partidos, placar, retratos, Lente, cartões de compartilhar e os tokens deles. Peça genérica nova ou correção numa peça do kit vai para o kit, num PR de lá, e não numa cópia aqui.
- O idioma é fixado em pt-BR por `FiscalLanguage.install()` no início do app e dos widgets ([ADR 0003](0003-portuguese-only.md)), porque o `AppLanguage.system` do kit segue o idioma do aparelho.
- O kit continua privado (decisão do usuário em 2026-10-29). Os scripts carregam `scripts/kit-access.sh`, que passa a conta `byescaleira` do `gh` só no ambiente do comando e usa `-scmProvider system` no `xcodebuild`.
- Mínimo 26 em iOS, iPadOS, macOS e visionOS, com o que é do 27 atrás de `#available` e uma alternativa no 26.

## Consequências

- Correções de componente chegam ao Fiscal numa versão nova do kit, sem copiar código.
- Quem clonar o Fiscal (público) sem acesso ao kit não compila; o Xcode Cloud precisa de acesso ao repositório do kit.
- Atualizar o kit é trocar a versão no `FiscalKit/Package.swift`, resolver (`xcodebuild -resolvePackageDependencies`) e passar a verificação completa.
- Os testes das peças que foram para o kit saem do Fiscal e passam a valer lá.

## Alternativas consideradas

- **Manter as cópias:** é o que fez os apps divergirem.
- **Kit público:** o usuário preferiu manter privado.
- **Kit copiado como subpasta:** compila em qualquer lugar, mas volta a divergir.
