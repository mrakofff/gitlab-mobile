# Code Style — реестр правил glab-ios

Правила кодстайла, проверенные на этом репо; часть — адаптация из
platform, часть — местные прецеденты (см. также
docs/LESSONS_LEARNED.md — камни уровня «поведение API/OS», здесь —
стиль и структура кода).

## Swift и SwiftUI

### Модели API — tolerant reader
Декодинг ответов GitLab — tolerant: незнакомые поля игнорировать
(декодируем только объявленное; `additionalProperties` у GitLab REST
нет). Новые поля модели — optional, если клиент переживает их
отсутствие; required — только то, без чего UI не работает. Разные
инстансы GitLab (gitlab.com и self-hosted разных версий) отдают поля
не одинаково — optional обязателен для всего, что не в ядре ответа.
Проверяется на ревью.

### Эндпоинты — через типизированный слой Core/API
Новый запрос — `GitLabAPIRequest<Response>` в соответствующем
`*Endpoints.swift`, а не сырой URLSession у экрана. Аутентификация и
кэш подключаются автоматически через `GitLabSessionClient`. Сырой
HTTP — только для raw-файлов (уже есть `Core/API` raw-file sessions).

### Модель отделять от view; загрузчик — actor или @MainActor @Observable
Экранный паттерн репо: `XxxModel` (@MainActor @Observable, владеет
состоянием и загрузкой) + `XxxView` (SwiftUI, без сетевой логики).
Лоадеры без UI-состояния — actor. Не смешивать: fetch в body, сетевая
логика в view — на ревью.

### Пагинация — через GitLabPaginatedResourceModel
Списки — `GitLabResourcePage<Item>` + `nextPageURL`; не изобретать
свою offset-пагинацию. Снапшот страниц перед мутациями очереди
(урок LESSONS_LEARNED: снапшотить Todo-страницы до completion'ов).
Не выдавать размер загруженной страницы за общее число.

### Кэш — per-account
Всё, что кэшируется (ответы, аватары, drafts, trace), — ключ по
`GitLabAccountID` (Core/Cache). Новый кэш без аккаунт-скоупа — баг:
данные одного аккаунта утекут в другой.

### Сортировка — локально, не доверять порядку API
GitLab API ordering не гарантирован (LESSONS_LEARNED): сортировать
на клиенте, пиннинг важных элементов — через отдельный запрос и merge
в первую страницу, не рассчитывать на пагинацию.

## UI и DesignSystem

### Компоненты — из Core/DesignSystem, не локальные копии
Пилюли/лейблы — `GitLabResourceViews` (`GitLabLabelPill` и др.),
аватары — `GitLabUserAvatar` + `GitLabAvatarImageLoader`, поиск —
`GitLabSearchField`, состояния — `GitLabContentStateViews`,
клавиатура — `GitLabKeyboardDismissButton`. Локальная копия общего
компонента — на ревью; общее двух экранов — в DesignSystem.

### Цвета — через GlabTheme
`GlabTheme` (GlabCanvas, GlabRaisedSurface, GlabSeparator, GlabList…).
Хардкод `Color(hex:)`/системных цветов в фичевых экранах — на ревью;
новый семантический цвет — добавить в тему. Динамические цвета лейблов
обязательны (урок про HTML attributed strings и dark mode).

### Компактность (AGENTS.md)
Минимум занятого экрана: связанные контролы — одна пилюля, иконка без
текста там, где иконка ясна, сворачиваемое вместо постоянно
развёрнутого. Liquid glass где уместно.

### Поиск — GitLabSearchField в stable safeAreaInset
`.searchable` может смонтировать glass поздно и заменить навигационный
layout при фокусе (LESSONS_LEARNED) — общий филд в `safeAreaInset`.

## Тесты

- Тест только тогда, когда важен сценарий (AGENTS.md): контракты
  декодинга (tolerant reader — да), регрессии багов — да; UI-снапшоты
  и тесты ради покрытия — нет.
- Тесты не зависят от сети: фейковые лоадеры/фикстуры (прецедент
  `GitLabPipelineFixtureJobTraceLoader`).

## Форматирование

- Стиль — как соседний код (AGENTS.md «Match existing style»).
- Новый файл — имя по сущности (`GitLabXxx…` для GitLab-доменных
  типов), раскладка фичи: `Features/<Feature>/` (model + views +
  endpoints рядом), общее — `Core/`.
