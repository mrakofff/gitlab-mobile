# План: привести Glab к дизайну референса GLab (App Store)

## Context

Существующий форк smolcars/glab-ios работает (сборка, PAT-вход, мультиаккаунт, Todos, Home), но его UI — двухтабличное приложение (Home + Todos). Пользователь хочет UI, похожий на коммерческий "GLab – Client for GitLab" (id6772132185): dashboard "Needs attention" со счётчиками, inbox с фильтр-чипами, карточку проекта с языковой шкалой, карточку пайплайна с Retry failed и тестами, дифф-ревью с Approve/Merge. Решения пользователя: **форк + свой UI** (Core не трогаем, переписываем экраны), **только для личного пользования**, не публикуем.

Проверено по коду: 427 swift-файлов. Core/API (типизированные `GitLabAPIRequest<Response>`, actor `GitLabSessionClient`, пагинация, per-account кэши), Core/Session (мультиаккаунт), Core/DesignSystem (`GlabTheme`, `GitLabResourceViews`, `GitLabIcon`, `GitLabUserAvatar`) — переиспользуем как есть. Pipelines (27 файлов) доступны только из MR (sheet в `GitLabMergeRequestViews.swift:1102`). `HomeDashboardEndpoints` уже тянет assigned/created MR, review requests, assigned/created issues, recent projects — хватает для всех плиток без новых эндпоинтов.

Юридическая рамка: свой брендинг, дизайн «вдохновлён», не копируем ассеты/название/скриншоты референса.

## Дыры в Core/API (аддитивно, по ходу фаз)

1. Нет `GET /projects/:id/pipelines` — добавить в `GitLabPipelineEndpoints.swift` (`pipelinePath` уже умеет detail/retry/cancel по ID).
2. Нет `GET /projects/:id/languages` — новая модель `GitLabProjectLanguage {name, percentage}` + эндпоинт (цвета назначаем сами).
3. Нет `GET /projects/:id/pipelines/:id/test_report` — новая модель + эндпоинт.
4. `GitLabProject` не декодирует `description`, `open_issues_count`, `forks_count` — аддитивные optional-поля.

## Фаза 1 — Shell + Home dashboard v2 (s2)

- `Glab/Features/AppShell/SignedInShellView.swift`: расширить `GitLabAppTab` → Home / Inbox (плейсхолдер) / Todos.
- Новый `Glab/Core/DesignSystem/GitLabStatTileViews.swift`: `GitLabStatTile` (счётчик + подпись, liquid glass) и ряд 4-в-ряд.
- `Glab/Features/Home/HomeView.swift` + `HomeDashboardViews.swift` + `HomeDashboardModel.swift`: заголовок с хостом инстанса и аватаром аккаунта; плитки MRs / Review / Todos / Projects; секции "Assigned merge requests" (чипы Ready to merge / Merged / Waiting for approval, относительное время) и "My issues"; ссылки "See all" в существующие списки через `GitLabDeepLink`.
- Переиспользуем: `HomeDashboardModel`/`Endpoints`, `GitLabUserAvatar`, `GitLabLabelPill`, относительное время из `GitLabFormatting`.

**Проверка:** сборка + скриншоты Home в симуляторе: реальные счётчики, строки с чипами, тапы по "See all", dark mode.

## Фаза 2 — Project overview card + проектные пайплайны (s4)

- `Glab/Features/Projects/GitLabProjectDetailView.swift` + `GitLabProjectDetailModel.swift` + `LiveGitLabProjectLoader.swift`: карточка (avatar, name, namespace, description), ряд плиток (issues/MRs/activity), языковая шкала, action-пилюля Star / Clone / Share / Browser, секция Code с последними коммитами (author, message, файлы, чип ветки).
- Новый `Glab/Features/Projects/GitLabProjectOverviewViews.swift` + `GitLabProjectPipelinesView.swift` + `GitLabProjectPipelinesModel.swift`.
- Эндпоинты: `languages` (новый), `members/all` (счётчик через `X-Total`), `repository/commits` (есть), `branches` (маленький новый), `projects/:id/pipelines` (новый, из дыр).
- Переиспользуем: star/unstar + `GitLabProjectStarring`, `GitLabProjectViews` (строки, breadcrumbs), существующий `GitLabPipelineDetailView` как цель пуша из нового списка.

