# Revisão da FSC-025, etapa A, contra o canvas

- **Canvas:** [FSC-025](../prompt/FSC-025-202611081040-[Feat]-site-and-universal-links-on-cloudflare-pages.md)
- **Análise:** [FSC-025](../analysis/FSC-025-202611081015-[Analysis]-site-and-universal-links-on-cloudflare-pages.md)
- **Intervalo:** `origin/development..dc2ec61`; a nova revisão cobriu `dc2ec61..ef041ac`.
- **Data:** 08/11/2026.
- **Revisor:** `byescaleira-workspace:spec-reviewer`, por leitura, sem rodar build nem testes.
- **Escopo:** só a etapa A (cenários 1 a 9 e 15). A etapa B vem depois do deploy da FSC-020.

## Veredito: Ready to Merge, depois da correção

A primeira rodada deu Needs Rework, com 1 crítico. A nova revisão sobre `ef041ac` confirmou a correção e não achou crítico novo.

| Seção | Estado na primeira rodada | Achados |
| --- | --- | --- |
| Requirements | desvio | 2 |
| Entities | ok | 0 |
| Approach | ok | 0 |
| Structure | desvio | 1 |
| Operations | ok | 0 |
| Norms | ok | 0 |
| Safeguards | desvio | 1 |
| Sincronia | ok | 0 |

## Achados

| Severidade | Arquivo | Achado | Próximo passo | Situação |
| --- | --- | --- | --- | --- |
| crítica | `scripts/site-publish.sh:6` | **Acréscimo.** `FISCAL_SITE_BRANCH` trocava a branch esperada, inclusive no `--apply`. Isso permitia publicar de uma `feature/*`, contra o cenário 7 e o Safeguard de publicação | Corrigir o código | Resolvido em `ef041ac` |
| importante | `scripts/site-build.mjs`, `scripts/site-build.test.mjs` | **Divergência.** O cenário 2 dizia que a regra do arquivo da Apple tinha `Cache-Control`; ele vem da regra `/*` | `spdd-prompt-update` e um teste de regras sem cabeçalho repetido | Resolvido em `ef041ac` |
| importante | `docs/server-runbook.md` | **Omissão.** A Structure e a operação 4 citavam a seção 7 do runbook, que fala das rotas `/api/*` e é da FSC-020 | `spdd-prompt-update` | Resolvido em `ef041ac` |
| informativa | `spdd/README.md` | A FSC-025 fica "em andamento" até a etapa B | Nenhum | — |

## Definição de pronto (etapa A)

| Cenários | Situação |
| --- | --- |
| 1 a 4 | Teste (`scripts/site-build.test.mjs`) |
| 5 | `site-i18n.py check` |
| 6 e 7 | Roteiro manual no QA. O caminho sem erro na `development` fica para a operação 5 |
| 8 | Conferido na leitura; o `--apply` só roda com o ok |
| 9 | `verify.sh` |
| 15 | Documentos |

## Decisões implícitas da IA

- A checagem de árvore suja não inclui o arquivo de teste. Isso é coerente com o canvas.
- O `wrangler whoami` roda com a saída descartada.

## Saída de escopo

- Nenhuma.
