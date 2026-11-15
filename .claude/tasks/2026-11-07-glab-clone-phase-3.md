# Задача: Фаза 3 — Inbox с фильтр-чипами (s3)

**Статус:** done (коммит 96fc84f, смёржено в main 2026-11-15)

**Примечание (2026-11-15):** таб Inbox к моменту реализации занят todos-inbox (фаза 10), поэтому экран реализован отдельным GitLabInboxView с точкой входа «See all» на Home (Assigned MR-модуль). Mentioned — через Todos API (scope=mentioned не существует в API).
**План:** ../plans/2026-11-07-glab-clone.md (Фаза 3)
**Создана:** 2026-11-07

+++ ### Цель
Единый Inbox на месте плейсхолдера фазы 1: MR + issues в одной ленте, скроллящийся ряд фильтр-чипов All / Assigned / Mentioned / Review requested / Build failed, строки с проектом, лейблами и относительным временем.

+++ ### Скоуп (разрешено трогать)
- Новый Glab/Features/Inbox/ (GitLabInboxView, GitLabInboxModel, GitLabInboxFilter, GitLabInboxEndpoints)
- Glab/Features/AppShell/SignedInShellView.swift (подключить таб к реальному экрану)

+++ ### ЗАПРЕЩЕНО трогать
- MergeRequestsModel/существующие лоадеры — только переиспользование
- TodosView
- Core/API (эндпоинты собираются из существующих: merge_requests со scope/reviewer_id, issues)

+++ ### Критерии приёмки
- [ ] Чипы переключают фильтры, активный подсвечен
- [ ] Assigned/Mentioned/Review requested отдают реальных данных
- [ ] Build failed фильтрует по head_pipeline.status на клиенте
- [ ] Тап по строке: MR → MR detail, issue → issue detail
- [ ] Pull-to-refresh; пустые состояния из GitLabContentStateViews
- [ ] Скриншоты light+dark; сборка зелёная
