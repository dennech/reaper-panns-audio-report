# Установка

## Рекомендуемый путь для macOS

### 1. Установи REAPER и ReaPack

1. Установи REAPER `7.x`.
2. Открой REAPER и проверь, есть ли меню `Extensions -> ReaPack -> Browse Packages...`.
3. Если меню нет:
   - скачай ReaPack с [reapack.com](https://reapack.com/)
   - в REAPER открой `Options -> Show REAPER resource path in Finder`
   - положи скачанный файл ReaPack в папку `UserPlugins`
   - перезапусти REAPER

### 2. Добавь репозиторий REAPER Audio Tag в ReaPack

1. В REAPER открой `Extensions -> ReaPack -> Import repositories...`.
2. Добавь URL этого репозитория:

   `https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/index.xml`

3. Открой `Extensions -> ReaPack -> Browse Packages...`.
4. Найди `REAPER Audio Tag`.
5. Установи пакет.

### 3. Установи ReaImGui

1. В ReaPack найди `ReaImGui: ReaScript binding for Dear ImGui`.
2. Установи пакет.
3. Перезапусти REAPER.

Если позже `ReaImGui` всё ещё будет отсутствовать, `REAPER Audio Tag: Setup` и основной action сами отправят тебя обратно в поиск нужного пакета через ReaPack.

### 4. Запусти Setup action

1. Открой Actions list в REAPER.
2. Найди `REAPER Audio Tag: Setup`.
3. Запусти его один раз.
4. Дождись завершения Setup.

Setup автоматически:

- скачивает version-pinned bundled runtime из соответствующего GitHub release
- проверяет checksum скачанного bundle
- устанавливает bundled Python runtime и packaged dependencies в REAPER data directory
- устанавливает pinned checkpoint `Cnn14_mAP=0.431.pth`
- записывает `config.json` в `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/`

В обычном пользовательском сценарии не нужно отдельно ставить Python и не нужно вручную скачивать модель PANNs.

### 5. Запусти отчёт

1. Выбери ровно один аудио-item в REAPER.
2. Найди `REAPER Audio Tag` в Actions list.
3. Запусти action.

## Ручной fallback

Если не хочется ставить через ReaPack:

1. Открой страницу [GitHub Releases](https://github.com/dennech/reaper-audio-tag/releases/latest).
2. Скачай installer ZIP под архитектуру своего Mac.
3. Запусти `Install.command`.
4. Открой REAPER.
5. Запусти `REAPER Audio Tag: Setup`.
6. Запусти `REAPER Audio Tag`.

Этот fallback использует тот же bundled runtime и тот же Setup action. Меняется только способ копирования Lua-скриптов в REAPER.

## Настройка для разработчиков

Разработчики по-прежнему могут использовать source-checkout flow:

1. Клонируй репозиторий.
2. Запусти `scripts/bootstrap.command`.
3. Добавь `reaper/REAPER Audio Tag.lua` в REAPER Actions list.

`bootstrap.command` остаётся developer/recovery-путём. Это больше не основной публичный install entrypoint.

## Где хранятся runtime-данные

- Config: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/config.json`
- Bundled runtime: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/runtime`
- Bundled model: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/models`
- Jobs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/jobs`
- Export temp WAV: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/tmp`
- Export logs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/logs`

В developer checkout по-прежнему может использоваться `<repo>/.local-models`, если `bootstrap.command` запускается из writable source tree.
