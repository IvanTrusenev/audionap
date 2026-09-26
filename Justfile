# Команды разработки AudioNap. Запуск: just <таск> (список: just --list)

# Собрать демона и запустить с аргументами (just daemon --help / --test-once)
daemon *ARGS:
    xcodebuild -project AudioNap.xcodeproj -scheme audionapd build
    BIN=$(find ~/Library/Developer/Xcode/DerivedData -name audionapd -type f -path '*Debug*' | head -1); "$BIN" {{ARGS}}

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
