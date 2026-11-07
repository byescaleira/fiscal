# SPDD Analysis: compartilhar como fluxo completo, por rede social

## Original Requirement

Pedidos do usuário em 31/10/2026, literais:

> aprimorarmos o compartilhamento de informações em redes sociais. precisamos incentivar e promover essa parte social. um fluxo completo sobre ela, onde podemos escolher de forma objetiva e clara o que queremos compartilhar.

> o foco é instagram, tiktok, facebook e whatsapp. cada app tem sua peculiaridade. precisamos de estilos diferentes, talvez gif/videos, mas o importante é ser bonito e estilizado

É a fase 3 do plano. As fases 1 e 2 já foram entregues (PRs #6 e #7). Pesquisa de apoio: [docs/research/2026-10-31-social-sharing.md](../../docs/research/2026-10-31-social-sharing.md).

Critérios de aceite:

1. **Fluxo em três passos claros**, em qualquer ponto de compartilhar:
   1. **O quê:** o assunto e os fatos que entram, escolhidos de forma objetiva (ligar e desligar métricas, fonte, QR);
   2. **Estilo:** pelo menos três estilos visuais;
   3. **Destino:** Instagram, TikTok, Facebook, WhatsApp ou outros.

   Cada passo mostra a prévia ao vivo.
2. **Cada destino recebe o formato certo:**
   - Stories, Reels e TikTok em 9:16, com a zona segura de 14% no topo e 35% embaixo;
   - Feed em 4:5;
   - WhatsApp: imagem mais texto com link.
3. **Estilos diferentes, bonitos e estilizados:** o pôster com arte de hoje e mais dois estilos novos, todos com a fonte, a data e o "Fiscal" visíveis.
4. **Cartão animado:** um MP4 curto em laço (3 a 6 s, H.264, 30 fps) para Stories, Reels, TikTok e Status. Sem GIF (pesquisa).
5. **O que vai junto:** a imagem ou o vídeo, mais um texto curto com o fato, a fonte e o link, quando o destino aceita texto.
6. **O link volta para o conteúdo:**
   - abre o app em quem tem;
   - quem não tem cai no site;
   - o WhatsApp mostra um cartão de prévia (Open Graph).
7. **Incentivo sem empurrar:**
   - convite discreto para compartilhar depois de seguir alguém;
   - cartaz de "quem eu sigo";
   - nada de contagem nem de ranking.
8. **O que já vale continua valendo** (canvas [FSC-005](../prompt/FSC-005-202610291700-[Codify]-share-cards-and-art.md)):
   - nada da Lente nem de quem a pessoa apoia vai no cartaz;
   - "—" no lugar de dado ausente, nunca 0;
   - crédito da obra;
   - os links já impressos (`?person=` e os outros) continuam.

## Domain Concept Identification

### Existing Concepts

- **Assunto de compartilhar** (`ShareSubject` em `FeatureCore/Navigation/ShareSubject.swift`): pessoa, votação, gastos, disputa, comparação, bancada, destaque e investigação. Entra pela `Route.share(...)`, aberta de cerca de dez pontos do app.
- **Tela atual** (`FeatureShare/ShareScreen.swift`, `ShareModel`, `ShareRenderer`):
  - prévia, seletor de formato e seletor de arte;
  - `ShareLink(item: rendered.file)` exporta só o PNG "Fiscal.png";
  - o `shareMessage` existe e não é usado.
- **Formatos** (`ShareFormat` do kit): Stories 360×640 pt, Feed 360×450 pt e Mensagem 360×360 pt, desenhados em 3x.
- **Cartazes** (`ShareCardView`, `SharePoster`, `SharePosterHeroes`, `ShareVictoryPoster`, `ShareInvestigationPoster`):
  - herói por assunto, métricas fixas por cargo (4), fatos, fonte com carimbo, QR e crédito da obra;
  - arte do `art-credits.json`, com 44 obras em 2 coleções.
- **Link e QR:** `ShareCardBuilder`, `ShareCode`, `https://fiscal.byescaleira.com/?person=<slug>` e afins. O site ignora os parâmetros. O AASA cobre só `/link`. O app não tem Associated Domains.
- **Seguir** (fase 2): `FollowController`, `FollowedPerson`. Há a rota `.representatives(uf:)`, mas não existe assunto "quem eu sigo".

### New Concepts Required

- **Destino** (`ShareDestination`):
  - Instagram (Stories, Reels, Feed), TikTok, Facebook (Stories, Feed), WhatsApp (conversa, Status) e Outros (folha do sistema);
  - cada um com formato, mídia (imagem ou vídeo), se aceita texto e como abre.
- **Estilo** (`ShareStyle`):
  - **Pôster:** o de hoje, com arte;
  - **Tipográfico:** número e frase grandes em Bricolage, fundo de cor sólida da paleta neutra;
  - **Dados:** gráfico de barras ou placar, com o fato no centro.
- **Seleção de conteúdo** (`ShareSelection`): os fatos ligados e desligados (métricas, fonte, QR, crédito). A fonte e o "Fiscal" nunca desligam.
- **Cartão animado:** a mesma composição com entrada em etapas (números contando, barras enchendo), gravada em MP4 no aparelho, respeitando Reduzir movimento na prévia.
- **Legenda pronta:** o texto curto com o fato, a fonte, a data e o link, que a pessoa pode editar antes de enviar.
- **Assunto "quem eu sigo":** cartaz com até 6 pessoas seguidas, só nomes, partidos e cargos.

### Key Business Rules

- **Zona segura do 9:16:** nada de texto nos 14% de cima nem nos 35% de baixo; 6% de margem lateral.
- **Vídeo:** de 3 a 6 s, H.264, 30 fps, até 1080×1920, menos de 50 MB (limite do Stories direto).
- **Itens obrigatórios:** a fonte, a data, "Fiscal" e o crédito da obra nunca saem de nenhum estilo nem formato.
- **Neutralidade:** o cartaz e a legenda nunca levam a Lente, quem a pessoa apoia ou a pergunta de uma investigação não compartilhada. Também nunca levam adjetivo nem opinião; só os fatos.
- **IA:** nenhuma imagem gerada ou alterada por IA no cartaz (regra do TSE).
- **Links:** os já impressos continuam válidos; o link novo leva ao mesmo conteúdo.

## Strategic Approach

### Solution Direction

- **Uma tela de três passos:** a `ShareScreen` vira o fluxo O quê → Estilo → Destino, com a prévia sempre visível e grande.
- **Conteúdo:** o model monta a seleção de fatos por assunto, e os estilos desenham a mesma seleção.
- **Destino:**
  - decide o formato e a mídia;
  - o envio usa o caminho direto da rede quando ele existe e está configurado;
  - senão, usa a folha do sistema, ou salva no Fotos e abre o app da rede.
- **Animação:** o MP4 é gravado no aparelho a partir dos mesmos quadros do SwiftUI.
- **Volta ao conteúdo:**
  - o app passa a abrir os links do site (Associated Domains e AASA com os parâmetros);
  - o site ganha a leitura dos parâmetros, com a prévia Open Graph geral;
  - a página por pessoa com cartão próprio fica na fase 5, a da web.

### Key Design Decisions

| Decisão | Escolha | Trade-off | Porta |
| --- | --- | --- | --- |
| Envio direto para Instagram e Facebook Stories | Usar as chaves de pasteboard com um App ID da Meta criado por você e publicado. Sem App ID, cai na folha do sistema | Abre o Stories pronto, com sticker e cores; depende de conta e app na Meta | `pergunta` (respondida em 31/10/2026: criar o App ID e usar o envio direto) |
| TikTok | Salvar no Fotos e abrir o TikTok agora; o Share Kit (`client_key`, Fotos, Universal Link) depois de você registrar o app | Sem SDK de terceiro agora; um passo a mais para a pessoa | `pergunta` (respondida: salvar no Fotos e abrir o TikTok agora) |
| Cartão animado | MP4 de 3 a 6 s gerado no aparelho, nos estilos que têm números ou barras; GIF fora | Mais bonito em Stories e TikTok; custa tempo de geração (mostrar progresso) | `pergunta` (respondida: MP4 animado agora) |
| Três estilos | Pôster (o de hoje), Tipográfico e Dados | Mais variedade sem mexer no acervo de arte | `veto` |
| Seleção de fatos | Interruptores por fato; a fonte e o "Fiscal" sempre ligados | A pessoa escolhe o que mostra sem quebrar o dever de citar a fonte | `reversível` |
| Legenda | Texto pronto e editável com o fato, a fonte e o link; vai junto onde o destino aceita | O Facebook descarta texto na folha do sistema: a fonte também fica na imagem | `reversível` |
| Links | Associated Domains no app e AASA com os parâmetros atuais; o site lê o parâmetro e mostra o assunto com prévia geral | Abre o app sem mudar o link impresso; o cartão por pessoa no WhatsApp fica para a fase 5. Publicar o site espera o seu ok | `veto` |
| Incentivo | Convite discreto "Compartilhe quem você acompanha" depois do primeiro seguir, e o cartaz "quem eu sigo" | Promove o social sem contagem nem ranking | `veto` |

### Alternatives Considered

- **GIF:** a pesquisa não acha aceitação oficial, e ele pesa mais que o MP4.
- **SDK da Meta (Facebook SDK):** as chaves de pasteboard bastam; o SDK traz dependência e coleta de dados.
- **Página por pessoa com imagem própria agora:** depende da geração estática na carga ou de um serviço novo, que é a fase 5.
- **Contador de compartilhamentos:** vai contra a regra de não rastrear e de só mostrar fatos.

### Crítica honesta da tela atual

- **Escolha:** a pessoa escolhe formato e arte, mas não o que entra. As métricas são fixas por cargo.
- **Envio:** sai só o PNG, sem texto nem link. O QR cai na página inicial do site e não abre o app.
- **Estilo:** um só, o pôster com arte. Ele fica bonito no Stories e pesado na conversa.
- **Destino:** "Stories", "Feed" e "Mensagem" falam de formato, não de onde a pessoa quer postar.
- **Movimento e "quem eu sigo":** não há cartaz animado nem cartaz de "quem eu sigo".

## Risk & Gap Analysis

| Critério de aceite | Coberto pela direção? | Lacuna ou risco |
| --- | --- | --- |
| 1. Três passos com prévia | sim | A tela fica longa no iPhone pequeno; a prévia encolhe e os passos viram abas |
| 2. Formato por destino | sim | Medidas de Feed e de Facebook sem fonte oficial (pesquisa, confiança baixa): 4:5 por convenção |
| 3. Três estilos | sim | Cada estilo precisa caber em 8 assuntos e 3 formatos: o teste de layout cobre a matriz |
| 4. Cartão animado | sim, se aprovado | Gerar 180 quadros em 1080×1920 leva segundos: mostrar progresso e gerar só ao escolher destino de vídeo |
| 5. Legenda com link | sim | A folha do sistema pode descartar o texto (Facebook): a fonte também fica na imagem |
| 6. Link de volta | parcial | Abrir o app precisa da AASA publicada no site (seu ok). O cartão por pessoa no WhatsApp fica na fase 5 |
| 7. Incentivo | sim | — |
| 8. Regras da FSC-005 | sim | — |

- **Riscos:**
  - **App ID da Meta:** sem ele, os Stories diretos ficam desligados. Mitigação: a folha do sistema continua, e o App ID entra pelo `Info.plist`.
  - **Toques e prévia no Duo:** verificar a tela nova na dobra (FSC-008).
  - **Tamanho do vídeo:** limite de 50 MB. Mitigação: H.264 com taxa de bits limitada, 6 s no máximo.
- **Lacunas:** nenhuma. As três decisões de porta `pergunta` foram respondidas pelo usuário em 31/10/2026. Falta o App ID da Meta, que ele cria em developers.facebook.com.
- **Quebra:**
  - Nada muda nos dados salvos.
  - Os links impressos continuam.
  - O arquivo passa a se chamar pelo assunto (por exemplo, "Fiscal - Fulana.png"), em vez de só "Fiscal.png".
  - Os textos dos formatos ("Stories", "Feed", "Mensagem") viram nomes de destino.
  - Entra o entitlement de Associated Domains (`applinks:fiscal.byescaleira.com`), e a AASA do site muda. Publicar o site espera o seu ok.
