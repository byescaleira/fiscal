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
| [0004](0004-lens-on-device-store.md) | A Lente fica num banco só do aparelho; os seguidos no iCloud privado | Aceito |
| [0005](0005-data-ingest-process.md) | Carga de dados num processo próprio, com ligações e slugs guardados no servidor | Aceito |
| [0006](0006-ingest-sqlite-store.md) | A carga guarda tudo num SQLite com histórico, e os arquivos públicos saem dele | Aceito |
| [0007](0007-pages-cdn-phased-ingest.md) | Dados públicos no Cloudflare Pages, carga em fases na VPS atual e App Attest no registro | Aceito; calendário e publicação substituídos por [0008](0008-smart-sync.md) |
| [0008](0008-smart-sync.md) | Sincronização por cadência, detecção de mudança e reconstrução incremental | Aceito |
| [0009](0009-bricolage-emphasis-font.md) | Bricolage Grotesque como fonte de ênfase, SF Pro no corpo | Aceito |
| [0010](0010-byescaleira-kit.md) | Design, componentes e idioma vêm do byescaleira-kit | Aceito |
| [0011](0011-free-app-noncommercial-license.md) | App gratuito sem StoreKit e código sob a PolyForm Noncommercial | Aceito |
| [0012](0012-constitution-version-and-facts.md) | Constituição: versão e "fato, não opinião" | Aceito |
| [0013](0013-party-symbol-icons.md) | Ícones alternativos de partido com símbolos genéricos, atrás de flag | Aceito |
| [0014](0014-settings-in-today-toolbar.md) | Ajustes na toolbar de Hoje, não numa aba | Aceito |
| [0015](0015-background-fetch-offline-pack.md) | Modo `fetch` em segundo plano para o pacote offline | Aceito |
| [0016](0016-web-companion-after-1-0.md) | Fiscal na Web só depois da 1.0 | Aceito |
| [0017](0017-app-store-privacy-label.md) | Rótulo de privacidade da loja com os tokens e as chaves guardados no servidor | Aceito |
| [0018](0018-widgets-read-public-data.md) | Os widgets leem os dados públicos direto, sem retrato escrito pelo app | Proposto |
