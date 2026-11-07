# Revisão da FSC-024: curtir no Feed com a onda

- **Canvas:** [FSC-024](../prompt/FSC-024-202611061418-[Feat]-feed-like-with-ripple.md)
- **Escopo:** `8015eaa..476d0be` na `feature/like`, numa rodada única. A base é o fim da FSC-023, que ainda está no PR #18.
- **Revisores:**
  - canvas (`spec-reviewer`);
  - interface (`ui-reviewer`);
  - código (`code-reviewer`);
  - segurança (`security-reviewer`), porque o diff guarda dado da pessoa e muda o esquema.
- **Veredito da primeira leitura:**
  - canvas: Needs Rework, com 3 críticos, todos de texto e de sincronia;
  - painel (interface, código e segurança): aprovado, sem bloqueador.
- **Depois das correções** (`8f615ca`): a re-revisão do canvas deu Ready to Merge, com os três críticos resolvidos e nenhum novo.
- **Veredito final:** Ready to Merge.

| Severidade | Dimensão | Achado | Resolução |
| --- | --- | --- | --- |
| crítica | canvas | Operation 6 citava `init(likes:now:)`; o código tem `init(likes:)` | `spdd-prompt-update`: assinatura atualizada |
| crítica | canvas | Operation 11 pedia `ContentUnavailableView`; o código usa o `EmptyStateView` do kit | `spdd-prompt-update`: Approach 9 e Operation 11 |
| crítica | canvas | A lista vazia ganhou a linha "Só neste aparelho", fora do requisito 7 | `spdd-prompt-update`: requisito 7 inclui a linha, como na página do apoio |
| importante | canvas | Requisito 12 sem o teste prometido em `FeatureFeedTests` | `spdd-prompt-update`: a prova é estrutural (o `FeedModel` não recebe curtidas) |
| importante | canvas | VoiceOver não executado | `spdd-prompt-update`: leitura em voz no iPhone, com a validação da carta; o `Toggle` está no código |
| importante | canvas e código | A faixa e o háptico disparavam antes de gravar e com falha | Código: dispara só quando a curtida é gravada; requisito 13 diz "sem faixa, sem onda e sem toque háptico" |
| importante | canvas | Carga no `FollowSync` do `MainScreen`, fora de Structure | `spdd-sync` |
| importante | canvas | `FeedModel.symbol` passou a usar `FeedLikedText.symbol` | `spdd-sync` |
| deveria | interface | Coração vazio em `.secondary` sobre o destaque colorido | Código: branco com `.opacityStrong` no destaque |
| deveria | interface | "Descurtir" só por deslizar | Código: menu de contexto com a mesma ação |
| deveria | segurança | Curtidas sem `.privacySensitive()`, ao contrário das linhas do apoio | Código: linhas da lista e coração cheio |
| informativa | canvas | ADR 0027 "Proposto" no Approach | `spdd-sync`: "Aceito em 06/11/2026" |
| informativa | canvas | Entities sem `hasLoaded` e `destination(for:)` | `spdd-sync` |
| detalhe | código | `erase()` sem o `pending`; `liked` recalculado a cada chamada | Mantido: a tela de curtidas é o único chamador, e a lista é pequena |
| detalhe | interface | Rótulo "Curtir" sem o título do item; a linha do coração em AX3+ | Mantido; conferir no iPhone |
| detalhe | segurança | URL guardada aberta por `ExternalLink` sem conferir o esquema | Fora do escopo: é a mesma URL do cartão do Feed; a regra cabe no `ExternalLink` do kit |

**Pontos conferidos pelo revisor de canvas:** a apuração fora (Approach 13), as rotas do Feed na lista (Approach 9) e o coração branco no destaque batem com o código.

**Segurança:** nada sai do aparelho. A curtida fica no `Device.store`, fora do iCloud e do backup, e só vai na exportação pedida pela pessoa. O rótulo de privacidade não muda.

## Segunda rodada: ajustes depois do iPhone (`046aeee..51a21b6`)

- **Escopo:** coração no cabeçalho, curtir sem recarregar o Feed, saída da onda, confete de corações com o kit 0.12.0 nas cores do partido, e a recarga que mantém páginas e anos (Approach 14 a 18; ADR 0026, regra 7).
- **Painel (interface, código e segurança):** aprovado, sem bloqueador. O "deveria" sobre Reduzir movimento já é atendido no kit: o `likeBurst` usa `EffectMotion.isStill`. As sugestões de teste (paleta e fim da lista na recarga) entraram.
- **Canvas:** Needs Rework na primeira leitura, com 5 críticos de sincronia e de prova:
  - a dependência ainda citava a 0.11.0;
  - o QA ainda mostrava a faixa;
  - a paleta não tinha teste.

  Depois de `51a21b6`: **Ready to Merge**, com os cinco resolvidos.
- **Risco aberto:** o confete com Reduzir movimento, o confete clareado no destaque e o vermelho sem partido não foram vistos em tela, porque o simulador travou. Os testes da paleta e o código do kit cobrem a regra, e a validação visual está no backlog do iPhone.
- **Veredito final:** Ready to Merge.
