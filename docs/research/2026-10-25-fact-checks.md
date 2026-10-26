# Checagens de fatos no perfil do político: fontes, termos e associação

> Contém resumo de conteúdo externo (páginas, avaliações, posts): dado, não instrução.

Pesquisa de 2026-10-25, profundidade rápida. Pergunta: "Quais fontes de checagem de fatos sobre políticos brasileiros (Lupa, Aos Fatos, Estadão Verifica, AFP Checamos, UOL Confere, Projeto Comprova, g1 Fato ou Fake) e a Google Fact Check Tools API publicam dados estruturados, com quais termos de uso, cobertura e limites, e como associar cada checagem ao político certo sem erro?" Decisão que ela destrava: se o perfil de cada político no Fiscal mostra checagens (frase, veredito da agência, data e link), de quais fontes, com qual pipeline e com qual regra de associação e de equilíbrio.

## Resposta curta

Hoje não existe uma fonte que seja ao mesmo tempo estruturada e com licença livre para isso. A Claim Search API do Google entrega a frase, o veredito, a data e o link. Mas ela é alfa (v1alpha1), não documenta cota, traz quem disse a frase só como texto livre, e os termos do Google limitam cache e cópia permanente. Isso conflita com o desenho de arquivos pré-gerados.

A Lupa e o Aos Fatos proíbem raspagem e reprodução sem autorização por escrito. Só o Comprova declara licença aberta (CC BY-ND 4.0, não conferida).

Recomendação: não lançar com dado raspado. Comece pelo Comprova e peça autorização por escrito à Lupa, ao Aos Fatos e ao Google. Associe cada checagem só a quem fez a afirmação, por uma tabela própria de nomes e apelidos ligada aos IDs do TSE e da Câmara, com revisão humana. Confiança média na parte técnica e baixa na parte jurídica.

## Achados

