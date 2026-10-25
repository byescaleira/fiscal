# 0004. Carga de dados num processo próprio, com ligações e slugs guardados no servidor

- **Estado:** Proposto
- **Data:** 2026-10-25
- **Mudança:** [`app-1.0`](../changes/app-1.0/proposal.md)

## Contexto

A 1.0 publica perfis, votações, gastos, pauta e o resumo do dia como arquivos estáticos ([ADR 0002](0002-static-first-server.md), [contrato](../changes/app-1.0/contract.md)). Os dados vêm de seis fontes oficiais com formatos, limites e horários diferentes, e o mesmo político aparece em várias delas sem uma chave comum publicada. A apuração ao vivo já roda no container `fiscal-api` e não pode parar por causa da carga.

## Decisão

1. **Um binário próprio, `fiscal-ingest`, na mesma imagem**, num segundo serviço do `compose.yaml` (`fiscal-ingest`): sem porta, `read_only`, sem capacidades, escrevendo só em `/data` (volume `ingest-data`) e em `/public`. Carga completa diária e atualização ao vivo a cada 10 minutos.
2. **Um pacote por fonte** (`internal/sources/{camara,senado,tse,ibge,receita,assembleias}`) que só lê e converte, e um pacote `internal/publicdata` que liga as bases e monta os arquivos do contrato. A escrita atômica com `.gz` saiu da apuração para `internal/publish`, usada pelos dois processos.
3. **Ligações:** CPF entre Câmara e TSE; nome + UF + cargo + ano entre Senado e TSE, só com resultado único. O CPF não é publicado: internamente vira um hash com prefixo fixo.
4. **Quem está no cargo** segue a casa (Câmara, Senado e, onde existe, o SAPL da assembleia); o que só o TSE informa (presidente, governadores, deputados estaduais) segue o resultado de 2022, com a regra de desincompatibilização (art. 14, § 6º): o chefe do Executivo que disputou outro cargo em 2026 renunciou, e o vice assume.
5. **Slugs estáveis por registro** (`DATA_DIR/slugs.json`): um slug dado a uma pessoa não muda nem passa para outra quando surge um homônimo.
6. **Datas de fonte estáveis** (`DATA_DIR/sources.json`): o `updatedAt` de uma fonte só muda quando os dados dela mudam, para os arquivos não serem regravados (e o `ETag` não mudar) sem novidade.
7. **Falha fechada:** fonte obrigatória que falha, ou lista menor que o esperado, interrompe a carga sem publicar; fonte opcional vira `null` com `coverage` explicando.

## Consequências

- A apuração e a carga sobem e caem separadas; a reinicialização da apuração não apaga mais os arquivos da carga (só `races*`).
- O servidor guarda estado que precisa de backup: `slugs.json` (perder o arquivo pode trocar slugs de homônimos) e o cache de downloads (perder só custa tempo e banda).
- A cobertura dos governadores e deputados estaduais depende da regra de 2022 + 2026: vacâncias por morte, cassação ou licença sem registro no SAPL não aparecem.
- O `mem_limit` de 1536m é uma estimativa com folga: a carga limitada (AC, 2026, com os arquivos nacionais da Câmara) teve pico de 108 MiB; a nacional ainda não foi medida. O cache em disco fica na casa de centenas de MiB a 1 GiB.

## Alternativas consideradas

- **Modo `ingest` dentro do `liveresults-server`:** um processo só, mas uma falha ou pico de memória da carga derrubaria a apuração em dia de eleição.
- **Banco de dados (SQLite ou Postgres):** facilitaria consultas, mas o contrato é de arquivos prontos e a biblioteca padrão basta para gerá-los; fica para quando houver histórico de várias legislaturas.
- **Slug calculado a cada carga:** mais simples, mas um homônimo novo trocaria o slug de quem já está salvo nos aparelhos.
