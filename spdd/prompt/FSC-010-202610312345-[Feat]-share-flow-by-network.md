# Compartilhar como fluxo completo, por rede social

## Requirements

Hoje o compartilhar escolhe só o formato e a arte, exporta só um PNG, sem texto nem link, e tem um estilo só. O usuário pediu, em 31/10/2026, um fluxo completo em que a pessoa escolha de forma objetiva o que compartilha, com foco em Instagram, TikTok, Facebook e WhatsApp, estilos diferentes, vídeo, e "o importante é ser bonito e estilizado". Análise: [FSC-010](../analysis/FSC-010-202610312330-[Analysis]-share-flow.md). Pesquisa: [2026-10-31-social-sharing](../../docs/research/2026-10-31-social-sharing.md).

Decisões do usuário em 31/10/2026:
- **Meta:** criar o App ID da Meta e usar o envio direto aos Stories.
- **TikTok:** salvar no Fotos e abrir o TikTok, sem SDK nesta fase.
- **Animação:** MP4 animado agora.

Definição de pronto:

- **Given** a pessoa abre Compartilhar num perfil **When** a tela aparece **Then** ela vê:
  - a prévia no topo;
  - três seções, nesta ordem: "O que entra", "Estilo" e "Onde postar";
  - embaixo, um botão com o nome do destino escolhido (por exemplo, "Postar no Instagram Stories").
  - Prova: captura em `docs/evidence/FSC-010/`.
- **Given** "O que entra" num perfil de deputada com 4 métricas **When** a pessoa desliga "Presença" e o QR **Then** a prévia e o arquivo saem sem a presença e sem o QR. A fonte, a data, "Fiscal" e o crédito da obra continuam e não podem ser desligados (`ShareSelectionTests.hidesOnlyOptionalFacts`).
- **Given** os estilos **When** a pessoa escolhe entre eles **Then** a prévia troca para:
  - **Pôster:** o de hoje, com arte e crédito;
  - **Tipográfico:** fundo de cor sólida neutra, o número ou a frase principal em Bricolage grande e a fonte embaixo;
  - **Dados:** o placar ou as barras no centro, com o fato.

  Os 8 assuntos desenham nos três estilos e nos três formatos sem cortar texto (`ShareStyleTests.everySubjectFitsEveryStyleAndFormat`).
- **Given** "Onde postar" **When** a pessoa escolhe o destino **Then** o formato e a mídia seguem a tabela (`ShareDestinationTests.mapsEachDestination`):

  | Destino | Formato | Mídia | Texto |
  | --- | --- | --- | --- |
  | Instagram Stories | 9:16 | vídeo ou imagem | não |
  | Instagram Reels | 9:16 | vídeo | não |
  | Instagram Feed | 4:5 | imagem | sim |
  | TikTok | 9:16 | vídeo ou imagem | não |
  | Facebook Stories | 9:16 | vídeo ou imagem | não |
  | Facebook Feed | 4:5 | imagem | sim |
  | WhatsApp, conversa | 1:1 | imagem | sim |
  | WhatsApp Status | 9:16 | vídeo ou imagem | não |
  | Outros | 4:5 | imagem | sim |
- **Given** um formato 9:16 **When** o cartaz é desenhado **Then** nenhum texto, número ou QR fica nos 14% de cima (90 de 640 pt), nos 35% de baixo (224 pt) nem nos 6% de cada lado (22 pt). Fundo e arte podem passar (`ShareSafeAreaTests.ninebysixteenKeepsTheSafeZone`).
- **Given** um destino de vídeo e os estilos Tipográfico ou Dados **When** a pessoa toca em postar **Then**:
  - o app gera um MP4 H.264 de 4 s, 30 fps, 1080×1920, com os números contando e as barras enchendo, e com menos de 50 MB;
  - aparece uma barra de progresso ("Preparando o vídeo"), e a geração pode ser cancelada.

  Prova: `ShareVideoTests.writesAFourSecondLoop`. No estilo Pôster, o vídeo anima só o número do herói.
