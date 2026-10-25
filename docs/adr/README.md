# Decisões de arquitetura (ADRs)

Cada decisão que molda o Fiscal além de uma única mudança ganha um registro curto aqui: o contexto, o que foi decidido, as consequências e as alternativas. As decisões de antes dos ADRs estão em [decisions.md](../decisions.md), como histórico.

## Quando escrever

- Arquitetura, targets e dependências entre eles; dependência externa nova.
- Dados: schema, migração, CloudKit, backup, o que sai do aparelho.
- Plataforma, versão mínima, integração com o sistema, monetização.
- Exceção do lint ou da auditoria (`.byescaleira-sdd.json › allow`).
- Qualquer regra que contrarie a [constituição](../constitution.md) ou a skill `byescaleira-sdd` (a constituição muda no mesmo commit).

## Como escrever

1. Copie [0000-template.md](0000-template.md) para `NNNN-<titulo-em-kebab-case>.md`, com o próximo número livre de quatro dígitos e o título em inglês.
2. Preencha em pt-BR, curto: uma decisão por ADR.
3. Estado: **Proposto** enquanto espera o usuário; **Aceito** com o ok; **Substituído por NNNN** quando outro ADR o troca (o antigo não é apagado nem reescrito, só ganha o novo estado).
4. Acrescente a linha no índice abaixo, no mesmo commit.

## Índice

| ADR | Título | Estado |
| --- | --- | --- |
| [0001](0001-record-architecture-decisions.md) | Registrar decisões em ADRs | Aceito |
| [0002](0002-static-first-server.md) | Servidor estático primeiro: tudo pronto, nada calculado por acesso | Aceito |
| [0003](0003-portuguese-only.md) | O Fiscal é só em português do Brasil | Aceito |
| [0004](0004-lens-on-device-store.md) | A Lente fica num banco só do aparelho; os seguidos no iCloud privado | Proposto |
| [0005](0005-data-ingest-process.md) | Carga de dados num processo próprio, com ligações e slugs guardados no servidor | Proposto |
| [0006](0006-ingest-sqlite-store.md) | A carga guarda tudo num SQLite com histórico, e os arquivos públicos saem dele | Aceito |
