# Задача: Фаза 9 — MR-флоу (Closed-фильтр + New merge request)

**Статус:** open
**План:** ~/.claude/plans/composed-forging-volcano.md — «Дополнение (2026-11-14)»
**Создана:** 2026-11-14
**Референс:** /Users/andrei/glab-reference r18–r19 (NOTES.md)

+++ ### Цель
Полный список MR проекта (с фильтром Closed) и создание merge request из приложения.

+++ ### Скоуп (разрешено трогать)
- Расширить GitLabProjectMergeRequestState кейсом closed (аддитивно, проверить все switch).
- Список MR проекта: капсула-фильтр Open / Merged / Closed / All, кнопка «+» (r18).
- Новый экран New merge request (sheet, r19): Source branch (пикер, default = default branch), Target branch (default main), Title, Description, toggles «Delete source branch when merged» / «Squash commits when merged», кнопка «Create merge request» disabled до валидности.
- POST merge_requests — аддитивный эндпоинт в Features/MergeRequests endpoints. После создания: dismiss + открыть существующий detail MR.
- Ошибки создания (409/source==target и т.п.) показать на форме.

+++ ### ЗАПРЕЩЕНО трогать
- Core/Session, Core/API (кроме аддитивного POST merge_requests)
- Существующие MR-detail экраны (кроме push-навигации)

+++ ### Критерии приёмки
- [ ] Фильтр Open/Merged/Closed/All переключает список
- [ ] Создание MR реальным POST: задача появляется в списке Open
- [ ] Валидация: source= заблокировано → кнопка disabled
- [ ] Тест на сериализацию тела POST
- [ ] Скриншоты light+dark; сборка зелёная

+++ ### Связи
- источник: NOTES.md r18–r19; GAP.md кластер D
