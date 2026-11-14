# Задача: Фаза 10 — Shell (Home/Inbox/Search) + поиск users + Inbox empty-state

**Статус:** open
**План:** ~/.claude/plans/composed-forging-volcano.md — «Дополнение (2026-11-14)»
**Создана:** 2026-11-14
**Референс:** /Users/andrei/glab-reference r05, r20 (NOTES.md)

+++ ### Цель
Таб-бар как в референсе: Home / Inbox / Search; Todos остаются плиткой на Home и темой Inbox.

+++ ### Скоуп (разрешено трогать)
- Glab/Features/AppShell/SignedInShellView.swift: GitLabAppTab → home/inbox/search (удалить таб todos; проверить все switch по enum). Стеклянная капсула-таббар по центру.
- Миграция Todos-контента: убедиться, что Todos доступны с Home (список проектов из phase-7 модулей) и что старый Todos-экран достижим (Inbox или deep link) — без потери функциональности.
- Новый таб Search: большое поле «Search projects», чипы Projects / Issues / MRs / Users, Recent Projects, карточка ссылок «All Projects / Groups». База — существующий GitLabGlobalSearchView; users — аддитивно (GET /search scope=users или /users).
- Inbox: empty-state «All caught up» в стиле r05 (если phase-3 ещё не реализовала).
- Линт: не оставить мёртвых переходов на таб todos.

+++ ### ЗАПРЕЩЕНО трогать
- Core/Session, Core/API (кроме аддитивного поиска users)
- Todos-модель и экраны (только точка входа)

+++ ### Критерии приёмки
- [ ] Три таба, переключение без потери состояния стеков
- [ ] Todos не потеряли точку входа
- [ ] Поиск users возвращает результаты
- [ ] Inbox empty-state по референсу
- [ ] Скриншоты light+dark; сборка зелёная

+++ ### Связи
- depends-on: phase-3 (Inbox) желателен, но не обязателен — фаза может идти после
- источник: NOTES.md r05, r20; GAP.md кластер E
