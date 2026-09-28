# Команды разработки AudioNap. Запуск: just <таск> (список: just --list)

# Собрать демона и запустить с аргументами (just daemon --help / --test-once)
daemon *ARGS:
    xcodebuild -project AudioNap.xcodeproj -scheme audionapd build
    BIN=$(find ~/Library/Developer/Xcode/DerivedData -name audionapd -type f -path '*Debug*' | head -1); "$BIN" {{ARGS}}

# Пересобрать демона, развернуть в Application Support и перезапустить агента
# (launchd исполняет копию бинаря — сборка сама её не обновляет)
deploy-daemon:
    xcodebuild -project AudioNap.xcodeproj -scheme audionapd build
    BIN=$(find ~/Library/Developer/Xcode/DerivedData -name audionapd -type f -path '*Debug*' | head -1); cp "$BIN" "$HOME/Library/Application Support/AudioNap/audionapd"
    # Stamp the version marker so the app's DaemonInstaller doesn't overwrite the dev copy
    echo "0.1.0" > "$HOME/Library/Application Support/AudioNap/audionapd.version"
    launchctl kickstart -k gui/$(id -u)/online.threealab.audionap.daemon
    tail "$HOME/Library/Logs/AudioNap/daemon.log"

# Автоформат кода пакета (swift-format, канон в .swift-format)
format:
    swift format format --in-place --recursive Shared/Sources Shared/Tests Daemon

# Тесты пакета Shared
test:
    cd Shared && swift test

# Тесты + таблица покрытия
coverage:
    ./scripts/coverage.sh

# Тесты + HTML-отчёт с подсветкой в браузере
coverage-html:
    ./scripts/coverage.sh --html