- **Given** Reduzir movimento ligado **When** a prévia aparece **Then** ela fica parada no quadro final. O vídeo exportado continua animado, porque é para outra pessoa ver.
- **Given** o App ID da Meta no `Info.plist` (`FiscalMetaAppID`) e o Instagram instalado **When** a pessoa posta no Instagram Stories **Then** o app abre o Stories com o cartaz:
  - o cartaz vai como `backgroundImage` ou `backgroundVideo`, com as cores de topo e base da paleta do estilo;
  - a pasteboard é escrita com expiração de 5 min.

  O Facebook Stories funciona igual, com as chaves `com.facebook.sharedSticker.*` e o `appID`. Prova: `ShareDeliveryTests.storiesWriteThePasteboardItems`, mais o roteiro no iPhone.
- **Given** o App ID vazio ou o app da rede não instalado **When** a pessoa posta nos Stories **Then** a folha do sistema abre com o arquivo, sem erro (`ShareDeliveryTests.fallsBackToTheShareSheet`).
- **Given** TikTok **When** a pessoa toca em postar **Then** o app pede o acesso de só adicionar ao Fotos, salva o arquivo, mostra "Salvo no Fotos. Abra o TikTok e escolha o vídeo." e abre o TikTok se ele estiver instalado. Sem permissão, o texto explica como liberar nos Ajustes. Prova: roteiro no iPhone.
- **Given** Instagram Feed, Facebook Feed, WhatsApp ou Outros **When** a pessoa posta **Then** a folha do sistema recebe o arquivo e a legenda.
- **Given** a legenda **When** a pessoa a vê e edita **Then** ela começa com o fato e traz a fonte, a data e o link `https://fiscal.byescaleira.com/?person=<slug>`, com no máximo 280 caracteres (`ShareCaptionTests.carriesFactSourceAndLink`). Ela nunca leva a Lente, apoio ou adjetivo.
- **Given** um link `https://fiscal.byescaleira.com/?person=<slug>` (e `vote`, `expenses`, `compare`, `place`, `race`, `highlight`) **When** ele é aberto num iPhone com o Fiscal **Then** o app abre no conteúdo, pelo Associated Domains com a AASA, que passa a aceitar esses parâmetros na raiz (`DeepLinkTests.siteLinksOpenTheContent`). Sem o app, o site abre. A AASA nova só passa a valer com o site publicado, o que espera o ok do usuário.
- **Given** a pessoa segue alguém pela primeira vez **When** volta à aba Seguindo **Then** aparece uma linha dispensável "Compartilhe quem você acompanha". Ela abre o assunto novo "Quem eu sigo", que mostra até 6 pessoas com nome, partido e cargo, em ordem alfabética. Nunca há contagem nem ranking (`ShareModelTests.followingCardListsUpToSixAlphabetically`).
- **Given** qualquer assunto e qualquer Lente **When** o cartaz e a legenda são montados **Then** nenhum texto traz a Lente ou quem a pessoa apoia, o "—" segue no lugar de dado ausente, e o arquivo se chama "Fiscal - <assunto>.png" ou ".mp4" (`ShareModelTests.theCardNeverCarriesWhoTheUserSupports`, já existente e ampliado aos estilos).
- **Given** o fluxo pronto **When** as imagens são redesenhadas (pedido do usuário em 01/11/2026: "vale revisitar as imagens para compartilhar também, esse processo de compartilhamento ele deve ser repensado com um todo") **Then** cada tipo de assunto (pessoa, votação, gastos, disputa, comparação, seguindo) tem composição própria com uma frase-gancho factual, saída de uma crítica honesta das imagens atuais e de um quadro de referências reais; 2 ou 3 direções visuais vão ao iPhone do usuário e a escolhida é a que ele aprovar (roteiro: capturas de cada direção em `docs/evidence/FSC-010/directions/`).
- **Erro:** falha ao gerar o vídeo cai na imagem, com o aviso "Não deu para gerar o vídeo; vai a imagem." Falha ao salvar no Fotos mostra o motivo. Nenhuma falha perde a seleção feita.

## Entities

