# 0020. Compartilhar nas redes sem SDK de terceiros

- **Estado:** Aceito (2026-11-01)
- **Data:** 2026-10-31
- **Mudança:** [`FSC-010`](../../spdd/prompt/FSC-010-202610312345-[Feat]-share-flow-by-network.md)

## Contexto

O usuário quer que o compartilhar leve o cartaz pronto ao Instagram, ao TikTok, ao Facebook e ao WhatsApp, com vídeo. O que as redes oferecem (pesquisa [2026-10-31-social-sharing](../research/2026-10-31-social-sharing.md)):
- **Instagram e Facebook Stories:** abrem pelo app com as chaves de pasteboard, mas exigem um App ID da Meta publicado.
- **TikTok:** pede o Share Kit, com app registrado, `client_key` e acesso às Fotos.
- **WhatsApp:** não tem API oficial atual para mídia.

O Fiscal promete não coletar nada da pessoa (ADR 0017) e evitar dependências.

## Decisão

- **Instagram e Facebook Stories:** abra pelas chaves de pasteboard (`instagram-stories://share`, `facebook-stories://share`), com o App ID da Meta no `Info.plist` (`FiscalMetaAppID`) e a pasteboard expirando em 300 s. Nunca adicione o SDK da Meta.
- **TikTok:** salve no Fotos, com permissão só de adicionar, e abra o app. O Share Kit só entra com um ADR novo, depois que o app estiver registrado no TikTok for Developers.
- **Feed, WhatsApp e o resto:** use a folha do sistema com o arquivo e a legenda.
- **Identidade das redes:** identifique cada rede pelo nome escrito e por um símbolo SF genérico. Nunca use logo de terceiros.
- **Formato:** o cartaz animado é MP4 H.264. Nunca GIF.

## Consequências

- **Facilidades:**
  - nenhum SDK, nenhuma coleta e nenhuma revisão de privacidade nova;
  - o caminho reserva continua quando falta o App ID ou o app da rede.
- **Obrigações:**
  - o usuário cria e publica o app na Meta para o envio direto valer;
  - o TikTok exige um passo a mais da pessoa (escolher o arquivo no Fotos);
  - a QA dos Stories só roda no iPhone, com o App ID.
- **Arquivos que mudam junto:**
  - o `Info.plist` ganha `FiscalMetaAppID`, `LSApplicationQueriesSchemes` e `NSPhotoLibraryAddUsageDescription`;
  - o entitlement ganha `applinks:fiscal.byescaleira.com`.

## Alternativas consideradas

- **SDK da Meta (FBSDKShareKit):** dependência grande e coleta de eventos, e as chaves de pasteboard bastam.
- **TikTok Share Kit agora:** depende de registro e de acesso de leitura às Fotos; fica para quando o app estiver registrado.
- **GIF:** sem aceitação oficial nas redes e mais pesado que o MP4.
