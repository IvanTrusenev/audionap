# Команды разработки AudioNap. Запуск: just <таск> (список: just --list)

# Автоформат кода пакета (swift-format, канон в .swift-format)
format:
    swift format format --in-place --recursive Shared/Sources Shared/Tests

# Тесты пакета Shared
test:
    cd Shared && swift test

# Тесты + таблица покрытия
coverage:
    ./scripts/coverage.sh

# Тесты + HTML-отчёт с подсветкой в браузере
coverage-html:
    ./scripts/coverage.sh --html
