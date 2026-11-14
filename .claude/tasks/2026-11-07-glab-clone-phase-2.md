# Задача: Фаза 2 — Project overview card + проектные пайплайны (s4)

**Статус:** done (коммиты 8770c5c, 2785975 от 2026-11-14)
**План:** ../plans/2026-11-07-glab-clone.md (Фаза 2)
**Создана:** 2026-11-07

+++ ### Цель
Экран проекта — карточка в стиле s4: header (avatar, name, namespace, description), ряд плиток, языковая шкала, action-пилюля Star/Clone/Share/Browser, секция Code с последними коммитами; плюс проектный список пайплайнов с входом из карточки.

+++ ### Скоуп (разрешено трогать)
- Glab/Features/Projects/GitLabProjectDetailView.swift, GitLabProjectDetailModel.swift, LiveGitLabProjectLoader.swift
- Новый Glab/Features/Projects/GitLabProjectOverviewViews.swift
- Новый Glab/Features/Projects/GitLabProjectPipelinesView.swift + GitLabProjectPipelinesModel.swift
- Glab/Features/Pipelines/GitLabPipelineEndpoints.swift: projectPipelines(projectID:)
- Glab/Features/Projects/GitLabProject.swift: аддитивные optional-поля (description, open_issues_count, forks_count)
- Новый эндпоинт languages в Core/API

+++ ### ЗАПРЕЩЕНО трогать
- Core/Session, транспорт, кэши
- Существующий GitLabPipelineDetailView (только push-цель)
- MR/Issues фичи

+++ ### Критерии приёмки
- [x] Карточка проекта: описание, плитки issues/MRs/activity
- [x] Языковая шкала с реальными процентами (GET projects/:id/languages)
- [x] Action-пилюля: Star работает, Clone/Share/Browser доступны
- [x] Секция Code: последние 5 коммитов (author, message, чип ветки)
- [x] Pipelines: проектный список открывается, тап ведёт в существующий detail
- [x] Скриншоты light+dark; сборка зелёная

+++ ### Связи
- blocked-by: phase-1 (табы должны существовать, карточка рендерится из нового Home)
