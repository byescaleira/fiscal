# Compartilhar no Instagram, TikTok, Facebook e WhatsApp (pesquisa de 31/10/2026)

Insumo da fase 3 ([FSC-010](../../spdd/analysis/FSC-010-202610312330-[Analysis]-share-flow.md)). Cada afirmação traz a fonte e a confiança. Páginas da Meta não mostram data, e o rodapé "© 2026" é o único sinal de que estão vigentes.

## Medidas e zonas seguras

- **Instagram Stories e Reels:** 9:16, 1080×1920 como base; deixar livres cerca de 14% no topo, 35% embaixo e 6% de cada lado. A regra de 35% é a mais conservadora; outra página da Meta diz 20%. [Meta Ads Guide, Stories](https://www.facebook.com/business/ads-guide/update/video/instagram-story) e [Reels](https://www.facebook.com/business/ads-guide/update/image/instagram-reels). Confiança: média (são specs de anúncio).
- **TikTok:**
  - Share Kit aceita proporção entre 1/2,2 e 2,2 e vídeo de até 10 min. [Share Kit iOS](https://developers.tiktok.com/doc/share-kit-ios-quickstart-v2), atualizado em 04/08/2026. Confiança: alta.
  - Posts de foto aceitam até 35 imagens. [Content Posting API](https://developers.tiktok.com/doc/content-posting-api-reference-photo-post), atualizada em 27/10/2026. Confiança: alta.
- **WhatsApp, cartão de link:**
  - Lê `og:title`, `og:description` e `og:url`, obrigatórios. `og:image` é opcional, absoluta, com menos de 600 KB, 300 px ou mais de largura e proporção de até 4:1.
  - As tags precisam estar nos primeiros 300 KB do HTML, sem depender de JavaScript.
  - O crawler faz um GET com User-Agent "WhatsApp/2.x".

  Fonte: [Meta, Link Previews](https://developers.facebook.com/docs/whatsapp/link-previews). Confiança: alta.
- **Feed em 4:5 e 1:1:** só aparece em blogs. Confiança: baixa.

## Abrir a rede direto do app

- **Instagram Stories:**
  - O app abre `instagram-stories://share?source_application=<App ID da Meta>`, com `instagram-stories` em `LSApplicationQueriesSchemes`.
  - Na pasteboard vão `backgroundImage`/`backgroundVideo`, `stickerImage` e as cores do fundo, que expiram em 5 min.
  - O App ID é obrigatório desde janeiro de 2023; sem ele, o Instagram recusa.
  - Imagem com pelo menos 720×1280; vídeo H.264/H.265 de até 1080p, 20 s e menos de 50 MB.

  Fonte: [Meta, Sharing to Stories](https://developers.facebook.com/docs/instagram-platform/sharing-to-stories/). Confiança: alta.
- **Instagram Reels:** o app abre `instagram-reels://share` com `backgroundVideo` e `appID`, vídeo de 3 a 60 s, e o app da Meta precisa estar publicado. [Meta, Reels iOS](https://developers.facebook.com/docs/ios/sharing-to-reels-instagram/). Confiança: alta.
- **Facebook Stories:** o app abre `facebook-stories://share` com as chaves `com.facebook.sharedSticker.*` e `appID` obrigatório; vídeo de até 20 s. [Meta, Stories iOS](https://developers.facebook.com/documentation/sharing/sharing-to-stories/ios-developers). Confiança: alta.
- **TikTok Share Kit:**
  - Pede app registrado com `client_key`, o produto Share Kit e Universal Link de retorno.
  - A mídia vai pelos `localIdentifiers` da biblioteca de Fotos, o que exige acesso às Fotos.
  - Cada envio é só de imagens (até 35) ou só de vídeos (até 12).

  Fonte: [Share Kit iOS](https://developers.tiktok.com/doc/share-kit-ios-quickstart-v2). Confiança: alta. A página não fala de revisão.
- **WhatsApp:**
  - `whatsapp://send?text=` e o UTI de imagem não têm fonte oficial atual. Confiança: baixa; testar no aparelho.
  - **Folha do sistema com imagem, link e texto:** só há relatos antigos. O Facebook descarta o texto, e o WhatsApp não é consistente. Confiança: baixa. A fonte e a data vão sempre dentro da própria imagem.

## Cartão animado

- **GIF:** não tem aceitação oficial nas redes orgânicas; o WhatsApp converte em MP4. Confiança: baixa. GIF fica fora.
- **Formato:** MP4 H.264, 30 fps, 9:16. Um laço de 3 a 6 s serve ao Stories (até 20 s) e ao Reels (3 a 60 s). Fontes acima. Confiança: alta.
- **`ImageRenderer`:** só desenha views do próprio SwiftUI; web views, players e UIKit saem como placeholder. [Apple](https://developer.apple.com/documentation/swiftui/imagerenderer). Confiança: alta.
- **`AVAssetWriter`:** usar o pool do adaptador e tempos de quadro fixos, e esperar o `finishWriting` antes de usar o arquivo. [Apple](https://developer.apple.com/tutorials/data/documentation/avfoundation/avassetwriterinputpixelbufferadaptor.md). Confiança: média.

## Padrões de apps

- **Spotify Wrapped:** slides 9:16 com botão de compartilhar por slide. Confiança: baixa/média.
- **Strava:** números e rota como sticker sobre a foto da pessoa. Confiança: média.
- **Apple Music:** a pessoa escolhe as linhas da letra antes de compartilhar, e o link volta para a música. Confiança: média.
- **API do Instagram:** o modelo é sticker sobre fundo de cor. Confiança: alta.
- **Link sticker:** liberado para todos no Instagram desde 2021. Confiança: média.

## Política

- **Meta:** desde 2025 trata conteúdo político como qualquer outro. [Transparency Center](https://transparency.meta.com/features/approach-to-political-content/), atualizado em 18/09/2025. Confiança: alta.
- **TikTok:** proíbe anúncio político pago e fez acordo com o TSE para 2026. Confiança: média.
- **TSE:** conteúdo feito ou alterado por IA exige aviso, e há bloqueio de 72 h antes e 24 h depois de cada turno (o Fiscal já segue isso). Os turnos de 2026 já passaram. Confiança: média.
