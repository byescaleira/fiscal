# Fiscal 1.0: dados federais e estaduais, 5 abas, Lente, arte e compartilhamento

Proposta da mudança `app-1.0`.

- **Estado:** em andamento
- **Data:** 2026-10-25
- **Branch:** `feature/app-1.0`, com cada frente na sua `feature/app-1.0-<frente>`, integradas pelo coordenador

## Por quê

O usuário pediu, em 2026-10-25, "fazer todo o restante do app numa tacada só com as novas diretrizes e depois (no final) fazer as validações". As decisões dele:
- **escopo:** federal mais estados;
- **revisão visual:** uma rodada no fim, com todas as seções;
- **imagens:** download das obras em domínio público, com checagem de licença;
- **paralelismo:** workflow multiagente;
- **preço:** o app é totalmente gratuito.

Cobre as fases 2 a 8 do [roadmap](../../roadmap.md), seguindo o [brief](../../brief.md) e o [contrato](contract.md).

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
   - cada uma passa pelo ciclo de design por seção (referência visual real e dados de teste), com a revisão visual do usuário numa rodada só, no fim.
4. **Lente e arte:**
   - o setup em 3 passos e a aparência (paletas espelhadas, ícones alternativos);
   - o acervo em domínio público com `art-credits.json`;
   - a galeria de artistas.
5. **Compartilhar:** cards de Stories, feed e mensagem para perfil, votação, gastos, apuração e comparação, com o crédito gravado na imagem.
6. **Integrações:**
   - widgets (meus representantes, votação do dia);
   - App Intents com Siri ("como meu deputado votou?");
   - Spotlight dos perfis.

## Fora do escopo

- Prefeitos, vereadores e STF.
- Broadcast push (a apuração continua por token).
- Publicação na loja e TestFlight externo.
- Arte encomendada e licenças pagas.

## Verificação (no fim, uma vez)

- `scripts/verify.sh --full`: lint, build das 3 plataformas, a suíte inteira, web e admin.
- Testes do servidor com `-race` e `govulncheck`.
- Revisores de design, acessibilidade, código e segurança sobre o diff inteiro.
- Capturas de todas as seções no iPhone, para a rodada de revisão do usuário.
- Deploy da carga na VPS, com o ok do usuário.

## O que fica com você

- A rodada de revisão visual no fim.
- O ok para o deploy da carga na VPS e para o merge na `development`.