```mermaid
classDiagram
  class ShareDestination {
    <<enum>>
    instagramStories
    instagramReels
    instagramFeed
    tiktok
    facebookStories
    facebookFeed
    whatsapp
    whatsappStatus
    other
    ShareFormat format
    Media media
    Bool acceptsCaption
    Delivery delivery
  }
  class ShareStyle {
    <<enum>>
    poster
    typographic
    data
  }
  class ShareSelection {
    Set~String~ hidden
    Bool showsCode
    isOn(fact) Bool
  }
  class ShareFact {
    String id
    String title
    Bool isOptional
  }
  class ShareCaption {
    make(content, selection) String
  }
  class ShareVideoRenderer {
    render(card, seconds, fps, progress) URL
  }
  class ShareDelivery {
    send(file, caption, destination) Result
  }
  class ShareModel {
    ShareStyle style
    ShareDestination destination
    ShareSelection selection
    String caption
    Double exportProgress
  }
  ShareModel --> ShareDestination
  ShareModel --> ShareStyle
  ShareModel --> ShareSelection
  ShareSelection --> ShareFact
  ShareModel ..> ShareVideoRenderer
  ShareModel ..> ShareDelivery
```

- **`ShareDestination`** (novo, `FeatureShare`): o formato vem do `ShareFormat` do kit (`.stories` 9:16, `.feed` 4:5, `.message` 1:1). Tem também a mídia (`.image`, `.video`, `.either`), se aceita legenda e a entrega:
  - `.instagramStories` e `.facebookStories`: pasteboard;
  - `.photosThenOpen(URL)`: salvar no Fotos e abrir o app;
  - `.shareSheet`: folha do sistema.
- **`ShareStyle`** (novo): o `ShareCardView` desenha o pôster de hoje, e dois views novos desenham `ShareTypographicView` e `ShareDataView` a partir do mesmo `ShareCardContent`.
- **`ShareFact`** e **`ShareSelection`** (novos):
  - o `ShareCardContent` expõe os fatos opcionais de cada assunto: métricas do perfil, linhas de comparação, maior categoria de gastos, peso do destaque e QR;
  - a seleção guarda os ids desligados;
  - a fonte, a data, "Fiscal" e o crédito não são `ShareFact`, e por isso não desligam.
- **`ShareCaption`** (novo, função pura): monta a legenda com no máximo 280 caracteres.
- **`ShareVideoRenderer`** (novo):
  - desenha os quadros com o `ImageRenderer` sobre o mesmo view, com `\.shareProgress` de 0 a 1;
  - grava com `AVAssetWriter` (H.264, 30 fps, 4 s, 1080×1920, até 8 Mbps), usando o pool do `AVAssetWriterInputPixelBufferAdaptor`;
  - escreve num arquivo temporário e só entrega depois do `finishWriting`.
- **`ShareDelivery`** (novo, iOS):
  - escreve a pasteboard dos Stories com `UIPasteboard.setItems(_:options:)` e expiração de 300 s, e abre `instagram-stories://share?source_application=<id>` ou `facebook-stories://share`;
  - salva no Fotos com `PHPhotoLibrary`, só adição;
  - devolve o que fez, para a tela dizer.
- **`ShareSubject.following`** (novo caso): a lista de até 6 pessoas seguidas vem do `FollowController`.

## Approach

1. **Estratégia:**
   - A `ShareScreen` vira uma tela de três seções com a prévia fixa no topo e o botão de postar fixo embaixo.
   - Todo estilo desenha o mesmo `ShareCardContent` filtrado pela `ShareSelection`.
   - O destino decide formato, mídia e entrega.
   - O vídeo nasce dos mesmos views, animados por um progresso.
