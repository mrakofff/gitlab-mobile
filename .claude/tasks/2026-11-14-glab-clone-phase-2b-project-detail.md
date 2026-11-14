# Задача: Фаза 2b — Project detail до уровня референса

**Статус:** open (одобрено 2026-11-14; следующая после закрытия фазы 2)
**План:** ~/.claude/plans/composed-forging-volcano.md — «Дополнение (2026-11-14)»
**Создана:** 2026-11-14
**Референс:** /Users/andrei/glab-reference r06–r09 (NOTES.md)

+++ ### Цель
Довести экран проекта до референса: секция Work, грид Tools, меню «…», сворачиваемый README, верхний бар.

+++ ### Скоуп (разрешено трогать)
- Glab/Features/Projects/GitLabProjectDetailView.swift + Overview-файлы фазы 2:
  - Секция «Work»: строки Merge requests / Issues / Pipelines / Branches / Releases — цветные иконки в скруг-квадратах, счётчик справа, push в существующие списки.
  - Секция «Tools» — грид 4×N: Boards, Labels, Milestones, Tags, Wiki, Activity, Members, Registry, DevOps, Branch Graph, Compare, Snippets. Реальные экраны минимум: Tags, Activity, Members, Labels, Milestones, Branches; остальные — плейсхолдеры (не раздувать скоуп).
  - Меню «…»: Copy Link, Copy Project ID, Compare Branches (push/заглушка).
  - README «Show All» — превью с разворачиванием.
- Верхний бар проекта: back-кружок, «имя / группа» по центру, «…» справа.

+++ ### ЗАПРЕЩЕНО трогать
- Core/Session, Core/API (кроме аддитивных эндпоинтов при необходимости)
- Экраны, реализованные в других фазах

+++ ### Критерии приёмки
- [ ] Work-строки с реальными счётчиками, навигация работает
- [ ] Tools-грид рендерится, минимум 6 пунктов ведут на реальные экраны
- [ ] Меню «…» копирует link/ID
- [ ] README-превью разворачивается/сворачивается
- [ ] Скриншоты light+dark; сборка зелёная

+++ ### Связи
- depends-on: phase-2 (in-review → done/коммит)
- источник референса: NOTES.md r06–r08, GAP.md кластер B
