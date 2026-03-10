# Гайд по переносу кода из divo-ios-dummy в TelegramApp

## Контекст
- **divo-ios-dummy** (`/Users/Surf/Projects/DIVO/divo-ios-dummy`) — standalone iOS проект для разработки DIVO-экранов без Bazel/MTProto
- **TelegramApp** (`/Users/Surf/Projects/DIVO/Tg-Mike/TelegramApp`) — форк Telegram-iOS с интегрированным слоем DIVO
- Разработка ведётся в dummy, периодически переносится в TelegramApp

## Маппинг директорий

| divo-ios-dummy | TelegramApp |
|---|---|
| `App/UI/ProfileScreen/Components/` | `submodules/ProfileScreenUI/Sources/Components/` |
| `App/UI/ProfileScreen/ProfileScreen/` | `submodules/ProfileScreenUI/Sources/ProfileScreen/` |
| `App/UI/ProfileScreen/PublicProfile/` | `submodules/ProfileScreenUI/Sources/PublicProfile/` |
| `App/UI/Events/` | `submodules/EventsUI/Sources/` |
| `App/UI/ModelsFeed/ModelsFeed/` | `submodules/ModelsFeedUI/Sources/ModelsFeed/` |
| `App/UI/ModelsFeed/ShimmerView.swift` | `submodules/TelegramCore/.../Divo/Services/ShimmerView.swift` (!) |
| `App/UI/OnboardingScreen/` | `submodules/OnboardingUI/Sources/` |
| `App/Models/` | `submodules/TelegramCore/.../Divo/Models/` |
| `App/Services/` | `submodules/TelegramCore/.../Divo/Services/` |
| `App/SwiftSignalKit/` | НЕ переносится (уже есть в TelegramApp) |
| `App/App/` (контроллеры навигации) | НЕ переносится (навигация Telegram) |
| `App/Models/DivoStubs.swift` | НЕ переносится (реальные типы в Telegram) |

## Пошаговый алгоритм переноса

### 1. Анализ изменений
```bash
# В dummy-репо: посмотреть что изменилось с последнего переноса
cd /Users/Surf/Projects/DIVO/divo-ios-dummy
git log --oneline <last-migrated-commit>..HEAD
```

### 2. Для НОВЫХ файлов
- Скопировать в соответствующую директорию по маппингу выше
- Добавить `public` access если файл в TelegramCore (модели, сервисы)
- Bazel подхватит автоматически (glob pattern)
- Для нового модуля — создать BUILD файл по образцу существующих

### 3. Для ИЗМЕНЁННЫХ файлов — boilerplate-адаптация
При копировании из dummy в TelegramApp нужно адаптировать:

| dummy (как есть) | TelegramApp (как надо) |
|---|---|
| `context.presentationData` | `context.sharedContext.currentPresentationData.with { $0 }` |
| `var presentationDataDisposable: Any?` | `var presentationDataDisposable: Disposable?` |
| `NavigationBarStrings(back: "Back", close: "Close")` | `NavigationBarStrings(presentationStrings: self.presentationData.strings)` |
| `StatusBarStyle(systemStyle: ...)` | Прямое присвоение `.White` / `.Black` |
| Signal без `.strict()` | Добавить `.strict()` |
| `super.init(...)` с параметрами panel | Убрать `mediaAccessoryPanelVisibility`, `locationBroadcastPanelSource`, `groupCallPanelSource` |
| Без `overallDarkAppearance` | Добавить `overallDarkAppearance: true` в NavigationBarTheme |
| `NavigationBarPresentationData(...)` вручную | `NavigationBarPresentationData(presentationData:)` |
| `import Foundation` / `import UIKit` только | Добавить TelegramApp импорты: `import Postbox`, `import SwiftSignalKit`, `import TelegramCore` и др. |

### 4. Особые случаи

#### ShimmerView
`ShimmerView` и расширения `addShimmerOverlay()`/`removeShimmerOverlay()` живут в **TelegramCore** (не ModelsFeedUI), потому что `ImageLoader` (тоже в TelegramCore) их использует. В dummy ShimmerView лежит в `App/UI/ModelsFeed/`.

