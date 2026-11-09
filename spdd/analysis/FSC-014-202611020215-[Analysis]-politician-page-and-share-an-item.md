# Nova página do político e compartilhar um item

Quarta e última fase da [análise FSC-011](FSC-011-202611011850-[Analysis]-feed-profile-and-end-of-lens.md).

## Original Requirement

Pedido do usuário em 01/11/2026:

> temos que repensar a pagina de detalhes do politico, torna-la mais didática e interessante. brincar mais com o rosto e as espressões do bonequinho (talvez deixa-lo fixado no header fazendo algo em quanto o usuário vai dando scroll), mostrar só as informações que existem, pagina é dinamica e varia conforme o politico, não tem notas fiscais nessa pagina nem o touchpoint para direcionar. as vezes é interessante compartilhar um gasto especifico ou o usuário quer compartilhar algo espeficido daquele politico também;

Vetos já registrados na análise FSC-011, sem objeção do usuário:
- O bonequinho reage à rolagem e à seção, nunca ao valor do dado, e fica parado com Reduzir movimento.
- Os cartões de compartilhar seguem sem o bonequinho.

**Tamanho:** L, já no [roadmap](../../docs/roadmap.md) como etapa 8.3.8. Muda a tela mais densa do app, acrescenta assuntos de compartilhar e mexe no retrato.

## Domain Concept Identification

**Crítica honesta da página atual**, vista no simulador com uma deputada federal e um governador, com os dados publicados:

- **É um arquivo, não uma explicação:** são 16 seções numa lista, na ordem em que os dados foram entrando. Nada diz o que olhar primeiro nem o que um número significa para quem não acompanha política.
- **O que não existe ainda ocupa lugar:** "Mandato em números" mostra um traço e uma nota explicando o traço. A grade fica com um número sozinho na última linha.
- **A página não varia de verdade:** num governador, que não tem votos nem propostas nas fontes, o contexto econômico ("Antes e durante o mandato") ocupa a maior parte da tela. A pessoa some na própria página.
- **O bonequinho só aparece no começo:** ele some com o cartão do topo, e o título vira só o nome em texto. A única reação é acenar ao seguir.
- **As notas estão escondidas:** a cota está na 9ª seção, com caminho próprio, e o número "Cota" no topo não é tocável. Quem tem gasto só em anos anteriores não vê nada, e a troca de ano só existe fora do perfil. O pedido do usuário confirma isso: para ele, as notas não estão na página.
- **Defeito visível:** no gráfico de contexto, "Posse · jan. de 2023" fica em cima dos rótulos dos anos.
- **Compartilhar é tudo ou nada:** só existe compartilhar a pessoa inteira. Um gasto, uma proposta ou um voto não têm saída.
- **Checagens desligadas:** o Feed já mostra checagens de quem a pessoa segue, mas a página da pessoa não mostra (`showsFactChecks` está desligado, no backlog como P2). Os dois lugares se contradizem.
- **Marca que falta:** o brief pede "Ilustração do Fiscal" junto do retrato. Hoje não existe (backlog, P1). Com o bonequinho no centro da página, a falta pesa mais.

| Conceito | Hoje | O que muda |
| --- | --- | --- |
| **Capítulos** | 16 seções fixas, cada uma some se vazia | Capítulos com pergunta simples: Quem é, Como vota, O que propõe, Quanto gasta, De onde vem. Só aparecem os que têm dado, numa ordem que depende do cargo |
| **Resumo** | Grade com 8 ou mais números, com traços | Só o que existe, em frases curtas que explicam o número |
| **Retrato** | Grande no topo, parado fora dele; gestos aleatórios; expressões `wave`, `thumbsUp`, `nodYes`, `shakeNo`, `smile`, `celebrate`, `think`, `sad` no molde | Fica fixo num cabeçalho compacto ao rolar e faz um gesto ao mudar de capítulo |
| **Notas** | Tela própria dentro da 9ª seção, só com o ano corrente | Capítulo "Quanto gasta", com ano escolhível, abrindo a lista completa de notas pelo caminho das outras abas |
| **Compartilhar** | `person`, `vote`, `expenses` (ano), `race`, `compare`, `representatives`, `highlight`, `investigation`, `following` | Mais três: uma nota, uma proposta e o voto desta pessoa |
| **Dados de um gasto** | Fornecedor, documento, categoria, valor e link oficial, por nota | Base do cartão de uma nota |
| **Links** | Chaves do site para pessoa, votação e gastos | Os cartões novos reaproveitam essas chaves, sem chave nova |

