# Revisão da FSC-016: cartões no modo claro e bonequinho de todos

- **Canvas:** [FSC-016](../prompt/FSC-016-202611021923-[Feat]-light-cards-and-portraits.md)
- **Intervalo revisado:** `efaae65..37b543c`, numa rodada só, com o `spec-reviewer` e o painel de interface e código.
- **Veredito do canvas:** Needs Rework (2 críticos, 3 importantes, 1 informativo). **Veredito do painel:** aprovado, sem bloqueador, com 1 "deveria" e 6 detalhes.
- **Limite:** os revisores só leram o código; não rodaram build nem testes.

## Achados do canvas

| Severidade | Onde | Achado | O que foi feito |
| --- | --- | --- | --- |
| crítica | Safeguard "Modo escuro igual" | Faltava a captura de comparação | Comparados os builds de `efaae65` e o novo: placar sem pixel diferente; comparar difere só no rosto corrigido. Conclusão e "Na sua região agora" seguem só lidos no código, declarado no QA |
| crítica | Cenário 6 | Sem prova automática | `scripts/portrait-check-test.py`, no `verify --full` |
| importante | `HeroSurface` | Com mais de duas colunas, a do meio perdia a cor | `HeroTone.lightStops`, com teste |
| importante | QA 14 e 17 | Afirmavam além da evidência | Capturas com legenda; 14 "em parte" e 17 "não comprovado" |
| importante | `spdd/README.md` | Atualizar no fechamento | No fechamento |
| informativa | Análise | Fala nos 16 cartões da primeira leitura | Mantida como histórico; o alcance está no canvas e no ADR |

## Achados do painel

| Severidade | Onde | Achado | Decisão |
| --- | --- | --- | --- |
| deveria | `PortraitLibrary.swift:76` | O script é a única defesa contra rosto errado, e o modo publicado é manual | Registrado no ADR 0025 e na validação; rodado antes deste PR |
| detalhe | `HeroCardsTests.swift:20` | Não falha se o preto voltar | Mantido; cobertura visual, declarada no QA |
| detalhe | `VoteHeroSection.swift:50` | Texto simples no claro e chip no escuro | Mantido, escolha do usuário; VoiceOver não usado |
| detalhe | `VoteHeroSection.swift:90` | Regra do "Não" no ponto de uso | Mantido |
| detalhe | `HeroSurface.swift:50` | `dimmed` e `secondary` iguais no claro | Mantido |
| detalhe | `HeroSurface.swift:70` | Escuro com Aumentar contraste não conferido | Fora do canvas |
| detalhe | `HeroSurfaceTests.swift:58` | Contraste com valores copiados do sistema | Declarado no QA |
