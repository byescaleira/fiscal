# Cartazes e arte (histórico)

Congelada em 2026-10-29; a verdade atual está em [`spdd/prompt/FSC-005-202610291700-[Codify]-share-cards-and-art.md`](../../spdd/prompt/FSC-005-202610291700-[Codify]-share-cards-and-art.md).

Os cartazes prontos para Stories, feed e mensagem que a pessoa gera a partir de um perfil, uma votação, gastos, uma disputa, uma comparação, uma bancada, um destaque ou uma investigação, e o acervo de obras que veste esses cartazes, com a galeria Artistas (Ajustes › Seu Fiscal e `fiscal://artists`). O que falta fazer está em [backlog.md](../backlog.md).

## Princípios

- **O dado manda; a arte veste.** A obra fica atrás do véu e nunca muda número, cor de partido nem texto.
- **Licença conferida obra a obra, com crédito no cartaz.** Nenhuma obra entra sem a licença checada pelo script e o crédito gravado na imagem.
- **Retrato é ilustração, nunca foto.** Retratos de políticos são desenhados pelo Fiscal a partir de traços cadastrados; nada é decalcado nem gerado por IA a partir da foto.
- **Mesma regra para todos.** O mesmo molde, a mesma arte padrão e o mesmo crédito para qualquer pessoa ou partido.

## Onde fica

| Target | O que fica nele |
| --- | --- |
| `FeatureCore` (`Navigation/`) | `ShareSubject` (os 8 assuntos) |
| `FeatureShare` | `ShareModel`, `ShareCardBuilder` (e `+Groups`), `ShareCardContent`, `ShareCardView`, pôsteres de vitória e de investigação, `ShareArtwork`, `ShareRenderer`, `ShareScreen`, `ArtistsScreen` |
| `FiscalDesignSystem` | `ShareCardTokens`, `SharePosterTokens`, `ShareVictoryTokens`, `PersonPortrait` |
| `FiscalResource` | `art-credits.json` e `Assets/Art.xcassets` (`ArtCatalog`) |
| `scripts/` | `art.py check\|fetch` (domínio público), `art-photos.py` (fotos com licença aberta), `art-works.json`, `art-photos.json` |

## Mecânicas e regras

### Assuntos e formatos

- Assuntos: pessoa, votação, gastos (pessoa e ano), disputa, comparação, bancada da UF, destaque e investigação. A disputa com vencedor vira o cartaz de vitória.
- Vitória e investigação desenham o próprio pôster, sem obra de fundo.

| Formato | Proporção | Tela (pt) | Herói até | Linhas da disputa | Título |
| --- | --- | --- | --- | --- | --- |
| Stories | 9:16 | 360 × 640 | 132 pt | 8 | 4 linhas |
| Feed | 4:5 | 360 × 450 | 96 pt | 5 | 3 linhas |
| Mensagem | 1:1 | 360 × 360 | 72 pt | 3 | 2 linhas |

- O cartaz é desenhado na escala da tela do aparelho (1080 × 1920, 1080 × 1350 e 1080 × 1080 a 3x).
- Fatos e a nota aparecem só no Stories; o QR code some na Mensagem. O QR aponta para `https://fiscal.byescaleira.com/?{tipo}={id}`, com correção de erro M.
- O compartilhamento exporta só a imagem, um PNG chamado `Fiscal.png`, pelo `ShareLink`; nenhum texto vai junto.

### Acervo

| Coleção | Id | Obras | Licença |
| --- | --- | --- | --- |
| Brasil agora | `brasil-agora` | 22 | CC BY-SA 4.0 (fotos do Wiki Loves Earth Brasil) |
| Acervo histórico | `acervo-historico` (`reserve`) | 22 | Domínio público (`PD-Art`, `PD-old-70/80/95/100-expired`, `PD-old-auto-expired`) |

- São 44 obras de 29 artistas. Obra conta como domínio público quando a licença começa com "PD" ou o link da licença tem "publicdomain", e aparece como "Domínio público".
- `python3 -I scripts/art.py check` confere cada obra de domínio público no Wikimedia Commons: licença curta "Public domain" ou "CC0", código `pd` ou `cc0`, a categoria declarada no arquivo, autor morto até 1955 (`deathYearLimit`) e arquivo de imagem com miniatura; uma obra reprovada para tudo, sem baixar nada. O `scripts/verify.sh --full` roda o `check`.
- `scripts/art-photos.py` confere as fotos: licença `cc-by-sa-4.0`, `cc-by-4.0` ou `cc0`, do Wiki Loves Earth Brasil, com autor, sem categoria nem restrição que bloqueie, em JPEG.

### Arte do cartaz

- A coleção padrão do cartaz é o Acervo histórico, quando existe; senão, a coleção da Lente. A obra padrão é a primeira do acervo (`pedro-americo-independencia-ou-morte`); no seletor, as paisagens vão por último.
- Toda obra preenche o fundo do cartaz (`scaledToFill`, recortada) atrás de um véu.

### Crédito

| Onde | Texto |
| --- | --- |
| Cartaz, domínio público | "Arte: {artista}, {obra} ({ano}) · {licença} · {acervo}" |
| Cartaz, licença aberta | "Foto: {autor}, {obra} ({ano}) · {licença}, adaptada · {acervo}" |
| Tela de compartilhar | "{artista} · {obra}, {ano} · {licença}" |
| Galeria Artistas | "Artistas: N · licença conferida obra a obra"; por obra, o chip da licença (verde para domínio público, azul para licença aberta), "{ano} · {acervo}" e os links da licença e da fonte |

- O acervo aparece como "Wikimedia Commons" quando a imagem vem de lá; senão, o nome do detentor.
- Os rodapés da galeria dizem que as fotos recentes têm licença aberta, com crédito e marcadas como adaptadas, e que as obras históricas estão em domínio público porque o autor morreu há mais de 70 anos (Lei 9.610, art. 41).

### Retratos

- Os retratos são desenhados pelo Fiscal (`PersonPortrait`, `PortraitRig`) e congelados como imagem parada no cartaz; o VoiceOver lê "Ilustração de {nome}".
- Os cartazes de vitória e de investigação levam retrato; os outros, não.
- A marca visível "Ilustração do Fiscal" e a regra de não gerar cartaz de candidato com retrato nas 72 h antes e nas 24 h depois de uma votação ainda não existem ([backlog](../backlog.md)).

## Construção

1. **Recursos:** `ArtCatalogTests` e `PortraitLibraryTests` em `FiscalResourceTests`.
2. **Feature:** `ShareModelTests`, `ShareCardBuilderTests`, `SharePosterTests`, `ShareCardSnapshotTests` e `ArtistsModelTests` em `FeatureShareTests`; `PortraitTests` em `FiscalDesignSystemTests`.
3. **Licenças:** `python3 -I scripts/art.py check` no `verify.sh --full`.
4. **Textos:** pt-BR no catálogo.

## O que fica com você

- Aprovar obra nova antes do `art.py fetch` e qualquer arte encomendada, com contrato por escrito ([pesquisa de artistas](../research/2026-10-25-contemporary-artists.md)).

## Histórico

| Data | Mudança ou ADR |
| --- | --- |
| 2026-10-29 | [`app-1.0`](../changes/archive/2026-10-29-app-1.0/proposal.md), com os [cartazes](../changes/archive/2026-10-29-app-1.0/share-cards.md) |
| 2026-10-29 | [`setup-lens-art`](../changes/archive/2026-10-29-setup-lens-art/proposal.md) (substituída) |
