# Validação

Como verificar o Fiscal antes de uma versão, do automático ao que depende de aparelhos, do servidor e de dados reais. O caminho até a loja está em [app-store/README.md](app-store/README.md); a atualização obrigatória, em [force-update.md](force-update.md). O app é gratuito ([ADR 0011](adr/0011-free-app-noncommercial-license.md)): não há compras para validar. O lançamento é só iOS (iPhone e iPad) e só em pt-BR ([ADR 0003](adr/0003-portuguese-only.md)).

## Automático

Rode antes de cada commit; o Xcode Cloud repete o build e os testes.

```sh
scripts/verify.sh --quick
scripts/verify.sh --full
scripts/ui-test.sh
```

- `--quick`: build da plataforma, testes dos alvos afetados, ponte e cifra da web e, se `server/` mudou, `go build`, `go vet` e `go test` com a versão do Go do `server/go.mod`.
- `--full`: `scripts/lint.sh` (formatação e SwiftLint estrito, com a regra `emphasis_font`), build das três plataformas, a suíte inteira, web, admin, servidor Go, `python3 -I scripts/art.py check` (licenças da arte no Commons, pede rede) e `scripts/audit.sh`.
- Zero warnings em iOS, macOS, visionOS e nos testes do pacote.
- `scripts/test.sh` escolhe sozinho um iPhone disponível (de preferência o já ligado, no runtime mais novo); para o simulador do sim-monitor, `FISCAL_TEST_DESTINATION="platform=iOS Simulator,id=<udid>"` depois do `scripts/simulator.sh acquire`, e `release` no fim.
- `scripts/ui-test.sh` confere o layout em telas grandes (iPad).
- `scripts/audit.sh` só roda quando o pacote tiver o target `FiscalAudit`.
- Testes que dependem do modelo de linguagem do sistema falham no simulador; rode-os no aparelho e não conte como regressão.

## Antes de distribuir

Roteiro manual a cada build candidata. Marque cada item na build que vai para a revisão e anote o número da build.

Build: `____` · Data: `__/__/____`

### Aparelhos

- [ ] iPhone físico com a build do TestFlight (Release, ambiente de produção do CloudKit).
- [ ] iPad físico ou simulador de iPad, com a mesma build.
- [ ] Segundo aparelho com a mesma conta do iCloud, para os seguidos e as investigações.
- [ ] Capturas reais de cada tamanho enviado ([app-store/media/README.md](app-store/media/README.md)).

### Apuração

A Atividade ao Vivo da disputa e o botão de acompanhar saíram até a próxima eleição ([ADR 0028](adr/0028-app-reads-only-from-cdn-and-local-alerts.md)). A apuração continua nas telas, lida em `v2/races.json` na CDN.

- [ ] Em Debug, `-FiscalLiveScenario close`, `decided` e `waiting`: os números aparecem como antes, sem botão de acompanhar.
- [ ] Sem rede: a tela usa o `races.json` do pacote offline ou mostra "Sem conexão. Mostrando os últimos números recebidos."
- [ ] Em dia de eleição, com o `fiscal-pages.timer` ligado ([runbook](server-runbook.md)): a tela acompanha `v2/races.json`, com o horário do arquivo do TSE. O modo `SIMULATE=1` do servidor não publica nada, então não aparece no app.

### Página do político e cartões de um item

- [ ] Deputado, senador, governador, prefeito e vereador, inclusive quem deixou o cargo: só os capítulos com dado, sem traço, com a frase do que a fonte não publica.
- [ ] Rolar: o cabeçalho aparece quando o topo sai, o retrato faz um gesto por capítulo e fica parado com Reduzir movimento e pouca energia.
- [ ] Compartilhar uma nota, um mês, um voto e uma proposta; nota sem CNPJ não tem botão.
- [ ] Cartão que abre outra tela mostra a setinha; no Feed, a pessoa abre o perfil, e o resto abre o conteúdo.

### Destaque na tela de bloqueio e notificação

