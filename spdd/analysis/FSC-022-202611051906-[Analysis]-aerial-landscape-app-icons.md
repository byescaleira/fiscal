# Ícones do app com paisagens do Brasil vistas de cima

## Original Requirement

Pedido do usuário em 05/11/2026:

> quero fazer um ajuste em "ícone do app" e "Temas". Esse ícones o background devem ser um background visto de cima e com paisagens caracteristicas do brasil.

Critérios que vieram com o pedido, pela sessão principal:

- o fundo de cada ícone das seções "Ícone do app" e "Temas" é uma paisagem característica do Brasil vista de cima;
- o que identifica o Fiscal continua no ícone;
- design a partir de referências reais, com variantes lado a lado no iPhone antes de ampliar para todos, até o ok;
- toda imagem com licença compatível com repositório público e uso comercial, com origem e licença registradas.

**Tamanho:** M, uma mudança de identidade visual em 11 ícones, sem dado novo nem tela nova.

## Domain Concept Identification

**Crítica honesta dos ícones atuais (capturas de 05/11/2026, `ictool`, claro e escuro):**

- **Os 11 ícones são a mesma cena de frente.** O principal, "Amazônia de dia" e os 8 temas repetem céu, sol, três fileiras de copas e um rio em curva; "Rio Amazonas" é a única cena diferente, uma copa vista de cima com o rio e ipês amarelos.
- **Os temas são só recolor.** Floresta, Urucum, Índigo, Ipê, Savana, Mar, Grafite e Areia trocam a paleta da mesma floresta. Em Índigo, Ipê e Grafite a cena vira uma floresta de cor impossível, e nada diz Brasil além do mapa.
- **O fundo some atrás do mapa.** O Brasil em vidro ocupa quase todo o quadro e cobre o sol e o centro da cena. Sobra uma faixa de copas embaixo, igual em todos, então na tela inicial os temas se distinguem só pela cor.
- **O escuro achata.** No modo escuro o céu e as copas viram dois tons próximos, e o rio quase desaparece.
- **O que funciona:** o mapa em vidro com borda branca é reconhecível e é a marca do Fiscal; "Rio Amazonas" já mostra que a vista de cima lê bem no tamanho de ícone e deixa o mapa respirar sobre uma textura em vez de uma linha do horizonte.

### Existing Concepts

- **Ícone do app** (`AppIcon` em `FiscalKit/Sources/FeatureCore/Icons/AppIcon.swift`): 47 casos em quatro coleções (`main`, `themes`, `fauna`, `parties`). O valor bruto e o `assetName` (`FiscalIcon<Caso>`) são o que fica salvo na escolha da pessoa e o nome do ícone alternativo no `Info.plist`.
- **Arquivos do ícone** (`Fiscal/Fiscal/FiscalIcon*.icon`): pacotes do Icon Composer com camadas SVG 1024×1024 e cores por aparência (claro, escuro, tinted). O mapa (`9 Map.svg`) e a borda (`9b Rim.svg`) em vidro são os mesmos em todos.
- **Prévias em Ajustes** (`scripts/icons.sh`): exporta cada `.icon` para `Media.xcassets/AppIcon` em claro e escuro, usadas por `AppIconImage` e `AppIconSection` em `FeatureSettings`.
- **Acervo de arte** (`scripts/art.py`, `art-credits.json`, FSC-005): checa licença e origem de imagens em domínio público.
- **ADR 0013:** ícones de partido atrás da flag `partyIcons`; diz que o principal, os de Amazônia, os de tema e os de fauna não dependem dela.

### New Concepts Required

- **Paisagem de cada ícone:** um lugar brasileiro real e reconhecível, visto de cima, por ícone das duas seções.
- **Gerador das camadas:** as cenas aéreas têm forma orgânica (dunas, meandros, recifes) que não se desenha à mão em 11 arquivos; um gerador no projeto produz as camadas SVG de cada `.icon` a partir de uma descrição por paisagem, repetível e revisável.

### Key Business Rules

- 11 ícones mudam: 3 em "Ícone do app" (`standard`, `amazonDay`, `amazonRiver`) e 8 em "Temas". Os 6 de fauna e os 30 de partido ficam como estão.
- O mapa do Brasil em vidro com a borda branca continua em todos, no mesmo lugar e tamanho.
- Os 11 valores brutos e nomes de asset não mudam, para a escolha salva continuar valendo depois da atualização.
- Cada tema mantém a cor que dá o nome: a paisagem é escolhida para ter essa cor de verdade.
- Nenhuma pessoa, bandeira, brasão, logotipo ou marca na cena.

## Strategic Approach

### Solution Direction

Cada ícone passa a ser uma vista aérea de um lugar do Brasil, com o mapa em vidro por cima. As cenas são ilustrações vetoriais planas, geradas no projeto a partir de referências reais (fotos aéreas e de satélite dos lugares, só como referência), no mesmo estilo de camadas que o Icon Composer espera, o que mantém o vidro, o modo escuro e o tinted funcionando. Os temas deixam de ser recolor e ganham cada um o seu lugar, escolhido pela cor. Primeiro uma rodada de 3 paisagens lado a lado no iPhone, depois a ampliação para os 11, com nova parada no iPhone.

**Proposta de paisagem por ícone:**

