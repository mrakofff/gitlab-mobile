# Задача: Фаза 5 — Diff review (s5)

**Статус:** open (блокируется phase-1…4 — последняя фаза)
**План:** ../plans/2026-11-07-glab-clone.md (Фаза 5)
**Создана:** 2026-11-07

+++ ### Цель
Экран дифф-ревью в стиле s5: word-level подсветка изменений внутри строк, чипы заголовка файла, inline-обсуждения с Resolve/Reply, нижний бар Approve + Merge с comment-полем.

+++ ### Скоуп (разрешено трогать)
- Glab/Features/MergeRequests/GitLabMergeRequestDiffViews.swift, GitLabDiffCollectionView.swift, GitLabDiffRenderer.swift, GitLabDiffSyntaxHighlighter.swift
- Новый Glab/Features/MergeRequests/GitLabDiffReviewBottomBar.swift
- Glab/Features/Discussions/GitLabDiffDiscussionViews.swift

+++ ### ЗАПРЕЩЕНО трогать
- Сервисы approvals/merge/discussions (только переиспользование)
- Модель диффа (GitLabUnifiedDiff) кроме подсветки

+++ ### Критерии приёмки
- [ ] Word-level подсветка внутри изменённых строк
- [ ] Чипы заголовка файла (путь, +/- счётчики)
- [ ] Inline-треды: Resolve и Reply работают на месте
- [ ] Нижний бар: Approve и Merge доступны на подходящем MR, состояния согласованы
- [ ] Comment-поле как keyboard accessory, dismissing по GitLabKeyboardDismissButton
- [ ] Скриншоты light+dark; сборка зелёная