Os dois alertas são agendados no próprio aparelho, sem servidor ([FSC-020](../spdd/prompt/FSC-020-202611042045-[Feat]-app-reads-only-from-cdn-and-local-alerts.md)). O último roteiro no iPhone está em [evidence/FSC-020/qa.md](evidence/FSC-020/qa.md).

- [ ] Instalação nova: "Destaques de maior peso na tela de bloqueio" ligado e "Notificação de destaque" desligado (Ajustes › Geral › Notificações); a pergunta do iOS sobre notificações não aparece ao abrir nem ao navegar.
- [ ] Build DEBUG lançada com `-FiscalAlertTestSeconds` (horários de teste à frente) e `-fiscal.highlightAlerts.shown "()"`, com o app fechado e a tela bloqueada: a Atividade do destaque aparece com o bonequinho, o título do Feed e o subtítulo, toca o som padrão e fica na tela.
- [ ] Ligar "Notificação de destaque": a pergunta do iOS aparece só nesse momento. Aceitar: a notificação chega depois da Atividade, sem som, com o destaque seguinte. Recusar: o interruptor volta, aparece "As notificações do Fiscal estão desligadas nos Ajustes." e o botão abre os Ajustes.
- [ ] Tocar na Atividade e na notificação, com o app fechado e aberto: abre o perfil, a votação ou o Feed certo.
- [ ] Desligar cada interruptor: a Atividade pendente ou a notificação agendada sai.
- [ ] Nenhum texto de Ajustes ou do método cita hora.
- [ ] Atividades ao Vivo desligadas nos Ajustes do iOS: a notificação, se ligada, leva o primeiro destaque.

### Dados públicos e pacote offline

- [ ] Primeira abertura com rede: Feed, Votações, Dinheiro, Região e Fiscalizar carregam da CDN (`dados.fiscal.byescaleira.com`), com fonte e data em cada bloco.
- [ ] Com o log de acesso da VPS aberto (só leitura, com o ok do usuário): abrir Feed, Região, Pessoa, Votações, Apuração e Ajustes não gera nenhum pedido com agente `Fiscal/`.
- [ ] Ajustes › Seus dados e privacidade › Dados offline mostra o pacote baixado e o tamanho.
- [ ] Modo avião e reabrir: o Feed, a cidade de casa, os seguidos e os apoiados abrem do pacote; o resto mostra "Isso não está salvo para uso offline."
- [ ] `BGAppRefresh`: com o app em segundo plano, forçar a tarefa `com.byescaleira.fiscal.offline-refresh` pelo depurador (`e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.byescaleira.fiscal.offline-refresh"]`) e conferir a data nova do pacote.

### Barra ao rolar e telas novas

- [ ] Votação, corrida, notas e político: ao rolar, a barra aparece sem o conteúdo pular, e some ao voltar ao topo; o puxar para atualizar continua funcionando.
- [ ] Com Reduzir movimento, a barra aparece sem deslizar, e os atalhos saltam sem animar.
- [ ] Votações em dia com sessão e em dia sem sessão: a linha diz "Em sessão" ou a próxima data, e a pauta de data passada não aparece.
- [ ] Filtro Seguindo, widget "Quem eu sigo" e Siri abrem a tela de quem você segue; seguir e deixar de seguir nela mudam o Feed.
- [ ] Mac, iPad e Duo aberto: a coluna fica legível, e o que se abre vai ao outro lado.

### Retratos e cartões

- [ ] Quem assume em 2027 aparece desenhado, mesmo com outro partido no dado: conferir Eduardo Riedel e rodar `python3 -I scripts/portrait-check.py --published` depois de cada carga.
- [ ] No modo claro, o placar, "Na sua região agora", a conclusão da investigação e comparar não têm fundo preto; no escuro, ficam como antes.
- [ ] O cartão do político e os outros cartões coloridos ficam iguais nos dois modos.
- [ ] O ajuste de Aparência e Aumentar contraste valem para esses quatro cartões.

### Meu apoio e privacidade

