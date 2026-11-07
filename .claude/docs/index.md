# Docs Router — что читать по типу задачи

AGENTS.md автозагружается всегда и держит только каркас. Профилированное
чтение — по таблице; «не читать» — чтобы не жечь контекст на нерелевантных
доках.

| Профиль задачи | Читать обязательно | По надобности | Не читать |
|---|---|---|---|
| `ui-dev` — экран/фича в Glab/Features | AGENTS.md, [code-style.md](code-style.md) (UI-раздел) | [process.md](process.md) (ярусы проверок), LESSONS_LEARNED по затронутой области, исходники переиспользуемых компонентов DesignSystem | GlabTests целиком, Core/API внутренности |
| `api-dev` — модель/эндпоинт в Core/API | [code-style.md](code-style.md) (Swift-раздел) | GitLab API docs (источник истины — AGENTS.md), Core/Cache устройство | фичевые views |
| `session-dev` — аккаунты/сессии/кэши | [code-style.md](code-style.md) (per-account кэш), AppSession.swift | GitLabAccountIndexStore, KeychainGitLabCredentialStore | фичевые views |
| `pipeline-dev` — Pipelines | [code-style.md](code-style.md), список файлов Features/Pipelines | LESSONS_LEARNED (trace/diff пункты), GitLab API pipelines/jobs docs | |
| `planning` — план новой фазы/фичи | [process.md](process.md) (задачи и план), текущий план и задачи в `.claude/plans/` и `.claude/tasks/` | LESSONS_LEARNED целиком (что уже изобретено) | |

Спорный случай (UI + API сразу) — прочитать оба профиля обязательных колонок.
