# Задача: Фаза 8 — Repository browsing (blame, история, файл-действия, лог+теги)

**Статус:** open
**План:** ~/.claude/plans/composed-forging-volcano.md — «Дополнение (2026-11-14)»
**Создана:** 2026-11-14
**Референс:** /Users/andrei/glab-reference r10–r15, r17 (NOTES.md)

+++ ### Цель
Достроить работу с файлами и историей репозитория до уровня референса.

+++ ### Скоуп (разрешено трогать)
- Новый Glab/Features/Repository/ файлы (или расширение существующих Repository-):
  - Blame файла: эндпоинт GET /repository/blame (аддитивно в Endpoints), sheet с группировкой по коммитам «автор · sha · время + title», строки кода с номерами.
  - History файла: commits?path= (аддитивный параметр), секции по датам, бейдж «History stops at the last rename of this file.»
  - History проекта: те же секции по датам (r17).
  - Действия файла в blob-view: ряд Copy / Blame / History / Share.
  - Меню файла «…»: Edit, Copy Path / Copy Link / Copy Permalink (SHA), Open in Browser, Add deletion to commit, Delete file — Edit/Delete только при наличии write-доступа и с подтверждением.
  - Карточка файла: MIME · N lines · N bytes.
  - Карточка последнего коммита ветки поверх дерева файлов.
- «Лог коммитов + теги» вместо полного network graph (решено 2026-11-14): вертикальная линия с точками, карточки коммитов, бейджи тегов (v*), чип ветки, toggle All branches. Эндпоинт tags (аддитивно).

+++ ### ЗАПРЕЩЕНО трогать
- Core/Session, Core/API (кроме аддитивных эндпоинтов: blame, tags, commits?path=)
- GitLabDiffRenderer и commit detail (переиспользуем как есть)

+++ ### Критерии приёмки
- [ ] Blame открывается, группировка по коммитам корректна
- [ ] History файла и проекта группируются по датам
- [ ] Copy Path/Link/Permalink кладут правильные значения в буфер
- [ ] Лог коммитов с тегами и переключателем All branches
- [ ] Скриншоты light+dark; сборка зелёная

+++ ### Связи
- depends-on: phase-2b (не строго), переиспользует commit-карточку из фазы 2
- источник: NOTES.md r10–r15, r17; GAP.md кластер C
