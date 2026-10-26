# Validação

Como verificar o Fiscal antes de uma versão, do automático ao que depende de aparelhos e dados reais. O caminho até a loja está em [app-store/README.md](app-store/README.md); a atualização obrigatória, em [force-update.md](force-update.md). O app é gratuito: não há compras para validar.

## Automático

Rode antes de cada commit; o Xcode Cloud repete os mesmos passos.

```sh
scripts/format.sh
scripts/lint.sh
scripts/build.sh Debug
scripts/test.sh
scripts/audit.sh
```

- Zero warnings em iOS, macOS, visionOS e nos testes do pacote.
- `scripts/test.sh` usa o simulador só pelo sim-monitor (`scripts/simulator.sh acquire`, `FISCAL_TEST_DESTINATION="platform=iOS Simulator,id=<udid>"`, `release`).
- `scripts/ui-test.sh` confere o layout em telas grandes (iPad).
- `scripts/audit.sh` só roda quando o pacote tiver o target `FiscalAudit` (migração, preview e volume).
- Testes que dependem do modelo de linguagem do sistema falham no simulador; rode-os no aparelho e não conte como regressão.

## Antes de distribuir

Roteiro manual a cada build candidata. Marque cada item na build que vai para a revisão e anote o número da build.

Build: `____` · Data: `__/__/____`

### Aparelhos

- [ ] iPhone físico com a build do TestFlight (Release, ambiente de produção do CloudKit).
- [ ] Segundo aparelho assinado com a mesma conta do iCloud (iPad ou outro iPhone).
- [ ] Mac com o app de macOS, se a versão for para o Mac.
- [ ] Apple Vision Pro ou simulador de visionOS, se a versão for para o visionOS.
- [ ] Cada plataforma do envio tem capturas reais dela (ver [app-store/media/README.md](app-store/media/README.md)).

### CloudKit em dois aparelhos

- [ ] Schema publicado em Production pelo usuário no CloudKit Console.
- [ ] Criar no aparelho A e ver chegar no B; editar no B e ver voltar no A.
- [ ] Excluir num aparelho e conferir que some no outro.
- [ ] Offline num aparelho: criar e editar, reconectar e conferir que nada se perde nem duplica.
- [ ] Conflito: editar o mesmo item nos dois aparelhos sem rede e reconectar; o resultado é previsível.
- [ ] Duas janelas no iPad (e no Mac) mostram a mesma mudança.
- [ ] Conta do iCloud desligada ou cheia: o app continua funcionando com o banco local.

### Backup e exportação

- [ ] Exportar os dados (JSON) e abrir o arquivo: tudo presente e legível.
- [ ] Apagar tudo, importar o backup e conferir contagens e totais.
- [ ] Importar num segundo aparelho com iCloud e ver os registros chegarem ao primeiro.
- [ ] Exportar continua disponível na tela de atualização obrigatória.

### Interface por plataforma

- [ ] iPhone retrato e paisagem: criar, editar e excluir em cada editor.
- [ ] iPad: barra lateral, inspetor, Split View e Stage Manager; rotação com editor aberto.
- [ ] Mac: janela redimensionada, Ajustes em janela própria, atalhos de teclado e menus.
- [ ] visionOS: ornamentos, profundidade e alvos de toque.
- [ ] Tema claro e escuro, cada cor de destaque e os 10 idiomas (textos longos em alemão e russo, sem corte).
- [ ] Estados vazios com exemplo e guia; erros com mensagem e saída.

### Acessibilidade

- [ ] VoiceOver: cada controle tem rótulo, valor e dica; ordem de leitura faz sentido; gráficos e barras têm resumo.
- [ ] Dynamic Type até o maior tamanho de acessibilidade, sem texto cortado nem sobreposto.
- [ ] Reduzir movimento troca as animações Lottie pela pose parada.
- [ ] Contraste aumentado e Diferenciar sem cor: o estado não depende só da cor.

### Integrações no aparelho

- [ ] App Intents e App Shortcuts: frases da Siri em pt-BR e em inglês, e no app Atalhos.
- [ ] Widgets em cada tamanho, com dados reais, e tocando para abrir a tela certa.
- [ ] Controles da Central de Controle e do botão de Ação, se houver.
- [ ] Notificações com ação, deep links (`fiscal://...`) e links universais.
- [ ] Face ID, câmera e outras permissões: pedido, recusa e caminho para os Ajustes.

### Atualização obrigatória

Detalhes em [force-update.md](force-update.md#como-testar).

- [ ] Política `AppRelease` com a mínima acima da build instalada bloqueia o app ao abrir.
- [ ] Modo avião e reabrir: continua bloqueado (vale o cache).
- [ ] **Export Data** funciona na tela de bloqueio; **Update** abre a página do app na App Store.
- [ ] Baixar a mínima no admin e voltar ao primeiro plano depois de 1 minuto: o bloqueio sai.
- [ ] Só a recomendada acima: o aviso aparece uma única vez para aquela versão.
- [ ] Política final em Production deixa a build da revisão em `current`.

No simulador o app usa o banco local com CloudKit desligado; nos aparelhos, o container `iCloud.fiscal` precisa das capabilities e da assinatura.
