import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ChatListSearchItemHeader
import AppBundle
import ItemListUI

protocol SliderValue: CVarArg, Equatable {
    var floatValue: Float { get }
    init(_ float: Float)
    var stringValue: String { get }
    static var step: Float { get }
}

extension Int: SliderValue {
    var floatValue: Float { Float(self) }
    var stringValue: String { String(self) }
    static var step: Float { 1.0 }
}

extension Double: SliderValue {
    var floatValue: Float { Float(self) }
    
    var stringValue: String {
        let number = NSNumber(value: self)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US")
        
        if let formatted = formatter.string(from: number) {
            return formatted
        } else {
            return "\(self)"
        }
    }
    
    static var step: Float { 0.01 }
}

class AgeSliderNode<T: SliderValue>: ASDisplayNode {
    private let titleNode: ASTextNode
    private let valueNode: ASTextNode
    public let slider: UISlider

    private let minAgeNode: ASTextNode
    private let maxAgeNode: ASTextNode
    private let type: String
    private let step: Float
    
    public var currentValue: T {
        return T(slider.value)
    }

    init(title: String, type: String, defaultValue: T, minimumValue: T, maximumValue: T, step: Float? = nil) {
        self.type = type
        self.step = step ?? T.step
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(16), textColor: .white)
        self.titleNode.displaysAsynchronously = false

        self.valueNode = ASTextNode()
        self.valueNode.attributedText = NSAttributedString(string: "\(defaultValue.stringValue) \(type)", font: Font.bold(16), textColor: .white)
        self.valueNode.displaysAsynchronously = false

        self.slider = UISlider()
        self.slider.minimumValue = minimumValue.floatValue
        self.slider.maximumValue = maximumValue.floatValue
        self.slider.value = defaultValue.floatValue
        self.slider.tintColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)

        // Кастомизация ползунка: меньший размер с цветным border
        let thumbSize: CGFloat = 16.0
        let borderColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        let thumbImage = generateImage(CGSize(width: thumbSize, height: thumbSize), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            // Рисуем круг с border
            let borderRect = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            let path = UIBezierPath(ovalIn: borderRect)
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(2.0)
            context.addPath(path.cgPath)
            context.strokePath()
            // Белая середина (без просвета)
            let innerRect = CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4)
            let innerPath = UIBezierPath(ovalIn: innerRect)
            context.setFillColor(UIColor.white.cgColor)
            context.addPath(innerPath.cgPath)
            context.fillPath()
        })
        self.slider.setThumbImage(thumbImage, for: .normal)
        self.slider.setThumbImage(thumbImage, for: .highlighted)

        self.minAgeNode = ASTextNode()
        self.minAgeNode.attributedText = NSAttributedString(string: minimumValue.stringValue, font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
        self.minAgeNode.displaysAsynchronously = false

        self.maxAgeNode = ASTextNode()
        self.maxAgeNode.attributedText = NSAttributedString(string: maximumValue.stringValue, font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
        self.maxAgeNode.displaysAsynchronously = false

        super.init()

        self.slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        self.addSubnode(titleNode)
        self.addSubnode(valueNode)
        self.view.addSubview(self.slider)

        self.addSubnode(self.minAgeNode)
        self.addSubnode(self.maxAgeNode)
    }

    override func layout() {
        super.layout()

        let sideInset: CGFloat = 0.0
        let maximumWidth: CGFloat = self.bounds.width
        // let maxHeight: CGFloat = self.bounds.height

        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(x: sideInset, y: 0, width: titleSize.width, height: titleSize.height)

        let valueSize = self.valueNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.valueNode.frame = CGRect(x: maximumWidth - sideInset - valueSize.width, y: 0, width: valueSize.width, height: valueSize.height)

        let sliderWidth = maximumWidth - sideInset * 2.0
        let sliderHeight: CGFloat = 30.0 // Фиксированная высота для слайдера
        let sliderY = titleSize.height
        self.slider.frame = CGRect(x: sideInset, y: sliderY, width: sliderWidth, height: sliderHeight)

        let minSize = self.minAgeNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.minAgeNode.frame = CGRect(x: sideInset, y: sliderY + sliderHeight, width: minSize.width, height: minSize.height)

        let maxSize = self.maxAgeNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.maxAgeNode.frame = CGRect(x: maximumWidth - sideInset - maxSize.width, y: sliderY + sliderHeight, width: maxSize.width, height: maxSize.height)
    }

    @objc private func sliderValueChanged() {
        let rawValue = self.slider.value
        let steppedValue = round(rawValue / step) * step
        let clampedValue = max(slider.minimumValue, min(slider.maximumValue, steppedValue))
        self.slider.value = clampedValue
        let genericValue = T(clampedValue)
        let valueString = genericValue.stringValue
        self.valueNode.attributedText = NSAttributedString(string: "\(valueString) \(type)", font: Font.bold(16), textColor: .white)
        self.setNeedsLayout()
    }
}

class CheckboxNode: ASButtonNode {
    private let checkboxSize: CGSize
    
    init(size: CGSize = CGSize(width: 20, height: 20)) {
        self.checkboxSize = size
        super.init()
        self.updateAppearance()
    }
    
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    private func updateAppearance() {
        let normalImage = UIImage(bundleImageName: "Models/Checkbox")
        let selectedImage = UIImage(bundleImageName: "Models/CheckboxSelected")
        
        self.setImage(normalImage, for: .normal)
        self.setImage(selectedImage, for: .selected)
        self.setImage(selectedImage, for: .highlighted)
    }
}

