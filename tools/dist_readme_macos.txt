Рацион — расчёт энергозатрат и суточного рациона
===============================================

Установка
  Перетащите Ration.app в папку «Программы» (Applications).

Первый запуск
  Приложение не подписано сертификатом Apple, поэтому macOS при первом запуске
  сообщит, что не может проверить разработчика. Чтобы открыть:
    1. Попробуйте открыть Ration.app — появится предупреждение, нажмите «Готово».
    2. Откройте «Системные настройки» → «Конфиденциальность и безопасность»,
       внизу рядом с сообщением о Ration нажмите «Всё равно открыть».
  Либо одной командой в «Терминале»:
    xattr -dr com.apple.quarantine /Applications/Ration.app

Системные требования
  macOS 12 Monterey или новее, Mac на Apple Silicon или Intel.

Где хранятся данные
  ~/Library/Containers/com.rationplanner.app/Data/Library/Application Support/com.rationplanner.app/ration_planner.db
  Чтобы сбросить программу к исходному состоянию, удалите этот файл.

Удаление
  Удалите Ration.app из «Программ» и папку ~/Library/Containers/com.rationplanner.app.