2. **Decisões:**
   - **Seções em vez de páginas:** as três seções ficam numa lista só, e não num assistente de páginas. A pessoa vê tudo e muda em qualquer ordem, com a prévia sempre visível. Estilos e destinos são grades de miniaturas, porque escolhas visuais vão em grade (`design-principles.md`), e não `Picker` segmentado.
   - **Destinos agrupados por rede:** Instagram (Stories, Reels, Feed), TikTok, Facebook (Stories, Feed), WhatsApp (conversa, Status) e Outros.
     - O ícone de cada rede é um símbolo SF genérico (câmera, play, pessoas, balão), sem logo de terceiros.
     - O nome da rede vai escrito.
     - Logo de marca exige licença, e por isso não entra.
   - **Meta:**
     - o App ID entra pelo `Info.plist` (`FiscalMetaAppID`, vazio no repositório até o usuário criar o app);
     - `instagram-stories` e `facebook-stories` entram em `LSApplicationQueriesSchemes`;
     - sem App ID, a entrega é a folha do sistema;
     - nada do SDK da Meta entra no app.
   - **TikTok sem SDK:** a mídia é salva no Fotos (`NSPhotoLibraryAddUsageDescription`: "O Fiscal salva no Fotos o cartão que você quer postar."), e o app abre o TikTok pelo esquema registrado. A existência do esquema é conferida com `canOpenURL` na QA; sem ele, só o aviso.
   - **Vídeo:**
     - 4 s, para ficar dentro dos 3 a 6 s da pesquisa e do mínimo de 3 s do Reels;
     - os números contam com a curva do `MotionBudget`;
     - os quadros saem do `ImageRenderer` (só views do SwiftUI, sem retrato Lottie em movimento, com `portraitsStill`);
     - a geração roda fora da main thread, mas o `ImageRenderer` exige a main, então os quadros saem em lotes com `Task.yield`.
   - **Links:**
     - o app ganha o entitlement `com.apple.developer.associated-domains` com `applinks:fiscal.byescaleira.com`;
     - `site/.well-known/apple-app-site-association` passa a ter `components` para `/` com `?person=*` e os outros parâmetros, além de `/link`;
     - o `DeepLink` passa a aceitar `https://fiscal.byescaleira.com/?…` e cair no mesmo destino que `fiscal://`;
     - a página por pessoa com imagem própria fica na fase 5;
     - publicar a AASA espera o ok do usuário.
   - **Incentivo:**
     - uma linha dispensável na aba Seguindo depois do primeiro seguir, guardada em `fiscal.share.followingInviteDismissed`;
     - sem push, sem contagem e sem pedido repetido.
   - **Nome do arquivo:** "Fiscal - <assunto>", com o nome da pessoa, o número da votação ou o título, sem barras.
   - **ADR:**
     - [ADR 0020](../../docs/adr/0020-share-to-social-networks.md) (Proposto) registra a integração com Meta e TikTok sem SDK, o App ID no `Info.plist` e a regra de não usar logos de terceiros;
     - ela vira Aceito com o ok deste canvas.
3. **Referências:**
   - a pesquisa de 31/10/2026, com as Meta Sharing to Stories e Reels, o TikTok Share Kit e o WhatsApp Link Previews;
   - Spotify Wrapped (cartões 9:16 por slide), Strava (sticker de dados) e Apple Music (escolher o trecho antes);
   - o canvas [FSC-005](FSC-005-202610291700-[Codify]-share-cards-and-art.md) para o pôster, a arte e os créditos.

## Structure

