# Задачи — индекс

Локальный трекер (Linear пока нет): одна задача = один файл в этом каталоге.
Статусы: `open` → `in-progress` → `in-review` → `done` (пишутся в шапку файла).
Шаблон секций — как в platform (.claude/templates/ticket.md): Цель → Скоуп →
ЗАПРЕЩЕНО → Критерии приёмки → Порядок/Связи/Открытые вопросы. Новая задача —
новый файл `YYYY-MM-DD-<slug>.md`, не дописывание в чужой.

## Активные

| Задача | Статус | Блокирует |
|---|---|---|
| [phase-1 Shell + Home dashboard v2](2026-11-07-glab-clone-phase-1.md) | done | phase-2, phase-3 |
| [phase-2 Project overview + проектные пайплайны](2026-11-07-glab-clone-phase-2.md) | done (8770c5c, 2785975) | — |
| [phase-3 Inbox с фильтр-чипами](2026-11-07-glab-clone-phase-3.md) | open | — |
| [phase-4 Деталь пайплайна + tests](2026-11-07-glab-clone-phase-4.md) | done (6384920) | phase-5 |
| [phase-5 Diff review](2026-11-07-glab-clone-phase-5.md) | open | — |
| [phase-6 Брендинг](2026-11-07-glab-clone-phase-6.md) | open | — |
| [phase-8 Repository browsing (blame/история/теги)](2026-11-14-glab-clone-phase-8-repository-browsing.md) | done (991ea0a, 45aa372) | phase-9 |
| [phase-9 MR-флоу (Closed + New MR)](2026-11-14-glab-clone-phase-9-mr-flow.md) | done (f3902cb) | phase-10 |
| [phase-10 Shell Home/Inbox/Search + поиск users](2026-11-14-glab-clone-phase-10-shell-search.md) | done (4e26078) | phase-4 |

Порядок исполнения (решено 2026-11-14 по референсу r01–r20):
phase-8, phase-9, phase-10, phase-4 (done) → **phase-3**;
phase-3/4/5/6 — из основного плана, вставляются по готовности
(обоснование — в плане ~/.claude/plans/composed-forging-volcano.md, раздел
«Дополнение (2026-11-14)»).

## Готовые

| Задача | Дата | Коммиты |
|---|---|---|
| [phase-1 Shell + Home dashboard v2](2026-11-07-glab-clone-phase-1.md) | 2026-11-07 | e15069e |
| [phase-2 Project overview + проектные пайплайны](2026-11-07-glab-clone-phase-2.md) | 2026-11-14 | 8770c5c, 2785975 |
| [phase-2b Project detail до референса](2026-11-14-glab-clone-phase-2b-project-detail.md) | 2026-11-14 | e4e6dd1, 90c473f |
| [phase-7 Настраиваемый Home + CI](2026-11-07-glab-clone-phase-7-home-modules.md) | 2026-11-14 | 62ff3b9 |
| [phase-8 Repository browsing](2026-11-14-glab-clone-phase-8-repository-browsing.md) | 2026-11-15 | e021e73, 991ea0a, 45aa372 |
| [phase-9 MR-флоу (Closed + New MR)](2026-11-14-glab-clone-phase-9-mr-flow.md) | 2026-11-15 | f3902cb |
| [phase-10 Shell Home/Inbox/Search + поиск users](2026-11-14-glab-clone-phase-10-shell-search.md) | 2026-11-15 | 4e26078 |
| [phase-4 Деталь пайплайна + tests](2026-11-07-glab-clone-phase-4.md) | 2026-11-15 | 6384920 |
