# 0014. Ajustes na toolbar de Hoje, não numa aba

- **Estado:** Aceito
- **Data:** 2026-10-29
- **Mudança:** [`align-workspace`](../changes/archive/2026-10-29-align-workspace/proposal.md)

## Contexto

O template põe Ajustes como uma aba. O Fiscal tem cinco abas de conteúdo (Hoje, Região, Votações, Dinheiro e Fiscalizar, esta com `Tab(role: .search)`), e uma sexta aba só de configuração tiraria espaço da barra para algo que a pessoa abre raramente. O brief registra a decisão do usuário: "Ajustes saem da barra de abas e viram um botão na toolbar de Hoje, onde a pessoa também edita a Lente". A skill `byescaleira-sdd` (`settings-structure.md`) também fixa uma ordem de grupos que o Fiscal adapta, porque não tem assinatura, idioma nem backup.

## Decisão

- No iPhone, no iPad e no visionOS, Ajustes abre pela toolbar de Hoje: o botão `gearshape` ("Ajustes") abre `Route.settings` na pilha de Hoje, ao lado do botão `heart` ("Quem você apoia"), que abre a Lente. No Mac, o mesmo botão é um `SettingsLink` para a janela de Ajustes do sistema. O link `fiscal://settings` abre Ajustes em Hoje.
- A ordem dos grupos é fixa:
  1. **Seu Fiscal:** cartão da Lente (quem você apoia, temas e aparência) e Artistas.
  2. **Aparência:** tema, cor de destaque e ícone do app.
  3. **Seus dados e privacidade:** dados offline, sem conta e sem anúncio, investigações no iCloud, a Lente fica no aparelho, destaques na tela de bloqueio (só iOS) e a política de privacidade.
  4. **Fontes e método:** "Como medimos" e as fontes oficiais, quando a lista de fontes carrega.
  5. **Sobre:** guias (com a flag `guides`), novidades e "Sobre o Fiscal".
  6. **Desenvolvedor:** só em Debug.
- Grupo novo entra nesta lista por um ADR que substitua este, ou como linha dentro de um grupo existente.

## Consequências

- A barra de abas fica só com conteúdo; Ajustes continua a um toque de Hoje e por deep link.
- Atalhos e guias que citam Ajustes dizem "Hoje › Ajustes", nunca "aba Ajustes".
- Testes de interface e o roteiro de [validation.md](../validation.md) abrem Ajustes pela toolbar de Hoje.

## Alternativas consideradas

- **Aba Ajustes:** sexta aba, gasta espaço com algo raro e empurra Fiscalizar.
- **Ajustes no menu do perfil ou na busca:** escondido demais; a pessoa procura em Hoje, onde também edita a Lente.