**Проверка:** открыть проект: языковая шкала с реальными процентами, Star работает, Pipelines → список → существующий detail.

## Фаза 3 — Inbox с фильтр-чипами (s3)

- Новый `Glab/Features/Inbox/`: `GitLabInboxView/Model/Filter/Endpoints.swift`.
- Чипы: All / Assigned / Mentioned / Review requested / Build failed — скроллящийся ряд в стиле `GitLabLifecycleStatePicker`.
- Эндпоинты: `merge_requests` с `scope=assigned_to_me|mentioned`, `reviewer_id=me`; Build failed — фильтр по `head_pipeline.status` на клиенте. MR + issues склеиваются в один тип строки (проект, лейблы, время).
- Переиспользуем: загрузчики `MergeRequestsModel`, `GitLabContentStateViews` (пустые/ошибочные состояния), `GitLabSearchField`.
- Подключить таб `.inbox` в `SignedInShellView`.

**Проверка:** чипы переключают фильтры, тап по строке открывает существующие detail-экраны, pull-to-refresh.

## Фаза 4 — Деталь пайплайна + tests summary (s1)

- `Glab/Features/Pipelines/GitLabPipelineDetailView.swift` + `GitLabPipelineDetailModel.swift` + новый `GitLabPipelineTestSummary.swift` (+ эндпоинт из дыр): header-карточка (статус-пилюля + длительность), чипы ветки/deploy, стат-плитки (coverage/duration/range), крупная кнопка Retry failed, Tests-блок с упавшими тестами/сьютами.
- Переиспользуем: `LiveGitLabPipelineActionService` (retry/cancel), `GitLabPipelineStage`, `GitLabJobTraceView` для drill-in.
- Fallback: если test_report недоступен на инстансе — показываем упавшие job'ы.

**Проверка:** failed pipeline: карточка, Retry работает и статус обновляется; green pipeline прячет Retry.

## Фаза 5 — Diff review (s5)

- `Glab/Features/MergeRequests/GitLabMergeRequestDiffViews.swift`, `GitLabDiffCollectionView.swift`, `GitLabDiffRenderer.swift`, `GitLabDiffSyntaxHighlighter.swift`: word-level подсветка внутри строк.
- Новый `GitLabDiffReviewBottomBar.swift`: Approve + Merge пилюли + comment accessory (`GitLabKeyboardDismissButton`); чипы заголовка файла.
- Inline обсуждения: `Glab/Features/Discussions/GitLabDiffDiscussionViews.swift` — Resolve/Reply на месте (сервисы approvals/merge/discussions уже есть, эндпоинт не нужен).

**Проверка:** дифф MR: подсветка слов, thread Resolve/Reply, Approve/Merge на подходящем MR.

## Порядок и что не трогаем

Порядок 1 → 2 → 3 → 4 → 5 (каждая фаза самостоятельна и проверяема). Не трогаем: `Core/Session`, транспорт/кэши `Core/API` (кроме аддитивных эндпоинтов выше), job trace, Discussions-модель.

## Верификация

- После каждой фазы: `xcodebuild -project Glab.xcodeproj -scheme Glab -destination 'platform=iOS Simulator,id=4488644D-0A9F-4AEE-A15D-DE4EFC6ADE3B' -derivedDataPath /Users/andrei/orca/glab-ios-derived build` + `simctl` скриншоты; интерактивно через превью-страницу эмулятора (туннель пользователя) или `orca emulator tap`.
- Полный тест-сьют — один раз в конце (по AGENTS.md); точечные тесты только там, где важен сценарий.
- Вести `docs/LESSONS_LEARNED.md` по правилам AGENTS.md.

## Открытые вопросы

- Точный набор query-параметров для плиток Review/Todos — сверить с `HomeDashboardEndpoints` при реализации фазы 1.
- Tests summary: JUnit test_report против упавших job'ов — решить на фазе 4 по данным реального инстанса.