| Achado | Confiança | Fontes |
| --- | --- | --- |
| A Fact Check Tools API tem dois serviços. A ClaimReview Read/Write é para quem publica e exige autorização no Search Console. A Claim Search consulta os mesmos resultados do Fact Check Explorer e exige chave de API. Os dois seguem os Termos de Serviço das APIs do Google. Página atualizada em 2023-05-25. | média | [Fact Check Tools API (Google for Developers)](https://developers.google.com/fact-check/tools/api) |
| O claims:search (v1alpha1) aceita query (obrigatória, salvo com reviewPublisherSiteFilter), reviewPublisherSiteFilter (um domínio por chamada), languageCode (BCP-47, sem região), maxAgeDays, pageSize (padrão 10, máximo não documentado), pageToken e offset (ignorado quando há pageToken). Dá para listar por domínio de agência sem texto de busca. | alta | [Method: claims.search (Fact Check Tools API, v1alpha1)](https://developers.google.com/fact-check/tools/api/reference/rest/v1alpha1/claims/search) |
| Uma chamada sem chave ao claims:search devolveu HTTP 403. Isso foi observado pela conferência, não está escrito na fonte. | média | [Method: claims.search (Fact Check Tools API)](https://developers.google.com/fact-check/tools/api/reference/rest/v1alpha1/claims/search) |
| A resposta traz Claim com text, claimant (string livre), claimDate e claimReview[], e cada ClaimReview traz publisher (name, site), url, title, reviewDate, textualRating e languageCode. Não há ID de pessoa, partido nem cargo. ClaimAuthor e sameAs existem só no lado de escrita da API. | média | [REST Resource: claims (Fact Check Tools API)](https://developers.google.com/fact-check/tools/api/reference/rest/v1alpha1/claims) |
| Nem a documentação nem os termos da API trazem cota numérica para o claims:search. A cota real aparece só no console do Google Cloud do projeto. | média | [Fact Check Tools API Terms of Service](https://developers.google.com/fact-check/tools/api/terms) |
| Os termos das APIs do Google (modificados em 2021-11-09) dizem que o Google define e aplica limites a seu critério. Eles proíbem raspar, montar bancos de dados ou cópias permanentes e guardar cache além do que o cabeçalho permite. Exigem a atribuição pedida pela documentação e vedam sugerir endosso do Google. Não conferida. | baixa | [Google APIs Terms of Service](https://developers.google.com/terms) |
| Em 2025-06-12 o Google anunciou que deixaria de dar suporte ao ClaimReview nos resultados da Pesquisa. Em 2025-09-08 cortou os relatórios do Search Console para esses tipos. Segundo o anúncio, o uso fora da Pesquisa não é afetado. Não conferida. | baixa | [Simplifying the search results page (Google Search Central Blog)](https://developers.google.com/search/blog/2025/06/simplifying-search-results) |
| A página de ClaimReview do Google (atualizada em 2026-09-08) diz que a marcação continua suportada no Fact Check Explorer. Exige claimReviewed, reviewRating com alternateName e url. Só recomenda itemReviewed.author, ou seja, quem disse a frase nem sempre vem estruturado. Não conferida. | baixa | [Fact check (ClaimReview) structured data (Google Search Central)](https://developers.google.com/search/docs/appearance/structured-data/factcheck) |
| O Poynter (2025-07-21) relata que os destaques de checagem sumiram da Busca e que o ClaimReview segue como padrão aberto do Schema.org. Bill Adair (Duke) pediu aos checadores que continuem marcando e mantenham base própria. | média | [Google removes ClaimReview fact-check snippets from search (Poynter/IFCN)](https://www.poynter.org/ifcn/2025/google-claimreview-fact-checks-snippets-removed/) |
| O schema.org identifica quem fez a afirmação em itemReviewed.author (Person com name e sameAs opcional), separado de about e mentions. O blog do Schema.org (2021-12-09) recomenda o Wikidata como alvo comum de sameAs. | média | [ClaimReview - Schema.org Type](https://schema.org/ClaimReview), [Enriching Claim Reviews (Schema.org blog)](https://blog.schema.org/2021/12/09/the-art-of-connection/) |
| O feed ClaimReview do Data Commons é CC BY 4.0, mas a licença vale só para a marcação: cada registro traz a sua em sdLicense, e o artigo segue os termos do publicador. O arquivo passa de 10 MB e não foi inspecionado. Não conferida. | baixa | [Fact Checks - Data Commons](https://datacommons.org/factcheck/download) |
| A FAQ do Data Commons cita só agências dos EUA na versão inicial (FactCheck.org, Snopes, PolitiFact, Washington Post, Weekly Standard) e não menciona agências brasileiras. | média | [Fact Checks FAQ - Data Commons](https://datacommons.org/factcheck/faq) |
| Os termos da Lupa (2025-11-04) dizem que reproduzir, adaptar ou distribuir o conteúdo exige autorização prévia, que o uso é só pessoal e não comercial e que scraping e mineração são proibidos (3.1 a 3.3). O domínio lupa.news redireciona para agencialupa.org. Não conferida. | baixa | [Termos de Uso (Agência Lupa)](https://www.agencialupa.org/termos-de-uso/) |
| Os termos do Aos Fatos (2024-07-07) proíbem copiar e reformatar o conteúdo e fazer coleta automatizada sem consentimento por escrito (4.2, 8.6). O item 4.4 permite uso nos limites da lei, com crédito e link. Não há API. O site diz que licencia checagens a plataformas. Não conferida. | baixa | [Termos de uso (Aos Fatos)](https://www.aosfatos.org/termos-de-uso/), [Sobre o Aos Fatos](https://www.aosfatos.org/sobre-o-aos-fatos/) |
| O Projeto Comprova declara na metodologia a licença CC BY-ND 4.0: dá para republicar com crédito e sem alterar. Foi a única licença aberta explícita achada. Não conferida. | baixa | [Metodologia (Projeto Comprova)](https://projetocomprova.com.br/about/metodologia/) |
| O feed RSS do Comprova só tem 3 itens de 2019, dois de teste, e o selo fica só no corpo do texto. | média | [Projeto Comprova (feed RSS)](https://projetocomprova.com.br/feed/) |
| O feed RSS 2.0 da Lupa (em 2026-10-25) traz título, link, data e categorias com nomes de políticos (Flávio Bolsonaro, Lula, Erika Hilton). Também traz categorias que não são de políticos, como Ronaldo, Meta e TSE. O veredito aparece só no título e no selo da página. Não conferida. | baixa | [Feed RSS - Agência Lupa](https://www.agencialupa.org/feed/) |
| O feed RSS do Aos Fatos não tem category, e alguns links vêm com o domínio duplicado. A página de cada checagem traz a tag do político, e o veredito aparece no título (exemplo: "É falso que PCC e CV declararam apoio a Lula", 2026-10-09). | média | [Feed RSS - Aos Fatos](https://www.aosfatos.org/noticias/feed/), [É falso que PCC e CV declararam apoio a Lula](https://www.aosfatos.org/noticias/pcc-comando-vermelho-apoio-lula-falso/) |
| O Aos Fatos agrupa checagens por pessoa em URLs do tipo noticias/?termometro={slug}, para cerca de nove pessoas (Lula, Flávio, Eduardo e Jair Bolsonaro, Zema, Caiado, Tarcísio, Renan Santos, Trump). A listagem não mostra data nem selo. Não conferida. | baixa | [Notícias - termômetro Lula (Aos Fatos)](https://www.aosfatos.org/noticias/?termometro=lula) |
| Uma checagem do Aos Fatos (2026-09-17) junta Lula e Flávio Bolsonaro e seis afirmações num só artigo, e só uma tem selo explícito. Mostrar o título no perfil de um deles pode atribuir a ele a falha do outro. Não conferida. | baixa | [Lula e Flávio citam informações falsas e imprecisas ao repercutir crise no STF (Aos Fatos)](https://www.aosfatos.org/noticias/lula-flavio-crise-stf/) |
| Muitas checagens de 2026 tratam de conteúdo viral contra o político, e não de frase dita por ele. Exemplo: a capa falsa da Folha sobre propinas de Lula (2026-10-25), de autor desconhecido. Não conferida. | baixa | [É falsa capa da Folha de S. Paulo sobre supostos R$ 300 bilhões em propinas de Lula (Lupa)](https://www.agencialupa.org/verificacao/2026/10/25/e-falsa-capa-da-folha-de-s-paulo-sobre-supostos-r-300-bilhoes-em-propinas-de-lula/) |
| A política editorial do Aos Fatos tem três selos (VERDADEIRO, NÃO É BEM ASSIM, FALSO). Diz que checa todo o espectro, com mais escrutínio sobre quem está no poder, e que não checa opinião nem promessa. Cada agência usa uma escala própria. Não conferida. | baixa | [Política editorial - Aos Fatos](https://www.aosfatos.org/politica-editorial) |
| O Aos Fatos (2025-07-07) diz ter feito mais de 19 mil checagens e checado 167 figuras públicas, com 4.851 alegações únicas de Bolsonaro, puxadas pelo contador de 2019 a 2022. A cobertura se concentra em poucos nomes, e os números da matéria não batem entre as seções. Não conferida. | baixa | [Como a desinformação transformou o debate político em dez anos (Aos Fatos)](https://www.aosfatos.org/noticias/desinformacao-transformou-debate-politico-dez-anos/) |
| O Estadão Verifica aparece como autor de ClaimReview num espelho de terceiros (CIMPLE, da EURECOM). Não há confirmação no site do Estadão. | baixa | [CIMPLE Explorer: claim-review (Estadão Verifica)](https://explorer.cimple.eu/claim-review/5df4cbf732368f5adb6edaa0e981a0e4ef91ce2ec56b74c8cfc8da4b) |
| O FACTCK.BR (2019) coletou 1.309 afirmações em ClaimReview de agências brasileiras, com 14 rótulos de veredito e licença MIT. Mostra que a marcação brasileira existiu, mas é um retrato de 2019. | média | [FACTCK.BR: A New Dataset to Study Fake News](https://sol.sbc.org.br/index.php/webmedia/article/view/8073) |
| Os registros do IFCN achados são antigos: Lupa (2022, conforme), Estadão Verifica (signatário desde 2019), UOL Confere (selo válido até 2024-11-02). O status de 2026 não foi confirmado. | média | [Lupa - IFCN Code of Principles](https://mail.ifcncodeofprinciples.poynter.org/application/public/lupa/282CC55D-2D3A-8E87-A7B2-5E98981262F0), [UOL Confere (IFCN)](https://mail.ifcncodeofprinciples.poynter.org/profile/uol-confere) |
| Comprova e Lupa seguem publicando checagens com data de 24 e 25/10/2026, no segundo turno de 2026. | média | [Projeto Comprova (página inicial)](https://projetocomprova.com.br/), [Agência Lupa (página inicial)](https://www.agencialupa.org/) |
| O TSE publica o conjunto "Candidatos - 2026" em CC BY, atualizado quatro vezes por dia, com SQ_CANDIDATO, NR_CPF e NM_URNA. A API da Câmara devolve id, nome, partido e foto por deputado (campos exatos não confirmados). | média | [Candidatos - 2026 (TSE)](https://dadosabertos.tse.jus.br/dataset/candidatos-2026), [Dados Abertos da Câmara - API](https://dadosabertos.camara.leg.br/swagger/api.html) |
| A diretriz 5.2.2 da App Store exige autorização específica nos termos do serviço de terceiros cujo conteúdo o app exibe, a ser apresentada se a Apple pedir. A 1.1.1 veda difamação. Não conferida. | baixa | [App Review Guidelines - Apple Developer](https://developer.apple.com/app-store/review/guidelines/) |
| O art. 46 da Lei 9.610/98 permite reproduzir na imprensa notícia ou artigo informativo com autor e origem (I, a) e citar passagens para crítica, na medida do necessário (III). A jurisprudência é restritiva e não unânime. Não é parecer jurídico. | baixa | [Lei de Direitos Autorais - art. 46 (modeloinicial)](https://modeloinicial.com.br/lei/L-9610-1998/array-0x564bbcef85c0/art-46), [EBC não pode reproduzir conteúdo do Valor Econômico (Migalhas)](https://www.migalhas.com.br/quentes/188126/ebc-nao-pode-reproduzir-conteudo-do-jornal-valor-economico) |
| A Meta encerrou a checagem por terceiros nos EUA em janeiro de 2025. No Brasil disse que as agências ficam "por enquanto", o que é um risco de continuidade para elas. | média | [Abraji se opõe à ruptura da Meta com agências de checagem (Congresso em Foco)](https://www.congressoemfoco.com.br/area/mundo-cat/abraji-se-opoe-a-ruptura-da-meta-com-agencias-de-checagem/) |
| Nenhum app brasileiro mostra checagens por político: a busca em português na App Store devolveu zero resultados. Nos EUA aparecem Snopes (4,79, 833 avaliações) e Govvy (4,13, 98). | média | [iTunes Search API: politicians fact check (US)](https://itunes.apple.com/search?term=politicians%20fact%20check&entity=software&country=us&limit=25), [iTunes Search API: fact check (BR)](https://itunes.apple.com/search?term=fact%20check&entity=software&country=br&limit=25) |
| Um artigo de opinião (2026-10-21) acusa tratamento desigual entre direita e esquerda pelas agências e diz que o pico de buscas da Lupa em 2026 foi 68% menor que em 2022. É opinião de veículo crítico às agências, não prova de viés. | baixa | [Por onde andam as agências de checagem (Gazeta do Povo)](https://www.gazetadopovo.com.br/ideias/por-onde-andam-as-agencias-de-checagem/) |

## Referências do mercado

| Produto | O que faz bem | O que trazer |
| --- | --- | --- |
| [Google Fact Check Explorer e Claim Search API](https://developers.google.com/fact-check/tools/api) | Junta o ClaimReview de várias agências numa consulta, com frase, veredito, data e link | Usar como descoberta (achar a checagem e o link), não como base copiada, até haver confirmação dos termos |
| [Data Commons Fact Check feed](https://datacommons.org/factcheck/download) | Feed aberto com licença por registro e link ao original | Ler o sdLicense de cada registro antes de qualquer uso |
| [Full Fact API and Content Syndication Licence](https://fullfact.org/api/license/) | Licença de sindicação: checagem inteira, sem alterar, com link de volta | Usar como roteiro do pedido de autorização às agências brasileiras |
| [Projeto Comprova](https://projetocomprova.com.br/about/metodologia/) | CC BY-ND 4.0 declarada | Primeira fonte do piloto, com crédito e sem reescrever |
| [Agência Lupa (RSS)](https://www.agencialupa.org/feed/) | Categorias com nomes de políticos | Sinal de candidato para a associação, só depois de autorizado |
| [Aos Fatos (termômetro)](https://www.aosfatos.org/noticias/?termometro=lula) | Slug estável por pessoa pública | Ideia de chave por pessoa; uso só com autorização |
| [CIMPLE Explorer (EURECOM)](https://explorer.cimple.eu/claim-review/5df4cbf732368f5adb6edaa0e981a0e4ef91ce2ec56b74c8cfc8da4b) | Marca as entidades citadas em cada afirmação | Separar quem disse de quem é citado |
| [FACTCK.BR](https://sol.sbc.org.br/index.php/webmedia/article/view/8073) | Rótulos de veredito brasileiros em escala de dados | Base para o mapa de rótulos usado só nos filtros |
| [Snopes (iOS, EUA)](https://itunes.apple.com/search?term=politicians%20fact%20check&entity=software&country=us&limit=25) | App de checagem bem avaliado | Cartão simples com selo e link à fonte |
| [Govvy: US Politicians](https://itunes.apple.com/search?term=politicians%20fact%20check&entity=software&country=us&limit=25) | Perfil por político, o mais perto do formato do Fiscal | Checagens como uma seção do perfil, não como o centro dele |
| Ground News (iOS) | Compara a cobertura por viés político (4,71, 48.804 avaliações) | Deixar visível de onde vem cada item, como regra de equilíbrio |

## O que trazer para o produto

1. **Piloto com o Comprova:** é a única licença aberta achada (CC BY-ND 4.0). Mostrar a frase, o selo, a data e o link sem reescrever cabe na licença. Antes, confirmar a licença (não conferida) e ver com advogado se um cartão resumido conta como derivação.
2. **Autorização por escrito antes de Lupa e Aos Fatos:** os termos das duas proíbem reprodução e raspagem. A diretriz 5.2.2 da App Store pede que a autorização possa ser apresentada. Use o modelo do Full Fact como roteiro do pedido (no Aos Fatos, o contato indicado é ouvidoria@aosfatos.org).
3. **Job agendado, com consulta ao Google antes:** a Claim Search é alfa e sem cota documentada, e os termos limitam cache e cópia permanente. Pré-gerar arquivos com o resultado da API fica em zona cinzenta. Confirme com o Google (factcheck-support@google.com) e, enquanto isso, use a API só para descobrir links de checagens de fontes já autorizadas.
4. **Associação só por quem fez a afirmação:** o claimant é texto livre, e há artigos com vários políticos e checagens de conteúdo feito contra o político. Por isso:
   - manter uma tabela própria de nomes e apelidos, ligada ao ID do TSE (SQ_CANDIDATO) ou da Câmara;
   - publicar só quando houver correspondência exata e única;
   - mandar homônimos, artigos com várias pessoas e casos sem autor para revisão humana.
5. **Selo original da agência:** cada agência tem escala própria (o Aos Fatos usa três selos; o FACTCK.BR achou 14 rótulos). Mostrar o rótulo como veio e usar um mapa de normalização só para filtrar e contar.
6. **Mesma regra para todos:**
   - mesmo conjunto de agências e mesmo cartão em todos os perfis;
   - contagem "N checagens de M agências" por selo, em vez de uma nota;
   - todas as checagens da janela, não só as falsas;
   - regra de inclusão publicada no site.

   Isso responde à crítica de desequilíbrio e ao fato de a cobertura se concentrar em quem está no poder.
7. **Aviso de cobertura no perfil:** a maioria dos 513 deputados terá zero checagens. O perfil deve dizer que a lista reflete o que as agências escolheram checar e que a ausência não quer dizer "sem falsidades".
8. **Revalidação periódica:** a API pode mudar, os rótulos são texto livre e links quebram. O job deve conferir os links e o status IFCN das agências de tempos em tempos.

## O que não trazer

- **Raspar Lupa ou Aos Fatos:** os dois termos proíbem, e isso pode derrubar o app na revisão da App Store.
- **Associar pelo título, pelas tags ou por quem é citado:** a capa falsa sobre Lula e o artigo Lula e Flávio mostram que isso põe na boca de um político a falsidade de outro ou um conteúdo feito contra ele.
- **Selo, nota ou manchete criados pelo Fiscal:** o app não deve reclassificar o veredito nem comentar a checagem. Isso evita o risco de difamação (diretriz 1.1.1) e a acusação de viés.
- **Mostrar só as checagens falsas:** reforça a crítica de seleção desigual.
- **Chamar a API do Google a cada visita:** exigiria servidor com a chave, o que contraria o desenho estático e expõe a chave.
- **Usar o feed do Data Commons sem inspeção:** não se sabe se há agências brasileiras nele, e a licença da marcação não cobre o artigo.

## Contradições e incertezas

- **Termos do Aos Fatos:** uma pesquisa leu os termos do site (atualizados em 2024-07-07). Outra só achou os termos da plataforma Aos Fatos Mais e não achou termos separados do site público. Abrir as duas páginas e comparar resolve.
- **Feeds do Aos Fatos:** uma fonte diz que /feed/ dá 404 e outra que /noticias/feed/ funciona. São URLs diferentes, mas vale confirmar qual é o feed oficial.
- **Datas das páginas do Google:** a página da API aparece como "sem data" e também como "atualizada em 2023-05-25". A página de ClaimReview aparece sem data e com 2026-09-08. A numeração das seções dos termos (5.e, 5.e.1, 8.b) varia entre as leituras, e os termos não foram conferidos.
- **Futuro da Claim Search:** não há aviso oficial de fim nem de garantia depois da saída do ClaimReview da Busca em 2025. Só a página de Search diz que o Explorer segue suportado.
- **Afirmações decisivas não conferidas:** a licença do Comprova, os termos de Lupa e Aos Fatos, os termos do Google e a diretriz 5.2.2. Uma leitura direta, mais um parecer jurídico, resolve.
- **Quem publica ClaimReview hoje:** não está confirmado para nenhuma agência brasileira. Com uma chave de API, rode claims:search com reviewPublisherSiteFilter para cada domínio (agencialupa.org, aosfatos.org e os demais) e veja o JSON-LD no código-fonte das páginas.
- **Números do Aos Fatos:** a matéria dos 10 anos não fecha entre as seções.
- **Viés das agências:** a crítica da Gazeta do Povo é opinião. Não se achou estudo da distribuição de checagens por partido.

## O que não foi pesquisado

- g1 Fato ou Fake, AFP Checamos, UOL Confere e Estadão Verifica: as páginas não abriram (domínios bloqueados pela ferramenta ou sem termos achados). Termos, RSS e ClaimReview dessas quatro ficaram sem verificação.
- O JSON-LD das agências: a ferramenta só devolve texto renderizado, então "não vi" não prova que não existe.
- Uma chamada real à Claim Search com chave: não foi criada chave. Ficaram em aberto a cota padrão, a cobertura em pt-BR e a lista de agências brasileiras no Explorer.
- O conteúdo do feed do Data Commons (mais de 10 MB) e o texto integral do post do Google de junho de 2025. O Nieman Lab (403) e a EBU (404) também falharam.
- O status IFCN de 2026 de todas as agências: a lista oficial carrega por JavaScript.
- O art. 8 da Lei 9.610/98 (o site do Planalto falhou) e a Resolução TSE 23.610, que só tem fontes secundárias. Nada aqui é parecer jurídico.
- IDs de senadores e do executivo, a propriedade do ID da Câmara no Wikidata, os campos exatos da API da Câmara e o tratamento de homônimos.
- Avaliações e ranking de apps gratuitos no Brasil, além das buscas por termo. A página Fato ou Boato do [TSE](https://www.tse.jus.br) não foi aberta.
- Nenhum dos ângulos (tecnologia, risco e referências) falhou por inteiro; as lacunas acima são parciais.