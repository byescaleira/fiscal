# Mídia da App Store do Fiscal

Capturas de marketing, cabeçalho da página do produto e arte da busca. Os textos da página estão em [../metadata.json](../metadata.json) e o caminho até o envio, em [../README.md](../README.md). Textos das imagens em pt-BR, o único idioma do app e da loja ([ADR 0003](../../adr/0003-portuguese-only.md)), com a mesma mensagem do site e do `metadata.json`. Todas as telas são capturas reais do app no simulador, com os dados de teste dos cenários de Debug; nenhuma tela é redesenhada. O app é gratuito: não há captura de revisão de compra ([ADR 0011](../../adr/0011-free-app-noncommercial-license.md)).

**Sem vídeos** (decisão de 19/10/2026): nada de App Preview, com ou sem música, a não ser que o usuário peça.

## Pastas

| Pasta | Conteúdo | No git |
| --- | --- | --- |
| `iphone/` | Capturas finais do iPhone 6,9" (1320×2868) | sim |
| `iphone-6.3/` | As mesmas, reduzidas para o slot "medium display" (1206×2622) | sim |
| `ipad/` | Capturas finais do iPad 13" (2064×2752) | sim |
| `header/` | Cabeçalho da página do produto | sim |
| `search/` | Arte dos resultados de busca | sim |
| `source/` | `launch.sh`, `compose.py`, `keyart.py`, `render.py` e `style.css` | sim |
| `source/raw/` | Capturas cruas (`iphone/`, `ipad/`) e o ícone exportado (`keyart/icon.png`) | não (`.gitignore`) |

As pastas de saída são criadas pelos scripts; `source/raw/` é criada à mão na primeira captura.

## Tamanhos

| Peça | Tamanho | Campo no App Store Connect | Observação |
| --- | --- | --- | --- |
| iPhone 6,9" | 1320×2868 | iPhone 6.9" Display | PNG RGB, até 10 capturas, legendas de benefício |
| iPhone 6,3" | 1206×2622 | iPhone 6.3" Display (medium display) | mesmas capturas, reduzidas pelo `compose.py` |
| iPad 13" | 2064×2752 | iPad 13" Display | PNG RGB |
| Cabeçalho | 5244×2950 e 3840×1646 | Header | conteúdo numa faixa central com margem larga para cortes |
| Busca | 3840×2560 | Search | componente principal destacado de telas reais |

O lançamento é só iOS: entram iPhone e iPad. Mac e Vision Pro só com capturas reais deles, numa versão futura.

## Ordem de envio

1. **iPhone 6,9"** (`iphone/01-…png` em diante) e **iPhone 6,3"** (`iphone-6.3/`), na mesma ordem. A primeira captura vende o benefício principal do brief; as três primeiras aparecem na busca sem a arte.
2. **iPad 13"** (`ipad/`).
3. **Cabeçalho** (`header/header-5244x2950.png` e `header/header-3840x1646.png`).
4. **Busca** (`search/search-3840x2560.png`).

Envie no idioma Portuguese (Brazil). O navegador do app bloqueia envio de arquivos a partir do App Store Connect: use o Claude in Chrome (`file_upload`, até 10 MB por arquivo). Arte que fica "processando" para sempre: remova e envie de novo.

## Como refazer

1. Build de Debug para o simulador, num cache próprio: `FISCAL_BUILD_ROOT=~/Library/Developer/FiscalBuild-media scripts/build.sh Debug ios`.
2. `scripts/simulator.sh acquire <udid>` (um iPhone de 6,9" para 1320×2868; um iPad de 13" para 2064×2752).
3. `docs/app-store/media/source/launch.sh <udid> fresh` instala o app e abre com `-FiscalDataScenario normal` e `-FiscalLiveScenario finished` (dados de teste do showcase), `-AppleLanguages (pt-BR)` e `-AppleLocale pt_BR`, barra de status 9:41 com Wi-Fi e bateria cheia e aparência clara. Variáveis: `FISCAL_APPEARANCE=dark`, `FISCAL_DATA_SCENARIO` (`normal`, `empty`, `offline`, `longNames`, `unavailable`) e `FISCAL_LIVE_SCENARIO` (por exemplo `close` ou `progressing`). Argumentos extras vão no fim.
4. Navegar pelos deep links (`xcrun simctl openurl <udid> fiscal://...`, lista em [../../architecture.md](../../architecture.md#links)) e capturar com `xcrun simctl io <udid> screenshot docs/app-store/media/source/raw/iphone/<tela>.png` (ou `raw/ipad/`).
5. `python3 docs/app-store/media/source/compose.py [iphone] [ipad]` monta as capturas finais com o Chrome headless: layout e legendas em `IPHONE` e `IPAD` no `compose.py`, estilo em `style.css`. Cada slide diz nome, cor de fundo, se o texto é escuro, título, subtítulo, captura e recortes opcionais em cartões. O `iphone` também grava `iphone-6.3/`.
6. Exportar o ícone para `source/raw/keyart/icon.png` com o `ictool` do Icon Composer (`--export-image --platform iOS --rendition Default --width 1024 --height 1024 --scale 1`) a partir de `Fiscal/Fiscal/FiscalIcon.icon`.
7. `python3 docs/app-store/media/source/keyart.py` gera `header/header-3840x1646.png`, `header/header-5244x2950.png`, `search/search-3840x2560.png` e `search/search-1920x1280.png` (prévia). O cabeçalho é o ícone grande sem texto (nada a traduzir). A busca mostra três iPhones com telas reais e o componente principal de cada uma ampliado por cima: telas e recortes ficam em `SHOWCASE`, em pontos de uma tela de 414 de largura.
8. `scripts/simulator.sh release <udid>` e `xcrun simctl status_bar <udid> clear`.

Requisitos: Google Chrome em `/Applications`, Python 3 com Pillow e as fontes que o `style.css` carrega.

## Antes de enviar

- [ ] Legendas iguais à mensagem do site e do `metadata.json`, sem prometer o que o app não faz e sem anunciar o Fiscal na Web ([ADR 0016](../../adr/0016-web-companion-after-1-0.md)).
- [ ] Nenhum dado pessoal nas capturas; só os cenários de teste.
- [ ] Barra de status 9:41 em todas; nenhuma dica do TipKit ou alerta do sistema na frente.
- [ ] Tamanhos conferidos (`sips -g pixelWidth -g pixelHeight <arquivo>`) e PNG sem transparência.
