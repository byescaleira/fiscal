# Página da App Store

Os textos da página do Fiscal na App Store ficam em `metadata.json`, a fonte que é copiada para o App Store Connect. A mídia (capturas, cabeçalho e arte de busca) fica em [media/](media/README.md); o roteiro manual antes do envio, em [../validation.md](../validation.md). Os textos saem do brief do produto (`docs/brief.md`) e têm a mesma mensagem do site `https://fiscal.byescaleira.com`.

## `metadata.json`

```json
{
  "urls": { "support": "...", "marketing": "...", "privacy": "...", "terms": "..." },
  "locales": { "en-US": { "name": "", "subtitle": "", "promotionalText": "", "keywords": "", "whatsNew": "", "description": "" } },
  "review": { "notes": "", "contact": "" }
}
```

| Campo | App Store Connect | Limite | Regra |
| --- | --- | --- | --- |
| `urls.support` | App Information › Support URL (por idioma) | URL | `https://fiscal.byescaleira.com/support` |
| `urls.marketing` | Version › Marketing URL (por idioma) | URL | `https://fiscal.byescaleira.com` |
| `urls.privacy` | App Privacy › Privacy Policy URL (por idioma) | URL | `https://fiscal.byescaleira.com/privacy`; sem ela num idioma, o envio é bloqueado |
| `urls.terms` | Descrição (linha final) e `FiscalTermsURL` no `Info.plist` | URL | `https://fiscal.byescaleira.com/terms`; diretriz 3.1.2 quando há assinatura |
| `name` | App Information › Name | 30 caracteres | `Fiscal: <benefício>`, um por idioma; precisa estar livre na loja |
| `subtitle` | App Information › Subtitle | 30 caracteres | Benefício que o nome não disse; sem repetir palavras do nome |
| `promotionalText` | Version › Promotional Text | 170 caracteres | Muda sem nova versão; serve para novidades e ofertas |
| `description` | Version › Description | 4000 caracteres | Primeira frase vende; seções curtas; o que é grátis e o que é Pro; termos e privacidade no fim |
| `keywords` | Version › Keywords | 100 bytes | Separadas por vírgula, sem espaço; sem repetir palavras do nome e do subtítulo; acentos e CJK contam mais de 1 byte |
| `whatsNew` | Version › What's New in This Version | 4000 caracteres | Igual ao `ReleaseNote.current`; na primeira versão o campo não aparece |
| `review.notes` | Version › App Review Information › Notes | 4000 caracteres | Em inglês (abaixo) |
| `review.contact` | Version › App Review Information › Contact | — | E-mail de suporte (`support@byescaleira.com`), nunca o pessoal |

Locales, na ordem do arquivo: `en-US` (English U.S., principal), `pt-BR`, `es-ES`, `de-DE`, `fr-FR`, `it`, `ja`, `ko`, `zh-Hans` e `ru`, os mesmos 10 idiomas do catálogo do app.

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

- Se o app pede conta (o padrão é não pedir) e onde ficam os dados.
- O que é grátis, o que é Fiscal Pro (`fiscal.pro.monthly`, `fiscal.pro.yearly`, 7 dias grátis) e onde fica o paywall; restaurar fica no paywall.
- Como chegar a cada compra no app, se houver loja.
- Por que o app pede cada permissão (câmera, rede local, notificações, Face ID).
- Quais serviços externos recebem o quê, coerente com o rótulo de privacidade.
- Como ver dados de exemplo rapidamente.

## Ordem de preenchimento

1. **Contratos:** apps pagos ativo, conta bancária e dados fiscais (usuário).
2. **Registro do app** com o bundle id `com.byescaleira.fiscal` e o `name` em en-US. Copie o id do app para `FiscalAppStoreID` no `Info.plist` antes do build da revisão.
3. **Grupo de assinatura "Fiscal Pro"** com os dois planos e 7 dias grátis; depois as **compras no app**, com os mesmos IDs e preços do `Fiscal.storekit`.
4. **Textos e captura de revisão de cada produto** (`media/review/`).
5. **Testadores de sandbox** em Users and Access › Sandbox ([../subscription-sandbox.md](../subscription-sandbox.md)).
6. **Textos da versão** a partir deste `metadata.json`, idioma por idioma: nome, subtítulo, texto promocional, descrição, palavras-chave, URLs e "What's New" quando houver. Recarregue a página e confira cada idioma: alguns campos ignoram valor colado por script.
7. **Mídia** de [media/README.md](media/README.md), na ordem de envio.
8. **Privacidade:** rótulo ("Dados não coletados" enquanto for verdade) publicado pelo usuário, URL de privacidade em cada idioma, Content Rights.
9. **Disponibilidade** (todos os países exceto a China continental, que exige registro ICP) e **lançamento manual**.
10. **App Review Information** com `review.notes` e `review.contact`; build do Xcode Cloud; "Add for Review" na versão, nas compras e no grupo, no mesmo rascunho.
