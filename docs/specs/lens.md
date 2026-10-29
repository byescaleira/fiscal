# Lente

A Lente é a escolha de quem a pessoa apoia (até 5 políticos, ou "Prefiro não dizer") e dos temas que importam para ela (de 3 a 5), mais o visual (paleta, ícone e coleção de arte). Ela ordena o que o app mostra; nunca filtra nem reescreve os fatos. Aparece no setup da primeira abertura, no botão "Quem você apoia" da toolbar de Hoje e no cartão "Seu Fiscal" dos Ajustes. As decisões estão em [ADR 0004](../adr/0004-lens-on-device-store.md); o que falta fazer está em [backlog.md](../backlog.md).

## Princípios

- **Mesmo fato para todo mundo.** A Lente muda a ordem, nunca o conteúdo, o número, a cor de um partido ou candidato, nem o que existe na lista.
- **Só no aparelho.** Quem a pessoa apoia é opinião política, dado sensível na LGPD (art. 5º, II, e art. 11): fica num banco só do aparelho, fora do iCloud, do backup, das notificações, dos cartazes e do Spotlight.
- **Escolher é opcional.** "Prefiro não dizer" vale tanto quanto apoiar alguém e deixa o app na ordem neutra.
- **O visual é da pessoa; o dado, não.** Paleta e arte mudam a estrutura (destaque, fundos, ícone); gráficos, placares e listas de políticos mantêm a cor do dado.

## Onde fica

| Target | O que fica nele |
| --- | --- |
| `FiscalDomain` | `Lens` (limites, ordem, regras), `Theme` (17 temas), `SupportThemes` (sugestão de temas pelo que os apoiados fizeram) |
| `FiscalData` | `LensEntity` na configuração `Device` do `FiscalDatabase` (`cloudKitDatabase: .none`), `FiscalStore.resetLens`, exclusão do backup |
| `FeatureCore` | `LensContext` (Lente salva e se precisa de setup), `LensBadge` |
| `FeatureLens` | `LensSetupModel` e os passos, `LensModel` e `LensScreen` (edição e "Outra lente"), `LensExperience` |
| `AppShell` | `Route.lens` em Hoje; `fiscal://lens` |

## Mecânicas e regras

### Escolha

| Regra | Valor |
| --- | --- |
| Pessoas apoiadas | até 5 (`supportLimit`); a sexta é ignorada |
| Temas | de 3 a 5 (`themeRange`); não dá para tirar abaixo de 3 nem pôr acima de 5 |
| "Prefiro não dizer" | esvazia a lista de apoiados; apoiar alguém desliga a opção |
| Escolha feita (`hasChoice`) | "Prefiro não dizer" ou pelo menos 1 apoiado |
| Lente completa | escolha feita e de 3 a 5 temas |
| Paleta e arte sugeridas | `graphite` e `brasil-agora` |

- São 17 temas; o setup mostra 12 (saúde, educação, segurança, economia, impostos, meio ambiente, social, direitos, política, cidade, campo e mulheres) e guarda os outros 5 (transporte, cultura, consumidor, tecnologia e homenagens) em "mais". A ordem neutra é a dos 12 seguida dos 5.

### Setup

- Abre sozinho depois da tela de abertura, 450 ms depois, quando a Lente salva não tem escolha: em tela cheia no iPhone, no iPad e no visionOS, em folha no Mac.
- Passos: boas-vindas → quem você apoia → temas → visual. Os três últimos aparecem como "Passo N de 3". Botões: "Começar · 1 min", "Continuar", "Concluir" (e "Salvar" quando é edição).

| Passo | Pode continuar quando |
| --- | --- |
| Boas-vindas | sempre |
| Quem você apoia | há escolha |
| Temas | a Lente está completa |
| Visual | há paleta e coleção de arte |

