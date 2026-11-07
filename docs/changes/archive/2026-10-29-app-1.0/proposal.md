# Fiscal 1.0: dados federais e estaduais, 5 abas, Lente, arte e compartilhamento

Proposta da mudança `app-1.0`.

- **Estado:** entregue (arquivada em 2026-10-29; o que saiu está em "O que foi entregue", no fim)
- **Data:** 2026-10-25
- **Branch:** `feature/app-1.0`, com cada frente na sua `feature/app-1.0-<frente>`, integradas pelo coordenador

## Por quê

O usuário pediu, em 2026-10-25, "fazer todo o restante do app numa tacada só com as novas diretrizes e depois (no final) fazer as validações". As decisões dele:
- **escopo:** federal mais estados;
- **revisão visual:** uma rodada no fim, com todas as seções;
- **imagens:** download das obras em domínio público, com checagem de licença;
- **paralelismo:** workflow multiagente;
- **preço:** o app é totalmente gratuito.

Cobre as fases 2 a 8 do [roadmap](../../../roadmap.md), seguindo o [brief](../../../brief.md) e o [contrato](contract.md).

## O que muda

1. **Base:**
   - só português (ADR 0003);
   - sem compras;
   - sem o exemplo `Item`;
   - 5 abas, com Fiscalizar como aba de busca;
   - Ajustes na toolbar;
   - domínio e cliente dos dados públicos, com cenários de teste.
2. **Servidor de dados** (Go, `server/`):
   - carga da Câmara, do Senado, do TSE (incluindo governadores e deputados estaduais), do IBGE, da Receita e das assembleias com dado aberto;
   - classificação por tema e ementa em linguagem simples;
   - publicação dos arquivos do contrato.
3. **Telas:**
   - Hoje, Meus com o perfil, Votações, Dinheiro e Fiscalizar (Comparar e Eleições);
   - checagens de fatos no perfil, das agências sobre cada político, com veredito, data e link (brief, "As 5 abas"), depois da pesquisa de fontes e termos de uso;
   - cada uma passa pelo ciclo de design por seção (referência visual real e dados de teste), com a revisão visual do usuário numa rodada só, no fim.
4. **Lente e arte:**
   - o setup em 3 passos e a aparência (paletas espelhadas, ícones alternativos);
   - o ícone do app com a identidade do Fiscal, pelo ciclo de design (referências, conceitos instalados no iPhone como ícones alternativos, escolha do usuário), no lugar da estrela do template;
   - o acervo em domínio público com `art-credits.json`;
   - a galeria de artistas.
   - retratos animados dos políticos e selos dos partidos em Lottie, no estilo do Fiscal (brief, "Aparência pela Lente"), com o retrato genérico para quem ainda não tem traços.
5. **Compartilhar:** cards de Stories, feed e mensagem para perfil, votação, gastos, apuração e comparação, com o crédito gravado na imagem.
6. **Integrações:**
   - widgets (meus representantes, votação do dia);
   - App Intents com Siri ("como meu deputado votou?");
   - Spotlight dos perfis.

## Fora do escopo

- Prefeitos, vereadores e STF.
- Broadcast push (a apuração continua por token).
- Publicação na loja e TestFlight externo.
- Arte encomendada e licenças pagas (decisão do usuário em 2026-10-25: "só o que é livre por agora"; a encomenda a artistas atuais vai para o roadmap).

## Verificação (no fim, uma vez)

- `scripts/verify.sh --full`: lint, build das 3 plataformas, a suíte inteira, web e admin.
- Testes do servidor com `-race` e `govulncheck`.
- Revisores de design, acessibilidade, código e segurança sobre o diff inteiro.
- Capturas de todas as seções no iPhone, para a rodada de revisão do usuário.
- Deploy da carga na VPS, com o ok do usuário.

## O que fica com você

- A rodada de revisão visual no fim.
- O ok para o deploy da carga na VPS e para o merge na `development`.

## O que foi entregue

Integrado na `development` pela `feature/app-1.0` e conferido no código em 2026-10-29. A verdade atual de cada parte está nas [specs](../../../specs/README.md).

- **Base:** só pt-BR ([ADR 0003](../../../adr/0003-portuguese-only.md)), sem compras ([ADR 0011](../../../adr/0011-free-app-noncommercial-license.md)), sem o exemplo `Item`, cinco abas (Hoje, Região, Votações, Dinheiro e Fiscalizar com `Tab(role: .search)`), Ajustes na toolbar de Hoje ([ADR 0014](../../../adr/0014-settings-in-today-toolbar.md)) e o cliente de dados públicos com cenários de teste (`-FiscalDataScenario`).
- **Servidor:** `fiscal-ingest` com sincronização por cadência e SQLite ([ADR 0006](../../../adr/0006-ingest-sqlite-store.md), [0008](../../../adr/0008-smart-sync.md)), publicação `v2` no Cloudflare Pages pelo `fiscal-pages` ([ADR 0007](../../../adr/0007-pages-cdn-phased-ingest.md)) e as fontes Câmara, Senado, TSE, IBGE (municípios e SIDRA), Receita, ANP, assembleias com SAPL (AC, AM, PB, PI e RO), Projeto Comprova, Wikipédia e GDELT ([public-data-api.md](../../../specs/public-data-api.md)).
- **Telas:** Hoje (destaque do momento, resumo do Congresso, votações recentes, apuração), Região (quem governa a cidade, o estado e o país, bancadas), perfil, Votações, Dinheiro, Fiscalizar (busca, Comparar, Eleições, investigações salvas no iCloud) e a Memória (eleições desde 1989, períodos e guias de estudo).
- **Credibilidade:** fonte e data em cada bloco, comparação com os colegas por quartil, peso das ações por faixa, linha "Estimado" e explicações do Foundation Models no aparelho ([credibility.md](../../../specs/credibility.md)).
- **Lente e arte:** setup "quem você apoia", temas e visual ([lens.md](../../../specs/lens.md)); ícone da Amazônia com 16 alternativos e os 30 de partido atrás de flag ([ADR 0013](../../../adr/0013-party-symbol-icons.md)); 44 obras com licença conferida, 22 em domínio público e 22 fotos sob CC BY-SA 4.0; retratos desenhados e selos de partido.
- **Compartilhar:** cartazes de 8 assuntos em Stories, feed e mensagem, exportados em PNG com o crédito da obra ([share-cards-and-art.md](../../../specs/share-cards-and-art.md)).
- **Integrações:** widgets (representantes, votação, destaque), Live Activities da apuração e do destaque ([notifications.md](../../../specs/notifications.md)), três App Shortcuts, Spotlight dos perfis e o pacote offline ([ADR 0015](../../../adr/0015-background-fetch-offline-pack.md)).

### O que não saiu como proposto

- **Checagens no perfil:** a seção do perfil está desligada no código; as checagens do Comprova aparecem só nas investigações de Fiscalizar ([fact-checks.md](../../../specs/fact-checks.md)).
- **Marca "Ilustração do Fiscal" e a regra das 72 h antes e 24 h depois da votação** nos cartazes com retrato: não implementadas; estão no [backlog](../../../backlog.md).
- **Mac, visionOS e iPad com receita própria:** o lançamento é só iOS; a receita do Mac está no backlog.
- **Rodada de revisão visual do usuário e deploy da carga:** feitos ao longo das frentes; as revisões de design, acessibilidade e código sobre o conjunto ficam na rodada única da `align-workspace`.
