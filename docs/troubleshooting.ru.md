# Решение проблем

## Не установлен ReaImGui

- Открой `Extensions -> ReaPack -> Browse Packages...`.
- Установи `ReaImGui: ReaScript binding for Dear ImGui`.
- Перезапусти REAPER.
- Снова запусти `REAPER Audio Tag: Setup`.

## В Actions list нет `REAPER Audio Tag: Setup`

- Если ставил через ReaPack, проверь, что установлен пакет `REAPER Audio Tag`.
- Если использовал manual installer ZIP, снова запусти `Install.command`.
- Обнови или заново открой Actions list.
- Если нужно, вручную загрузи `Scripts/reaper/REAPER Audio Tag - Setup.lua`.

## Setup не может скачать bundled runtime

- Проверь интернет.
- Открой страницу [GitHub Releases](https://github.com/dennech/reaper-audio-tag/releases/latest) и убедись, что release assets доступны.
- Снова запусти `REAPER Audio Tag: Setup`.
- Если release asset скачался частично, удали `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/setup` и снова запусти Setup.

## Setup пишет про checksum mismatch

- Удали `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/setup`.
- Снова запусти `REAPER Audio Tag: Setup`.
- Если mismatch остаётся, проверь, не переписывает ли скачанные архивы прокси, mirror или antivirus tool.

## Отчёт пишет, что сначала нужно запустить Setup

- Запусти `REAPER Audio Tag: Setup`.
- Проверь, что `config.json` существует в `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/`.
- Проверь, что bundled runtime существует в `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/runtime`.

## Runtime ушёл в CPU fallback

- На Apple Silicon это нормально, если `MPS` недоступен или работает нестабильно.
- Runtime специально предпочитает безопасный fallback вместо крэша.

## Скрипт не принимает выбранный item

- Проверь, что выбран ровно один item.
- Проверь, что активный take — аудио, а не MIDI.
- Если окно отчёта уже открыто, не закрывай его: выбери следующий item и нажми `Another`.

## REAPER начинает тормозить при открытии отчёта

- Убедись, что у тебя последняя версия скрипта, и запусти action ещё раз.
- Теперь export готовится пошагово до запуска runtime inference.
- Если просадка остаётся, отметь, начинается ли она на `Preparing audio...`, на `Listening...` или только после появления готового отчёта.

## В compact view не видны цветные иконки

- В текущей версии используются bundled Noto Emoji PNG assets, а не системные emoji.
- Если в чипах виден только текст без иконок, значит image decode или render path в этой сессии REAPER недоступен.
- На качество анализа это не влияет: это только presentation fallback.

## Хочу получить export diagnostics без запуска модели

- Запусти `reaper/REAPER Audio Tag - Debug Export.lua`.
- Он экспортирует выбранный take range, пишет diagnostics log и останавливается до шага Python runtime.

## Я разработчик и хочу сохранить старый source-checkout bootstrap flow

- Используй `scripts/bootstrap.command`.
- `bootstrap.command` теперь нужен только для development и recovery.
- Публичная установка должна идти через ReaPack или manual installer ZIP, а затем через `REAPER Audio Tag: Setup`.
