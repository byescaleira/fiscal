# Etapas: live-results

- [x] Domínio: `Race`, `RaceCandidate`, `RaceActivityState`, `RaceActivityAttributes` e `RaceText`, com testes de contrato e de push.
- [x] Dados: `LiveResultsClient`, com `-FiscalAPIURL` como sobreposição só em debug.
- [x] Feature `FeatureLiveResults`: model com atualização a cada 15 s, controle das Live Activities e tela; 7 testes do model.
- [x] Extensão `FiscalWidgets`, com a Live Activity (tela de bloqueio e Dynamic Island), embutida só no iOS.
- [x] Textos nos 10 idiomas, no app e no widget.
- [ ] Servidor `server/` em Go: poller do TSE, API, registro de tokens e push APNs. Testes verdes.
- [ ] Deploy em `/opt/fiscal-api` (porta `127.0.0.1:3130`) e bloco `fiscal.byescaleira.com` no Caddy com `handle /api/*`, cada passo com o ok do usuário.
- [ ] Chave APNs em `/opt/fiscal-api/secrets/apns.p8`, copiada pelo usuário.
- [ ] Teste ponta a ponta no modo de simulação do servidor: iniciar a Live Activity no iPhone e receber os pushes.
- [ ] Voltar o servidor para o TSE real antes das 17h (Brasília).
- [ ] No iPhone físico: instalar, abrir a Apuração e acompanhar a disputa na tela de bloqueio.

## Fica para depois (backlog)

- Remover o exemplo `Item` do template (`FeatureHome`, repositório, rotas e intent), que continua no código, mas fora da aba.
- Push-to-start, para a atividade começar sozinha quando a apuração começar.
- Revisões de design, acessibilidade e código sobre o diff da fase.