- [ ] A instalação nova abre direto, sem setup e sem pergunta política.
- [ ] O apoio não aparece no iCloud do segundo aparelho nem volta depois de restaurar um backup.
- [ ] "Apagar meu apoio" apaga pessoas e causas e mantém quem a pessoa segue.
- [ ] Nenhum cartaz, notificação, Atividade ao Vivo ou resultado do Spotlight mostra quem a pessoa apoia.
- [ ] Exportar dados gera o JSON com o apoio e os seguidos.

### Explicações no aparelho

- [ ] Aparelho com Apple Intelligence: a explicação aparece com o selo "Explicação gerada pela Apple Intelligence no seu iPhone · pode errar; vale o texto oficial".
- [ ] Aparelho sem Apple Intelligence (ou com ela desligada): fica o texto fixo, sem selo e sem erro.
- [ ] Modo avião: a explicação continua (roda no aparelho).

### Interface por plataforma

- [ ] iPhone retrato e paisagem em todas as abas, no perfil, na Apuração, em "Meu apoio" e no compartilhar.
- [ ] iPad: barra lateral, inspetor, Split View e Stage Manager; rotação com uma folha aberta.
- [ ] Tema claro e escuro, cada paleta e cor de destaque; fundo branco ou preto em todas as telas.
- [ ] Textos em pt-BR sem corte, com nomes longos de político, partido e município (`-FiscalDataScenario longNames`).
- [ ] Estados vazios e de erro com mensagem e saída (`-FiscalDataScenario empty`, `offline`, `unavailable`).

### Acessibilidade

Roteiro da skill `byescaleira-sdd` (`accessibility.md`, seção 7), adaptado ao Fiscal:

- [ ] Tamanho de texto em AX3 e em xSmall: nada cortado, valores encolhem, linhas empilham, grades mudam de colunas, guias cabem (no AX3, abrem na altura cheia e rolam até os botões).
- [ ] VoiceOver em cada tela: um foco por linha ou cartão, nada decorativo lido, botões-ícone com nome, seleção anunciada, gráficos e barras com resumo; todo texto visível também é alcançável (nada escondido dentro de um único botão).
- [ ] Reduzir movimento ligado: nada se move sozinho, Lottie e retratos parados, transições trocadas por fade.
- [ ] Modo escuro com paleta escura e com paleta clara: chips, seleções e prévias legíveis; contraste aumentado e Diferenciar sem cor: o estado não depende só da cor (rótulo junto do selo de comparação).
- [ ] Controle por Voz e Acesso Total: alvos de pelo menos 44 pt, nenhuma ação só por gesto (deslizar tem equivalente no `contextMenu`).
- [ ] iPad em duas colunas: escolher outro item na lista anuncia a coluna de leitura (o inspetor avisa a troca de conteúdo).

### Integrações no aparelho

- [ ] App Shortcuts em pt-BR na Siri e no app Atalhos: "Como meu deputado votou no Fiscal", "Abrir o perfil de … no Fiscal", "Ver a apuração no Fiscal".
- [ ] Widgets de representantes, da votação e do destaque, em cada tamanho, com dados reais, tocando para abrir a tela certa.
- [ ] Spotlight: buscar um político abre o perfil.
- [ ] Links `fiscal://` da [arquitetura](architecture.md#links) e o link universal `/link` do site.

### Atualização obrigatória

Detalhes em [force-update.md](force-update.md#como-testar).

- [ ] Política `AppRelease` com a mínima acima da build instalada bloqueia o app ao abrir.
- [ ] Modo avião e reabrir: continua bloqueado (vale o cache).
- [ ] **Exportar dados** funciona na tela de bloqueio; **Atualizar** abre a página do app na App Store.
- [ ] Baixar a mínima no admin e voltar ao primeiro plano depois de 1 minuto: o bloqueio sai.
- [ ] Só a recomendada acima: o aviso aparece uma única vez para aquela versão.
- [ ] Política final em Production deixa a build da revisão em `current`.

No simulador o app usa o banco local com CloudKit desligado; nos aparelhos, o container `iCloud.fiscal` e o App Group precisam das capabilities e da assinatura. O app não usa push nem App Attest.
