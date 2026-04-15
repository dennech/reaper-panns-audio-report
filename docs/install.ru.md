# Installation

## Рекомендуемый путь для macOS

### 1. Установи REAPER и ReaPack

1. Установи REAPER `7.x`.
2. Открой REAPER и проверь, есть ли `Extensions -> ReaPack -> Browse Packages...`.
3. Если пункта нет:
   - скачай ReaPack с [reapack.com](https://reapack.com/)
   - в REAPER открой `Options -> Show REAPER resource path in Finder`
   - положи скачанный файл ReaPack в папку `UserPlugins`
   - перезапусти REAPER

### 2. Добавь ReaPack-репозиторий этого проекта

1. В REAPER открой `Extensions -> ReaPack -> Import repositories...`.
2. Добавь:

   `https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/index.xml`

3. Открой `Extensions -> ReaPack -> Browse Packages...`.
4. Найди `REAPER Audio Tag`.
5. Установи пакет.
6. ReaPack также установит встроенный runtime source в `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/runtime/src/`.

### 3. Установи ReaImGui

1. В ReaPack найди `ReaImGui: ReaScript binding for Dear ImGui`.
2. Установи пакет.
3. Перезапусти REAPER.

### 4. Установи Python 3.11

Установи Python `3.11` отдельно.

Рекомендуемый вариант:

- официальный macOS installer с python.org

Потом проверь в Terminal:

```bash
python3.11 --version
```

### 5. Создай локальный venv и установи Python-зависимости

Рекомендуемое место:

```text
~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv
```

Прозрачный ручной путь:

```bash
mkdir -p "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report"
python3.11 -m venv "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv"
source "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/activate"
python -m pip install --upgrade pip
python -m pip install \
  "numpy>=1.26,<2.0" \
  "soundfile>=0.12,<1.0" \
  "torch==2.6.0" \
  "torchaudio==2.6.0" \
  "torchlibrosa==0.1.0"
```

Опциональный helper для source checkout или отдельной загрузки репозитория:

```bash
./scripts/create_local_venv_macos.sh
```

Этот helper остаётся только удобной обёрткой. Он запускается в Terminal, а не внутри REAPER, и не скачивает модель.

### 6. Скачай модель вручную

Нужная модель:

- файл: `Cnn14_mAP=0.431.pth`
- размер: примерно `327 MB`
- sha256: `0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31`

Рекомендуемый источник:

- [Скачать checkpoint с Zenodo](https://zenodo.org/records/3987831/files/Cnn14_mAP%3D0.431.pth)

Проверь checksum:

```bash
shasum -a 256 /path/to/Cnn14_mAP=0.431.pth
```

### 7. Запусти Configure внутри REAPER

1. Открой Actions list.
2. Запусти `REAPER Audio Tag: Configure`.
3. Укажи:
   - Python environment: папку venv, куда установлены зависимости, обычно `.../reaper-panns-item-report/venv`
   - model file: сам файл `Cnn14_mAP=0.431.pth`
4. Нажми `Check Setup`.
5. Нажми `Save Configuration`.

Примеры:

- предпочтительный Python environment: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv`
- expert-путь к Python executable: `/opt/homebrew/bin/python3.11`
- путь к модели: `/path/to/Cnn14_mAP=0.431.pth`

### 8. Запусти отчёт

1. Выбери ровно один audio item.
2. Запусти `REAPER Audio Tag`.

Если конфигурация отсутствует или невалидна, основной action откроет `Configure`.

## Примечания

- `FFmpeg` для текущей версии не нужен.
- REAPER не устанавливает Python за тебя.
- REAPER не скачивает модель за тебя.
- Пока проект использует собственный ReaPack URL напрямую.

## Для разработчиков

Source checkout по-прежнему может использовать:

1. `git clone`
2. создание локального venv вручную или через `scripts/create_local_venv_macos.sh`
3. ручную загрузку `reaper/REAPER Audio Tag.lua`

Это остаётся developer/recovery tooling, а не основным публичным install flow.
