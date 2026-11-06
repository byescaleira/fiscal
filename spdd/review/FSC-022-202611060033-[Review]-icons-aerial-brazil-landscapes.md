# Revisão FSC-022: ícones com paisagens do Brasil vistas de cima

- **Canvas:** [FSC-022](../prompt/FSC-022-202611051909-[Feat]-icons-aerial-brazil-landscapes.md)
- **Escopo:** `658dea0..7df4fbd` (commits `beedd96` e `7df4fbd`)
- **Revisor:** `spec-reviewer`, uma rodada

**Veredito:** Needs Attention (0 críticos, 1 importante, 4 informativos)

## Tabela-resumo

| Seção | Estado | Achados |
| --- | --- | --- |
| Requirements | ok, com prova parcial | 1 |
| Entities | ok | 0 |
| Approach | ok | 0 |
| Structure | ok | 0 |
| Operations | ok; a 9 estava em curso | 0 |
| Norms | ok | 0 |
| Safeguards | ok | 1 |
| Desvio de intenção | nenhum | 0 |
| Sincronia | ok | 1 |

## Achados

| Severidade | Arquivo | Achado | Próximo passo |
| --- | --- | --- | --- |
| importante | `docs/evidence/FSC-022/qa.md` | **Sincronia.** A linha "iPhone físico" diz "pendente", mas o usuário aprovou os 11 ícones no iPhone em 06/11/2026. A evidência que fecha a operação 8 não estava registrada. | Corrigir o doc: registrar a aprovação no `qa.md`. A linha de `spdd/README.md` passa a "entregue" no merge. |
| informativa | `docs/evidence/FSC-022/qa.md` | A prova de 60 pt dos 8 ícones novos é a prévia de Ajustes. O modo clear ficou como "não executável aqui". | Registrar no `qa.md` o que a aprovação no iPhone cobre. |
| informativa | `scripts/landscape-icons.py` (`validate`) | O Safeguard "no máximo 6 formas e nenhuma camada abaixo de 24 px" só tem prova visual. O validador confere grupos, camadas (limite de 10, mais estrito que o de 12 do canvas) e cores, como pede a Approach 3. | Nenhum. |
| informativa | `FiscalIconAmazonDay.icon` e `FiscalIconAmazonRiver.icon`, `9 Map.svg` e `9b Rim.svg` | Os arquivos mudaram em relação à base porque agora são idênticos aos do principal, que não mudou. Isso cumpre o Safeguard "Marca do Fiscal". | Nenhum. |
| informativa | `beedd96` | O commit cria o canvas e também traz `Canvas-update: prompt-update`. | Nenhum. |

## Definição de pronto

| Cenário | Prova |
| --- | --- |
| Principal: Amazônia ao amanhecer vista de cima | `round1-settings.png`, `round2.png` e a aprovação no iPhone |
| Ordem de "Ícone do app" | `round2-settings.png` |
| Ordem e cores dos temas | `round2-settings.png`, `round2-themes.png` e as 9 chaves pt-BR do catálogo |
| `themeSand` continua `FiscalIconThemeSand` | `AppIconTests.landscapeIconsKeepTheirSavedNamesInOrder` e `assetNameRoundTrips` |
| Escuro e tinted | `round2.png` |
| Clear | só no iPhone |
| 60 pt | o principal na rodada 1; os outros 8 pela prévia de Ajustes e pela aprovação no iPhone |
| Gerador determinístico e paisagem inválida | `qa.md`; `main()` sai com 1 antes de escrever |
| Rodada 1 antes dos outros 8 | `beedd96` antes de `7df4fbd` |

## Desvio de intenção

- **Acréscimo não autorizado:** nenhum.
- **Omissão:** nenhuma no código. A evidência da operação 8 foi corrigida no `qa.md`.
- **Divergência:** nenhuma.

## Decisões implícitas da IA

- O validador limita a paisagem a 10 camadas, mais estrito que as 12 do canvas, sem risco.
- O catálogo de textos removeu as 9 chaves antigas que o `scripts/strings.sh` deixa como `stale`, como pede a seção Structure.

## Saída de escopo

- Nenhuma. Fauna, partido, `pbxproj` e `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` ficaram fora do diff.

## Portão de merge

- Sem bloqueador.
- O item importante foi corrigido no mesmo commit da revisão.
