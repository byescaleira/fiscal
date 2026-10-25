# 0003. O Fiscal é só em português do Brasil

- **Estado:** Aceito
- **Data:** 2026-10-25
- **Mudança:** nenhuma (a retirada dos outros idiomas vira uma mudança própria)

## Contexto

A constituição do template manda inglês como língua primária e um catálogo com 10 idiomas. O Fiscal é sobre política brasileira: representantes, votações e eleições do Brasil, com fontes oficiais em português, para um público brasileiro. O usuário decidiu em 2026-10-25: "é um caso excepcional", só português.

## Decisão

1. O app, os widgets, a Live Activity, as notificações e o site do Fiscal saem **só em português do Brasil** (`pt-BR`).
2. **Código continua em inglês**, inclusive as chaves dos catálogos. O catálogo guarda apenas a tradução `pt-BR` de cada chave, e a região de desenvolvimento do app passa a ser `pt-BR`.
3. Ajustes não tem mais a escolha de idioma.
4. O push de fim de apuração no servidor continua em português.

## Consequências

- Menos trabalho por tela (um idioma só) e textos mais cuidados para o público real.
- A regra 6 da constituição ganha a exceção do Fiscal, no mesmo commit.
- Fica uma mudança a fazer: tirar os 9 outros idiomas dos catálogos e do `knownRegions`, trocar a região de desenvolvimento para `pt-BR`, remover a seção de idioma dos Ajustes e os testes que dependem dela, e ajustar o site.
- A auditoria do plugin pode cobrar os 10 idiomas; a exceção entra em `.byescaleira-sdd.json › allow`, citando este ADR.

## Alternativas consideradas

- **Manter os 10 idiomas:** custo de tradução em toda tela para um público que não existe.
- **Inglês e português:** só ajudaria a ler o app no júri da Apple; o júri avalia o app no mercado dele, e as capturas e o vídeo podem ter legenda.
