# Fiscal no byescaleira-kit

- **Estado:** entregue
- **Data:** 2026-10-29
- **Branch:** `feature/kit-adoption`

## Por quê

O design system do Fiscal é uma cópia do template do workspace, e cada app divergiu na sua cópia. O `byescaleira-kit` (pacote Swift privado `byescaleira`, v0.5.0) passou a ser a referência em código das diretrizes. Pedido do usuário em 2026-10-29: "enquadrar o app à nova versão do byescaleira-workspace (tem um spm nele)". O próprio brief do kit prevê a migração do Fiscal num PR próprio.

Das 74 peças do `FiscalDesignSystem`, 47 existem no kit com o mesmo nome. Nenhuma está igual: o kit é a versão mais nova, com contraste testado, modo econômico (`LiteMode`), leitura no VoiceOver e as cinco plataformas. Do `FeatureCore`, 16 peças (guias, estado vazio, seletores de cor e mês, editor, alerta de erro, `ModelHost`) existem no `ByescaleiraUI`.

## O que muda

- O `FiscalKit` passa a depender do kit; as cópias saem do Fiscal e o que é só do Fiscal (partidos, placar, retratos, Lente, cartões de compartilhar) fica no app.
- Cores retrô mais escuras no claro (laranja `#AF5626`, mostarda `#906716`, oliva `#5C762D`), para passar 4,5:1 como texto.
- Fichas, botões de destaque e superfícies escolhem o texto pelo contraste e ficam opacos com Reduzir transparência ou no modo econômico.
- Barras de progresso podem ser lidas pelo VoiceOver; gráficos viram lista em tamanhos de acessibilidade.
- O app passa a rodar a partir do iOS, iPadOS, macOS e visionOS 26, com o que é do 27 atrás de `#available`.
- Versão no formato SemVer de três números (`1.0.0`) e `CHANGELOG.md`.

## Fora do escopo

- Redesenhar telas com as receitas de tela do kit (`CardGrid`, `StageDetail` e afins): fica para uma mudança de design por tela.
- Apple TV e Apple Watch: o Fiscal não tem esses alvos.
- Analytics e segurança do kit (fases 6 e 7, ainda não publicadas).

## Specs afetadas

### `docs/specs/`

- **Alterado:** nenhuma regra de produto muda. O design system passa a ser descrito pelo kit; `docs/design-system.md` aponta para ele e lista só o que é do Fiscal.

## Impacto

- **Targets:** `FiscalDesignSystem`, `FeatureCore`, todas as features (imports), widgets, app, testes.
- **Dados:** nenhum.
- **Textos:** os textos das peças do kit vêm do catálogo dele; os do Fiscal continuam só em pt-BR.
- **Repositório:** o kit é privado e o Fiscal é público (decisão do usuário em 2026-10-29: o kit continua privado). Quem clonar o Fiscal sem acesso ao kit não compila; o Xcode Cloud precisa de acesso ao repositório do kit.

## Decisões pendentes

1. Tag `v0.5.1` do kit com a correção do `FlowLayout` vinda do Fiscal ([byescaleira-kit#11](https://github.com/byescaleira/byescaleira-kit/pull/11)). Até lá, o Fiscal aponta para o commit do PR.

## O que fica com você

- Merge do PR #11 do kit, a versão `v0.5.1` e a troca do commit pela versão no `FiscalKit/Package.swift`.
- No App Store Connect › Xcode Cloud, liberar o acesso ao repositório `byescaleira/byescaleira-kit`.
