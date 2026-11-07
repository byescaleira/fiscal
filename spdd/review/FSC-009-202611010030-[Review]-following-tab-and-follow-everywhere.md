# Revisão da FSC-009: aba Seguindo e seguir em todo lugar

Canvas: [FSC-009](../prompt/FSC-009-202610312200-[Feat]-following-tab-and-follow-everywhere.md). Primeira rodada sobre `44a2f84..df6bb74` (65 arquivos); correções em `dee4a92` e sync do canvas em `a3cbdbd`.

## Resumo

| Revisor | Primeira rodada | Re-revisão (`df6bb74..a3cbdbd`) |
| --- | --- | --- |
| spec (`spdd-code-review`) | Needs Rework: 4 críticos, 6 importantes | Ready to Merge, 0 críticos |
| design | Reprovado: 1 bloqueador (selo "Novo" feito à mão), 5 deveria | Aprovado (selo pelo `Chip`), auditoria ok com 61 arquivos |
| código | Reprovado: 2 bloqueadores (teste da regra do arquivo vazio, CHANGELOG), 5 deveria | Aprovado |
| acessibilidade | Aprovado: 7 deveria | Os deveria entraram em `dee4a92` |
| segurança | Aprovado: 2 deveria (autenticação dos intents, App Group compartilhado no ADR 0018) | Os dois entraram em `dee4a92` |

## Críticos e bloqueadores, e como foram resolvidos

- **Tabela de representantes do Mac:** ganhou Seguir e Deixar de seguir no menu de contexto (`MineRoster.card(for:)`).
- **Fonte em cada novidade:** a Casa (Câmara ou Senado) vem do cargo no voto e nos gastos, e a checagem traz o veículo.
- **Falha de leitura:** o canvas passou a descrever a linha agregada ("Não deu para carregar A e B"). O teste `aMissingFileIsEmptyAndOnlyFailuresAreMissing` prova que o arquivo inexistente é vazio e que uma falha não esconde as outras.
- **Sincronia do canvas:** Entities, Structure e Approach foram alinhados ao código (`Canvas-update: sync`).
- **Selo "Novo":** passou para o `Chip` do design system.
- **CHANGELOG:** o `Unreleased` descreve a fase, e "Meus" virou Seguindo.

## Achados descartados na conferência

- **Spec, importante 1:** dizia que seguir pela linha não atualiza as outras telas. A gravação no SwiftData publica no `FiscalChangeHub`, que recarrega a sessão (`SessionModel.generation`). A QA confirmou: a pessoa passou para "Quem você segue" logo depois do toque.

## Ficou como detalhe

- O ícone de seguindo continua `person.fill.checkmark`, porque `person.badge.checkmark` só existe a partir do 27.
- A formatação de data do widget ainda está na view (`FollowingWidgetViews`).
- O háptico também dispara quando o estado muda por fora.
- A novidade compara a data do fato, e um dado publicado com atraso não ganha o selo.
- Não há teste da leitura vazia que invalida outra em andamento; quem cobre é o próprio `settle`.
