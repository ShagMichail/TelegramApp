# Локализация

## Где хранятся строки

Все пользовательские строки DIVO-слоя хранятся в одном файле:

```
submodules/TelegramCore/Sources/TelegramEngine/Divo/Services/DivoStrings.swift
```

Поддерживаемые языки: `en`, `ru`, `es`, `pt`, `zh`.

## Как добавить новую строку

1. Открыть `DivoStrings.swift`
2. Добавить `public static var` в подходящую секцию (MARK-комментарии):

```swift
public static var myNewString: String {
    L(en: "English text", ru: "Русский текст", es: "Texto español", pt: "Texto português", zh: "中文文本")
}
```

3. Использовать в коде: `DivoStrings.myNewString`

## Что локализуется

- Заголовки экранов, навбаров, секций
- Тексты кнопок (Save, Cancel, Apply, Create и т.д.)
- Placeholder'ы текстовых полей
- Тексты алертов (ошибки, успех)
- Названия табов и сегментов
- Лейблы параметров (Age, Height, Gender и т.д.)
- Тексты пустых состояний (empty state)
- Тексты загрузки ("Loading...")

## Что НЕ локализуется

- Enum rawValue (технические идентификаторы)
- Cell reuse identifiers
- API пути (`"/event/create"`)
- Форматы дат (`"yyyy-MM-dd"`)
- Print/log сообщения
- Bundle image names
- Единицы измерения в типах (`"y.o"`, `"cm"`, `"kg"`)
- Тестовые данные (`"Some street"`)

## Шрифт HelveticaNeueLTCom-BdCn и CJK

Шрифт `Font.helveticaNeue()` не содержит CJK-глифов. При отображении китайского текста система подставляет fallback-шрифт с большей высотой символов, что приводит к обрезанию текста сверху.

При создании UILabel/UIButton с `Font.helveticaNeue` добавляйте минимальную высоту:

```swift
// UILabel
label.font = Font.helveticaNeue(12)
label.heightAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true

// UIButton
button.titleLabel?.font = Font.helveticaNeue(14)
button.titleLabel?.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
```

Таблица минимальных высот:

| Font size | Min height |
|-----------|------------|
| 10pt      | 20pt       |
| 11pt      | 20pt       |
| 12pt      | 22pt       |
| 13pt      | 24pt       |
| 14pt      | 24pt       |
| 16pt      | 26pt       |
| 18pt      | 30pt       |
| 20pt      | 30pt       |
| 26pt      | 38pt       |
| 30pt      | 42pt       |

Constraint `greaterThanOrEqual` не влияет на латиницу/кириллицу — срабатывает только когда CJK-глифы требуют больше места.

## Смена локали в runtime

При смене языка через дебаг-экран отправляется `DivoStrings.didChangeNotification`. Подписчики должны:

1. Обновить текст (`label.text = DivoStrings.xxx`)
2. Пересчитать layout (`containerLayoutUpdated` или `setNeedsLayout`)