| Ícone | Paisagem vista de cima |
| --- | --- |
| Principal (`standard`) | Amazônia ao amanhecer: copa densa cortada por um rio em meandros, com braços mortos em lua |
| Amazônia de dia (`amazonDay`) | A mesma floresta ao meio-dia, verde cheio e rio claro |
| Rio Amazonas (`amazonRiver`) | Encontro das Águas: o Rio Negro escuro e o Solimões barrento lado a lado, com a floresta nas margens |
| Floresta (`themeForest`) | Cataratas do Iguaçu: as quedas em ferradura dentro da Mata Atlântica |
| Urucum (`themeAnnatto`) | Jalapão: dunas alaranjadas, veredas e fervedouros |
| Índigo (`themeIndigo`) | Pantanal na hora azul: baías e salinas redondas entre cordilheiras de mata |
| Ipê (`themeIpe`) | Cerrado com ipês-rosa floridos vistos de cima |
| Savana (`themeSavanna`) | Chapada dos Veadeiros: cerrado dourado, cânion e veredas de buriti |
| Mar (`themeSea`) | Fernando de Noronha: o Morro Dois Irmãos, a Baía do Sancho e o mar turquesa |
| Grafite (`themeGraphite`) | Pão de Açúcar: o granito, a Baía de Guanabara e a faixa de areia |
| Areia (`themeSand`) | Lençóis Maranhenses: dunas brancas e lagoas azuis e verdes |

### Key Design Decisions

| Decisão | Escolha | Trade-off | Porta |
| --- | --- | --- | --- |
| Estilo do fundo | Ilustração vetorial plana gerada no projeto, a partir de referências reais | Coerente com o vidro, o escuro e o tinted, leve e sem licença de terceiro; perde a riqueza de uma foto | pergunta |
| Paisagem de cada ícone | A tabela acima, uma por ícone, escolhida pela cor do tema | Cada tema vira um lugar; quem escolheu "Índigo" pela cor ganha uma cena nova | pergunta |
| Nome dos temas | Passa a ser o lugar ("Lençóis", "Noronha", "Jalapão"…), com o mesmo valor bruto | O nome diz o que se vê; muda um texto já publicado em Ajustes | pergunta |
| O que fica do Fiscal | Mapa em vidro com borda branca, igual em todos | Identidade estável; o mapa cobre parte da paisagem | veto |
| Escopo | Só "Ícone do app" e "Temas"; fauna e partidos intactos | Mudança contida; a coleção de fauna continua com cena de frente | veto |
| Identificadores | Mantém os 11 valores brutos e nomes de asset | A escolha salva continua valendo; o nome em inglês do caso deixa de descrever a cena | veto |
| Gerador | Script Python no projeto que escreve as camadas SVG de cada `.icon`; o `.icon` gerado vai para o git | Repetível e revisável; mais um script em `scripts/` | reversível |
| Rodadas no iPhone | 3 paisagens primeiro (Amazônia, Lençóis, Noronha), em claro e escuro, depois os 11 | Ajusta o estilo antes de gastar nos 11 | reversível |
| Imagem do README e do site | Atualiza `.github/readme/icon*.png` com o novo principal; o site fica para quando for publicado | O README acompanha; o site só com o ok de publicação | reversível |
| Peça no kit | Nenhuma: o gerador e os ícones são do Fiscal | Nada vai para o `byescaleira-kit` | reversível |

### Alternatives Considered

- **Foto de satélite em domínio público (NASA Landsat e fotos da ISS):** real e bonita, mas em 1024 px a resolução de 15 a 30 m não mostra Noronha ou o Pão de Açúcar; no tinted e no escuro a foto vira cinza chapado e briga com o vidro; e o estilo dos 11 não ficaria coerente.
- **Sem o mapa, só a paisagem:** cada ícone ficaria mais bonito, mas o Fiscal perde a marca e vira um app de viagem.
- **Manter a cena de frente e só trocar a paisagem do horizonte:** não atende o pedido de vista de cima.
- **Ilustração gerada por IA de imagem:** licença e origem incertas para repositório público e uso comercial.

## Risk & Gap Analysis

| Critério de aceite | Coberto pela direção? | Lacuna ou risco |
| --- | --- | --- |
| Fundo visto de cima em "Ícone do app" e "Temas" | sim | — |
| Paisagens características do Brasil | sim | Lugar famoso e reconhecível de cima é difícil no tamanho de ícone; a rodada de 3 prova a leitura |
| O que identifica o Fiscal continua | sim | O mapa cobre o centro; a cena precisa de assunto fora do centro ou textura que leia em volta |
| Variantes lado a lado no iPhone antes de ampliar | sim | — |
| Licença compatível e origem registrada | sim | Referências reais só para olhar, nunca copiadas; registro no Approach do canvas |
| Escolha salva continua valendo | sim | — |

- **Riscos:**
  - Cena aérea com muito detalhe vira ruído a 60 pt → poucas formas grandes por cena, conferidas no tamanho da tela inicial e na prévia de Ajustes.
  - O vidro do mapa sobre fundo muito claro (Lençóis, Areia) perde contraste → borda branca com sombra e a lagoa escura sob o mapa, conferido no claro e no escuro.
  - O tinted e o clear do iOS desbotam a cena → cada camada tem o tom tinted próprio, conferido nas quatro aparências.
  - Pão de Açúcar e Iguaçu são lugares públicos, sem marca registrada na forma; nada de teleférico, prédio ou placa na cena.
- **Lacunas:** o pedido não diz se os nomes mudam nem se o estilo é foto ou ilustração; as duas viram pergunta, junto com a lista de paisagens.
- **Quebra:** nenhuma em dado salvo, link ou API. Muda o ícone de quem já instalou, o texto de 8 títulos em Ajustes (se os nomes mudarem) e o rodapé de "Ícone do app" ("A Amazônia ao amanhecer é o ícone principal"), que continua verdadeiro.
