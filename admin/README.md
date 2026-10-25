# Fiscal Admin

Painel em `https://fiscal.byescaleira.com/admin` para flags remotas (CloudKit público) e para a ponte do Fiscal na Web. Spec: `docs/admin.md`.

- Código: `src/` (Node 22, só `@simplewebauthn/server` como dependência, versão fixa com `package-lock.json`). Testes: `npm test` (precisa do `../bridge/server.mjs` ao lado, usado como ponte real nos testes).
- Telas: Visão geral (estado da ponte e gráfico da última hora), Flags (Desenvolvimento e Produção), Versões (`AppRelease` por plataforma, Desenvolvimento e Produção; esquema em `docs/admin.md`), Ponte (pausa e limites), Registro.
- Visual: usa o `/style.css` do site e só acrescenta `public/admin.css`.
- Catálogo de flags: `src/flags.mjs` espelha o `enum FeatureFlag` do app (`FiscalKit/Sources/FeatureCore/Flags/FeatureFlag.swift`), com o mesmo nome, um título em pt-BR e o mesmo padrão. Flag nova no app entra no mesmo commit aqui; o admin recusa nomes que não conhece. O template já traz `guides` e `web` (a alavanca de carga do Fiscal na Web).

## Como roda na VPS

- Pasta `/opt/fiscal-admin` com `Dockerfile`, `compose.yaml`, `package.json`, `package-lock.json`, `src/`, `public/`.
- Container `fiscal-admin` em `127.0.0.1:3120`, `read_only`, usuário `node` (uid 1000), sem capabilities. Só `secrets/` e `data/` são graváveis (pastas do host, dono 1000, `chmod 700`).
- `.env` (chmod 600): `BRIDGE_ADMIN_TOKEN` (o mesmo de `/opt/fiscal-bridge/.env`), `CLOUDKIT_KEY_ID_DEVELOPMENT` e `CLOUDKIT_KEY_ID_PRODUCTION` (o CloudKit cria uma chave server-to-server por ambiente; as duas usam a mesma chave pública). `CLOUDKIT_KEY_ID` vale para os dois se os específicos estiverem vazios.
- `secrets/cloudkit.pem`: chave privada P-256 do CloudKit (chmod 600, nunca sai da VPS). `secrets/auth.json`: hash scrypt da senha e a passkey.
- `data/audit.log`: registro das ações do admin, uma linha JSON por ação.
- Conversa com a ponte pela rede Docker `fiscal-control` em `http://fiscal-bridge:3111` (porta interna da ponte, nunca publicada no host nem no Caddy). A ponte precisa subir antes, porque é ela que cria a rede.
- Caddy, no bloco `fiscal.byescaleira.com`, antes do `file_server`:

```
handle /admin* {
	reverse_proxy 127.0.0.1:3120
}
```

## Runbook

Atualizar (depois de copiar os arquivos):

```bash
cd /opt/fiscal-admin && docker compose up -d --build
docker compose logs --tail=50 fiscal-admin
```

Primeiro acesso:

1. `cd /opt/fiscal-admin && docker compose logs fiscal-admin | grep "setup code"` mostra o código de uso único (vale 30 minutos e só aparece uma vez por início do serviço). Se expirar: `docker compose restart fiscal-admin` e ler de novo.
2. Abrir `https://fiscal.byescaleira.com/admin/setup`, digitar o código, criar a senha (mínimo 14 caracteres) e registrar a passkey.
3. Depois disso `/admin/setup` responde 404 e o login pede senha **e** passkey.

Trocar a senha ou perder a passkey: `rm /opt/fiscal-admin/secrets/auth.json && docker compose restart fiscal-admin` e repetir o primeiro acesso.

Chave do CloudKit:

1. Gerada na VPS: `openssl ecparam -name prime256v1 -genkey -noout -out secrets/cloudkit.pem`, `chmod 600`, dono 1000.
2. Chave pública para o CloudKit Console: `openssl ec -in secrets/cloudkit.pem -pubout`.
3. No CloudKit Console, container `iCloud.fiscal` › API Access › Server-to-Server Keys › nova chave com essa pública. Copiar o Key ID para `CLOUDKIT_KEY_ID` no `.env` e rodar `docker compose up -d`.
4. A chave do servidor não cria schema: criar no Console (Development) o tipo `FeatureFlag` com `name` (String), `isOn` e `rollout` (Int64) e os índices consultáveis de `name` e `recordName`. Produção só depois do **Deploy Schema Changes** (irreversível).

Segurança:

- Cinco erros por IP em 15 minutos bloqueiam o IP por 15 minutos (código de configuração, senha ou passkey).
- Sessão em memória: cookie `fiscal_admin` `HttpOnly; Secure; SameSite=Strict; Path=/admin`, 12 horas, renovada a cada uso. Reiniciar o serviço encerra as sessões.
- Toda requisição que escreve precisa de `Origin: https://fiscal.byescaleira.com`. CSP sem script inline.

Em caso de carga: baixar o rollout da flag `web` em Produção; se não bastar, pausar a ponte na tela Ponte.
