# Admin do Fiscal

Painel em `https://fiscal.byescaleira.com/admin` para controlar o app sem publicar versão: flags remotas, política de versões e a ponte do Fiscal na Web. Receita completa na skill `byescaleira-sdd` (`admin-and-remote-config.md`); código e runbook em `admin/` e `admin/README.md`.

## Por que assim

- **Flags e versões ficam no CloudKit público** do container `iCloud.fiscal`. O app lê sem login na abertura (`CloudKitFlagSource`); a carga é da Apple. O admin só **escreve** nesses registros.
- **A VPS só atende o que não tem outro jeito** (a ponte do Fiscal na Web). Sob carga, a primeira alavanca é o rollout da flag `web`, depois a pausa da ponte.

## Serviço

- Container `fiscal-admin` (Node 22, só `@simplewebauthn/server` com versão fixa e `package-lock.json`) em `127.0.0.1:3120`, `read_only`, usuário `node`, sem capabilities, atrás de `handle /admin*` no Caddy.
- Pasta `/opt/fiscal-admin`; graváveis só `secrets/` (`cloudkit.pem`, `auth.json`) e `data/` (`audit.log`).
- Fala com a ponte pela rede Docker `fiscal-control` em `http://fiscal-bridge:3111`, com `BRIDGE_ADMIN_TOKEN`. A ponte sobe antes, porque é ela que cria a rede.
- `.env` (chmod 600): `BRIDGE_ADMIN_TOKEN`, `CLOUDKIT_KEY_ID_DEVELOPMENT` e `CLOUDKIT_KEY_ID_PRODUCTION` (uma chave server-to-server por ambiente, mesma chave pública). `CLOUDKIT_KEY_ID` vale para os dois quando os específicos estão vazios.
- Testes: `cd admin && npm ci && npm test` (ponte real de `../bridge/server.mjs` e um CloudKit falso que confere a assinatura).

## Acesso

- **Primeiro acesso:** código de configuração de uso único no log (`docker compose logs fiscal-admin | grep "setup code"`), válido por 30 minutos. Em `/admin/setup` o usuário digita o código, cria a senha (14+ caracteres, scrypt) e registra a passkey (RP ID `fiscal.byescaleira.com`). Depois `/admin/setup` responde 404.
- **Entrar:** senha **e** passkey. Cinco erros por IP em 15 minutos bloqueiam por 15 minutos.
- **Sessão:** cookie `fiscal_admin` `HttpOnly; Secure; SameSite=Strict; Path=/admin`, 12 horas, em memória. Toda escrita confere `Origin`.
- O Claude sobe o serviço e o Caddy; senha, passkey, chaves no Console e Deploy Schema Changes ficam com o usuário.

## Telas

1. **Visão geral:** estado da ponte, sessões guardadas, leituras e escritas por minuto, `429` e `503` por minuto, memória, tempo no ar e o gráfico da última hora.
2. **Flags:** o catálogo de `admin/src/flags.mjs` com o padrão do app e o valor remoto em Desenvolvimento e em Produção, interruptor, rollout de 0 a 100% e "voltar ao padrão".
3. **Versões:** a política `AppRelease` por plataforma (`ios`, `macos`, `visionos`) em Desenvolvimento e em Produção: versão e build mínimas e recomendadas, recomendada ≥ mínima. "Remover política" apaga o registro e o app deixa de pedir atualização.
4. **Ponte:** pausar e retomar, limite de sessões, leituras e escritas por minuto por IP, tamanho máximo do pacote e validade (até 24 h).
5. **Registro:** as últimas ações do admin, sem dados de usuários.

## Catálogo de flags

`admin/src/flags.mjs` espelha o `enum FeatureFlag` (`FiscalKit/Sources/FeatureCore/Flags/FeatureFlag.swift`): mesmo nome, título em pt-BR e mesmo padrão. Flag nova no app entra no mesmo commit no admin; o admin recusa nomes que não conhece.

| Flag | Título | Padrão |
| --- | --- | --- |
| `guides` | Guias | ligada |
| `web` | Fiscal na Web | ligada |

## Esquema no CloudKit Console (banco Public)

A chave server-to-server **não cria schema**. O usuário cria em **Development** e publica em **Production** com **Deploy Schema Changes** (irreversível).

**`FeatureFlag`** (um registro por flag, `recordName` = nome):

| Campo | Tipo | Índice |
| --- | --- | --- |
| `recordName` | sistema | Queryable (o app consulta com `TRUEPREDICATE`) |
| `name` | String | Queryable |
| `isOn` | Int64 | — |
| `rollout` | Int64 | — |

**`AppRelease`** (um registro por plataforma, `recordName` = `ios`, `macos` ou `visionos`):

| Campo | Tipo | Índice |
| --- | --- | --- |
| `recordName` | sistema | Queryable |
| `platform` | String | Queryable |
| `minimumVersion` | String | — |
| `minimumBuild` | Int64 | — |
| `recommendedVersion` | String | — |
| `recommendedBuild` | Int64 | — |

- Permissões dos dois tipos: `World` e `Authenticated` só **Read**; quem grava é a chave do admin.
- Sem registro no ambiente, vale o padrão do código (flags) ou nenhuma política (versões).

## Capacidade

- Pacote médio do resumo de 20 a 80 KB; com o limite padrão de 5.000 sessões, a ponte fica abaixo de ~400 MB (`mem_limit` 768 MB).
- A página espera o QR com uma busca a cada 2 s (até 10 minutos) e depois a cada 30 s; o app só envia quando os dados mudam.
- Sob carga: 1) baixar o rollout da flag `web` em Produção; 2) pausar a ponte; 3) só então mexer em limites ou máquina.
