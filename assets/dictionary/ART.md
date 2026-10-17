# Подложка словарика

## Текущий непрерывный свиток

После добавления 50 слов конечная иллюстрация больше не растягивается целиком. `lib/dictionary/infinite_paper.dart` рисует непрерывный контур с неровными боковыми краями, уходящими за верхнюю и нижнюю границы экрана. При прокрутке меняется участок контура. Для фактуры берётся только чистая внутренняя часть прежней иллюстрации; верхний и нижний рулоны не повторяются. Фон рисуется отдельно от живого текста. Новых растровых ассетов и генераций в этой итерации нет.

## Иллюстрация предыдущей итерации, источник фактуры

- Итоговый файл: `assets/dictionary/dictionary-scroll.png`, PNG RGBA, 1024 × 1536.
- Способ: встроенный инструмент `image_gen`, редактирование существующей иллюстрации; навык `imagegen`.
- Основа: `main @ 5a124fb:assets/backgrounds/paper.webp`.
- Сохранены: неровный контур бумаги, верхний левый завиток, нижний рулон, тёплая фактура и листья.
- Изменено: прозрачная внешняя область, убраны монеты. Внешний фон игры не изображает свиток, дополнительных рамок и валиков нет.
- Проверка: внешние углы и боковые точки имеют alpha=0; бумага непрозрачна. Исходная иллюстрация не перезаписана.

## Промпт

Edit target: the attached existing blank parchment artwork from a Russian children's fairy-tale financial education game. Produce a production UI background asset, a cutout on genuinely transparent alpha. Preserve the original organic uneven parchment silhouette, hand-painted watercolor texture, warm pale golden cream paper, dark thin irregular ink edge, upper left small curled paper end, diagonal rolled bottom edge and restrained green leaves. IMPORTANT preserve the same single scroll design and approximately 2:3 portrait aspect ratio, with broad light uncluttered interior for live UI text. Remove all dark brown/olive background OUTSIDE the scroll to full transparency. Remove the gold coins at the lower right and reconstruct that area as parchment edge; this is a quiet learning reference, not a treasure collectible. Keep leaves discreet and outside the writing area. No text, no numbers, no symbols, no wax seal, no additional rectangle or inner scroll, no added second border or second roll, no backdrop, no cast background rectangle. The final result must be exactly ONE beautiful organically shaped blank parchment scroll with transparent exterior. Do not change the core original style.
