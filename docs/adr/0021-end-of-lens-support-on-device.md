# 0021. O fim da Lente: apoio só no aparelho, sem efeito na ordem das telas

- **Estado:** Aceito (2026-11-01)
- **Data:** 2026-11-01
- **Mudança:** [FSC-012](../../spdd/prompt/FSC-012-202611012040-[Feat]-end-of-lens-my-support.md)
- **Substitui:** a parte da Lente do [ADR 0004](0004-lens-on-device-store.md) e o trecho sobre ela no ADR 0014

## Contexto

A Lente juntava quem a pessoa apoia, os temas, a ordem das telas, a arte, a paleta e um setup na primeira vez. O usuário decidiu acabar com ela: o conceito não faz mais sentido no app. O apoio segue útil como acompanhamento, e continua sendo dado sensível na LGPD (art. 5º, II, e art. 11).

## Decisão

1. A Lente deixa de existir. O apoio vira uma escolha opcional de até 5 pessoas e até 5 causas, mostrada só na página "Meu apoio".
2. O apoio não muda a ordem, o filtro nem o destaque de nenhuma outra tela. A única outra tela que o usa é a da votação, em "Como quem você apoia votou", que mostra fato.
3. Causa é assunto, não posição. O app nunca diz que alguém votou a favor ou contra uma causa, não calcula alinhamento e não compara apoiados.
4. Pessoas e causas seguem em `Device.store`, sem CloudKit e fora do backup. Nunca vão para servidor, telemetria, notificação, Spotlight, widget, Siri ou cartaz. Só saem na exportação pedida pela pessoa.
5. A `FiscalSchemaV4` é leve: acrescenta `SupportEntity` e mantém `LensEntity`. Na primeira leitura, o `FiscalStore` copia apoiados e temas e apaga a linha antiga. `LensEntity` sai do esquema numa versão futura.
6. O app abre sem setup. A cor de destaque e o ícone ficam só em Aparência.

## Consequências

- A primeira experiência fica mais curta, e nenhuma pergunta política aparece ao abrir.
- O app fica igual para todo mundo fora da página, o que reforça a neutralidade.
- Quem queria ver antes o que importa para si perde a ordem personalizada; o Feed e os seguidos cobrem o acompanhamento.
- A paleta e a arte escolhidas somem; quem testa volta à cor de destaque atual.
- `LensEntity` continua no esquema até uma versão futura.

## Alternativas consideradas

- **Etapa personalizada no `FiscalMigrationPlan`:** copia na migração, mas traz risco num contêiner que também tem CloudKit, sem ganho para um app que ainda não saiu na loja.
- **Manter o apoio ordenando as telas:** preserva parte da Lente e mantém o problema que o usuário quer tirar.
- **Guardar no iCloud privado:** daria o apoio em todos os aparelhos, mas a opinião política sairia do aparelho, contra o brief.