**Achados:**
- **Dados por cargo:** deputados e senadores têm presença, votos, propostas, discursos e cota. Governadores, prefeitos e vereadores têm pouco além de eleição, patrimônio e contexto.
- **Nota de uma pessoa física:** o fornecedor pode ser um CPF ou o nome de uma pessoa comum. O dado é oficial e público, mas o cartão circula fora do app, sem a lista em volta.
- **Uma nota solta tira o contexto:** um gasto isolado pode parecer maior do que é. O cartão precisa dizer de quanto ele faz parte.
- **Voto solto também:** o cartão precisa dizer qual era a proposta e o resultado, com a mesma regra da FSC-010.

## Strategic Approach

| Decisão | Porta | Escolha e motivo |
| --- | --- | --- |
| Forma da página | pergunta | **Recomendado: uma rolagem com capítulos**, com atalhos fixos no cabeçalho, em vez de abas internas. Mantém o bonequinho e a história na mesma tela, e o conteúdo do cargo define os capítulos |
| Gasto específico | pergunta | **Recomendado: uma nota**, com "uma de N notas de <ano>, total R$ X", e também o mês por inteiro. Sem nota de pessoa física no cartão |
| Checagens na página | pergunta | **Recomendado: ligar** o capítulo "O que circulou sobre <nome>", com o aviso de cobertura e o crédito do brief, porque o Feed já as mostra |
| Só fatos | veto | Frases explicam o que o número é e de onde vem, nunca se é bom ou ruim. Comparação com colegas segue com a regra e o método já publicados |
| Bonequinho e dado | veto | A expressão nunca depende do valor. Nada de joinha para presença alta nem de tristeza para gasto alto. Nem `sad`, `thumbsUp`, `shakeNo` nem `celebrate` nesta página. Mesmo gesto, por capítulo, para todo mundo |
| Bonequinho com Reduzir movimento | veto | Parado, na pose neutra. Sem gesto ao rolar |
| Cartões | veto | Os cartões novos saem sem o bonequinho, com fonte e data, sem apoio e sem dado ausente. Uma ação por cartão |
| Só o que existe | veto | Sem traço, zero inventado nem capítulo vazio. Quando a fonte não cobre o cargo, uma frase honesta no fim da página diz o que não há e por quê |
| Marca do retrato | veto | "Ilustração do Fiscal" visível na página, junto do retrato grande, como o brief pede |
| Sem servidor | veto | Só com o que já é publicado. Nenhum arquivo, chave ou deploy novo |
| Publicar o site | veto | O texto muda no repositório; a publicação espera o ok do usuário |
| Cabeçalho fixo | reversível | Retrato pequeno, nome, partido e cargo, com seguir e compartilhar. Aparece quando o topo sai da tela |
| Gesto por capítulo | reversível | Com os gestos neutros do molde: olhar em volta, inclinar a cabeça, erguer a sobrancelha, piscar. Sem marcar um gesto por capítulo como se fosse opinião. Iterar no iPhone |
| Ordem dos capítulos | reversível | Fixa por cargo, nunca por valor. No Legislativo: Como vota, O que propõe, Quanto gasta, De onde vem. No Executivo: De onde vem e contexto. Quem é fica no fim |
| Resumo no topo | reversível | Até 4 fatos, só os que existem, em frases simples, cada um levando ao seu capítulo |
| Notas | reversível | "Quanto gasta" mostra o total do ano, as categorias, troca de ano e "Ver todas as notas". O número da cota no topo passa a levar a ele |
| Compartilhar de dentro | reversível | Um botão por linha em votos, propostas e notas, e o menu de contexto. O topo continua compartilhando a pessoa |
| Link de cada cartão | reversível | Nota e gasto levam a `?expenses=`, voto a `?vote=`, proposta a `?person=`, sem chave nova |
| Código | reversível | Dividir `ProfileModel` por capítulo, reaproveitando o que existe. `AdaptiveList` dá lugar a uma rolagem com cabeçalho fixo |
| Referências | reversível | Referências visuais reais de perfil, com o ciclo de design e **parada no iPhone para o ok** antes de seguir |