```text
FiscalKit/
  Sources/FeatureCore/Navigation/ShareSubject.swift            caso .following
  Sources/FeatureShare/ShareDestination.swift                  (novo) destinos, formato, mídia, entrega
  Sources/FeatureShare/ShareStyle.swift                        (novo) estilos
  Sources/FeatureShare/ShareSelection.swift                    (novo) fatos opcionais e seleção
  Sources/FeatureShare/ShareCaption.swift                      (novo) legenda
  Sources/FeatureShare/ShareTypographicView.swift              (novo) estilo Tipográfico
  Sources/FeatureShare/ShareDataView.swift                     (novo) estilo Dados
  Sources/FeatureShare/ShareMotion.swift                       (novo) \.shareProgress e contagem
  Sources/FeatureShare/ShareVideoRenderer.swift                (novo) MP4 com AVAssetWriter
  Sources/FeatureShare/ShareDelivery.swift                     (novo, iOS) pasteboard, Fotos, folha
  Sources/FeatureShare/ShareCardContent.swift, ShareCardBuilder*.swift   fatos opcionais, assunto seguindo
  Sources/FeatureShare/ShareCardView.swift, SharePoster*.swift zona segura 9:16 e seleção
  Sources/FeatureShare/ShareModel.swift                        estilo, destino, seleção, legenda, exportação
  Sources/FeatureShare/ShareScreen.swift                       três seções, prévia e botão de postar
  Sources/FeatureShare/ShareRenderer.swift                     nome do arquivo por assunto
  Sources/FeatureMine/MineFollowing.swift                      convite "Compartilhe quem você acompanha"
  Sources/AppShell/DeepLink.swift                              links https do site
  Tests/FeatureShareTests/ShareDestinationTests.swift          (novo)
  Tests/FeatureShareTests/ShareSelectionTests.swift            (novo)
  Tests/FeatureShareTests/ShareStyleTests.swift                (novo) matriz assunto × estilo × formato
  Tests/FeatureShareTests/ShareSafeAreaTests.swift             (novo)
  Tests/FeatureShareTests/ShareCaptionTests.swift              (novo)
  Tests/FeatureShareTests/ShareVideoTests.swift                (novo)
  Tests/FeatureShareTests/ShareDeliveryTests.swift             (novo)
  Tests/FeatureShareTests/ShareModelTests.swift                estilos, seguindo, nome do arquivo
  Tests/AppShellTests/DeepLinkTests.swift                      links https
Fiscal/Fiscal/Info.plist                                       FiscalMetaAppID, LSApplicationQueriesSchemes, NSPhotoLibraryAddUsageDescription
Fiscal/Fiscal/Fiscal.entitlements                              applinks:fiscal.byescaleira.com
site/.well-known/apple-app-site-association                    components com os parâmetros
docs/adr/0020-share-to-social-networks.md                      (novo, Proposto)
Fiscal/Fiscal/Localizable.xcstrings                            textos em pt-BR
docs/evidence/FSC-010/, CHANGELOG.md, docs/roadmap.md, spdd/README.md
```

## Operations

1. **Conteúdo e seleção:**
   - `ShareFact`, `ShareSelection` e os fatos opcionais por assunto;
   - o assunto `.following`;
   - o nome do arquivo por assunto.
   - Verificação: `ShareSelectionTests` e `ShareModelTests`.
2. **Destinos e legenda.** `[P]` com 1.
   - `ShareDestination` com a tabela da definição de pronto.
   - `ShareCaption`.
   - Verificação: `ShareDestinationTests` e `ShareCaptionTests`.
3. **Estilos e zona segura.** Depende de: 1.
   - `ShareStyle`, `ShareTypographicView` e `ShareDataView`.
   - A zona segura no 9:16 dos três estilos.
   - O `ShareCardView` respeitando a seleção.
   - Verificação: `ShareStyleTests` e `ShareSafeAreaTests`.
4. **Movimento e vídeo.** Depende de: 3.
   - `\.shareProgress`, a contagem e as barras.
   - `ShareVideoRenderer`, com progresso e cancelamento.
   - Verificação: `ShareVideoTests` (arquivo de 4 s, 120 quadros, H.264, menos de 50 MB).
5. **Entrega.** Depende de: 2.
   - `ShareDelivery`: pasteboard dos Stories, Fotos e TikTok, e a folha do sistema como alternativa.
   - `Info.plist` e esquemas.
   - Verificação: `ShareDeliveryTests`, com a pasteboard e o abridor injetados.
6. **Tela.** Depende de: 1 a 5.
   - `ShareScreen` com as três seções, a prévia, a legenda editável e o botão de postar com progresso.
   - O `ShareModel` amarra tudo.
   - Verificação: `scripts/verify.sh --quick ios`.
7. **Links e incentivo.** `[P]` com 6.
   - Associated Domains, a AASA e o `DeepLink` com https.
   - O convite na aba Seguindo.
   - O ADR 0020.
   - Verificação: `DeepLinkTests` e build.
8. **Textos.** Depende de: 6 e 7.
   - Chaves em pt-BR.
   - Verificação: `scripts/strings.sh`.
