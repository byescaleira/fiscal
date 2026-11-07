# Enquadrar o Fiscal no byescaleira-workspace

_Proposta da mudança `align-workspace`._

- **Estado:** entregue
- **Data:** 2026-10-29
- **Branch:** `feature/workspace-alignment` (sai da `feature/kit-adoption`)

## Por quê

A adoção do byescaleira-kit trouxe o código compartilhado, mas o Fiscal ainda segue partes do template antigo: documentos, site e loja copiados do template, regras de design e de acessibilidade que o workspace endureceu depois, models que fazem trabalho de view e dados do iCloud que não chegam à tela. Uma varredura das referências do workspace contra o repositório achou cerca de 170 lacunas em quatro áreas (processo, arquitetura, design e publicação). Esta mudança fecha todas as que não pedem decisão sua e registra as que pedem.

O Rafael pediu também que o fundo do app seja branco no claro e preto no escuro.

## O que muda

- **Fundo:** toda tela fica branca ou preta, com os cartões em cinza do sistema, pela superfície lisa nova do kit (`GroupedSurface.plain`).
- **Design:** placar acompanha o Dynamic Type, filtros na toolbar com subtítulo de escopo, confirmações e "Como medimos" em guias, estados vazios do kit, barras e etiquetas pelos componentes do kit, títulos de seção e nomes em Bricolage, botões em cápsula grandes, efeitos em loop com orçamento de movimento e Modo econômico lido na raiz.
- **Acessibilidade:** texto visível alcançável pelo VoiceOver, alvos de 44 pt, aviso de troca no inspector, Reduzir movimento em toda transição, plurais com `zero` e variações nas contagens.
- **Arquitetura:** duplicatas do kit removidas (animação, tokens de gráfico, `ShareFormat`, PNG), navegação só por `Route`, serviços abertos uma vez por processo, cálculo e formatação saem das views, carga protegida contra resposta atrasada, mudanças do iCloud chegam à tela, preferência de iCloud nos Ajustes, App Group com tipo único, atualização obrigatória que vale também para intents, push e segundo plano, seção Desenvolvedor completa.
- **Publicação:** entitlement do App Attest, manifestos de privacidade do app e dos widgets, links do Sobre, notas de revisão e descrição sem afirmação errada, "What to Test" em pt-BR.
- **Site:** a landing deixa de ser o template e passa a vender o Fiscal, só em pt-BR (ADR 0003), sem assinatura Pro, sem anunciar o Fiscal na Web antes da hora, com a Bricolage, o link real da App Store e a privacidade com as saídas de rede de verdade.
- **Servidor:** `/health` com a versão em todos os serviços; catálogo de flags do admin igual ao do app.
- **Processo:** `AGENTS.md`, `CLAUDE.md` e constituição com a regra de versão e os revisores de acessibilidade, segurança e spec; specs vivas das capacidades; mudanças antigas arquivadas; roadmap e backlog reais; verificação completa cobrindo o servidor Go e as licenças da arte; lint com a regra de fonte de destaque.

## Fora do escopo

- Receita do Mac (lista de origem, `Table`, `GroupBox`, comandos): o lançamento é só iOS; vai para o backlog.
- Alvos `FiscalMock`, `FiscalPreview` e `FiscalAudit`: backlog.
- Capturas da loja geradas pelo pipeline (precisam do aparelho e do texto final do site): backlog.
- Contrato do Fiscal na Web: fica para quando o recurso entrar.

## Specs afetadas

Esta mudança cria as specs vivas que faltam: `live-results.md`, `public-data-api.md`, `lens.md`, `credibility.md`, `share-cards-and-art.md`, `fact-checks.md` e `notifications.md`, cada uma com a verdade atual do app.

## Impacto

- **Targets:** todos os do `FiscalKit`, o app, os widgets, o site, a ponte, o admin e o servidor.
- **Dados:** schemas V1 a V3 congelados como foram distribuídos; chaves de `UserDefaults` com o prefixo `fiscal.` e migração única da chave antiga; preferência `fiscal.settings.cloudSync`.
- **Textos:** só pt-BR; plurais com `zero`; chaves novas sincronizadas pelo `scripts/strings.sh`.
- **Flags:** `liveResults`, `highlightAlerts` e `intelligence` novas, e `partyIcons` no admin.

## Decisões pendentes

1. Aceitar os ADRs 0004, 0005 e 0007, que estão "Proposto" mas já rodam em produção. Recomendado: aceitar.
2. Trocar a branch padrão do GitHub de `feature/app-1.0` para `main`. Recomendado: trocar.
3. O que fazer com `feature/news-webngrams` (4 commits fora da `development`). Recomendado: item no backlog, branch mantida.
4. Rótulo de privacidade da loja com tokens de push e chaves do App Attest guardados no servidor. Recomendado: declarar "Identificadores › ID do dispositivo, não vinculado à pessoa, funcionalidade do app" (ADR proposto nesta mudança).

## O que fica com você

- Aprovar as decisões acima.
- Publicar o site novo e subir o servidor com a versão no `/health` (deploy só com o seu ok).
- Liberar o acesso do Xcode Cloud ao `byescaleira/byescaleira-kit` e mergear os PRs do kit para cortar a `v0.5.1`.
