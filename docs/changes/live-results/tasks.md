# Etapas: live-results

- [x] Domínio: `Race`, `RaceCandidate`, `RaceActivityState`, `RaceActivityAttributes` e `RaceText`, com testes de contrato e de push.
- [x] Dados: `LiveResultsClient`, com `-FiscalAPIURL` como sobreposição só em debug.
- [x] Feature `FeatureLiveResults`: model com atualização a cada 15 s, controle das Live Activities e tela; 7 testes do model.
- [x] Extensão `FiscalWidgets`, com a Live Activity (tela de bloqueio e Dynamic Island), embutida só no iOS.
- [x] Textos nos 10 idiomas, no app e no widget.
- [x] Servidor `server/` em Go: poller do TSE, arquivos estáticos pré-comprimidos, registro de tokens e push APNs. Testes verdes com `-race`; `govulncheck` limpo no Go 1.26.10.
- [x] Deploy em `/opt/fiscal-api` (porta `127.0.0.1:3130`, por enquanto com `APNS_DISABLED=1`) e bloco `fiscal.byescaleira.com` no Caddy, com o ok do usuário. Conferido de fora: 200, gzip, `ETag` e `304`; vizinhos em 200.
- [ ] Chave APNs em `/opt/fiscal-api/secrets/apns.p8`, copiada pelo usuário.
- [x] Cenários simulados da tela e da Live Activity (`-FiscalLiveScenario`), com testes.
- [ ] Conta Apple no Xcode para assinar o bundle novo (feito pelo usuário).
- [ ] Teste ponta a ponta no modo de simulação do servidor: iniciar a Live Activity no iPhone e receber os pushes.
- [ ] Voltar o servidor para o TSE real antes das 17h (Brasília).
- [ ] No iPhone físico: instalar, abrir a Apuração e acompanhar a disputa na tela de bloqueio.

## Fica para depois (backlog)

- Remover o exemplo `Item` do template (`FeatureHome`, repositório, rotas e intent), que continua no código, mas fora da aba.
- Push-to-start, para a atividade começar sozinha quando a apuração começar.
- Revisões de design, acessibilidade e código sobre o diff da fase.
