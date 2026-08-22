# Quick Toggles — Fase 0

These fixtures freeze the current persisted inputs before the layout refactor. The
expected behavior is intentionally expressed in terms of order, dimensions, and
first-fit packing; no service behavior is part of this baseline.

| Cenário | Entrada | Comportamento esperado |
| --- | --- | --- |
| only-1x1 | cinco toggles 1x1 | preencher a linha atual antes de abrir outra |
| one-by-one-and-two-by-one | 1x1, 2x1, 1x1 | usar a primeira célula livre que comporte cada item |
| slider-after-three-single-cells | três 1x1, slider 4x1, 1x1 | o último 1x1 ocupa a célula restante da primeira linha |
| media-2x2 | media 2x2 e itens menores | bloquear as duas linhas ocupadas pelo media |
| multiple-pages | duas páginas | preservar ordem e conteúdo de cada página |
| partially-empty-page | entrada com `null` e página vazia | ignorar `null` e preservar a página vazia |
| legacy-size-only | somente `size` | migrar para `sizeW`/`sizeH`, sem persistir `size` |
| live-config-baseline | configuração atual do usuário | preservar intenção, ordem e páginas durante a normalização |

Machine-readable inputs live in `fixtures/phase0-scenarios.json`.
