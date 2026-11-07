# Задача: Фаза 1 — Shell + Home dashboard v2 (s2)

**Статус:** done
**План:** ../plans/2026-11-07-glab-clone.md (Фаза 1)
**Создана:** 2026-11-07

+++ ### Цель
Главный экран = dashboard «Needs attention» в стиле референса s2: заголовок с хостом инстанса и аватаром аккаунта, 4 счётчиковые плитки, секции Assigned merge requests (с чипами состояний) и My issues; навигация — 3 таба (Home / Inbox-плейсхолдер / Todos).

+++ ### Скоуп (разрешено трогать)
- Glab/Features/AppShell/SignedInShellView.swift (+ GitLabAppTab)
- Glab/Features/Home/HomeView.swift, HomeDashboardViews.swift, HomeDashboardModel.swift
- Новый Glab/Core/DesignSystem/GitLabStatTileViews.swift

+++ ### ЗАПРЕЩЕНО трогать
- Core/Session, Core/API транспорт/кэши
- Todos-фича целиком (только счётчик из её модели)
- Pipelines, Projects, MergeRequests, Discussions

+++ ### Критерии приёмки
- [ ] Таб-бар: Home / Inbox (плейсхолдер) / Todos
- [ ] Home: заголовок = хост инстанса + аватар активного аккаунта, кнопка Account
- [ ] Ряд 4 плиток MRs / Review / Todos / Projects с реальными числами
- [ ] Секция «Assigned merge requests»: строки с чипом состояния (Ready to merge / Waiting for approval) и относительным временем
- [ ] Секция «My issues» с реальными issues
- [ ] «See all» открывает существующие списки
- [ ] Скриншоты light+dark в симуляторе; сборка зелёная

+++ ### Порядок работ
1. GitLabStatTileViews → сборка
2. Табы + плейсхолдер Inbox → сборка
3. Home dashboard v2 → сборка
4. Скриншоты + тап-проверка → доклад пользователю
