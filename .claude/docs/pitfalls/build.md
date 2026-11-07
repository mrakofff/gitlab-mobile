# Сборка и Xcode

## xcode-select и first-launch (2026-11-07)
- `xcode-select` может указывать на CommandLineTools — тогда `simctl`
  и `xcodebuild` виснут/не видят симуляторы (`emulator_simctl_unavailable`
  у Orca). Переключить на полный Xcode: `sudo xcode-select -s
  /Applications/Xcode.app/…`.
- `sudo xcodebuild -license accept` и `sudo xcodebuild -runFirstLaunch`
  требуют TTY: через `!`/bash-input в сессии агента падают — просить
  пользователя выполнить в настоящем терминале. Проверка готовности:
  `xcodebuild -checkFirstLaunchStatus` (0 = ок).

## Simulator.app больше нет (Xcode 27)
- В Xcode 27.2 нет Simulator.app — его заменил DeviceHub.app.
  `open -a Simulator` падает; открывать DeviceHub, если нужен
  «родной» симулятор. Но см. simulator.md: DeviceHub глушит ввод Orca.

## DerivedData — переиспользовать (AGENTS.md)
- Постоянный путь `/Users/andrei/orca/glab-ios-derived`; не указывать
  временные — каждая чистая сборка минут пять.
- Лог сборки — в файл (`> /tmp/glab-build.log 2>&1`), читать хвост;
  полные 427-файловые логи в контекст не тащить.

## Тестовый таргет не собирается на Xcode 27.2 (2026-11-07)
- `GlabTests/Features/Pipelines/GitLabTerminalSanitizerTests.swift:25,46` —
  «unable to type-check this expression in reasonable time»; воспроизводится
  стабильно, файл не менялся, `xcodebuild test -only-testing:…` падает на
  сборке всего таргета. Тесты других фич из-за этого не запускаются, пока
  выражения в файле не разбиты на подвыражения (отдельная задача, не в
  скоупе фазы 1). Флаги `-solver-*-threshold` не принимаются.
