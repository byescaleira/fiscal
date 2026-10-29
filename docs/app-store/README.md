# Página da App Store

Os textos da página do Fiscal na App Store ficam em `metadata.json`, a fonte que é copiada para o App Store Connect. A mídia (capturas, cabeçalho e arte de busca) fica em [media/](media/README.md); o roteiro manual antes do envio, em [../validation.md](../validation.md). Os textos saem do brief do produto (`docs/brief.md`) e têm a mesma mensagem do site `https://fiscal.byescaleira.com`.

## `metadata.json`

```json
{
  "urls": { "support": "...", "marketing": "...", "privacy": "...", "terms": "..." },
  "locales": { "pt-BR": { "name": "", "subtitle": "", "promotionalText": "", "keywords": "", "whatsNew": "", "description": "" } },
  "review": { "notes": "", "contact": "" }
}
```

| Campo | App Store Connect | Limite | Regra |
| --- | --- | --- | --- |
| `urls.support` | App Information › Support URL (por idioma) | URL | `https://fiscal.byescaleira.com/support` |
| `urls.marketing` | Version › Marketing URL (por idioma) | URL | `https://fiscal.byescaleira.com` |
| `urls.privacy` | App Privacy › Privacy Policy URL (por idioma) | URL | `https://fiscal.byescaleira.com/privacy`; sem ela num idioma, o envio é bloqueado |
| `urls.terms` | Descrição (linha final) e `FiscalTermsURL` no `Info.plist` | URL | `https://fiscal.byescaleira.com/terms` |
| `name` | App Information › Name | 30 caracteres | `Fiscal: <benefício>`, um por idioma; precisa estar livre na loja |
| `subtitle` | App Information › Subtitle | 30 caracteres | Benefício que o nome não disse; sem repetir palavras do nome |
| `promotionalText` | Version › Promotional Text | 170 caracteres | Muda sem nova versão; serve para novidades e ofertas |
| `description` | Version › Description | 4000 caracteres | Primeira frase vende; seções curtas; o app é gratuito, sem assinatura; termos e privacidade no fim |
| `keywords` | Version › Keywords | 100 bytes | Separadas por vírgula, sem espaço; sem repetir palavras do nome e do subtítulo; acentos e CJK contam mais de 1 byte |
| `whatsNew` | Version › What's New in This Version | 4000 caracteres | Igual ao `ReleaseNote.current`; na primeira versão o campo não aparece |
| `review.notes` | Version › App Review Information › Notes | 4000 caracteres | Em inglês (abaixo) |
| `review.contact` | Version › App Review Information › Contact | — | E-mail de suporte (`support@byescaleira.com`), nunca o pessoal |

Locale único: `pt-BR` (Portuguese (Brazil), idioma principal), o mesmo do catálogo do app ([ADR 0003](../adr/0003-portuguese-only.md)).

Para conferir os limites antes de colar:

```sh
python3 -c "
import json
limits = {'name': 30, 'subtitle': 30, 'promotionalText': 170, 'description': 4000, 'whatsNew': 4000}
data = json.load(open('docs/app-store/metadata.json'))
for locale, texts in data['locales'].items():
    for field, limit in limits.items():
        if len(texts[field]) > limit:
            print(locale, field, len(texts[field]), '>', limit)
    if len(texts['keywords'].encode()) > 100:
        print(locale, 'keywords', len(texts['keywords'].encode()), 'bytes > 100')
if len(data['review']['notes']) > 4000:
    print('review notes', len(data['review']['notes']), '> 4000')
"
```

## Notas para a revisão

Em inglês, curtas, respondendo o que o revisor precisa para testar sem perguntar:

- O app não pede conta, cadastro nem login; a Lente fica só no aparelho.
- O app é gratuito: sem assinatura, compra no app, anúncio ou paywall.
- O que sai do aparelho e por quanto tempo: token da Atividade ao Vivo da apuração, token de push-to-start do destaque e a chave do App Attest ([ADR 0017](../adr/0017-app-store-privacy-label.md)), coerente com o rótulo de privacidade.
- Por que o app roda em segundo plano: `fetch` para o pacote offline ([ADR 0015](../adr/0015-background-fetch-offline-pack.md)) e `remote-notification` para a sincronização do iCloud. Não há pedido de permissão de notificações: os alertas são Atividades ao Vivo.
- De onde vêm os dados (CDN `dados.fiscal.byescaleira.com` e `fiscal.byescaleira.com/api`) e as explicações no aparelho (Foundation Models, com texto fixo de reserva).
- Neutralidade: nenhum partido em destaque; ícones de partido desligados por padrão ([ADR 0013](../adr/0013-party-symbol-icons.md)).

## Ordem de preenchimento

1. **Contratos:** o contrato de apps gratuitos já vale; o Fiscal não vende nada.
2. **Registro do app:** feito em 26/10/2026. Apple ID `6826982117`, bundle id e SKU `com.byescaleira.fiscal`, idioma principal Portuguese (Brazil), só iOS por enquanto, acesso de todos os usuários. O id já está em `FiscalAppStoreID` no `Info.plist`.
3. **Categorias:** principal **Notícias**, secundária **Referência** (o usuário confirma; nenhuma das duas pede documento extra).
4. **Classificação etária:** questionário em App Information › Age Rating, respondendo "não" a todo conteúdo sensível e "sim" só para acesso irrestrito à web se algum link abrir o navegador dentro do app; o resultado esperado é 4+.
5. **Preço:** gratuito, sem compras no app nem assinatura ([ADR 0011](../adr/0011-free-app-noncommercial-license.md)).
6. **Textos da versão** a partir deste `metadata.json`: nome, subtítulo, texto promocional, descrição, palavras-chave, URLs e "What's New" quando houver. Recarregue a página e confira: alguns campos ignoram valor colado por script.
7. **Mídia** de [media/README.md](media/README.md), na ordem de envio.
8. **Privacidade:** rótulo do [ADR 0017](../adr/0017-app-store-privacy-label.md) ("Identificadores › ID do dispositivo, não vinculado, funcionalidade do app", depois do ok do usuário), URL de privacidade e Content Rights (o app mostra conteúdo de terceiros: dados públicos, checagens CC BY-ND 4.0 e obras com licença conferida).
9. **Disponibilidade** (todos os países exceto a China continental, que exige registro ICP) e **lançamento manual**.
10. **App Review Information:** `review.notes`, o e-mail `review.contact` e um **telefone de contato** que o usuário informa na hora (não fica no repositório); "Sign-in required" desmarcado.
11. **TestFlight › Test Information:** e-mail de feedback (`support@byescaleira.com`), URL de marketing e de privacidade, descrição do beta em pt-BR e as mesmas notas de revisão; o "What to Test" de cada build sai do `ci_scripts/ci_post_xcodebuild.sh` (`TestFlight/WhatToTest.pt-BR.txt`).
12. **Envio:** build do Xcode Cloud, "Add for Review" na versão, com o ok do usuário.
