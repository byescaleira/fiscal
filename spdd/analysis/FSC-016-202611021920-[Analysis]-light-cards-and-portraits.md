# Cartões no modo claro e bonequinho de todos

## Original Requirement

Pedidos do usuário em 02/11/2026, ao ver o app no iPhone:

> Será que aquele card no início da tela detalhe da votação verde preto e vermelho tivesse o modo dark e o modo light, pq pra mim ele só está modo dark, vários cards estão assim no app, escuros para o modo light.

> Outra coisa devemos ter o boquinho para todos os políticos que vão assumir em 2027, vi aqui que tem vario que não tem (estão genéricos), como o Eduardo Riedel

**Tamanho:** M, uma fase em duas etapas com parada no iPhone: primeiro os bonequinhos, que são rápidos e independentes, depois os cartões.

## Domain Concept Identification

**Crítica honesta, com o que foi medido em 02/11/2026:**

**Bonequinho genérico**
- **Não falta desenho.** As 2.356 pessoas publicadas (`index/people.json` e `places/<uf>.json`) têm traços no app, inclusive as 1.668 que aparecem como eleitas em alguma das listas.
- **O problema é a regra.** O app só usa os traços se o partido gravado neles for igual ao partido do dado que chegou. Se não for, desenha o rosto neutro.
- **Quantos:** 246 pessoas nas listas por estado (240 eleitas e 6 em mandato) e 8 no índice geral.
- **Por que varia:** o partido da mesma pessoa muda de um arquivo para outro. São 264 pessoas com partidos diferentes entre o índice e as listas. Riedel é PSDB e "em mandato" no índice, e PP e "eleito" na lista de MS. Os traços dizem PP, então ele aparece desenhado numa tela e genérico em outra. O mesmo acontece com Arthur Henrique, visto com o rosto neutro no cartão de Região e desenhado em outra lista.
- **A regra protegia contra quê:** contra usar o rosto de uma pessoa em outra de mesmo identificador. Medido hoje: nenhum dos 2.356 identificadores publicados tem nome diferente do gravado nos traços. Só 2 têm outro estado (`flavio-bolsonaro` e `rosangela-moro`), e são as mesmas pessoas. A roupa e o fundo já usam o partido que chega, não o dos traços.

**Cartões escuros no modo claro**
- **Placar da votação:** gradiente verde, preto e vermelho, com os mesmos valores nos dois modos (`voteYesBoard`, `voteNoBoard`) e texto branco fixo (`BoardStyle`).
- **Modo escuro forçado em 13 pontos:**
  - 9 são cartões dentro de telas: `VoteHeroSection`, `ProfileHero`, `RegionGovernment`, `RegionNow`, `RaceWinnerCard`, `SearchHub`, `InvestigationConclusion`, `PastRaceSections` e `StudyGuideScreen`;
  - 4 são cartazes de compartilhar, em `ShareZoneArt`, `ShareDataView` e `ShareCardView`.
- **Sem forçar, mas com o mesmo efeito:** fundo próprio e branco fixo em `FeedHighlightHero`, `RaceHeroCard`, `RaceHeroHeader`, `RaceCompactCard`, `PastWinnerCard`, `PastCardParts` e `CompareParts`.
- **`PartyBackdrop`:** a cor do partido passa por uma película escura nos dois modos.
- **O resto do app** já segue o modo: fundo branco e cartões em cinza do sistema no claro. Por isso esses cartões parecem de outro aplicativo no modo claro.

| Conceito | Hoje | O que muda |
| --- | --- | --- |
| **Retrato de uma pessoa** | Identificador e partido iguais | Só o identificador; a cor continua vindo do partido que chega |
| **Conferência dos traços** | Nenhuma | Um teste garante que cada identificador publicado na fixture real aponta para o nome certo |
| **Cartão de destaque** | Escuro nos dois modos | Versão clara e versão escura, com contraste medido |
| **Cor do partido e do voto** | Fundo saturado sob película | Continua dizendo o partido e o voto, com a superfície seguindo o modo |
| **Cartaz de compartilhar** | Escuro | Igual: vira imagem e sai do app |

**Achados:**
- **Fato errado à vista:** a mesma pessoa aparece com dois partidos conforme a tela. Isso não é só retrato, é dado. Vem de como o servidor monta o índice e as listas, e os dados publicados estão parados em 28/10.
- **Widgets e Atividade ao Vivo:** têm placar e retrato próprios. A mudança do retrato chega a eles pela mesma biblioteca, mas o visual deles fica fora.
- **Testes:** `PortraitLibraryTests` hoje exige o rosto neutro com outro partido, e essa expectativa muda.

