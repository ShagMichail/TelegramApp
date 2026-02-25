# 🚀 Быстрый старт - Сборка Telegram iOS с Bazel

## Требования

```bash
# Установить Xcode 26.2 из Apple Developer
# Установить Homebrew (если не установлен)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Установить CMake
brew install cmake
```

## Сборка и запуск (5 минут)

### 1. Клонирование

```bash
git clone --recursive -j8 https://github.com/ShagMichail/TelegramApp.git
cd TelegramApp
```

### 2. Настройка конфигурации

```bash
mkdir -p build-input/configuration-repository
cp -r build-system/example-configuration/* build-input/configuration-repository/

cat > build-input/configuration-repository/MODULE.bazel << 'EOF'
module(
    name = "build_configuration",
    version = "1.0.0",
)
EOF
```

### 3. Сборка

```bash
bazel build //Telegram:Telegram \
  --//Telegram:disableProvisioningProfiles=true \
  --cpu=ios_sim_arm64 \
  --define=buildNumber=100001 \
  --define=telegramVersion=12.2.2
```

### 3. Сборка без сертификатов

```bash
bazel build //Telegram:Telegram \
  --define=disableProvisioningProfiles=true \
  --cpu=ios_sim_arm64 \
  --define=buildNumber=100001 \
  --define=telegramVersion=12.2.2
```

### 4. Установка и запуск

```bash
# Запустить симулятор (если не запущен)
xcrun simctl boot "iPhone 16"

# Установить приложение
xcrun simctl install booted bazel-bin/Telegram/Telegram.ipa

# Запустить приложение
xcrun simctl launch booted ph.telegra.Telegraph
```

## 📚 Полная документация

Смотрите [BAZEL_BUILD.md](BAZEL_BUILD.md) для подробных инструкций, решения проблем и настройки CI/CD.

## Часто используемые команды

```bash
# Очистить сборку
bazel clean

# Пересобрать всё
bazel clean --expunge

# Проверить версию Bazel
bazel --version  # Автоматически использует 8.4.2 через Bazelisk
```

## 🛠️ Удобные алиасы для разработки

### Настройка алиасов (рекомендуется)

Добавьте в `~/.zshrc`:

```bash
# Telegram iOS Build Aliases
TELEGRAM_ROOT="/Users/lab/MyTelegramDev/Telegram-iOS"

alias telegram-build='cd $TELEGRAM_ROOT && bazel build //Telegram:Telegram --define=disableProvisioningProfiles=true --cpu=ios_sim_arm64 --define=buildNumber=100001 --define=telegramVersion=12.2.2'

alias telegram-install='xcrun simctl install booted $TELEGRAM_ROOT/bazel-bin/Telegram/Telegram.ipa'

alias telegram-run='xcrun simctl launch booted ph.telegra.Telegraph'

alias telegram-boot='xcrun simctl boot "iPhone 16" 2>/dev/null || true'

alias telegram-build-run='telegram-boot && telegram-build && telegram-install && telegram-run'

alias telegram-clean='cd $TELEGRAM_ROOT && bazel clean --expunge'
```

Применить изменения:
```bash
source ~/.zshrc
```

### Использование алиасов

```bash
# Собрать и запустить на симуляторе (одной командой)
telegram-build-run

# Только собрать
telegram-build

# Установить на запущенный симулятор
telegram-install

# Запустить приложение
telegram-run

# Очистить кэш сборки
telegram-clean
```

## 📱 Запуск в Xcode

Этот проект использует Bazel как основную систему сборки. Для работы в Xcode:

### Вариант 1: Xcode как редактор кода
```bash
# Открыть проект в Xcode для редактирования
open -a Xcode /Users/lab/MyTelegramDev/Telegram-iOS
```

Сборка выполняется через Bazel (см. алиасы выше).

### Вариант 2: Генерация Xcode проекта через Tulsi
```bash
# Клонировать Tulsi
cd /Users/lab/MyTelegramDev/Telegram-iOS
mkdir -p build-system/tulsi
cd build-system/tulsi
git clone https://github.com/bazelbuild/tulsi.git .

# Сгенерировать Xcode проект
cd /Users/lab/MyTelegramDev/Telegram-iOS
sh build-system/generate-xcode-project.sh Telegram
```


## Требования

| ПО | Версия |
|----------|---------|
| Xcode | 26.2 |
| Bazel | 8.4.2 (через Bazelisk) |
| macOS | 26.x |
| CMake | Последняя |
