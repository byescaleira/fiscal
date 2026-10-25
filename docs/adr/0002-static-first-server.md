# 0002. Servidor estático primeiro: tudo pronto, nada calculado por acesso

- **Estado:** Aceito
- **Data:** 2026-10-25
- **Mudança:** [`live-results`](../changes/live-results/proposal.md)

## Contexto

A VPS é simples (2 vCPU, ~8 GB, vários serviços dividindo a máquina), e o app pode ter milhões de acessos simultâneos em dia de eleição ou de votação importante. O usuário pediu, em 2026-10-25: tudo cacheado, sem busca no servidor e sem processamento por acesso.

## Decisão

1. **Nenhuma leitura chama código.**
   - A carga e o poller geram arquivos JSON prontos, e uma versão `.gz` de cada um, numa pasta pública.
   - Quem entrega esses arquivos é o Caddy (`file_server` com `precompressed gzip`), com `Cache-Control: public` e `ETag`.
   - O Go nunca está no caminho de leitura.
2. **Um CDN na frente antes do lançamento.**
   - A pasta pública é publicada num CDN (Vercel ou Cloudflare), e a VPS vira só a origem.
   - Até lá, o Caddy serve os arquivos estáticos direto.
3. **A busca é feita no aparelho.**
   - O app baixa um índice compacto (nome, cargo, UF, partido, slug) e busca localmente.
   - O servidor não tem rota de busca.
4. **Perfis, listas e votações são arquivos por chave.** Exemplos: `v1/politicians/{slug}.json`, `v1/votes/{id}.json`, `v1/lists/{area}-{uf}.json`. Eles são regerados só quando a fonte muda.
5. **Push em escala, por canal.**
   - A Live Activity vai migrar para os canais de broadcast do APNs (iOS 18+): uma mensagem por disputa ou votação, qualquer que seja o número de pessoas.
   - O registro por token fica só enquanto o app estiver no TestFlight.
6. **A única escrita pública** é o registro de token (pequeno, com limite de taxa e teto), e ela some com o broadcast.

## Consequências

- A VPS aguenta pico porque só entrega arquivos pequenos e já comprimidos; com o CDN, quase nada chega nela.
- A carga fica mais pesada: precisa gerar e apagar arquivos, e o tamanho total da pasta pública precisa ser vigiado.
- O índice de busca vai junto com o app e é atualizado por arquivo versionado. A busca em texto livre do conteúdo (por exemplo, o resumo das propostas) também vira um índice baixado por tema ou fica para depois.
- A regra do backend "`Cache-Control: no-store` em resposta com dado" continua valendo para dado de pessoa, que este serviço não tem. Para dado público, vale `public` com validade curta.

## Alternativas consideradas

- **API dinâmica com cache em memória:** cada acesso ainda passa pelo Go, e milhões de conexões derrubam a VPS antes do cache ajudar.
- **App lendo direto o CDN do TSE:** funciona para a apuração, mas prende o app ao formato do TSE e não serve para os outros dados. Fica como plano B para a apuração, se a VPS cair.
