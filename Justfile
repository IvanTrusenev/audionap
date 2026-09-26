# Команды разработки AudioNap. Запуск: just <таск> (список: just --list)

# Тесты пакета Shared
test:
    cd Shared && swift test

# Тесты + таблица покрытия
coverage:
    cd Shared && ./Scripts/coverage.sh

# Тесты + HTML-отчёт с подсветкой в браузере
coverage-html:
    cd Shared && ./Scripts/coverage.sh --html
