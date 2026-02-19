# Cherry-Pick Руководство

## Настроенные Remote

```bash
origin     - https://github.com/ShagMichail/TelegramApp.git (ваш)
erupakov   - https://github.com/erupakov/Telegram-iOS.git (источник)
```

## Ветки

- **dev** - ваша основная ветка разработки
- **erupakov/feature/legacy** - ветка источника для cherry-pick

## Доступные коммиты для cherry-pick из erupakov/feature/legacy

### Bazel-коммиты:

| Хэш | Сообщение | Файлы |
|-----|-----------|-------|
| `9d2aa61ea0` | Bazel upgrade | .bazelrc, MODULE.bazel, versions.json |
| `74de23c162` | Update bazel and rules | MODULE.bazel, rules, versions.json |
| `dd8040f00c` | Update build system | BUILD.bazel, .vscode/, versions.json |
| `49ae84062b` | Update build system | - |
| `72270d288e` | [Temp] fix local build | - |

## Cherry-Pick Процесс

### 1. Просмотреть коммит

```bash
# Посмотреть изменения в коммите
git show <COMMIT_HASH>

# Посмотреть затронутые файлы
git show <COMMIT_HASH> --stat
```

### 2. Применить коммит

```bash
# Переключиться на dev
git checkout dev

# Применить коммит
git cherry-pick <COMMIT_HASH>

# Или применить несколько коммитов
git cherry-pick <HASH1> <HASH2> <HASH3>
```

### 3. Если возникли конфликты

```bash
# Отменить cherry-pick
git cherry-pick --abort

# Или исправить конфликты и продолжить
# 1. Исправьте конфликты в файлах
# 2. Добавьте исправленные файлы
git add <файлы>

# 3. Продолжите cherry-pick
git cherry-pick --continue
```

### 4. Применить с конкретной стратегией

```bash
# Использовать стратегию "ours" (игнорировать изменения из cherry-pick)
git cherry-pick -X ours <COMMIT_HASH>

# Использовать стратегию "theirs" (принять изменения из cherry-pick)
git cherry-pick -X theirs <COMMIT_HASH>

# Применить без коммита (для ручной проверки)
git cherry-pick --no-commit <COMMIT_HASH>
```

### 5. Отправить изменения

```bash
git push origin dev
```

## Примеры

### Пример 1: Применить обновление Bazel

```bash
git checkout dev
git cherry-pick 9d2aa61ea0
git push origin dev
```

### Пример 2: Применить несколько коммитов

```bash
git checkout dev
git cherry-pick 74de23c162 9d2aa61ea0 dd8040f00c
git push origin dev
```

### Пример 3: Применить с проверкой

```bash
git checkout dev
git cherry-pick --no-commit 9d2aa61ea0
# Проверить изменения
git diff --cached
# Если всё хорошо
git commit -m "Bazel upgrade (cherry-picked from erupakov/feature/legacy)"
git push origin dev
```

## Поиск нужных коммитов

```bash
# Поиск по сообщению коммита
git log erupakov/feature/legacy --oneline --grep="bazel"

# Поиск по файлам
git log erupakov/feature/legacy --oneline -- MODULE.bazel

# Просмотреть все коммиты в ветке
git log erupakov/feature/legacy --oneline -50
```

## Сравнение версий

```bash
# Сравнить MODULE.bazel
git diff dev erupakov/feature/legacy -- MODULE.bazel

# Сравнить .bazelrc
git diff dev erupakov/feature/legacy -- .bazelrc
```

## Отмена cherry-pick

```bash
# Если cherry-pick ещё не закоммичен
git cherry-pick --abort

# Если нужно откатить последний коммит
git revert HEAD
```

## Полезные команды

```bash
# Показать текущий статус cherry-pick
git status

# Показать историю cherry-pick
git reflog | grep cherry

# Сравнить вашу ветку с источником
git log --oneline dev ^erupakov/feature/legacy

# Показать коммиты источника, которых нет у вас
git log --oneline erupakov/feature/legacy ^dev
```

## Рекомендуемый порядок применения

1. Сначала примените коммиты с обновлением правил Bazel:
   ```bash
   git cherry-pick 74de23c162  # Update bazel and rules
   ```

2. Затем общее обновление Bazel:
   ```bash
   git cherry-pick 9d2aa61ea0  # Bazel upgrade
   ```

3. После - обновления build system:
   ```bash
   git cherry-pick dd8040f00c  # Update build system
   ```

4. Проверяйте сборку после каждого cherry-pick:
   ```bash
   bazel build //Telegram:Telegram --//Telegram:disableProvisioningProfiles=true --cpu=ios_sim_arm64 --define=buildNumber=100001 --define=telegramVersion=12.2.2
   ```