- **Quem você apoia?** Busca por nome, partido, cargo ou UF, sem acento nem caixa; até 40 sugestões (escolhidos, depois os representantes da cidade, depois presidente, vice e governadores, depois todos) e até 80 resultados. O cartão "Prefiro não dizer" diz "O Fiscal fica neutro: temas na ordem em que os dados chegam." O cartão de cadeado diz que a escolha fica só no aparelho e que outro iPhone ou uma reinstalação pergunta de novo.
- **Temas:** até a pessoa mexer, o app sugere os 5 temas mais frequentes nas ações recentes dos apoiados (ou nas propostas e discursos do perfil, se não houver ações), com a linha "Estimado: o tema de cada ação vem de palavras-chave da ementa oficial e pode errar." Com "Prefiro não dizer", sugere a ordem neutra. Dá para subir, descer, arrastar e tirar.
- **Visual:** 8 paletas em 4 pares espelhados (Mata e Urucum, Anil e Ipê, Cerrado e Mar, Grafite e Areia), nunca tiradas da cor de um partido; um ícone por paleta, além do padrão; e a coleção de arte, quando há mais de uma.
- Salvar segue no aparelho todos os apoiados.

### O que a Lente ordena

- Temas das Votações e, sem filtro ligado, os destaques nos temas da pessoa (a lista inteira continua).
- No detalhe da votação, os votos dos apoiados primeiro.
- Hoje e o destaque do momento pela ordem dos apoiados; seções de Dinheiro; linhas de tema no perfil.
- O selo `LensBadge` diz "Por quem você apoia" onde a ordem mudou.
- A cor de destaque do app vem da paleta.

### Outra lente

- Na tela da Lente, a pessoa vê o app em "Ordem neutra" ou "Quem apoia <nome>" para até 4 outras pessoas tiradas dos destaques.
- É uma prévia: nada é salvo. Uma faixa diz "Ordem neutra por um momento. Nada é salvo." com o botão "Voltar à minha".

### Privacidade e armazenamento

- `LensEntity` vive na configuração `Device`, sem CloudKit, e o arquivo do banco, o `-wal` e o `-shm` são marcados fora do backup. Os seguidos e as investigações ficam na configuração `Fiscal`, com o iCloud privado quando a sincronização está ligada.
- A Lente não sincroniza entre aparelhos; a única saída é a exportação feita pela própria pessoa (`DataArchive`).
- O rodapé da Lente diz que ela nunca vai em requisições, registros, notificações, cards compartilhados nem no Spotlight.
- **Pacote offline:** baixa da CDN só os perfis das pessoas seguidas e dos representantes, nunca os das apoiadas ([ADR 0015](../adr/0015-background-fetch-offline-pack.md)). Abrir o perfil de alguém continua sendo um pedido público como outro qualquer.

### Apagar

- O `LensScreen` tem a confirmação "Apagar sua lente?" com "Apagar minha escolha", que chama `FiscalStore.resetLens` e volta ao setup; hoje nenhum botão da tela abre essa confirmação ([backlog](../backlog.md)).

## Construção

1. **Domínio:** `LensTests` em `FiscalDomainTests`.
2. **Dados:** `LensPrivacyTests` e `DeviceStoreTests` em `FiscalDataTests` (sem CloudKit, fora do backup).
3. **Feature:** `LensSetupModelTests`, `LensModelTests` e `LensContextTests`; `LensPaletteSwatchTests` para as paletas.
4. **Textos:** pt-BR no catálogo.

## O que fica com você

- Nada no console: a Lente não usa CloudKit nem servidor.

## Histórico

| Data | Mudança ou ADR |
| --- | --- |
| 2026-10-29 | [`app-1.0`](../changes/archive/2026-10-29-app-1.0/proposal.md) |
| 2026-10-29 | [`setup-lens-art`](../changes/archive/2026-10-29-setup-lens-art/proposal.md) (substituída) |
| 2026-10-25 | [0004](../adr/0004-lens-on-device-store.md) |
