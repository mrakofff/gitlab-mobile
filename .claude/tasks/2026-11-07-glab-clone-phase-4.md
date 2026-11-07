# Задача: Фаза 4 — Деталь пайплайна + tests summary (s1)

**Статус:** open (блокируется phase-2 — нужен проектный вход в пайплайны)
**План:** ../plans/2026-11-07-glab-clone.md (Фаза 4)
**Создана:** 2026-11-07

+++ ### Цель
Деталь пайплайна — карточка в стиле s1: статус-пилюля + длительность, чипы ветки/deploy, стат-плитки (coverage/duration/range), крупная кнопка Retry failed, Tests-блок с упавшими тестами/сьютами.

+++ ### Скоуп (разрешено трогать)
- Glab/Features/Pipelines/GitLabPipelineDetailView.swift, GitLabPipelineDetailModel.swift
- Новый Glab/Features/Pipelines/GitLabPipelineTestSummary.swift
- Новый эндпоинт test_report в Core/API

+++ ### ЗАПРЕЩЕНО трогать
- LiveGitLabPipelineActionService (только переиспользование retry/cancel)
- GitLabJobTrace* (drill-in как есть)
- Списковые экраны пайплайнов

+++ ### Критерии приёмки
- [ ] Header-карточка: статус, длительность, чипы ветки
- [ ] Стат-плитки coverage/duration/range
- [ ] Retry failed: работает, статус обновляется; green pipeline прячет кнопку
- [ ] Tests-блок: имена упавших тестов из test_report; если отчёт недоступен (self-hosted старше) — fallback на упавшие job'ы
- [ ] Скриншоты light+dark; сборка зелёная

+++ ### Открытые вопросы
- Доступность test_report на целевом инстансе — проверить в начале задачи реальным запросом