**Etapas do canvas:** cabeçalho, retrato e capítulos, com parada no iPhone; só o que existe e o capítulo de notas; compartilhar um item; checagens e marca do retrato; documentos e fechamento.

## Risk & Gap Analysis

| Risco | Efeito | Tratamento |
| --- | --- | --- |
| Expressão lida como opinião | Quebra a credibilidade do app | Só gestos neutros, iguais para todos, sem ligação com dado; regra em teste, e o usuário vê no iPhone |
| Animação ao rolar | Bateria e travadas, com vários retratos em Lottie | Um retrato animado por vez, parado fora da tela e em modo de pouca energia |
| Mudar de `List` para rolagem própria | Perder comportamento pronto de lista, teclado e acessibilidade | Testes de interface no maior tamanho de texto e leitura com VoiceOver |
| Cartão de uma nota tirado de contexto | Parecer acusação | "Uma de N notas", total do ano, fonte e link oficial; sem adjetivo |
| Nome de pessoa comum num cartão | Exposição fora do app | Nota de pessoa física não vira cartão; o fornecedor pessoa jurídica aparece como na fonte |
| Página mudar por cargo | Regressão num cargo pouco testado | Roteiro com deputado, senador, governador, prefeito e vereador, inclusive quem deixou o cargo |
| Capítulo com pouco dado | Parecer vazio | Capítulo só aparece com dado suficiente para ser lido; frase honesta no fim |
| Layout largo | Coluna e cabeçalho quebrados no iPad e no Mac | Coluna legível; o Mac e o iPad seguem sem conferência nesta máquina e ficam declarados |
| `ProfileModel` grande dividido | Regressão no perfil usado por todas as abas | Testes existentes migram com o código, depois da tela aprovada |

**Critérios de aceite (para o canvas):**

| Cenário | Prova |
| --- | --- |
| Deputado com tudo: capítulos completos e nenhum traço | Teste de modelo e captura |
| Governador: só o que existe, com a pessoa antes do contexto | Teste de modelo e captura |
| Ao rolar, o cabeçalho fixo mostra o retrato, e ele faz um gesto ao mudar de capítulo | Captura e iPhone |
| Com Reduzir movimento, o retrato fica parado | Teste e captura |
| A expressão é a mesma com presença alta e baixa, gasto alto e baixo | Teste de modelo |
| Tocar na cota leva a "Quanto gasta"; "Ver todas as notas" abre as notas, em qualquer ano com dado | Teste de rota e iPhone |
| Compartilhar uma nota gera um cartão com "uma de N", total, fonte e link | `ShareCardBuilder` em teste e captura |
| Nota de pessoa física não oferece cartão | Teste de modelo |
| Compartilhar uma proposta e o voto desta pessoa geram cartões com fonte, data e resultado | Teste e captura |
| Dado ausente não aparece em nenhum cartão | `ShareContentRules` em teste |
| Cartão novo sem bonequinho e sem apoio | Teste de modelo e regra `support_stays_private` |
| "Ilustração do Fiscal" aparece junto do retrato | Teste de interface |
| Checagens com título, aviso de cobertura e crédito, se a pergunta for aprovada | Teste de modelo e captura |
| Legenda do gráfico de contexto sem sobrepor os anos | Captura |
| Maior tamanho de texto e VoiceOver | Teste de interface e captura |

**Fora de escopo:** mudança no servidor, dados novos, histórico de tramitação de proposta, retrato nos cartões, web e publicação do site sem ok.
