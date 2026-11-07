# Симулятор, Device Hub, Orca

## Device Hub глушит ввод Orca (2026-11-07)
- Пока DeviceHub.app запущен, симулятор игнорирует ввод Orca: `tap`,
  `type`, `gesture` падают `emulator_input_blocked`. Вариант Orca:
  `xcrun simctl spawn <udid> notifyutil -s
  com.apple.coredevice.dtuhidd.active 0` + `kickstart -k
  system/com.apple.backboardd` (закрывает запущенные приложения!), затем
  `orca emulator kill` и `attach` заново.
- Устройство управляется одним хозяином: не смешивать тапы агента и
  клики пользователя в DeviceHub — одновременное управление конфликтует.

## Симулятор может быть выключен, helper — мёртв
- Страница превью отдаёт `Connection refused`, если устройство в
  Shutdown: helper Orca на 3100 не поднят. Диагноз:
  `xcrun simctl list devices booted` + `lsof -nP -iTCP:3100`.
- Подъём заново: `simctl boot <udid>` → `orca emulator attach <udid>
  --worktree id:<id>::<путь>` → `simctl launch <udid> com.dunder.glab`.
  Туннель пользователя пересоединять не нужно — ssh-канал восстановится
  сам, когда порт снова начнёт отвечать.

## Поток и ввод — два разных адреса
- `…/stream.mjpeg` — только картинка, нажатия не проходят (пользователь
  однажды открыл его и решил, что эмулятор «нельзя нажимать»).
  Интерактивная страница — корень `http://127.0.0.1:3100/` (Simulator
  Preview): pointerdown + WebSocket. На MacBook — через туннель
  `ssh -N -L 13100:127.0.0.1:3100 andrei@100.119.100.51`, адрес
  `http://127.0.0.1:13100/`.

## Удалённый просмотр (пользователь на MacBook)
- Orca-панель эмулятора через remote-environment — исследована не до
  конца (pairing «Mobile», интерактивность не подтверждена). Рабочий
  путь на сегодня: ssh-туннель + страница Simulator Preview.
- Ссылки/скриншоты локального хоста (`127.0.0.1`) на MacBook не
  открываются напрямую — всегда через туннель с портом ≠ 3100 (3100
  на стороне хоста занят Orca).

## Скриншоты агента
- `xcrun simctl io <udid> screenshot /tmp/glab-test/<N>.png` — быстрый
  способ увидеть экран без превью-страницы; класть в /tmp/glab-test/
  с номером по порядку.
- Координаты тапов Orca — нормализованные 0..1 (верхний левый угол),
  не пиксели; точки элемента AX — центр фрейма.