## Strategic Approach

| Decisão | Porta | Escolha e motivo |
| --- | --- | --- |
| Quais cartões ganham versão clara | pergunta | **Recomendado: todos os cartões dentro das telas**, os 9 forçados e os 7 com fundo próprio, para o modo claro ficar coerente |
| Como fica o cartão no modo claro | pergunta | **Recomendado: superfície clara com a cor suave**, texto escuro e a cor forte só nos sinais (filete, número, círculo). As referências reais são conferidas antes de desenhar. Iterar no iPhone |
| Partido divergente entre os arquivos | pergunta | **Recomendado: mudança separada, logo depois desta**, junto com a causa da carga parada, porque pede servidor e deploy |
| Retrato pelo identificador | veto | Sai a exigência de partido igual. Medido: nenhum identificador publicado tem outro nome |
| Traços continuam descritos a partir da foto oficial | veto | Nada gerado por IA, nada novo a descrever nesta fase |
| Mesmo desenho para todos | veto | A regra de retrato continua igual para todos, sem depender de quem a pessoa apoia |
| Só fatos | veto | A cor do Sim e do Não e a do partido continuam só como informação; nenhum tom novo sugere juízo |
| Contraste medido | veto | Texto e sinais conferidos nos dois modos, com Aumentar contraste e Reduzir transparência |
| Cartazes de compartilhar | veto | Não mudam, porque viram imagem |
| Sem servidor nesta fase | veto | Nenhuma mudança em `server/`, nem deploy, nem publicação |
| Ajuste de Aparência | veto | O claro e o escuro escolhidos em Ajustes valem também para esses cartões |
| Película e cor do partido | reversível | Partir de uma camada clara sobre a cor do partido e ajustar no iPhone |
| Tokens de cor | reversível | Superfície e texto de cartão como tokens com claro e escuro, no design system do app; o que for genérico vai para o kit |
| Ordem dos cartões | reversível | Placar da votação primeiro, como modelo, e parada no iPhone antes dos outros |
| Referências | reversível | Olhar FotMob, Apple Sports e o Tempo da Apple nos dois modos antes de desenhar; ainda não foram conferidos para esta mudança |

**Etapas do canvas:** retrato pelo identificador, teste e parada no iPhone; placar da votação como modelo, com parada no iPhone; os demais cartões; documentos e fechamento.

## Risk & Gap Analysis

| Risco | Efeito | Tratamento |
| --- | --- | --- |
| Rosto da pessoa errada | O risco mais grave para a credibilidade | Teste com o identificador e o nome; conferência dos 2.356 repetida antes do merge |
| Identificador novo em carga futura | Pessoa nova cai em homônimo antigo | A conferência entra no teste com a fixture, e o que não tiver traços continua neutro |
| Contraste com cores de partido claras | Texto ilegível em alguns partidos | Medir com a paleta inteira, não só com o caso bonito |
| Cartão perder a força visual | App fica sem identidade no claro | Iterar no iPhone até o ok, como nas outras telas |
| Muitos arquivos de uma vez | Regressão no modo escuro | Modo escuro igual ao de hoje, conferido em captura |
| Partido divergente continuar visível | O bonequinho volta, mas a pessoa segue com dois partidos | Declarado no PR e no backlog até a mudança separada |
| Dados parados em 28/10 | Quem assume em 2027 pode estar desatualizado | Fora desta fase; a conferência é repetida depois da próxima carga |

**Critérios de aceite (para o canvas):**

| Cenário | Prova |
| --- | --- |
| Riedel e Arthur Henrique desenhados em qualquer tela, mesmo com outro partido no dado | Teste de modelo e captura |
| Todas as pessoas publicadas com traços aparecem desenhadas | Conferência dos 2.356 com o arquivo publicado |
| Pessoa sem traços continua com o rosto neutro | Teste de modelo |
| A roupa e o fundo usam o partido que o dado traz | Teste de modelo |
| Placar da votação com versão clara e escura | Captura dos dois modos, iPhone |
| Cartões de Região, político, Feed, corrida, Fiscalizar e Memória nos dois modos | Captura dos dois modos, iPhone |
| Modo escuro igual ao de hoje | Comparação de capturas |
| Ajuste de Aparência vale para os cartões | Simulador |
| Contraste conferido, com Aumentar contraste e Reduzir transparência | Medida e captura |
| Cartazes de compartilhar sem mudança | Testes existentes e captura |

**Fora de escopo:** servidor e partido divergente, carga parada, descrever novos traços, widgets, Atividade ao Vivo, cartazes, ícone do app.
