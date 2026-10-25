# Roadmap

O que o Fiscal vai ganhar, por fase. Cada fase diz o que entrega, a tecnologia e o tamanho; os pré-requisitos técnicos ficam no [backlog.md](backlog.md) e cada fase vira uma ou mais mudanças em [changes/](changes/README.md).

## Como dimensionar

- **S:** uma sessão; uma mudança pequena, sem dado novo nem tela nova (ajuste, texto, flag, integração já pronta no template).
- **M:** duas ou três etapas; uma tela ou entidade nova com testes, sem migração delicada.
- **L:** quatro ou mais etapas; dado novo com migração, serviço externo, plataforma nova ou fluxo inteiro. Fase L que puder ser dividida vira duas fases M.
- **Mantenha a 1.0 com até ~8 fases.** Passou disso, corte escopo para depois da 1.0 antes de começar; o template já traz a base (fase 0) pronta, então não refaça o que ele entrega.

## Fases

| Fase | Entrega | Tecnologia | Tamanho | Estado |
| --- | --- | --- | --- | --- |
| 0 | Base: estrutura por feature, design system, Ajustes (Aparência, Idioma, Guias, Sobre), guias com Lottie, flags, deep links, dez idiomas, lint, scripts, CI, site, ponte e admin | Template `byescaleira-workspace` | S | pronta |
| 1 | Primeira feature real, no lugar do exemplo `Item` | _a definir_ | _S/M/L_ | _a definir_ |
| _N_ | _..._ | _..._ | _S/M/L_ | _..._ |

A fase 1 é definida com o usuário: proposta em `docs/changes/<id>/`, desenho e etapas em fases, crítica antes de desenhar telas e a spec em `docs/specs/` ao arquivar.

## Depois da 1.0

- Widgets e controles (WidgetKit), App Intents, notificações, assinatura (StoreKit), onboarding, conforme `references/` da skill `byescaleira-sdd`.
