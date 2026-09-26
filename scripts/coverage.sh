#!/bin/bash
# Прогоняет тесты пакета Shared с профилем покрытия и показывает таблицу.
# Опционально: ./scripts/coverage.sh --html — дополнительно откроет страницу
# с подсветкой строк в браузере.
set -euo pipefail
cd "$(dirname "$0")/../Shared"

BIN=.build/out/Products/Debug/SharedTests.xctest/Contents/MacOS/SharedTests
PROFDATA=.build/out/Products/Debug/codecov/default.profdata

echo "▶ Прогон тестов с покрытием..."
swift test --enable-code-coverage

echo
echo "▶ Покрытие:"
xcrun llvm-cov report "$BIN" -instr-profile "$PROFDATA" \
  -ignore-filename-regex='\.build|Tests'

if [[ "${1:-}" == "--html" ]]; then
  OUT=/tmp/audionap-coverage
  xcrun llvm-cov show "$BIN" -instr-profile "$PROFDATA" \
    -format=html -output-dir="$OUT" -ignore-filename-regex='\.build|Tests'
  open "$OUT/index.html"
fi
