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

- [ ] iPhone físico com a build do TestFlight (Release, ambiente de produção do CloudKit, do APNs e do App Attest).
- [ ] iPad físico ou simulador de iPad, com a mesma build.
- [ ] Segundo aparelho com a mesma conta do iCloud, para os seguidos e as investigações.
- [ ] Capturas reais de cada tamanho enviado ([app-store/media/README.md](app-store/media/README.md)).

### Apuração e Atividade ao Vivo

- [ ] Servidor em modo de simulação (`SIMULATE=1`, [runbook](server-runbook.md)), com o ok do usuário para mexer na VPS.
- [ ] Seguir uma disputa na Apuração: a Atividade aparece na tela de bloqueio e na Dynamic Island.
- [ ] Receber os pushes de atualização (placar muda sem abrir o app) e o de fim (alerta "Resultado", Atividade some depois de 4 h ou ao tocar).
- [ ] Deixar de seguir: a Atividade termina na hora e o registro sai do servidor.
- [ ] Sem rede: a tela mostra "Sem conexão. Mostrando os últimos números recebidos."
- [ ] Voltar o servidor para o TSE real.

### Destaque na tela de bloqueio

- [ ] Com "Destaques de maior peso na tela de bloqueio" ligado (Ajustes › Seus dados e privacidade), o registro do token de push-to-start chega ao servidor (`highlight-registrations.json`).
- [ ] Um destaque de peso 85 ou mais do último dia abre a Atividade do destaque; tocar abre o perfil ou a votação certa.
- [ ] Desligar encerra a Atividade em andamento e remove o token.
- [ ] Atividades ao Vivo desligadas nos Ajustes do iOS: nada é registrado.

### App Attest

- [ ] Com o servidor em `APPATTEST_MODE=required`, o primeiro registro atesta a chave e os seguintes passam só com a asserção.
- [ ] Apagar a chave no servidor: o app recebe `attest_unknown_key`, atesta de novo e o registro passa na segunda tentativa.
- [ ] Build do TestFlight usa o ambiente de produção (o servidor recusa desenvolvimento sem `APPATTEST_ALLOW_DEVELOPMENT=1`).

### Dados públicos e pacote offline

- [ ] Primeira abertura com rede: Hoje, Região, Votações, Dinheiro e Fiscalizar carregam da CDN (`dados.fiscal.byescaleira.com`), com fonte e data em cada bloco.
- [ ] Ajustes › Seus dados e privacidade › Dados offline mostra o pacote baixado e o tamanho.
- [ ] Modo avião e reabrir: Hoje, a cidade de casa, os seguidos e os apoiados abrem do pacote; o resto mostra "Isso não está salvo para uso offline."
- [ ] `BGAppRefresh`: com o app em segundo plano, forçar a tarefa `com.byescaleira.fiscal.offline-refresh` pelo depurador (`e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.byescaleira.fiscal.offline-refresh"]`) e conferir a data nova do pacote.

### Lente e privacidade

- [ ] O setup abre na primeira vez; "Prefiro não dizer" deixa a ordem neutra.
- [ ] A Lente não aparece no iCloud do segundo aparelho nem volta depois de restaurar um backup; reinstalar pergunta de novo.
- [ ] Nenhum cartaz, notificação, Atividade ao Vivo ou resultado do Spotlight mostra quem a pessoa apoia.
- [ ] Exportar dados gera o JSON com a Lente e os seguidos.

### Explicações no aparelho

- [ ] Aparelho com Apple Intelligence: a explicação aparece com o selo "Explicação gerada pela Apple Intelligence no seu iPhone · pode errar; vale o texto oficial".
- [ ] Aparelho sem Apple Intelligence (ou com ela desligada): fica o texto fixo, sem selo e sem erro.
- [ ] Modo avião: a explicação continua (roda no aparelho).

### Interface por plataforma

- [ ] iPhone retrato e paisagem em todas as abas, no perfil, na Apuração, na Lente e no compartilhar.
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

No simulador o app usa o banco local com CloudKit desligado e não recebe push de Atividade ao Vivo; nos aparelhos, o container `iCloud.fiscal`, o App Group, o push e o App Attest precisam das capabilities e da assinatura.
