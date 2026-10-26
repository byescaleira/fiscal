# Setup inicial: Lente, aparência e arte

Proposta da mudança `setup-lens-art`.

- **Estado:** rascunho
- **Data:** 2026-10-25
- **Branch:** `feature/setup-lens-art`

## Por quê

O usuário pediu em 2026-10-25: "está faltando imagens, animações, tema. Precisamos adequar o app a cada usuário [...] um setup inicial onde ele escolhe o que ele gosta e o que ele quer ver de forma simples. As imagens de artistas são prioridade!". Hoje o app abre direto na apuração, sem arte, sem tema próprio e sem saber o que importa para a pessoa. É a [Lente do brief](../../brief.md) e a fase 4 do [roadmap](../../roadmap.md), adiantada para logo depois da apuração.

## O que muda

- **Setup inicial em 3 passos**, que dá para pular e refazer em Ajustes:
  1. **"O que importa para você?"** Grade de 12 temas com ícone e arte. A pessoa escolhe de 3 a 5.
  2. **"Como você se vê?"** Opcional, com "Prefiro não dizer" em destaque. Só sugere um pacote de temas e uma coleção de arte.
  3. **"Escolha o seu visual."** Coleções de arte com prévia real (o card e a tela de Hoje com aquela arte), paleta e ícone do app. Uma animação curta confirma a escolha.
- **Arte em todo lugar que importa:**
  - fundo do cabeçalho de Hoje e da Apuração;
  - fundo dos cards de compartilhar;
  - capas dos temas;
  - galeria "Artistas", com autor, obra, ano, acervo e licença.
- **Tema** com paletas em pares espelhados, sem cor de partido, aplicado à estrutura (destaque, fundos de card, ícone). Os dados mantêm a cor fixa de dado ([ADR 0002 não muda isso](../../adr/0002-static-first-server.md); a regra está no brief).
- **Animações:**
  - Lottie no setup, gerada por `scripts/animations.py`;
  - entrada em cascata das seções;
  - barras que enchem ao abrir;
  - `symbolEffect` no selo de eleito.
  
  Tudo respeita Reduzir movimento.
- **Privacidade:** a Lente, o posicionamento e as escolhas visuais ficam só no aparelho (SwiftData), sem ir ao servidor.

## Acervo da primeira versão (da [pesquisa de artistas](../../research/2026-10-25-art-and-licensing.md))

- **Domínio público:** Pedro Américo, J. Carlos, Angelo Agostini, Belmonte, Almeida Júnior, Benedito Calixto, Debret e Victor Brecheret (livre desde 2026).
  - Cada arquivo entra com a página do Commons ou do acervo, a data de morte do autor e os termos do acervo de origem. A Brasiliana Digital e a Biblioteca Nacional têm condições próprias mesmo para obra em domínio público.
- **Sem recolorir, recortar ou filtrar a obra:** ela aparece inteira, com o crédito gravado na imagem. A paleta é tirada da obra, não aplicada sobre ela.
- **Fase seguinte:** arte encomendada em espelho, com artistas dos dois campos, e licenças pagas (AUTVIS, Projeto Portinari), com contrato.
- **Manifesto `art-credits.json`** no app: obra sem linha no manifesto não aparece.

## Fora do escopo

- Arte encomendada e licenças pagas: contratos levam semanas.
- Cards de compartilhar completos (fase 7). Aqui só o fundo com arte e a prévia.
- Notificações por tema.

## Antes de desenhar

Pela nova regra do workspace: pesquisa de referências de onboarding e personalização em ganhadores do Apple Design Award e em Mobbin, Screenlane e Dribbble, registrada no `design.md` desta mudança.

## Decisões pendentes

1. **Baixar as imagens em domínio público:** são cerca de 20 arquivos do Wikimedia Commons e de acervos públicos, de 0,5 a 5 MB cada, redimensionados e convertidos para HEIC no app. Recomendo baixar só depois de conferir arquivo por arquivo a página de licença e os termos do acervo, com a lista de arquivos aprovada por você.
2. **Onde fica o setup:** recomendo uma folha na primeira abertura, que dá para pular, e não um bloqueio antes do app, para respeitar quem só quer ver a apuração.

## O que fica com você

- Aprovar a lista de obras e o download.
- Escolher os artistas da fase de encomenda (a pesquisa traz nomes e contatos dos dois lados).
