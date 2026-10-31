# Barnacle-rus

Русификатор для игры [Barnacle](https://store.steampowered.com/app/4627630/Barnacle/)

Совместимость: Steam build [23511000](https://steamdb.info/patchnotes/23511000/)

1. Скачать [последний релиз](https://github.com/SijyKijy/Barnacle-rus/releases/latest)
2. Установить
3. Запустить игру

`RU / EN` в меню переключает язык
`Shift+E` или `"Скрыть старое"` убирает старейшую реплику с экрана
Звук и надписи внутри изображений не переведены
При высоком DPI может понадобиться уменьшить масштаб интерфейса

Сборка: `python tools/build.py` (Python 3.11+), результат в `dist/`
Проверки: `python tools/test.py --lua lua5.1`

> [!WARNING]  
Каталоги перевода и `docs/GLOSSARY.md` содержат спойлеры
