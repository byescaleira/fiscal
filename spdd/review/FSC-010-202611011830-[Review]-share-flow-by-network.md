# Revisão da FSC-010: compartilhar como fluxo completo

- **Canvas:** [FSC-010](../prompt/FSC-010-202610312345-[Feat]-share-flow-by-network.md)
- **Análise:** [FSC-010](../analysis/FSC-010-202610312330-[Analysis]-share-flow.md)
- **Intervalo:** `75fb94a..3e97fb4` (23 commits, 75 arquivos)
- **Veredito:** **Needs Attention** (0 críticos, 3 importantes, 4 informativos)

## Resumo por seção

| Seção | Estado | Achados |
| --- | --- | --- |
| Requirements | ok, com a prova da QA em `docs/evidence/FSC-010/qa.md` | 1 |
| Entities | desvio leve | 1 |
| Approach | desvio leve | 2 |
| Structure | desvio | 1 |
| Operations | ok | 0 |
| Norms | ok | 0 |
| Safeguards | ok (300 s, 280 caracteres, 24 Mbps, zona 90/224/22, App ID vazio, sem SDK, sem logos) | 0 |
| Sincronia | ok (todos os commits trazem `Canvas:`) | 1 |
| Alucinação | ok (`UIPasteboard.setItems(_:options:)`, `requestAuthorization(for: .addOnly)` e as chaves `sharedSticker` existem) | 0 |

## Achados

| Severidade | Onde | Achado | Próximo passo |
| --- | --- | --- | --- |
| importante | `Fiscal/Fiscal/Info.plist:42-47` | Acréscimo: `instagram`, `snssdk1233` e `whatsapp` em `LSApplicationQueriesSchemes`, sem uso no código nem previsão no canvas | Corrigir o código |
| importante | Approach, Vídeo; `ShareVideoRenderer.swift:14` | Divergência: o canvas diz que a geração roda fora da main thread, mas o renderer é `@MainActor` com `Task.yield` em lotes | `spdd-sync` |
| importante | Structure | Faltam `ShareMetaApp.swift`, `SharePostSheet.swift`, `MineModel+ShareInvite.swift`, `ShareStyleTokens.swift`, `ShareArtwork.swift`, `ShareInvestigation.swift`, `ShareVictory.swift`, `ShareFormat.swift` e os casos de `FiscalEvents.swift`; `ShareMetaApp` falta em Entities | `spdd-sync` |
| informativa | Entities (Mermaid) | `ShareDelivery.send` e `ShareVideoRenderer.render` têm outra assinatura no código | `spdd-sync` |
| informativa | Structure | ADR 0020 aparece como Proposto, mas está Aceito | `spdd-sync` |
| informativa | `Localizable.xcstrings` | Aviso do TikTok para imagem não descrito no canvas | `spdd-sync` |
| informativa | `ShareVideoTests.writesAFourSecondLoop` | O nome diz 4 s, e o vídeo agora tem 5 s | Renomear o teste e o canvas |

## Desvio de intenção

- **Acréscimo:** os três esquemas extras do `Info.plist` e o aviso do TikTok para imagem.
- **Omissão:** nenhuma.
- **Divergência:** só a redação sobre a thread do vídeo.

## Decisões implícitas da IA

- Declarar `snssdk1233`, `instagram` e `whatsapp` em `LSApplicationQueriesSchemes`.
- Instagram sem `appID` na pasteboard, só com `source_application` na URL, enquanto o Facebook leva o `appID`.
- Dois quadros-chave por segundo e perfil High com CABAC no vídeo, sem efeito de comportamento.

## Fora do escopo

Nada feito além do canvas: sem SDK, GIF, logos, contagem ou rastreio. A AASA e o App ID da Meta seguem com o usuário.

## Portão de merge

Sem crítica e sem Needs Rework, logo sem bloqueador. Os três importantes são "deveria" e entram na mesma fase.

## Correções aplicadas na fase

- **Canvas:** os esquemas, a thread do vídeo, Structure, Entities, o ADR 0020 e o aviso do TikTok foram sincronizados, e o teste do vídeo renomeado.
- **Código:** o `Info.plist` mantém só `instagram-stories`, `facebook-stories` e `tiktok`.
- **Painel de interface, código e segurança (sem bloqueador):** sair da tela cancela o vídeo e nada é entregue depois; fechar a folha apaga o arquivo; alvos de 44 pt; `@ReducesMotion` no estúdio; avisos ao VoiceOver; layout de uma coluna com fonte de acessibilidade; pasteboard só neste aparelho; link do site com caminho no valor cai em Hoje.
- **Ficou como detalhe:** a pasta vazia do vídeo cancelado em `tmp`, que o sistema limpa.
