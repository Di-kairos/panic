#!/usr/bin/env bash
# Устанавливает panic в /usr/local/bin с проверкой целостности.
#
# Тянет бинарь и SHA256SUMS из РЕЛИЗНОГО тега (не из ветки main) и проверяет
# хеш ДО установки. Закрывает supply-chain риск «curl|bash из main без проверки»:
# содержимое релизного тега неизменно (в отличие от подвижной main), а хеш ловит
# повреждение, частичную/кэш-подмену и рассинхрон бинаря с публикацией.
# ЧЕСТНО: сумма и бинарь приходят по одному каналу — от подмены САМОГО релиза
# (переписаны оба) это не защищает; для подлинности нужна подпись / Homebrew.
#
# Использование (рекомендуется verify-then-run, см. README):
#   curl -fsSLO https://github.com/Di-kairos/panic/releases/latest/download/install.sh
#   curl -fsSLO https://github.com/Di-kairos/panic/releases/latest/download/SHA256SUMS
#   shasum -a 256 -c SHA256SUMS --ignore-missing   # проверить сам install.sh
#   less install.sh                                  # прочитать глазами
#   bash install.sh
#
# Переменные окружения:
#   PANIC_VERSION   — поставить конкретный тег (напр. 0.1.0). По умолчанию latest.
#   PANIC_BASE_URL  — переопределить источник целиком (для форков/тестов).
#   PANIC_DEST      — путь установки. По умолчанию /usr/local/bin/panic.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "panic работает только на macOS." >&2; exit 1
fi

REPO="Di-kairos/panic"
# Источник: явный PANIC_BASE_URL → конкретный тег PANIC_VERSION → latest-релиз.
if [[ -n "${PANIC_BASE_URL:-}" ]]; then
  BASE_URL="$PANIC_BASE_URL"
elif [[ -n "${PANIC_VERSION:-}" ]]; then
  BASE_URL="https://github.com/${REPO}/releases/download/v${PANIC_VERSION}"
else
  BASE_URL="https://github.com/${REPO}/releases/latest/download"
fi
DEST="${PANIC_DEST:-/usr/local/bin/panic}"

# Временный каталог под загрузку; чистим в любом случае.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Скачиваю panic и SHA256SUMS из релиза..."
curl -fsSL "${BASE_URL}/panic" -o "${TMP}/panic"
curl -fsSL "${BASE_URL}/SHA256SUMS" -o "${TMP}/SHA256SUMS"

# Проверка целостности ДО chmod +x.
echo "Проверяю контрольную сумму..."
if ! ( cd "$TMP" && shasum -a 256 -c SHA256SUMS --ignore-missing ); then
  echo "✗ Контрольная сумма НЕ совпала — установка прервана (возможна подмена)." >&2
  exit 1
fi

# Хеш верный → устанавливаем. Под несписываемый каталог — через sudo.
echo "Устанавливаю в ${DEST}..."
if [[ -w "$(dirname "$DEST")" ]]; then
  install -m 0755 "${TMP}/panic" "$DEST"
else
  sudo install -m 0755 "${TMP}/panic" "$DEST"
fi

echo "Установлено: $DEST"
echo "Дальше: повесь 'panic now' на хоткей (напр. через launchd / Shortcuts)."
