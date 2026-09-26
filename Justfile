# Команды разработки AudioNap. Запуск: just <таск> (список: just --list)

# Тесты пакета Shared
test:
    cd Shared && swift test

# Тесты + таблица покрытия
coverage:
    ./scripts/coverage.sh

# Тесты + HTML-отчёт с подсветкой в браузере
coverage-html:
    ./scripts/coverage.sh --html
