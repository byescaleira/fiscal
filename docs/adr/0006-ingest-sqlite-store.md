# 0006. A carga guarda tudo num SQLite com histórico, e os arquivos públicos saem dele

- **Estado:** Aceito
- **Data:** 2026-10-25
- **Mudança:** [`app-1.0`](../changes/app-1.0/proposal.md)

## Contexto

O `fiscal-ingest` ([ADR 0005](0005-data-ingest-process.md)) lê as fontes, monta o conjunto em memória e grava os arquivos estáticos; o que foi lido não fica guardado em lugar nenhum além do cache de downloads. Uma fonte obrigatória fora do ar interrompe a carga inteira, e nada guarda o que mudou de um dia para o outro (troca de partido, de situação, voto, gasto, preço). O usuário pediu, em 2026-10-25, um backend que armazene tudo e sincronize sozinho, e decidiu: SQLite no próprio serviço, com a dependência Go pura `modernc.org/sqlite`, e backup diário.

## Decisão

1. **Um banco SQLite é a fonte da verdade e o histórico da carga:** `STORE_PATH` (padrão `DATA_DIR/fiscal.db`), modo WAL, `synchronous=NORMAL`, `temp_store=MEMORY` (o container é `read_only`), uma conexão só, arquivos `0600`. O schema é versionado em `schema_migrations` e migra no boot; um banco mais novo que o binário derruba o processo (falha fechada).
2. **Exceção à regra "só biblioteca padrão":** `modernc.org/sqlite` v1.60.1 (Go puro, `CGO_ENABLED=0` continua valendo), só no `fiscal-ingest`, pacote `internal/datastore`. A apuração (`liveresults-server`) não importa o pacote. `go.sum` vai no repositório e na imagem (`go mod verify` no build).
3. **Nada é apagado quando a fonte muda.** Toda tabela de dado tem `source`, `key`, `hash`, `payload` (JSON), `valid_from`, `valid_to`, `first_run` e `seen_run`. Ler a mesma coisa de novo só marca `seen_run`; conteúdo diferente fecha a versão atual (`valid_to`) e abre outra; o que sumiu de uma leitura completa da fonte é fechado, nunca apagado. As tabelas: `people`, `mandates`, `votes`, `ballots`, `propositions`, `expenses`, `places`, `city_officials`, `snapshots` (genérico por fonte e chave) e `series` (série histórica por `series_id`, `scope` e `date`).
4. **CPF nunca em claro no banco:** antes de gravar e antes da ligação entre bases, o CPF vira a chave interna `cpf:<hash>` (`publicdata.CPFKey`, agora idempotente). A ligação só compara igualdade, então o resultado é o mesmo.
5. **Cada execução é registrada** em `sources_runs` (início, fim, estado `ok`, `failed`, `fallback` ou `skipped`, contagens e erro), uma linha por execução e uma por fonte. O resumo sem erro nem caminho, sem segredo, sai em `PUBLIC_DIR/v1/status.json`.
6. **O servidor continua estático** ([ADR 0002](0002-static-first-server.md) segue valendo para as requisições): nenhuma leitura pública toca o banco. Os arquivos passam a ser gerados a partir do que está guardado: com a fonte lida, o conteúdo gravado é o publicado; com a fonte fora do ar, a carga usa a última leitura guardada daquela fonte, mantém o `updatedAt` dela e marca `fallback`. Sem nada guardado, vale o fluxo de antes (fonte obrigatória interrompe a carga; opcional vira `null`). Isso substitui o item 7 do ADR 0005 só quando há leitura guardada.
7. **Backup diário** depois da primeira carga completa bem-sucedida do dia: `VACUUM INTO` para `DATA_DIR/backups/fiscal-AAAA-MM-DD.db` (cópia consistente com o banco aberto), mantendo os `BACKUP_KEEP` mais novos (padrão 14). **Restauração:** com o serviço parado, `fiscal-ingest -restore <arquivo>` confere `PRAGMA integrity_check`, troca o banco por escrita atômica e apaga `-wal` e `-shm`.

## Consequências

- Fonte obrigatória fora do ar não derruba mais a publicação do dia, e a idade de cada dado fica visível no `updatedAt` e no `status.json`.
- O histórico permite responder "desde quando" e "o que mudou" (partido, situação, mandato, gasto, voto, preço) sem refazer a carga.
- O disco cresce: a carga nacional guarda votos nominais (centenas de milhares de linhas por ano) e gastos; cada backup é uma cópia inteira. Vigiar `ingest-data/` e `ingest-backups/`.
- A carga completa fica mais lenta (uma transação por fonte); a atualização ao vivo só grava as votações e a pauta do dia.
- Obrigação nova: copiar `ingest-backups/` para fora da VPS de vez em quando; um backup só na mesma máquina não protege de perder o disco.
- `slugs.json` e `sources.json` continuam como estão; podem migrar para o banco depois.

## Alternativas consideradas

- **Continuar só com arquivos JSON em `DATA_DIR`:** sem histórico nem consulta, e cada nova fonte inventaria seu próprio formato de cache.
- **Postgres em outro container:** mais um serviço para operar e proteger numa VPS dividida, para um único escritor.
- **SQLite com `mattn/go-sqlite3`:** exige CGO e toolchain C na imagem; o `modernc.org/sqlite` já é o padrão do workspace (`crunchy`).