8.1. **Redesenho das imagens** (prompt-update de 01/11/2026). Depende de: 3 e 6.
    - Crítica das imagens atuais e quadro de referências (Spotify Wrapped, resumos do Apple Fitness, Strava, The Pudding, NYT Upshot) em `docs/research/`.
    - Composição por tipo de assunto, com frase-gancho factual no topo, menos elementos por cartaz e a arte a serviço do dado.
    - 2 ou 3 direções no iPhone do usuário; iterar até o ok; a direção aprovada substitui o desenho dos estilos.
    - Verificação: `ShareStyleTests` (matriz) e capturas por direção.
9. **Rodar e QA.** Depende de: 1 a 8.1.
   - `scripts/verify.sh --full`.
   - Build no iPhone do usuário.
   - Roteiros em `docs/evidence/FSC-010/qa.md`:
     - a tela de três seções;
     - desligar fatos;
     - os três estilos;
     - o 9:16 com a zona segura;
     - gerar o vídeo;
     - Stories direto (com o App ID do usuário);
     - TikTok pelo Fotos;
     - WhatsApp com a legenda;
     - o link do site abrindo o app (depois da AASA publicada);
     - o convite.
10. **Revisão e PR.** Depende de: 9.
    - Revisores de spec, design, acessibilidade, código e segurança (pasteboard, Fotos, entitlements).
    - Correções num commit.
    - CHANGELOG, roadmap e `spdd/README.md`.
    - PR para a `development`, com o merge pedido ao usuário.

## Norms

- **Regra 3:** formato, mídia, seleção e legenda são decididos no model e em tipos puros; a view só desenha.
- **Regra 4:**
  - zero comentários e zero avisos;
  - Swift Testing nos tipos novos;
  - `.timeLimit` no teste do vídeo;
  - tokens para medidas (zona segura como tokens novos `.shareSafeTop`, `.shareSafeBottom`, `.shareSafeSide`).
- **Regra 5:**
  - Bricolage só no número e no título de destaque;
  - grades de miniaturas para estilo e destino;
  - nada de `Picker` segmentado;
  - cápsulas de texto curto com `lineLimit(1).fixedSize()` (memória "no-mid-word-wrap");
  - Reduzir movimento respeitado na prévia.
- **Regra 6:** pt-BR; a legenda curta, só com fatos.
- **Fatos só:** o cartaz e a legenda trazem fonte e data; nada de adjetivo, opinião ou ranking.
- **ADR 0017:** a lista de seguidos só sai do aparelho quando a própria pessoa compartilha o cartaz "Quem eu sigo".
- **ADR 0003:** só pt-BR.

## Safeguards

- **Funcional:**
  - fonte, data, "Fiscal" e crédito da obra presentes em todo estilo, formato e mídia;
  - "—" no lugar de dado ausente;
  - Lente e apoio nunca no cartaz nem na legenda;
  - as falhas de vídeo e de Fotos não perdem a seleção.
- **Desempenho:**
  - vídeo de 4 s, 120 quadros em 1080×1920, até 8 Mbps e menos de 50 MB;
  - geração cancelável, com progresso;
  - a prévia não gera vídeo.
- **Privacidade e segurança:**
  - a pasteboard dos Stories expira em 300 s e só leva o cartaz e as cores;
  - o Fotos é pedido com permissão de só adicionar;
  - nenhum SDK de terceiros;
  - o App ID da Meta é público (não é segredo) e fica no `Info.plist`;
  - nenhum rastreio de compartilhamento.
- **Compatibilidade:**
  - os links impressos (`?person=` e os outros) não mudam;
  - `fiscal://` continua;
  - os ids de coleção de arte e os nomes de imageset não mudam.
- **QUEBRA:**
  - o nome do arquivo deixa de ser "Fiscal.png" e passa a ser "Fiscal - <assunto>";
  - os seletores "Stories / Feed / Mensagem" viram destinos;
  - entram o Associated Domains, a permissão de adicionar ao Fotos e os esquemas de outros apps.
- **Fora do escopo:**
  - SDK da Meta e do TikTok;
  - página por pessoa com imagem própria e cartão do WhatsApp por pessoa (fase 5);
  - GIF;
  - Live Photos;
  - logos de terceiros;
  - contagem de compartilhamentos;
  - publicar o site (espera o ok);
  - novas obras de arte.