#### Access control
Все типы в `Divo/Models/` и `Divo/Services/` должны быть `public` — иначе ProfileScreenUI, EventsUI, ModelsFeedUI не смогут их использовать.

#### EventModel.swift
Использует `TelegramMediaImage` — в dummy это заглушка из DivoStubs, в TelegramApp это реальный тип. Просто копируем файл, тип резолвится автоматически.

### 5. Файлы которые НЕ переносятся
- `App/Models/DivoStubs.swift` — заглушки Telegram-типов, не нужны
- `App/App/*.swift` — навигация (DivoTabBarController, MainTabHost, etc.)
- `App/SwiftSignalKit/` — уже есть в Telegram
- `project.yml`, `divo-ios.xcodeproj` — Xcode-специфичное

### 6. Проверка после переноса
- Собрать проект (см. [QUICKSTART_RU.md](../QUICKSTART_RU.md) — раздел «Сборка»)
- Проверить что все типы доступны (public)
- Проверить что нет циклических зависимостей между модулями

## Типичные ошибки при переносе

### 1. `cannot find type 'X' in scope`
Файл в ProfileScreenUI/EventsUI/ModelsFeedUI использует тип из TelegramCore, но не имеет `import TelegramCore`.
**Решение:** добавить `import TelegramCore` в файл.

### 2. `initializer is inaccessible due to 'internal' protection level`
Структура в TelegramCore объявлена `public`, но не имеет явного `public init`. Swift не генерирует public memberwise init автоматически.
**Решение:** добавить явный `public init(...)` к структуре.

### 3. `'white' / 'whiteLarge' was deprecated in iOS 13.0`
В dummy используются устаревшие стили `UIActivityIndicatorView`.
**Решение:** `.white` → `.medium`, `.whiteLarge` → `.large`.

### 4. `missing argument for parameter 'overallDarkAppearance'`
`NavigationBarTheme` в TelegramApp требует первый параметр `overallDarkAppearance: Bool`, которого нет в dummy.
**Решение:** добавить `overallDarkAppearance: true` первым параметром.

### 5. `extra arguments ... mediaAccessoryPanelVisibility, locationBroadcastPanelSource, groupCallPanelSource`
`super.init(context:navigationBarPresentationData:)` в TelegramApp принимает только 2 параметра, без panel-параметров.
**Решение:** убрать `mediaAccessoryPanelVisibility`, `locationBroadcastPanelSource`, `groupCallPanelSource` из вызова.

### 6. `initializer does not override a designated initializer`
В dummy контроллер имеет `override public init(context:)`, но в TelegramApp базовый класс не имеет такого designated initializer.
**Решение:** убрать `override`.

### 7. `value 'X' was defined but never used`
Закомментированный код оставляет неиспользуемые переменные. С флагом `-warnings-as-errors` это ошибка.
**Решение:** заменить `let x = ...` на `let _ = ...`, `if let x = y` на `if y != nil`.

### 8. `filename "X.swift" used twice`
Файл с таким именем уже существует в другой директории того же модуля.
**Решение:** перед копированием проверять `find submodules/<Module> -name "FileName.swift"`.

### 9. `cannot convert NavigationController to ViewController`
В dummy используются UIKit-паттерны (`modalPresentationStyle`, `present(_:animated:)`), а в TelegramApp навигация через Display framework.
**Решение:** использовать `self.present(vc, in: .window(.root), with: ViewControllerPresentationArguments(...))` или пушить через `NavigationController`.

### 10. Кэш Bazel
После исправления файлов билд может падать с той же ошибкой из-за кэша.
**Решение:** `bazel clean` перед повторным билдом.

## История переносов

### 2026-03-10: Первый полный перенос
- **Коммит в dummy**: `b5c5311` (HEAD на момент переноса)
- **Что перенесено**: всё (22 новых файла + 33 обновлённых)
- **Модули затронуты**: ProfileScreenUI, EventsUI, ModelsFeedUI, TelegramCore, OnboardingUI (новый)
- **Ключевые фичи**: публичный профиль с галереей, похожие модели, шиммеры, пагинация ленты, онбординг, REST API клиент
