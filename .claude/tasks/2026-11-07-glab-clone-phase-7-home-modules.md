# Задача: Фаза 7 — настраиваемый Home (модули) + CI

**Статус:** done (коммит 697e759 от 2026-11-14)
**План:** ../plans/2026-11-07-glab-clone.md — раздел «Дополнение (2026-11-14)»
**Создана:** 2026-11-07. Обновлена: 2026-11-14 (решения по референсу r01–r04)

+++ ### Основание (из описания референса в App Store, v1.2–1.3)
- «You assemble the Home screen yourself»: до 8 модулей — review requests, your MRs, issues, todos, **failed / active / recent pipelines**, recent projects.
- Каждая секция — список или карусель (короткие элементы свайпятся вбок); порядок, содержимое и плотность настраиваются.
- Пресеты Developer / Reviewer / Lead-DevOps пересобирают Home одним тапом.
- Свой layout сохраняется, ненужные секции можно убрать и вернуть.
- «Active builds across all your projects» — живой счётчик запущенных сборок на Home.
- Виджеты (Home/Lock/StandBy) — вне нашего скоупа.

+++ ### Цель
Home собирается из модулей, которые пользователь включает/выключает и упорядочивает в настройках; добавлены CI-плитка в ряд плиток (рядом с Projects) и pipeline-модули (failed / active / recent).

+++ ### Скоуп (разрешено трогать)
- Новый Glab/Features/Home/HomeLayout*.swift: модель модулей (enum + порядок + вкл/выкл + режим list/carousel), хранение per-account в UserDefaults (по GitLabAccountID).
- Glab/Features/Home/HomeView.swift: рендер секций из layout вместо жёсткого порядка; плитка CI.
- Новый экран «Customize Home» (из меню аккаунта/настроек): список модулей с переключателями и перетаскиванием, пресеты Developer / Reviewer / DevOps.
- Новый Glab/Features/Home/HomePipelinesModel.swift + эндпоинт(ы) в Features/Pipelines/GitLabPipelineEndpoints.swift (аддитивно).
- GitLabStatTile: плитка CI (счётчик running; цвет по наличию failed).

+++ ### ЗАПРЕЩЕНО трогать
- Core/Session, транспорт, кэши
- Существующие экраны Pipelines/Projects/MR (только push-цели)
- Виджеты

+++ ### Открытые вопросы (решить до старта)
1. Источник «пайплайны по всем проектам»: в GitLab REST нет глобального списка. Решено (2026-11-14): берём N (≈8–10) недавно активных проектов (`membership=true&order_by=last_activity_at`) и параллельно запрашиваем `projects/:id/pipelines`; конкурентность ограничить, кэш per-account. GraphQL — запасной вариант, если не сойдётся.
2. Плитка CI — решено (2026-11-14): число running, красная точка при failed.
3. Карусель — решено (2026-11-14): делаем сразу (Recent projects, pipeline-модули).

+++ ### Критерии приёмки
- [ ] Настройки Home: включение/выключение и порядок модулей, сохраняется между запусками и отдельно на каждый аккаунт
- [ ] Пресеты Developer / Reviewer / DevOps пересобирают layout
- [ ] Плитка CI рядом с Projects, открывает список пайплайнов (failed/active/recent)
- [ ] Модули Failed / Active / Recent pipelines рендерят реальные данные, строка ведёт в существующий detail пайплайна
- [ ] Скриншоты light+dark; сборка зелёная; точечные тесты на layout (порядок/сериализация)

+++ ### Связи
- depends-on: phase-2 (проектные пайплайны: эндпоинт и строка)
- перекликается с: phase-4 (деталь пайплайна — push-цель)
